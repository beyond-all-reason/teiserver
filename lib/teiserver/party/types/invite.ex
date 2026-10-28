defmodule Teiserver.Party.Types.Invite do
  @moduledoc """
  Represent a pending invite for the party
  """

  alias Teiserver.Account.User

  @enforce_keys [:id, :invited_at, :valid_until, :timeout_ref]
  defstruct [:id, :invited_at, :valid_until, :timeout_ref]

  @type t :: %__MODULE__{
          id: User.id(),
          invited_at: DateTime.t(),
          valid_until: DateTime.t(),
          timeout_ref: :timer.tref()
        }
end
