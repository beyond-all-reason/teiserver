defmodule Teiserver.Matchmaking.Algos do
  @moduledoc """
  Interface for matchmaking algorithms
  """

  alias Teiserver.Matchmaking.Member

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
  """
  @callback get_matches(
              members :: [Member.t()],
              state :: state()
            ) :: :no_match | {:match, [[[Member.t()]]]}
end
