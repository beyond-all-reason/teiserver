defmodule Teiserver.Autohost.SessionRegistry do
  @moduledoc """
  Registry used to identify autohost sessions
  """

  alias Teiserver.Bot.Bot

  @type reg_value :: %{
          id: Bot.id(),
          max_battles: non_neg_integer(),
          current_battles: non_neg_integer()
        }

  def start_link() do
    Registry.start_link(keys: :unique, name: __MODULE__)
  end

  @doc """
  How to reach a given session
  """
  @spec via_tuple(Bot.id()) :: GenServer.name()
  def via_tuple(autohost_id) do
    {:via, Registry, {__MODULE__, autohost_id}}
  end

  @spec register(reg_value) :: {:ok, pid()} | {:error, {:already_registered, pid()}}
  def register(%{id: autohost_id} = val) do
    # this is needed mostly for tests
    Registry.register(__MODULE__, autohost_id, val)
  end

  @spec lookup(Bot.id()) :: {pid(), reg_value()} | nil
  def lookup(autohost_id) do
    case Registry.lookup(__MODULE__, autohost_id) do
      [x] -> x
      _ -> nil
    end
  end

  @spec set_value(
          Bot.id(),
          max_battles :: non_neg_integer(),
          current_battles :: non_neg_integer()
        ) :: reg_value()
  def set_value(autohost_id, max_battles, current_battles) do
    value = %{
      id: autohost_id,
      max_battles: max_battles,
      current_battles: current_battles
    }

    result = Registry.update_value(__MODULE__, autohost_id, fn _ -> value end)

    if result == :error do
      Registry.register(__MODULE__, autohost_id, value)
    end

    value
  end

  @spec get_value(Bot.id()) :: reg_value() | nil
  def get_value(autohost_id) do
    case Registry.lookup(__MODULE__, autohost_id) do
      [{_, val}] -> val
      _ -> nil
    end
  end

  def child_spec(_) do
    Supervisor.child_spec(Registry,
      id: __MODULE__,
      start: {__MODULE__, :start_link, []}
    )
  end

  def count() do
    Registry.count(__MODULE__)
  end

  @doc """
  Returns all the currently registered autohosts sessions
  """
  @spec list() :: [reg_value()]
  def list() do
    Registry.select(__MODULE__, [{{:_, :_, :"$1"}, [], [:"$1"]}])
  end
end
