defmodule Teiserver.Autohost.Registry do
  @moduledoc """
  Registry used for autohost using tachyon protocol

  Doesn't do much yet, can be used later for host selection for lobbies
  and matchmaking
  """

  alias Teiserver.Autohost.Types, as: AT
  alias Teiserver.Bot.Bot

  def start_link do
    Registry.start_link(keys: :unique, name: __MODULE__)
  end

  @doc """
  how to reach a given autohost
  """
  @spec via_tuple(Bot.id()) :: GenServer.name()
  def via_tuple(autohost_id) do
    {:via, Registry, {__MODULE__, autohost_id}}
  end

  @spec lookup(Bot.id()) :: {pid(), AT.Overview.t()} | nil
  def lookup(autohost_id) do
    case Registry.lookup(__MODULE__, via_tuple(autohost_id)) do
      [x] -> x
      _other -> nil
    end
  end

  @doc """
  Returns all the currently registered autohosts
  """
  @spec list() :: [AT.Overview.t()]
  def list do
    Registry.select(__MODULE__, [{{:_, :_, :"$1"}, [], [:"$1"]}])
  end

  def child_spec(_opts) do
    Supervisor.child_spec(Registry,
      id: __MODULE__,
      start: {__MODULE__, :start_link, []}
    )
  end
end
