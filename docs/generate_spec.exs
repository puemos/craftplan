domains = CraftplanWeb.JsonApiRouter.domains()

spec =
  AshJsonApi.OpenApi.spec(
    domains: domains,
    open_api_title: "Craftplan API",
    open_api_version: "0.1.0"
  )

# Redoc cannot handle hyphens in $ref tokens, so replace them with underscores.
json =
  spec
  |> Jason.encode!(pretty: true)
  |> String.replace(~r/"#\/components\/schemas\/([^"]+)"/, fn match ->
    String.replace(match, "-", "_")
  end)

# Also rename the schema keys themselves.
decoded = Jason.decode!(json)

schemas =
  decoded
  |> get_in(["components", "schemas"])
  |> Enum.map(fn {k, v} -> {String.replace(k, "-", "_"), v} end)
  |> Map.new()

# Fill in any dangling $ref targets with a permissive object schema.
# AshJsonApi sometimes omits schemas for embedded types used as action inputs.
ref_pattern = ~r/"\#\/components\/schemas\/([^"]+)"/
all_refs =
  ref_pattern
  |> Regex.scan(json)
  |> Enum.map(fn [_, name] -> name end)
  |> Enum.uniq()

address_schema = %{
  "type" => "object",
  "properties" => %{
    "street" => %{"type" => "string"},
    "city" => %{"type" => "string"},
    "state" => %{"type" => "string"},
    "zip" => %{"type" => "string"},
    "country" => %{"type" => "string"}
  },
  "additionalProperties" => false
}

schemas =
  Enum.reduce(all_refs, schemas, fn ref, acc ->
    if Map.has_key?(acc, ref) do
      acc
    else
      IO.puts("Adding stub schema: #{ref}")
      Map.put(acc, ref, address_schema)
    end
  end)

decoded = put_in(decoded, ["components", "schemas"], schemas)

# Set a default server so the "Try it" feature works out of the box.
decoded =
  Map.put(decoded, "servers", [
    %{"url" => "http://localhost:4000", "description" => "Local development"}
  ])

File.write!("docs/public/openapi.json", Jason.encode!(decoded, pretty: true))
IO.puts("Generated docs/public/openapi.json")
