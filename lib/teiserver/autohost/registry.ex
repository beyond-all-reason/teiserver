defmodule Teiserver.Autohost.Registry do
  @moduledoc """
  Registry used for autohost using tachyon protocol

  Doesn't do much yet, can be used later for host selection for lobbies
  and matchmaking
  """

  alias Teiserver.Bot.Bot

  @type reg_value :: %{
          id: Bot.id(),
          max_battles: non_neg_integer(),
          current_battles: non_neg_integer()
        }

  def start_link() do
    Horde.Registry.start_link(keys: :unique, name: __MODULE__)
  end

  @doc """
  how to reach a given autohost
  """
  @spec via_tuple(Bot.id()) :: GenServer.name()
  def via_tuple(autohost_id) do
    {:via, Horde.Registry, {__MODULE__, autohost_id}}
  end

  @spec register(reg_value) :: {:ok, pid()} | {:error, {:already_registered, pid()}}
  def register(%{id: autohost_id} = val) do
    # this is needed because the process that handle the ws connection is spawned
    # by phoenix, so we can't spawn+register in the same step
    Horde.Registry.register(__MODULE__, via_tuple(autohost_id), val)
  end

  @spec unregister(Bot.id()) :: :ok
  def unregister(autohost_id) do
    Horde.Registry.unregister(__MODULE__, via_tuple(autohost_id))
  end

  @spec lookup(Bot.id()) :: {pid(), reg_value()} | nil
  def lookup(autohost_id) do
    case Horde.Registry.lookup(__MODULE__, via_tuple(autohost_id)) do
      [x] -> x
      _ -> nil
    end
  end

  def update_value(autohost_id, callback) do
    Horde.Registry.update_value(__MODULE__, via_tuple(autohost_id), callback)
  end

  @doc """
  Returns all the currently registered autohosts
  """
  @spec list() :: [reg_value()]
  def list() do
    Horde.Registry.select(__MODULE__, [{{:_, :_, :"$1"}, [], [:"$1"]}])
  end

  def child_spec(_) do
    Supervisor.child_spec(Horde.Registry,
      id: __MODULE__,
      start: {__MODULE__, :start_link, []}
    )
  end
end
