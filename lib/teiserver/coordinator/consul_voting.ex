defmodule Teiserver.Coordinator.ConsulVoting do
  require Logger
  alias Teiserver.Coordinator.{ConsulServer, ConsulCommands}
  alias Teiserver.{Coordinator, Client, User}
  alias Teiserver.Account.UserCache
  alias Teiserver.Battle.Lobby
  import Central.Helpers.NumberHelper, only: [int_parse: 1]
  # alias Phoenix.PubSub
  alias Teiserver.Data.Types, as: T


  @empty_vote %{
    eligible: [],
    yays: [],
    nays: [],
    abstains: [],
    creator_id: nil,
    expires: nil,
    cmd: nil
  }
  @vote_ttl 30


  @doc """
    Given a command it creates a new vote (if one is not already in progress)
  """
  @spec create_vote(Map.t(), Map.t()) :: Map.t()
  def create_vote(cmd, state) do
    lobby = Lobby.get_lobby!(state.lobby_id)

    eligible = lobby.players
    |> Client.list_clients()
    |> Enum.filter(fn c -> c.player end)
    |> Enum.map(fn c -> c.userid end)

    # If there's just 1 person that can vote then we don't do a vote
    # so we just handle it anyway
    if Enum.count(eligible) == 1 do
      ConsulCommands.handle_command(cmd, state)
    else
      username = UserCache.get_username(cmd.senderid)
      command = ConsulServer.command_as_message(cmd)
      Lobby.sayex(state.coordinator_id, "#{username} called a vote for command \"#{command}\" [Vote !y, !n, !b]", state.lobby_id)
      vote = %{@empty_vote |
        expires: System.system_time(:second) + @vote_ttl,
        eligible: eligible,
        creator_id: cmd.senderid,
        yays: [cmd.senderid],
        cmd: %{cmd | vote: true}
      }
      %{state | current_vote: vote}
    end
  end


  @spec handle_vote_command(Map.t(), Map.t()) :: Map.t()

  def handle_vote_command(_cmd, %{current_vote: nil} = state) do
    state
  end

  def handle_vote_command(cmd = %{command: "y"}, state), do: handle_vote_command(%{cmd | command: "vote", remaining: "yes"}, state)
  def handle_vote_command(cmd = %{command: "yes"}, state), do: handle_vote_command(%{cmd | command: "vote", remaining: "yes"}, state)
  def handle_vote_command(cmd = %{command: "n"}, state), do: handle_vote_command(%{cmd | command: "vote", remaining: "no"}, state)
  def handle_vote_command(cmd = %{command: "no"}, state), do: handle_vote_command(%{cmd | command: "vote", remaining: "no"}, state)
  def handle_vote_command(cmd = %{command: "b"}, state), do: handle_vote_command(%{cmd | command: "vote", remaining: "abstain"}, state)
  def handle_vote_command(cmd = %{command: "abstain"}, state), do: handle_vote_command(%{cmd | command: "vote", remaining: "abstain"}, state)

  def handle_vote_command(_cmd = %{command: "vote", remaining: vote, senderid: senderid}, %{current_vote: current_vote} = state) do
    eligible = Enum.member?(current_vote.eligible, senderid)

    # Start by updating the vote
    new_vote = cond do
      # Not eligible, nothing happens
      eligible == false ->
        current_vote

      vote == "yes" ->
        Lobby.say(senderid, "!y", state.lobby_id)
        %{current_vote |
          yays: Enum.uniq([senderid | current_vote.yays]),
          nays: List.delete(current_vote.nays, senderid),
          abstains: List.delete(current_vote.abstains, senderid)
        }

      vote == "no" ->
        Lobby.say(senderid, "!n", state.lobby_id)
        %{current_vote |
          yays: List.delete(current_vote.yays, senderid),
          nays: Enum.uniq([senderid | current_vote.nays]),
          abstains: List.delete(current_vote.abstains, senderid)
        }

      vote == "abstain" ->
        Lobby.say(senderid, "!b", state.lobby_id)
        %{current_vote |
          yays: List.delete(current_vote.yays, senderid),
          nays: List.delete(current_vote.nays, senderid),
          abstains: Enum.uniq([senderid | current_vote.abstains])
        }
    end

    # Now we check to see the outcome, if the vote is completed then
    # we complete it
    if vote_completed?(new_vote) do
      complete_vote(state, new_vote)
    else
      %{state | current_vote: new_vote}
    end
  end

  def handle_vote_command(cmd = %{command: "ev"}, state) do
    client = Client.get_client_by_id(cmd.senderid)

    do_end = cond do
      state.current_vote == nil -> false
      client.moderator -> true
      cmd.senderid == state.current_vote.creator_id -> true
      true -> false
    end

    if do_end do
      Lobby.sayex(state.coordinator_id, "Vote cancelled by #{client.name}", state.lobby_id)
      %{state | current_vote: nil}
    else
      state
    end
  end

  @spec vote_completed?(Map.t()) :: boolean()
  def vote_completed?(vote) do
    yays = Enum.count(vote.yays)
    nays = Enum.count(vote.nays)
    abstains = Enum.count(vote.abstains)

    possible_votes = Enum.count(vote.eligible) - abstains
    win_count = :math.ceil(possible_votes / 2)

    remaining = possible_votes - yays - nays

    cond do
      remaining == 0 -> true
      yays > win_count and yays != nays -> true
      nays > win_count and yays != nays -> true
      true -> false
    end
  end

  @spec complete_vote(Map.t(), Map.t()) :: Map.t()
  def complete_vote(state, vote) do
    yays = Enum.count(vote.yays)
    nays = Enum.count(vote.nays)

    if yays > nays do
      do_vote_fail(state, vote)
    else
      do_vote_pass(state, vote)
    end
  end

  defp do_vote_fail(state, vote) do
    command = ConsulServer.command_as_message(vote.cmd)
    Lobby.sayex(state.coordinator_id, "\"#{command}\" failed", state.lobby_id)
    %{state | current_vote: nil}
  end

  defp do_vote_pass(state, vote) do
    command = ConsulServer.command_as_message(vote.cmd)
    Lobby.sayex(state.coordinator_id, "\"#{command}\" succeeded", state.lobby_id)
    %{state | current_vote: nil}
  end
end
