defmodule ExRay.Span do
  @moduledoc """
  A set of convenience functions to manage spans.
  """

  @doc """
  Create a new root span with a given name and unique request chain ID.
  The request ID uniquely identifies the call chain and will be used as
  the primary key in the ETS table tracking the span chain.
  """
  @spec open(String.t, String.t) :: any
  def open(name, req_id) do
    span = req_id
    |> ExRay.Store.current
    |> case do
      nil    -> name |> :otter.start
      p_span -> name |> :otter.start(p_span)
    end

    req_id |> ExRay.Store.push(span)
  end

  @doc """
  Creates a new span with a given parent span
  """
  @spec open(String.t, String.t, any) :: any
  def open(name, req_id, p_span) do
    span = name |> :otter.start(p_span)

    req_id |> ExRay.Store.push(span)
  end

  @doc """
  Closes the given span and pops the span state in the associated ETS
  span chain.
  """
  @spec close(any, String.t) :: any
  def close(span, req_id) do
    span |> :otter.finish()
    ExRay.Store.pop(req_id)
  end

  @doc """
  Convenience to retrive the parent span ID from a given span
  """
  @spec parent_id({:span, integer, integer, String.t, integer}) :: String.t
  def parent_id({:span, _, pid, _, _, _, _, _, _}) do
    pid
  end
end
