defmodule Teiserver.Matchmaking.Algos do
  @moduledoc """
  Interface for matchmaking algorithms
  """

  alias Teiserver.Matchmaking.Member
  alias Teiserver.Helpers.Combi

  @type state :: term()

  @doc """
  A way to initialize the module with some persistent state.
  For example, a http client or getting some parameters from the DB
  """
  @callback init(team_size :: pos_integer(), team_count :: pos_integer()) :: state()

  @doc """
  The function to invoke to pair some members.
  It returns a list of valid matches. A match is a list of teams, a team is a
  list of member.

  Optionally can pass a predicate to filter some matches
  """
  @callback get_matches(
              members :: [Member.t()],
              state :: state()
            ) :: :no_match | {:match, [[[Member.t()]]]}

  @spec match_members(
          [Member.t()],
          team_size :: pos_integer(),
          team_count :: pos_integer(),
          pred :: ([[Member.t()]] -> boolean),
          acc :: term()
        ) :: [[[Member.t()]]]
  def match_members(members, team_size, team_count, pred, acc \\ []) do
    res =
      match_stream(members, team_size, team_count)
      |> Stream.filter(pred)
      |> Enum.take(1)
      |> List.first()

    case res do
      nil ->
        acc

      match ->
        ids = for team <- match, member <- team, into: MapSet.new(), do: member.id

        remaining_members =
          Enum.filter(members, fn m ->
            not MapSet.member?(ids, m.id)
          end)

        match_members(remaining_members, team_size, team_count, pred, [match | acc])
    end
  end

  # Returns an enumerable of matches for the given members, team size and team count
  # a match is a list of `team_count` teams. Each teams is a list of member such
  # that the number of player in the team is `team_size`
  @spec match_stream(
          members :: [Member.t()],
          team_size :: pos_integer(),
          team_count :: pos_integer()
        ) :: Enumerable.t([[[Member.t()]]])
  def match_stream(members, team_size, team_count) when team_count <= 1 do
    Combi.combinations(members, team_size)
    |> Stream.map(fn t -> [t] end)
  end

  def match_stream(members, team_size, team_count) do
    teams = Combi.combinations(members, team_size)

    Stream.flat_map(teams, fn team ->
      ids = for member <- team, into: MapSet.new(), do: member.id

      available_members =
        Enum.filter(members, fn m ->
          not MapSet.member?(ids, m.id)
        end)

      other_matches = match_stream(available_members, team_size, team_count - 1)

      Stream.map(other_matches, fn teams -> [team | teams] end)
    end)
  end
end
