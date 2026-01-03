defmodule Teiserver.Player.Registry do
  @moduledoc """
  Registry used for websocket tachyon connections

  Note there's already a Teiserver.ClientRegistry which does more or less the
  same but for the spring protocol. However, with spring there are a few
  operations that requires to send messages to all connected clients.
  So unless there's a way to handle cross communication tachyon<->spring
  use a separate registry and keep clients separate.
  """

  alias Teiserver.Data.Types, as: T

  def start_link() do
    Horde.Registry.start_link(keys: :unique, name: __MODULE__)
  end

  @doc """
  how to reach a given connection
  """
  @spec via_tuple(T.userid()) :: GenServer.name()
  def via_tuple(user_id) do
    {:via, Horde.Registry, {__MODULE__, user_id}}
  end

  @doc """
  register the player. If the same player is already registered,
  unregister the existing process and kill it, then register.
  This ensure a player has at most one connection alive at a time
  """
  @spec register_and_kill_existing(T.userid()) :: {:ok, pid()}
  def register_and_kill_existing(user_id) do
    case register(user_id) do
      {:ok, pid} ->
        {:ok, pid}

      {:error, {:already_registered, existing_conn_pid}} ->
        Horde.Registry.unregister(__MODULE__, via_tuple(user_id))
        Process.send(existing_conn_pid, :force_disconnect, [])
        :timer.sleep(1)
        register_and_kill_existing(user_id)
    end
  end

  @spec register(T.userid()) :: {:ok, pid()} | {:error, {:already_registered, pid()}}
  def register(user_id) do
    # this is needed because the process that handle the ws connection is spawned
    # by phoenix, so we can't spawn+register in the same step
    Horde.Registry.register(__MODULE__, via_tuple(user_id), user_id)
  end

  @spec lookup(T.userid()) :: pid() | nil
  def lookup(user_id) do
    case Horde.Registry.lookup(__MODULE__, via_tuple(user_id)) do
      [{pid, _}] -> pid
      _ -> nil
    end
  end

  @spec connected_count() :: non_neg_integer()
  def connected_count() do
    case Horde.Registry.count(__MODULE__) do
      :undefined -> 0
      x -> x
    end
  end

  def child_spec(_) do
    Supervisor.child_spec(Horde.Registry,
      id: __MODULE__,
      start: {__MODULE__, :start_link, []}
    )
  end
end
