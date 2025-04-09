defmodule Teiserver.Party do
  @moduledoc """
  Anything party related. These are only tachyon related parties, and don't
  have anything shared with the existing parties under Teiserver.Account

  The main reason is that the logic to tie parties with matchmaking is
  completely different and there are also a few other semantic differences
  with regard to invites.
  """

  alias Teiserver.Party

  @type id :: Party.Server.id()

  @spec create_party() :: {id(), DynamicSupervisor.on_start_child()}
  def create_party() do
    party_id = Party.Server.gen_party_id()
    res = Party.Supervisor.start_party(party_id)
    {party_id, res}
  end

  @spec lookup(id()) :: pid() | nil
  defdelegate lookup(party_id), to: Party.Registry
end
