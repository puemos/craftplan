# This is a configuration file for igniter.
# For option documentation, see https://hexdocs.pm/igniter/Igniter.Project.IgniterConfig.html
# To keep it up to date, use `mix igniter.setup`
[
  module_location: :outside_matching_folder,
  extensions: [{Igniter.Extensions.Phoenix, []}],
  source_folders: ["lib", "test/support"],
  dont_move_files: [~r"lib/mix"]
]
