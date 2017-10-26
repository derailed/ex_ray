defmodule ExRay.NoWrapTest do
  use ExUnit.Case
  doctest ExRay

  use ExRay

  def f1(ctx) do
    assert ctx.meta[:kind] == :test
    1
  end
  def f2(_ctx, pre, _res) do
    assert pre == 1
  end

  # @trace kind: :test, post: :f1
  # def test1(a, b) do
  #   a + b
  # end

  # test "no_wrap" do
  #   assert test1(1, 2) == 3
  # end
end
