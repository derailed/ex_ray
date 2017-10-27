defmodule Nested.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    ExRay.Store.create

    children = [ ]

    opts = [strategy: :one_for_one, name: Nested.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
