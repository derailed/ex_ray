defmodule ExRay.Mixfile do
  use Mix.Project

  def project do
    [
      app:               :ex_ray,
      version:           "0.1.3",
      description:       description(),
      source_url:        "https://github.com/derailed/ex_ray",
      package:           package(),
      docs:              docs(),
      elixir:            "~> 1.5",
      start_permanent:   Mix.env == :prod,
      deps:              deps(),
      test_coverage:     [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls:        :test,
        "coveralls.html": :test
      ],
      dialyzer:          [plt_add_deps: :transitive]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:otter         , "~> 0.4.0"},
      {:ex_doc        , "~> 0.18.1", only: :dev, runtime: false},
      {:dogma         , "~> 0.1.15", only: :dev},
      {:credo         , "~> 0.8"   , only: [:dev, :test], runtime: false},
      {:excoveralls   , "~> 0.7.4" , only: :test},
      {:mix_test_watch, "~> 0.3"   , only: :dev, runtime: false},
      {:dialyxir      , "~> 0.5"   , only: [:dev], runtime: false}
    ]
  end

  defp description do
    """
    ExRay enables tracing for your Elixir/Phoenix applications using
    OpenTracing powered by Otter.
    """
  end

  defp package do
    [
      licenses:    ["Apache 2.0"],
      organization: "Imhotep Software",
      maintainers: ["Fernand Galiana"],
      files:       ["lib", "mix.exs", "README.md"],
      links:       %{"GitHub" => "https://github.com/derailed/ex_ray"}
    ]
  end

  defp docs do
    [
      main:   "ExRay",
      logo:   "assets/xray.png",
      extras: ["README.md"]
    ]
  end
end
