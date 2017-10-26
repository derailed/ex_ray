defmodule ExRay.SpanTest do
  use ExUnit.Case
  doctest ExRay

  use ExRay, pre: :f1, post: :f2

  alias ExRay.{Store, Span}

  setup_all do
    Store.create
    :ok
  end

  setup do
    span = {
      :span,
      1509045368683303,
      12387109925362352574,
      :root,
      15549390946617352406,
      :undefined,
      [],
      [],
      :undefined
    }
    %{span: span}
  end

  def f1(ctx) do
    assert ctx.meta[:kind] == :test
    :f1 |> Span.open("fred")
  end

  def f2(_ctx, span, _res) do
    span |> Span.close("fred")
  end

  @trace kind: :test
  def test1(a, b) do
    a + b
  end

  test "basic" do
    assert test1(1, 2) == 3
  end

  test "child span", ctx do
    Store.push("fred", ctx[:span])
    assert test1(1, 2) == 3
  end

  test "open/3", ctx do
    span = Span.open("fred", "1", ctx[:span])
    assert Store.current("1") == span
    span |> Span.close("1")
  end

  test "open/2" do
    span = Span.open("fred", "2")
    assert length(Store.get("2")) == 1
    span |> Span.close("2")
  end

  test "parent_id/1", ctx do
    assert ctx[:span] |> Span.parent_id == 12387109925362352574
  end
end
