defmodule Basic do
  use ExRay, pre: :before_fun, post: :after_fun

  alias ExRay.Span

  # Generates a request id
  @req_id :os.system_time(:milli_seconds) |> Integer.to_string |> IO.inspect

  @trace kind: :critical
  @spec fred(integer, integer) :: integer
  def fred(a, b), do: a+b

  @doc """
  Called before the annotated function fred is called. Allows to start
  a span and decorate it with tags and log information
  """
  defp before_fun(ctx) do
    ctx.target
    |> Span.open(@req_id)
    |> :otter.tag(:kind, ctx.meta[:kind])
    |> :otter.log(">>> #{ctx.target} with #{ctx.args |> inspect}")
  end

  @doc """
  Called once the annotated function is called. In this hook you can
  add addtional span info and close the span as we are all done here.
  """
  defp after_fun(ctx, span, res) do
    span
    |> :otter.log("<<< #{ctx.target} returned #{res}")
    |> Span.close(@req_id)
  end
end
