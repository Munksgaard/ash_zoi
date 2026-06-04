defmodule AshZoi.MixProject do
  use Mix.Project

  def project do
    [
      app: :ash_zoi,
      version: "0.2.1",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      name: "AshZoi",
      description: "Bridge Ash types and resources to Zoi validation schemas",
      source_url: "https://github.com/Munksgaard/ash_zoi",
      package: package(),
      docs: docs(),
      deps: deps()
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md", "LICENSE"]
    ]
  end

  defp package do
    [
      maintainers: ["Philip Munksgaard"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/Munksgaard/ash_zoi",
        "Changelog" => "https://hexdocs.pm/ash_zoi/changelog.html"
      }
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

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
      {:ash_money, "~> 0.2", optional: true},
      {:zoi, "~> 0.17.3"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.35", only: :dev, runtime: false}
    ]
  end
end
