defmodule Teiserver.Party do
  @moduledoc """
  Anything party related. These are only tachyon related parties, and don't
  have anything shared with the existing parties under Teiserver.Account

  The main reason is that the logic to tie parties with matchmaking is
  completely different and there are also a few other semantic differences
  with regard to invites.
  """

  alias Teiserver.Party
  alias Teiserver.Data.Types, as: T

  @type id :: Party.Server.id()

  @spec create_party(T.userid()) :: {:ok, id()} | {:error, reason :: term()}
  def create_party(user_id) do
    party_id = Party.Server.gen_party_id()

    case Party.Supervisor.start_party(party_id, user_id) do
      {:ok, _pid} -> {:ok, party_id}
      {:ok, _pid, _info} -> {:ok, party_id}
      :ignore -> {:error, :ignore}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec lookup(id()) :: pid() | nil
  defdelegate lookup(party_id), to: Party.Registry

  @spec get_state(id()) :: state() | nil
  defdelegate get_state(party_id), to: Party.Server
end
