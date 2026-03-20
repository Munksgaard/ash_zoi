defmodule AshZoi.MixProject do
  use Mix.Project

  def project do
    [
      app: :ash_zoi,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      name: "AshZoi",
      description: "Bridge Ash types and resources to Zoi validation schemas",
      source_url: "https://github.com/munksgaard/ash_zoi",
      package: package(),
      docs: docs(),
      deps: deps()
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"]
    ]
  end

  defp package do
    [
      maintainers: ["Philip Munksgaard"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/munksgaard/ash_zoi"}
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ash, "~> 3.0"},
      {:zoi, "~> 0.17.3"},
      {:ex_doc, "~> 0.35", only: :dev, runtime: false}
    ]
  end
end
