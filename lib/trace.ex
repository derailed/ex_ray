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
        trace_enabled? = Application.get_env(:opentracing, :enabled, false)
        if trace_enabled? do
          predefined_tags = Application.get_env(:opentracing, :predefined_tags, [])
          # list of available tags
          tags = get_opentracing_tags(ctx, predefined_tags)
          Logger.debug(fn -> ">>> Starting span for `#{inspect ctx.target}" end)
          request_id = get_request_id(ctx)
          span = Span.open(ctx.target, request_id)
          span = Enum.reduce(tags, span, fn({tag, val}, acc) -> :otter.tag(acc, tag, val) end)
          if Application.get_env(:opentracing, :logs_enabled, false) do
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
        trace_enabled? = Application.get_env(:opentracing, :enabled, false)
        if trace_enabled? do
          Logger.debug(fn -> "<<< Closing span for `#{inspect ctx.target}" end)
          res =
            if Application.get_env(:opentracing, :logs_enabled, false) do
              :otter.log(span, "<<< #{inspect ctx.target} returned #{inspect res}")
            else
              span
            end
          request_id = get_request_id(ctx)
          Span.close(res, request_id)
        end
      end

      @spec get_request_id(map()) :: String.t
      def get_request_id(ctx) do
        {:ok, request_id} = ctx.args
          |> get_request_id_from_conn()
          |> get_request_id_by_pid()
          |> get_random_request_id()
        request_id
      end

      defp get_request_id_from_conn(args) when is_list(args) and length(args) > 0 do
        first_arg = hd(args)
        get_request_id_from_conn(first_arg, args)
      end
      defp get_request_id_from_conn(%{req_headers: req_headers, resp_headers: resp_headers, __struct__: :"Plug.Conn"} = conn, args) do
        get_conn_request_id_header(req_headers, resp_headers, args)
      end
      defp get_request_id_from_conn(_, args), do: {:error, args}

      @doc """
      Trying to determine header contains request_id in Plug.Conn
      """
      @spec get_conn_request_id_header(list(), list(), list()) :: {:ok, String.t} | {:error, list()}
      defp get_conn_request_id_header(req_headers, resp_headers, args) do
        key = "x-request-id"
        {^key, req_id} =
          [req_headers, resp_headers, [{key, :request_id_not_found}]]
            |> Enum.map(&List.keyfind(&1, key, 0))
            |> Enum.filter(&(not is_nil(&1)))
            |> hd()
        if req_id == :request_id_not_found do
          {:error, args}
        else
          Store.link_request_id_and_pid(req_id, self())
          {:ok, req_id}
        end
      end

      @doc """
      Trying to determine request_id by current pid
      """
      defp get_request_id_by_pid({:ok, request_id} = res), do: res
      defp get_request_id_by_pid({:error, args}) do
        case Store.get_request_id(self()) do
          {:ok, request_id} -> {:ok, request_id}
          {:error, :not_found} -> {:error, args}
        end
      end

      @doc """
      Generate random request_id and link it to the current pid
      """
      defp get_random_request_id({:ok, request_id} = res), do: res
      defp get_random_request_id(_) do
        request_id = UUID5.generate
        Store.link_request_id_and_pid(request_id, self())
        {:ok, request_id}
      end
    end
  end
end
