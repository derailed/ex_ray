defmodule ExRay.Store do
  @moduledoc """
  Store the span chains in an ETS table. The table must be created during
  the application initialization using the create call. The span chain acts
  like a call stack by pushing and popping spans as they come in and out of
  scope.
  """

  @table_name :ex_ray_tracers_table
  @request_id_to_pids_table_name :ex_ray_request_id_to_pids_table
  @pid_to_request_id_table_name :ex_ray_pid_to_request_id_table

  require Logger

  @doc """
  Initializes the spans ETS table. The span table can be shared across
  process boundary.
  """
  @spec create :: any
  def create do
    :ets.new(@table_name,
      [
        :set,
        :named_table,
        :public,
        read_concurrency:  true,
        write_concurrency: true
      ]
    )
    :ets.new(@request_id_to_pids_table_name,
      [
        :set,
        :named_table,
        :public,
        read_concurrency:  true,
        write_concurrency: true
      ]
    )
    :ets.new(@pid_to_request_id_table_name,
      [
        :set,
        :named_table,
        :public,
        read_concurrency:  true,
        write_concurrency: true
      ]
    )
  end

  @doc """
  Pushes a new span to the span stack. The key must be unique.
  """
  @spec push(String.t, any) :: any
  def push(key, val) when is_binary(key) do
    vals = get(key)

    if length(vals) > 0 do
      :ets.insert(@table_name, {key, [val] ++ vals})
    else
      :ets.insert(@table_name, {key, [val]})
    end
    val
  end

  @doc """
  Pops the top span off the stack.
  """
  @spec pop(String.t) :: any
  def pop(key) when is_binary(key) do
    [h | t] = get(key)
    :ets.insert(@table_name, {key, t})
    h
  end

  @doc """
  Fetch span stack for the given key
  """
  @spec get(String.t) :: [any]
  def get(key) when is_binary(key) do
    @table_name
    |> :ets.lookup(key)
    |> case do
      []             -> []
      [{_key, vals}] -> vals
    end
  end

  @doc """
  Fetch the top level span for a given key
  """
  @spec current(String.t) :: [any]
  def current(key) when is_binary(key) do
    key
    |> get
    |> case do
     []       -> nil
     [h | _t] -> h
    end
  end


  @doc """
  Links a request_id to corresponding PID, and otherwise. The key must be unique.
  """
  @spec link_request_id_and_pid(String.t, pid()) :: :ok
  def link_request_id_and_pid(request_id, pid) when is_binary(request_id) and is_pid(pid) do
    pids =
      case :ets.lookup(@request_id_to_pids_table_name, request_id) do
        [] -> []
        [{_request_id, pids}] -> [pid | pids] |> Enum.dedup
      end
    :ets.insert(@request_id_to_pids_table_name, {request_id, pids})
    :ets.insert(@pid_to_request_id_table_name, {pid, request_id})
    :ok
  end

  @doc """
  Returns a pid by linked request id.
  """
  @spec get_pids(String.t) :: {:ok, list(pid())} | {:error, :not_found}
  def get_pids(request_id) when is_binary(request_id) do
    case :ets.lookup(@request_id_to_pids_table_name, request_id) do
      [] -> {:error, :not_found}
      [{_request_id, pids}] -> {:ok, pids}
    end
  end

  @doc """
  Returns a request id by linked pid.
  """
  @spec get_request_id(pid()) :: {:ok, String.t} | {:error, :not_found}
  def get_request_id(pid) when is_pid(pid) do
    case :ets.lookup(@pid_to_request_id_table_name, pid) do
      [] -> {:error, :not_found}
      [{_pid, request_id}] -> {:ok, request_id}
    end
  end

  @doc """
  Remove all records where the request id is a key
  """
  @spec remove_request_id(String.t) :: :ok
  def remove_request_id(request_id) when is_binary(request_id) do
    case :ets.lookup(@request_id_to_pids_table_name, request_id) do
      [] -> :ok
      [{request_id, pids}] ->
        :ets.delete(@request_id_to_pids_table_name, request_id)
        Enum.each(pids, &(:ets.delete(@pid_to_request_id_table_name, &1)))
    end
  end

  @doc """
  Remove all records where the pid is a key
  """
  @spec remove_pid(pid()) :: :ok
  def remove_pid(pid) when is_pid(pid) do
    :ets.delete(@pid_to_request_id_table_name, pid)
  end
end
