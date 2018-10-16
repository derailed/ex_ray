defmodule ExRay do
  @moduledoc """
  ExRay defines an annotation construct that wraps regular functions and enable
  them to be traced using a simple affordance **@trace** to interact with an
  OpenTracing compliant collector.

  [OpenTracing](http://opentracing.io/) defines the concept of spans that
  track the call stack and record timing information and various call artifacts
  that can be used for application runtime inspection.
  This is a really cool piece of technology that compliments your monitoring
  solution as you now have x-ray vision of your application at runtime once
  a monitoring metric gets off the chart.

  However, in practice, your code gets quickly cluttered by your tracing efforts.
  ExRay alleviates the clutter by injecting cross-cutting tracing concern into
  your application code. By using @trace annotation, you can trap the essence of
  the calls without introducing tracing code mixed-in with your business logic.

  ExRay leverages [Otter](https://github.com/Bluehouse-Technology/otter) Erlang
  OpenTracing lib from the fine folks of BlueHouse Technology.

  To enable OpenTracing with ExRay

  ```elixir
  defmodule Traceme do
    use ExRay, pre: :pre_fun, post: :post_fun

    alias ExRay.Span

    @trace kind: :cool_kid
    def elvis(a, b), do: a + b

    defp pre_fun(ctx) do
      ctx.target
      |> Span.open("123") # where 123 represent a unique callstack ID
      |> :otter.tag(:kind, ctx.meta[:kind])
      |> :otter.log("Calling Elvis!")
    end

    defp post_fun(_ctx, span, _res) do
      span
      |> :otter.log("Elvis has left the building!")
      |> Span.close("123")
    end
  end
  ```

  ExRay provisions an `ExRay.Context` with function details and metadata
  that comes from the annotation. You can leverage this information for
  tracing in your pre and post span-hook functions.
  """

  @doc """
  Defines a @trace annotation to enable regular function to be traced. Calling an
  annotated function f1 will ensure that a new span is created upon invocation
  and closed when the function exits. This macro will define a new function
  that will call the original function but decorated with pre
  and post tracing hooks. Tracing functions are generated at compile time.
  """
  defmacro __using__(opts) do
    quote do
      import ExRay

      __MODULE__ |> Module.put_attribute(:exray_opts, unquote(opts))
      __MODULE__ |> Module.register_attribute(:trace, accumulate: true)
      __MODULE__ |> Module.register_attribute(:trace_all, accumulate: true)
      __MODULE__ |> Module.register_attribute(:ex_ray_funs, accumulate: true)

      @on_definition  {ExRay, :on_definition}
      @before_compile {ExRay, :before_compile}
    end
  end

  @doc """
  Flags functions that have been annotated for further processing during
  the compilation phase
  """
  def on_definition(env, k, f, a, g, b) do
    tag = env.module |> Module.get_attribute(:trace)
    tag_all = env.module |> Module.get_attribute(:trace_all)
    cond do
      not Enum.empty?(tag) ->
        env.module |> Module.put_attribute(:ex_ray_funs, {k, f, a, g, b, tag})
      not Enum.empty?(tag_all) ->
        env.module |> Module.put_attribute(:ex_ray_funs, {k, f, a, g, b, tag_all})
      true ->
        :ok
    end
    env.module |> Module.delete_attribute(:trace)
  end

  @doc """
  Generates a new tracing function with before and after hooks that will
  call the original function. Pre and Post hooks can be defined at the
  module level or overriden on a per function basis.
  """
  defmacro before_compile(env) do
    funs = env.module |> Module.get_attribute(:ex_ray_funs)
    env.module |> Module.delete_attribute(:ex_ray_funs)

    Application.get_all_env(:ex_ray)
    |> Keyword.get(:active, true)
    |> case do
      true ->
        funs
        |> Enum.reduce({nil, 0, []}, fn(f, acc) -> generate(env, f, acc) end)
        |> elem(2)
      false -> :ok
    end
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
        _ ->
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
