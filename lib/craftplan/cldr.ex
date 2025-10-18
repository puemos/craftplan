defmodule Craftplan.Cldr do
  @moduledoc false
  use Cldr,
    otp_app: :craftplan,
    locales: ["en"],
    default_locale: "en",
    json_library: Jason,
    providers: [Cldr.Number],
    precompile_number_formats: ["¤¤#,##0.##"]
end
