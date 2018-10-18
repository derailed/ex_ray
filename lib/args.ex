defmodule ExRay.Args do
  @moduledoc false

  @doc """
  Expand_ignored ensures that all ignored arguments are
  expanded when calling wrapping span function.
  """
  @spec expand_ignored([any]) :: [any]
  def expand_ignored(arg) when not is_list(arg) do
    arg
  end
  def expand_ignored(args) do
    {res, _acc} =
      Enum.map_reduce(args, 1, fn(arg, acc) ->
        case arg do
          {{:., _, _} = k, l, m} ->
            {{k, l, m}, acc + 1}
          {:%{}, l, m} ->
            {{:%{}, l, expand_ignored(m)}, acc + 1}
          [{k, {a, l, m}} | t] ->
            {[{k, {unignore(a, acc), l, expand_ignored(m)}} | expand_ignored(t)], acc + 1}
          {k, {a, l, m}} ->
            {{k, {unignore(a, acc), l, expand_ignored(m)}}, acc + 1}
          {a, l, m} ->
            {{unignore(a, acc), l, expand_ignored(m)}, acc + 1}
          _ ->
            {arg, acc + 1} # in case of real value (not variable) as a param (function with pattern match)
        end
      end)
    res
  end

  def is_utility_word(a) when is_atom(a) do
    a_str = Atom.to_string(a)
    is_utility_word(a_str)
  end
  def is_utility_word(a_str) when is_bitstring(a_str) do
    String.starts_with?(a_str, "__") and String.ends_with?(a_str, "__")
  end

  defp unignore(arg, acc) do
    a = Atom.to_string(arg)
    cond do
      # the identifier is reserved word and should be bypassed
      is_utility_word(a) ->
        arg
      a == "_" ->
        String.to_atom("ex_ray_unique_fn_arg_var_#{acc}")
      String.starts_with?(a, "_") ->
        String.replace_leading(a, "_", "") |> String.to_atom
      true ->
        arg
    end
  end
end
