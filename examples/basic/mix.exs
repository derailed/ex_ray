defmodule Basic.Mixfile do
  use Mix.Project

  def project do
    [
      app:             :basic,
      version:         "0.1.0",
      elixir:          "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps:            deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Basic.Application, []}
    ]
  end

  defp deps do
    [
      {:ex_ray , path: "../.."},
      {:ibrowse, "~> 4.4.0"}
    ]
  end
end
