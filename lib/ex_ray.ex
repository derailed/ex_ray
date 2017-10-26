defmodule ExRay do
  @moduledoc """
  ExRay defines a custom annotation that wraps regular functions and enable
  them to be traced using a simple affordance aka @trace. At the base,
  OpenTracing defines the concept of a span that track the callstack and
  record timing information, tags and logs,... . So instead of littering
  your code with span management, ExRay provides an easy way to inject
  your tracing needs by simply using an annotation and wrapping your
  function calls.

  Under the scene, ExRay leverages
  [Otter](https://github.com/Bluehouse-Technology/otter) an Erlang library
  written by the fine folks at Bluehouse Technology.

  To enable OpenTracing with ExRay

  ```elixir
  defmodule Traceme do
    use ExRay, pre: :pre_fn, post: :post_fn

    @trace kind: :cool_kid
    def elvis(a, b), do: a + b

    defp pre_fn(ctx) do
      ctx.target
      |> ExRay.open("123") # where 123 represent a unique callstack ID
      |> :otter.tag(:kind, ctx.meta[:kind])
      |> :otter.log("Calling Elvis!")
    end

    defp post_fn(ctx, span, _res) do
      span
      |> :otter.log("Elvis has left the building!")
      |> ExRay.close("123")
    end
  end
  ```

  ExRay provisions an `ExRay.Context` with function details and metadata
  that comes from the annotation that you can leverage within with pre and
  post hook span functions.
  """

  @doc """
  Defines a @trace annotation to enable plain function to be traced. Calling an
  annotated function f1 will ensure that a new span is created upon invocation
  and closed when the function exits. This macro will define a new function
  that overrides the original function and generates a new function with pre
  and post function calls. There is no impact on the runtime as the new
  function is generated at compile time.
  """
  defmacro __using__(opts) do
    quote do
      import ExRay

      __MODULE__ |> Module.put_attribute(:exray_opts, unquote(opts))

      __MODULE__ |> Module.register_attribute(:trace, accumulate: true)
      __MODULE__ |> Module.register_attribute(:ex_ray_funs, accumulate: true)

      @on_definition  {ExRay, :on_definition}
      @before_compile {ExRay, :before_compile}
    end
  end

  def on_definition(env, k, f, a, g, b) do
    tag = env.module |> Module.get_attribute(:trace)
    unless tag |> Enum.empty? do
      env.module |> Module.put_attribute(:ex_ray_funs, {k, f, a, g, b, tag})
    end
    env.module |> Module.delete_attribute(:trace)
  end

  defmacro before_compile(env) do
    funs = env.module |> Module.get_attribute(:ex_ray_funs)
    env.module |> Module.delete_attribute(:ex_ray_funs)
    funs
    |> Enum.reduce({nil, 0, []}, fn(f, acc) -> generate(env, f, acc) end)
    |> elem(2)
  end

  defp generate(env, {_, f, a, g, _, meta}, {prev, arity, acc}) do
    def_body = gen_body(env, {f, a, g}, meta)

    def_override = quote do
      defoverridable [{unquote(f), unquote(length(a))}]
    end

    params = a |> ExRay.Args.expand_ignored

    def_func = g
    |> case do
    [] ->
      quote do
        def unquote(f)(unquote_splicing(params)) do
          unquote(def_body)
        end
      end
    _  ->
      quote do
        def unquote(f)(unquote_splicing(params)) when unquote_splicing(g) do
          unquote(def_body)
        end
      end
    end

    if f == prev and length(a) == arity do
      {f, length(a), acc ++ [def_func]}
    else
      {f, length(a), acc ++ [def_override, def_func]}
    end
  end

  defp gen_body(env, {fun, args, guard}, meta) do
    opts = env.module |> Module.get_attribute(:exray_opts)

    params = args
    |> ExRay.Args.expand_ignored
    |> Enum.map(fn(
      {:\\, _, [a, _]}) -> a
      (arg)             -> arg
    end)

    ctx = quote do
      ctx = %ExRay.Context{
        target: unquote(fun),
        args:   unquote(params),
        guards: unquote(guard),
        meta:   unquote(meta |> List.first)
      }
    end

    meta
    |> List.first
    |> is_list
    |> case do
      true  -> {
        meta |> List.first |> Keyword.get(:pre, opts[:pre]),
        meta |> List.first |> Keyword.get(:post, opts[:post])
      }
      false -> {opts[:pre], opts[:post]}
    end
    |> case do
      {nil, nil} ->
        raise ArgumentError, "You must define a `pre and `post function!"
      {_pre, nil} ->
        raise ArgumentError, "You must define a `post function!"
      {nil, _post} ->
        raise ArgumentError, "You must define a `pre function."
      {pre, post} ->
        quote do
          unquote(ctx)

          pre = unquote(pre)(ctx)
          try do
            super(unquote_splicing(params))
          rescue
            err -> unquote(post)(ctx, pre, err)
                   throw err
          else
            res -> unquote(post)(ctx, pre, res)
                   res
          end
        end
    end
  end
end
