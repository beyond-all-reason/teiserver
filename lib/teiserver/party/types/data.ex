defmodule Teiserver.Party.Types.Data do
  @moduledoc """
  Internal data for the party process
  """
  alias Teiserver.Account.User
  alias Teiserver.Helpers.MonitorCollection, as: MC
  alias Teiserver.Matchmaking
  alias Teiserver.Party.Types, as: PT

  @type id :: String.t()

  @enforce_keys [:version, :id, :members, :max_members]
  defstruct [
    # versionning of the state to avoid races between call and cast
    :version,
    :id,
    :members,
    :max_members,
    invited: %{},
    ids_to_rejoin: MapSet.new(),
    monitors: MC.new(),
    matchmaking: nil
  ]

  @type t :: %__MODULE__{
          version: integer(),
          id: id(),
          monitors: MC.t(),
          members: %{User.id() => %{id: User.id(), joined_at: DateTime.t()}},
          ids_to_rejoin: MapSet.t(User.id()),
          invited: %{User.id() => PT.Invite},
          matchmaking: nil | %{queues: [{Matchmaking.queue_id(), version :: String.t()}]},
          max_members: pos_integer()
        }
end
