defmodule NestedTest do
  use ExUnit.Case
  doctest Nested

  test "greets the world" do
    assert Nested.hello() == :world
  end
end
