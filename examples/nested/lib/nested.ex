defmodule Nested do
  use ExRay, pre: :before_fun, post: :after_fun

  require Logger

  alias ExRay.Span

  @req_id :os.system_time(:milli_seconds) |> Integer.to_string

  @trace kind: :critical
  @spec fred(integer, integer) :: integer
  def fred(a, b), do: blee(a, b)

  @trace kind: :coolness
  def blee(a, b) do
    :timer.sleep(200)
    a + b
  end

  defp before_fun(ctx) do
    Logger.debug(">>> Starting span for `#{ctx.target}...")
    ctx.target
    |> Span.open(@req_id)
    |> :otter.tag(:kind, ctx.meta[:kind])
    |> :otter.log(">>> #{ctx.target} with #{ctx.args |> inspect}")
  end

  defp after_fun(ctx, span, res) do
    Logger.debug("<<< Closing span for `#{ctx.target}...")
    span
    |> :otter.log("<<< #{ctx.target} returned #{res}")
    |> Span.close(@req_id)
  end
end
