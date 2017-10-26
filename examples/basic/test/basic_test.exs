defmodule BasicTest do
  use ExUnit.Case
  doctest Basic

  test "greets the world" do
    assert Basic.hello() == :world
  end
end
