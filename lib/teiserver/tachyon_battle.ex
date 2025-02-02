defmodule Teiserver.TachyonBattle do
  @moduledoc """
  To track ongoing battle. A battle should be linked with a running instance
  of the engine on an autohost.

  Ideally this should only be called Battle, but this clashes with the existing
  battle system tied to spring protocol and spads. This version, as the name
  suggest, is meant to be used with tachyon and autohosts.
  """

  alias Teiserver.TachyonBattle.Types, as: T
  alias Teiserver.TachyonBattle

  @type id :: T.id()

  @spec start_battle(Teiserver.Autohost.id()) :: {:ok, T.id()} | {:error, term()}
  def start_battle(autohost_id) do
    battle_id = gen_id()
    # TODO: handle potential errors, like "already registered"
    case TachyonBattle.Supervisor.start_battle(battle_id, autohost_id) do
      {:ok, _pid} -> {:ok, battle_id}
      {:ok, _pid, _info} -> {:ok, battle_id}
      _ -> {:error, "cannot start battle"}
    end
  end

  @spec lookup(T.id()) :: pid() | nil
  defdelegate lookup(battle_id), to: Teiserver.TachyonBattle.Registry

  @doc """
  Generate a battle id
  """
  @spec gen_id() :: T.id()
  def gen_id(), do: UUID.uuid4()
end
