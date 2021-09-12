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
        cmd: %{cmd | vote: true}
      }
      %{state | current_vote: vote}
    end
  end


  @spec handle_vote_command(Map.t(), Map.t()) :: Map.t()
  def handle_vote_command(cmd = %{command: "y"}, state), do: handle_vote_command(%{cmd | command: "vote", remaining: "yes"}, state)
  def handle_vote_command(cmd = %{command: "yes"}, state), do: handle_vote_command(%{cmd | command: "vote", remaining: "yes"}, state)
  def handle_vote_command(cmd = %{command: "n"}, state), do: handle_vote_command(%{cmd | command: "vote", remaining: "no"}, state)
  def handle_vote_command(cmd = %{command: "no"}, state), do: handle_vote_command(%{cmd | command: "vote", remaining: "no"}, state)
  def handle_vote_command(cmd = %{command: "b"}, state), do: handle_vote_command(%{cmd | command: "vote", remaining: "abstain"}, state)
  def handle_vote_command(cmd = %{command: "abstain"}, state), do: handle_vote_command(%{cmd | command: "vote", remaining: "abstain"}, state)

  def handle_vote_command(cmd = %{command: "vote", remaining: vote}, state) do
    IO.puts ""
    IO.inspect "VOTE #{vote}"
    IO.puts ""

    state
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
end
