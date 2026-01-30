sdl = Absinthe.Schema.to_sdl(CraftplanWeb.Schema)

File.write!("docs/public/schema.graphql", sdl)
IO.puts("Generated docs/public/schema.graphql")
