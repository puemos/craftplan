defmodule Craftplan.Storage.S3 do
  @moduledoc false
  @behaviour Waffle.StorageBehavior

  alias ExAws.S3

  @impl true
  defdelegate put(definition, version, file_and_scope), to: Waffle.Storage.S3

  @impl true
  defdelegate delete(definition, version, file_and_scope), to: Waffle.Storage.S3

  @impl true
  def url(definition, version, file_and_scope, options \\ []) do
    public_url = Application.get_env(:craftplan, :s3_public_url)

    if public_url && Keyword.get(options, :signed, false) do
      endpoint = public_endpoint!(public_url)

      config =
        :s3
        |> ExAws.Config.new()
        |> Map.merge(%{
          scheme: endpoint.scheme <> "://",
          host: endpoint.host,
          port: endpoint.port
        })

      bucket =
        case definition.bucket(file_and_scope) do
          {:system, name} -> System.fetch_env!(name)
          name -> name
        end

      key = Waffle.Storage.S3.s3_key(definition, version, file_and_scope)
      options = Keyword.put_new(options, :expires_in, options[:expire_in] || 300)
      {:ok, url} = S3.presigned_url(config, :get, bucket, key, options)
      url
    else
      Waffle.Storage.S3.url(definition, version, file_and_scope, options)
    end
  end

  defp public_endpoint!(url) do
    endpoint = URI.new!(url)

    if !(endpoint.scheme in ["http", "https"] && endpoint.host &&
           endpoint.path in [nil, "", "/"] && is_nil(endpoint.query) &&
           is_nil(endpoint.fragment) && is_nil(endpoint.userinfo)) do
      raise ArgumentError,
            "AWS_S3_PUBLIC_URL must be an HTTP(S) endpoint without a path or credentials"
    end

    endpoint
  end
end
