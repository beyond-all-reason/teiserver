defmodule Teiserver.TachyonLobby.Types.VoteState do
  @moduledoc """
  Data about the current active vote in the lobby

  Quorum
  The total number of votes requried for the results to be valid

  Majority
  Percentage of yes votes out of non abstaining votes required for the vote to pass
  """
  alias Teiserver.Account.User
  defstruct [:id, :action, :initiator, :voters, :duration_s, :until, :quorum, :majority]

  @type vote_action ::
          {:change_map, String.t()}
          | {:appoint_boss, User.id()}
          | {:kickban, User.id(), DateTime.t() | nil}
          | :start
  @type vote_ballot :: :yes | :no | :abstain
  @type vote_outcome :: :passed | :failed | :cancelled | :timeout

  @type t() :: %__MODULE__{
          id: String.t(),
          action: vote_action,
          initiator: Teiserver.Account.User.id(),
          voters: %{Teiserver.Account.User.id() => :pending | vote_ballot()},
          duration_s: non_neg_integer(),
          until: DateTime.t(),
          quorum: non_neg_integer(),
          majority: float()
        }
end
