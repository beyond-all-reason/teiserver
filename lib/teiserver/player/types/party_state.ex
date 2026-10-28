defmodule Teiserver.Player.Types.PartyState do
  @moduledoc """
  track info from relevant parties for a given player
  """

  alias Teiserver.Party

  defstruct version: 0, current_party: nil, invited_to: []

  @type t :: %__MODULE__{
          # the last party state version gotten from the party through GenServer.call
          # this is used to avoid races where the reply of the call would be processed
          # before a message already in the mailbox
          version: integer(),
          current_party: Party.id() | nil,
          invited_to: [{integer(), Party.id()}]
        }
end
