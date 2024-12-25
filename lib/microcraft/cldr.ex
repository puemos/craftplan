defmodule Microcraft.Cldr do
  use Cldr,
    otp_app: :microcraft,
    locales: ["en"],
    default_locale: "en",
    json_library: Jason,
    providers: [Cldr.Number],
    precompile_number_formats: ["¤¤#,##0.##"]
end
