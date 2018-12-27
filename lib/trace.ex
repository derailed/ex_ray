defmodule ExRay.Trace do
  # TODO: should be documented

  defmacro __using__(_opts) do
    _ = :ex_ray_trace_unique_atom # define unique atom in compile time

    quote do
      use ExRay, pre: :before_fun, post: :after_fun
      require Logger
      alias ExRay.Span
      alias ExRay.Store

      defp get_opentracing_tags(ctx, predefined_tags) do
        tags = predefined_tags ++ [
          "span.kind": "server",
          type: ctx.meta[:type] || nil,
          hostname: System.get_env("HOSTNAME") || nil,
          rts_id: System.get_env("RTS_ID") || nil,
          rts_host: System.get_env("RTS_HOST") || nil,
          cts_id: System.get_env("CCS_ID") || nil,
          cts_host: System.get_env("CCS_HOST") || nil,
          cts: System.get_env("CTS") || nil,
          lc: __MODULE__
        ] |> Enum.filter(fn({_, val}) -> not is_nil(val) end)
      end

      defp before_fun(ctx) do
        String.to_existing_atom("ex_ray_trace_unique_atom")
      rescue
        # this is runtime-only call since no an :ex_ray_trace_unique_atom is defined on runtime
        ArgumentError ->
          before_fun_body(ctx)
        _ ->
          :ok
      end

      defp before_fun_body(ctx) do
        trace_enabled? = Application.get_env(:ex_ray, :enabled, false)
        if trace_enabled? do
          predefined_tags = Application.get_env(:ex_ray, :predefined_tags, [])
          # list of available tags
          tags = get_opentracing_tags(ctx, predefined_tags)
          Logger.debug(fn -> ">>> Starting span for `#{inspect ctx.target}" end)
          request_id = get_request_id(ctx)
          span = Span.open(ctx.target, request_id)
          span = Enum.reduce(tags, span, fn({tag, val}, acc) -> :otter.tag(acc, tag, val) end)
          if Application.get_env(:ex_ray, :logs_enabled, false) do
            :otter.log(span, ">>> #{inspect ctx.target} with args: #{inspect ctx.args}")
          else
            span
          end
        end
      end

      defp after_fun(ctx, span, res) do
        String.to_existing_atom("ex_ray_trace_unique_atom")
      rescue
        # this is runtime-only call since no an :ex_ray_trace_unique_atom is defined on runtime
        ArgumentError -> after_fun_body(ctx, span, res)
      end

      defp after_fun_body(ctx, span, res) do
        trace_enabled? = Application.get_env(:ex_ray, :enabled, false)
        if trace_enabled? do
          Logger.debug(fn -> "<<< Closing span for `#{inspect ctx.target}" end)
          res =
            if Application.get_env(:ex_ray, :logs_enabled, false) do
              :otter.log(span, "<<< #{inspect ctx.target} returned #{inspect res}")
            else
              span
            end
          request_id = get_request_id(ctx)
          Span.close(res, request_id)
        end
      end

      @doc """
      Trying to determine request id from context (`ctx` param variable)
      """
      @spec get_request_id(map()) :: String.t
      def get_request_id(ctx) do
        {:ok, request_id} = ctx
          |> get_request_id_from_args()
          |> get_request_id_from_conn()
          |> throw_arg_err()
        request_id
      end

      defp find_request_id_in_arg({:request_id, request_id, _val}), do: request_id
      defp find_request_id_in_arg(arg) when is_map(arg) do
        cond do
          Map.has_key?(arg, :request_id) ->
            Map.get(arg, :request_id)
          Map.has_key?(arg, "request_id") ->
            Map.get(arg, "request_id")
          Map.has_key?(arg, :payload) ->
            Map.get(arg.payload, :request_id) || Map.get(arg.payload, "request_id")
          Map.has_key?(arg, :term) ->
            Map.get(arg.term, "request_id")
          true ->
            nil
        end
      end
      defp find_request_id_in_arg(_), do: nil

      defp get_request_id_from_args(ctx) do
        case Enum.find_value(ctx.args, &find_request_id_in_arg/1) do
          nil ->
            {:error, ctx}
          request_id ->
            {:ok, request_id}
        end
      end

      defp get_request_id_from_conn({:ok, _} = res), do: res
      defp get_request_id_from_conn({:error, ctx}) do
        if is_list(ctx.args) and length(ctx.args) > 0 do
          first_arg = hd(ctx.args)
          get_request_id_from_conn(first_arg, ctx)
        else
          {:error, ctx}
        end
      end

      defp get_request_id_from_conn(%Plug.Conn{} = conn, ctx) do
        h = Plug.Conn.get_req_header(conn, "x-request-id")
        case h do
          [] -> {:error, ctx}
          [request_id] -> {:ok, request_id}
        end
      end
      defp get_request_id_from_conn(_, ctx), do: {:error, ctx}

      @doc """
      Generate random request_id and link it to the current pid
      """
      defp throw_arg_err({:ok, request_id} = res), do: res
      defp throw_arg_err({:error, ctx}) do
        if Application.get_env(:ex_ray, :debug, false) do
          st = Process.info(self(), :current_stacktrace)
          IO.inspect("The request_id value is not found in the next args: #{inspect(ctx.args)}")
          IO.inspect("Stacktrace: #{inspect(st)}")
        end
        raise ArgumentError, "The `request_id` value is missing in a request params"
      end
    end
  end
end
