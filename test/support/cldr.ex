defmodule AshZoi.Test.Cldr do
  use Cldr, locales: ["en"], default_locale: "en", providers: [Cldr.Number]
end
