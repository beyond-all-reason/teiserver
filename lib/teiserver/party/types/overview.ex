defmodule Teiserver.Party.Types.Overview do
  @moduledoc """
  Similar to Data, but this is meant for external consumption
  """

  alias Teiserver.Account.User
  alias Teiserver.Party.Types, as: PT

  @enforce_keys [:version, :id, :pid, :members, :max_members, :invited]
  defstruct [:version, :id, :pid, :members, :max_members, :invited]

  @type t :: %__MODULE__{
          version: integer(),
          id: PT.Data.id(),
          pid: pid(),
          members: %{User.id() => %{id: User.id(), joined_at: DateTime.t()}},
          invited: %{User.id() => PT.Invite},
          max_members: pos_integer()
        }
end
