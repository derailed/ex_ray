defmodule ExRay.ArgsTest do
  use ExUnit.Case

  alias ExRay.Args

  test "expand_ignore/1" do
    args = [
      {:_fred, [line: 20], nil}
    ]
    assert args |> Args.expand_ignored == [{:fred, [line: 20], nil}]
  end

  test "expand_ignored/1 - default" do
    args = [{:\\, [line: 10], {:fred, [line: 20], 1}}]
    assert args |> Args.expand_ignored == args
  end

  test "expand_ignored/1 - keyword" do
    args = [{:blee, {:_fred, [line: 20], nil}}]
    assert args |> Args.expand_ignored == [{:blee, {:fred, [line: 20], nil}}]
  end

  test "expand_ignored/1 - list" do
    args = [
      [{:blee, {:_fred, [line: 20], nil}}]
    ]
    assert args |> Args.expand_ignored == [[{:blee, {:fred, [line: 20], nil}}]]
  end

  test "expand_ignored/1 - map" do
    args = [
      {:%{}, [line: 10], [{:fred, {:_blee, [line: 20], nil}}]}
    ]
    assert args |> Args.expand_ignored == [{:%{}, [line: 10], [{:fred, {:blee, [line: 20], nil}}]}]
  end
end
