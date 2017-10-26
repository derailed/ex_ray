defmodule ExRayTest do
  use ExUnit.Case
  doctest ExRay

  use ExRay, pre: :f1, post: :f2

  def f1(ctx) do
    assert ctx.meta[:kind] == :test
    1
  end
  def f2(_ctx, pre, _res) do
    assert pre == 1
  end

  @trace kind: :test
  def test1(a, b) do
    a + b
  end

  @trace kind: :test
  def test2(a, b \\ 1) do
    a + b
  end

  @trace kind: :test
  def test3(a, _b) do
    a
  end

  @trace kind: :test
  def test4(a, b) when is_number(a) do
    a + b
  end
  @trace kind: :test
  def test4(a, b) when is_atom(a) do
    b
  end

  test "basic" do
    assert test1(1, 2) == 3
  end

  test "default" do
    assert test2(1, 2) == 3
    assert test2(1)    == 2
  end

  test "ignored" do
    assert test3(1, 2) == 1
  end

  test "multi" do
    assert test4(1, 2) == 3
    assert test4(:fred, 2) == 2
  end
end
