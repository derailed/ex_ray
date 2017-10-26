defmodule Basic.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    ExRay.Store.create

    children = [
    ]

    opts = [strategy: :one_for_one, name: Fred.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
