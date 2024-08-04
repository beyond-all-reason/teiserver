defmodule Teiserver.Player.SessionRegistry do
  @moduledoc """
  Registry used to track player presence
  """

  alias Teiserver.Data.Types, as: T

  def start_link() do
    Horde.Registry.start_link(keys: :unique, name: __MODULE__)
  end

  @doc """
  how to reach a given session
  """
  @spec via_tuple(T.userid()) :: GenServer.name()
  def via_tuple(user_id) do
    {:via, Horde.Registry, {__MODULE__, user_id}}
  end

  @spec lookup(T.userid()) :: pid() | nil
  def lookup(user_id) do
    case Horde.Registry.lookup(__MODULE__, user_id) do
      [{pid, _}] -> pid
      _ -> nil
    end
  end

  def child_spec(_) do
    Supervisor.child_spec(Horde.Registry,
      id: __MODULE__,
      start: {__MODULE__, :start_link, []}
    )
  end
end
