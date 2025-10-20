defmodule Mix.Tasks.Craftplan.Organizations.Create do
  @shortdoc "Provision a new Craftplan organization"

  @moduledoc """
  Mix task to provision a new organization via `Craftplan.Organizations.Provisioning`.
  """
  use Mix.Task

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          name: :string,
          slug: :string,
          billing_plan: :string,
          status: :string,
          timezone: :string,
          locale: :string
        ],
        aliases: [n: :name, s: :slug]
      )

    opts
    |> validate_required!(:name)
    |> do_provision()
  end

  defp do_provision(opts) do
    attrs =
      opts
      |> Map.new()
      |> Map.update(:billing_plan, nil, &maybe_to_atom/1)
      |> Map.update(:status, nil, &maybe_to_atom/1)

    case Craftplan.Organizations.Provisioning.provision(attrs) do
      {:ok, organization} ->
        Mix.shell().info("Created organization #{organization.name} (#{organization.slug})")

      {:error, error} ->
        Mix.raise("Failed to create organization: #{Exception.message(error)}")
    end
  end

  defp maybe_to_atom(nil), do: nil
  defp maybe_to_atom(value), do: String.to_existing_atom(value)

  defp validate_required!(opts, key) do
    case Keyword.fetch(opts, key) do
      {:ok, value} when value not in [nil, ""] -> opts
      _ -> Mix.raise("Missing required --#{key} option")
    end
  end
end
