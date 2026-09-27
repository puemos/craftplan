ExUnit.start()

for app <- [:ex_aws, :hackney, :sweet_xml, :waffle], do: Application.ensure_all_started(app)

System.put_env(%{
  "DATABASE_URL" => "ecto://unused:unused@localhost/unused",
  "SECRET_KEY_BASE" => String.duplicate("integration-test", 8),
  "TOKEN_SIGNING_SECRET" => "integration-test",
  "CLOAK_KEY" => Base.encode64(:binary.copy(<<0>>, 32)),
  "AWS_S3_SCHEME" => "http://",
  "AWS_S3_HOST" => "127.0.0.1",
  "AWS_S3_PORT" => System.fetch_env!("STORAGE_TEST_PORT"),
  "AWS_S3_PUBLIC_URL" => "http://localhost:#{System.fetch_env!("STORAGE_TEST_PORT")}"
})

"config/runtime.exs"
|> Config.Reader.read!(env: :prod, target: :host)
|> Application.put_all_env()

defmodule Craftplan.StorageIntegrationTest do
  use ExUnit.Case, async: false

  alias Craftplan.Catalog.Product.Photo
  alias ExAws.S3

  @tag timeout: 180_000
  test "real MinIO migration, Waffle photos, public signatures, persistence and deletion" do
    bucket = System.fetch_env!("AWS_S3_BUCKET")
    port = "STORAGE_TEST_PORT" |> System.fetch_env!() |> String.to_integer()
    endpoint = [scheme: "http://", host: "127.0.0.1", port: port, region: "us-east-1"]
    assert Application.fetch_env!(:ex_aws, :s3) == endpoint
    assert Application.fetch_env!(:waffle, :storage) == Craftplan.Storage.S3

    source = [
      scheme: "http://",
      host: "127.0.0.1",
      port: "MINIO_TEST_PORT" |> System.fetch_env!() |> String.to_integer(),
      access_key_id: System.fetch_env!("MINIO_ROOT_USER"),
      secret_access_key: System.fetch_env!("MINIO_ROOT_PASSWORD"),
      region: "us-east-1"
    ]

    assert {:ok, _} = bucket |> S3.put_bucket("us-east-1") |> ExAws.request(source)
    product = %{id: "existing-product"}

    directory =
      Path.join(System.tmp_dir!(), "craftplan-storage-#{System.unique_integer([:positive])}")

    File.mkdir_p!(directory)
    on_exit(fn -> File.rm_rf!(directory) end)
    photo = Path.join(directory, "existing photo.png")
    {_, 0} = System.cmd("convert", ["-size", "32x32", "xc:red", photo])

    Application.put_env(:ex_aws, :s3, source)
    assert {:ok, filename} = Photo.store({photo, product})

    keys =
      for version <- [:original, :thumb],
          do: "uploads/products/#{product.id}/existing photo_#{version}.png"

    objects = [
      {"nested/space + café.txt", "legacy metadata"},
      {"empty", ""},
      {"large", :binary.copy(<<123>>, 6 * 1024 * 1024)}
    ]

    for {key, body} <- objects do
      assert {:ok, _} =
               bucket
               |> S3.put_object(key, body,
                 content_type: "application/octet-stream",
                 meta: [origin: "minio"]
               )
               |> ExAws.request(source)
    end

    original =
      Map.new(keys ++ Enum.map(objects, &elem(&1, 0)), fn key ->
        {:ok, %{body: body}} = bucket |> S3.get_object(key) |> ExAws.request(source)
        {key, body}
      end)

    Application.put_env(:ex_aws, :s3, endpoint)
    migrate!()

    assert {:ok, _} =
             bucket
             |> S3.put_object("nested/space + café.txt", "broken metadata")
             |> ExAws.request()

    {_, status} =
      System.cmd(
        "docker",
        [
          "compose",
          "-f",
          "test/integration/docker-compose.yml",
          "run",
          "--rm",
          "--entrypoint",
          "rclone",
          "storage-migrate",
          "check",
          "old:#{bucket}",
          "new:#{bucket}",
          "--download",
          "--one-way"
        ],
        stderr_to_stdout: true
      )

    assert status != 0
    migrate!()

    for {key, body} <- original do
      assert {:ok, %{body: ^body}} = bucket |> S3.get_object(key) |> ExAws.request()
      assert {:ok, %{body: ^body}} = bucket |> S3.get_object(key) |> ExAws.request(source)
    end

    {:ok, %{headers: headers}} =
      bucket |> S3.head_object("nested/space + café.txt") |> ExAws.request()

    assert Enum.any?(headers, fn {name, value} ->
             String.downcase(name) == "x-amz-meta-origin" && value == "minio"
           end)

    Application.put_env(:craftplan, :s3_public_url, "http://localhost:#{port}")

    for version <- [:original, :thumb] do
      url = Photo.url({filename, product}, version, signed: true)
      assert URI.parse(url).host == "localhost"
      assert {:ok, 200, _, body} = :hackney.get(url, [], "", [:with_body])
      assert body == original["uploads/products/#{product.id}/existing photo_#{version}.png"]
    end

    assert {:ok, status, _, _} =
             :hackney.get("http://localhost:#{port}/#{bucket}/empty", [], "", [:with_body])

    assert status in [401, 403]

    assert {:error, _} =
             bucket
             |> S3.put_object("unauthorized", "no")
             |> ExAws.request(secret_access_key: "wrong-secret")

    new_product = %{id: "new-product"}
    assert {:ok, new_filename} = Photo.store({photo, new_product})
    compose!(["restart", "seaweedfs"])
    compose!(["up", "-d", "--wait", "seaweedfs"])

    {address, 0} =
      System.cmd("docker", [
        "compose",
        "-f",
        "test/integration/docker-compose.yml",
        "port",
        "seaweedfs",
        "9000"
      ])

    port = address |> String.trim() |> String.split(":") |> List.last() |> String.to_integer()
    Application.put_env(:ex_aws, :s3, Keyword.put(endpoint, :port, port))
    Application.put_env(:craftplan, :s3_public_url, "http://localhost:#{port}")

    for {key, body} <- original do
      assert {:ok, %{body: ^body}} = bucket |> S3.get_object(key) |> ExAws.request()
    end

    url = Photo.url({new_filename, new_product}, :thumb, signed: true)
    assert {:ok, 200, _, _} = :hackney.get(url, [], "", [:with_body])
    assert :ok = Photo.delete({new_filename, new_product})

    for version <- [:original, :thumb] do
      assert {:error, {:http_error, 404, _}} =
               bucket
               |> S3.get_object("uploads/products/new-product/existing photo_#{version}.png")
               |> ExAws.request()
    end
  end

  defp migrate!, do: compose!(["run", "--rm", "storage-migrate"])

  defp compose!(args) do
    {output, status} =
      System.cmd("docker", ["compose", "-f", "test/integration/docker-compose.yml" | args], stderr_to_stdout: true)

    assert status == 0, output
    IO.puts(output)
  end
end
