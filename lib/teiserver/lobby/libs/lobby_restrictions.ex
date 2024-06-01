defmodule Teiserver.Lobby.LobbyRestrictions do
  @moduledoc """
  Helper methods for lobby policies
  """
  alias Teiserver.CacheUser
  require Logger
  alias Teiserver.Battle.BalanceLib
  alias Teiserver.Battle

  @rank_upper_bound 1000
  @rating_upper_bound 1000
  @splitter "---------------------------"
  @spec rank_upper_bound() :: number
  def rank_upper_bound, do: @rank_upper_bound
  def rating_upper_bound, do: @rating_upper_bound

  def get_lobby_restrictions_welcome_text(state) do
    play_level_bounds = get_rating_bounds_text(state)
    play_rank_bounds = get_rank_bounds_text(state)

    cond do
      play_level_bounds == nil && play_rank_bounds == nil -> []
      true -> ["This lobby has the following play restrictions:", play_level_bounds, play_rank_bounds]
      |> Enum.filter(fn x-> x != nil end)
    end
  end

  def get_rating_bounds_text(state) do
    get_rating_bounds_for_title(state)
  end

  def get_rank_bounds_text(state) do
    get_rank_bounds_for_title(state)
  end

  def get_rank_bounds_for_title(consul_state) when consul_state == nil do
    nil
  end

  def get_rank_bounds_for_title(consul_state) do
    default_state = %{maximum_rank_to_play: @rank_upper_bound, minimum_rank_to_play: 0}
    consul_state = Map.merge(default_state, consul_state)
    # Chevlevel stuff here
    cond do
      # Default chev levels
      consul_state.maximum_rank_to_play >= @rank_upper_bound &&
          consul_state.minimum_rank_to_play <= 0 ->
        nil

      # Just a max rating
      consul_state.maximum_rank_to_play < @rank_upper_bound &&
          consul_state.minimum_rank_to_play <= 0 ->
        "Max chev: #{consul_state.maximum_rank_to_play + 1}"

      # Just a min rating
      consul_state.maximum_rank_to_play >= @rank_upper_bound &&
          consul_state.minimum_rank_to_play > 0 ->
        "Min chev: #{consul_state.minimum_rank_to_play + 1}"

      # Chev range
      # It shouldn't go here
      consul_state.maximum_rank_to_play < @rank_upper_bound ||
          consul_state.minimum_rank_to_play > 0 ->
        "Chev between: #{consul_state.minimum_rank_to_play} - #{consul_state.maximum_rank_to_play}"

      true ->
        nil
    end
  end

  def get_rating_bounds_for_title(consul_state) when consul_state == nil do
    nil
  end

  def get_rating_bounds_for_title(consul_state) do
    default_state = %{maximum_rating_to_play: @rating_upper_bound, minimum_rating_to_play: 0}
    consul_state = Map.merge(default_state, consul_state)

    cond do
      # Default ratings
      consul_state.maximum_rating_to_play >= @rating_upper_bound &&
          consul_state.minimum_rating_to_play <= 0 ->
        nil

      # Just a max rating
      consul_state.maximum_rating_to_play < @rating_upper_bound &&
          consul_state.minimum_rating_to_play <= 0 ->
        "Max rating: #{consul_state.maximum_rating_to_play}"

      # Just a min rating
      consul_state.maximum_rating_to_play >= @rating_upper_bound &&
          consul_state.minimum_rating_to_play > 0 ->
        "Min rating: #{consul_state.minimum_rating_to_play}"

      # Rating range
      consul_state.maximum_rating_to_play < @rating_upper_bound ||
          consul_state.minimum_rating_to_play > 0 ->
        "Rating between: #{consul_state.minimum_rating_to_play} - #{consul_state.maximum_rating_to_play}"

      true ->
        nil
    end
  end

  def get_failed_rank_check_text(player_rank, consul_state) do
    bounds = get_rank_bounds_for_title(consul_state)

    [
      @splitter,
      "You don't meet the chevron requirements for this lobby (#{bounds}). Your chevron level is #{player_rank + 1}. Learn more about chevrons here:",
      "https://www.beyondallreason.info/guide/rating-and-lobby-balance#rank-icons"
    ]
  end

  def get_failed_rating_check_text(player_rating, consul_state, rating_type) do
    bounds = get_rating_bounds_for_title(consul_state)
    player_rating_text = player_rating |> Decimal.from_float() |> Decimal.round(2)

    [
      @splitter,
      "You don't meet the rating requirements for this lobby (#{bounds}). Your #{rating_type} match rating is #{player_rating_text}. Learn more about rating here:",
      "https://www.beyondallreason.info/guide/rating-and-lobby-balance#openskill"
    ]
  end

  @doc """
  Returns {:ok, nil} or {:error,msg}
  """
  def check_rank_to_play(user, consul_state) do
    state = consul_state

    # Contributors auto pass since their ranks are not defined on playtime. To be fixed seperately.
    is_contributor? = CacheUser.is_contributor?(user)

    if is_contributor? do
      {:ok, nil}
    else
      cond do
        state.minimum_rank_to_play != nil and user.rank < state.minimum_rank_to_play ->
          # Send message
          msg = get_failed_rank_check_text(user.rank, state)
          {:error, msg}

        state.maximum_rank_to_play != nil and user.rank > state.maximum_rank_to_play ->
          # Send message
          msg = get_failed_rank_check_text(user.rank, state)
          {:error, msg}

        true ->
          {:ok, nil}
      end
    end
  end

  @doc """
  Returns {:ok, nil} or {:error,msg}
  """
  def check_rating_to_play(user_id, consul_state) do
    state = consul_state
    team_size = state.host_teamsize
    team_count = state.host_teamcount

    rating_type =
      cond do
        team_count > 2 && team_size == 1 -> "FFA"
        team_count > 2 && team_size > 1 -> "Team FFA"
        team_size == 1 -> "Duel"
        true -> "Team"
      end

    {player_rating, _player_uncertainty} =
      BalanceLib.get_user_rating_value_uncertainty_pair(user_id, rating_type)

    cond do
      state.minimum_rating_to_play != nil and player_rating < state.minimum_rating_to_play ->
        msg = get_failed_rating_check_text(player_rating, state, rating_type)
        {:error, msg}

      state.maximum_rating_to_play != nil and player_rating > state.maximum_rating_to_play ->
        msg = get_failed_rating_check_text(player_rating, state, rating_type)
        {:error, msg}

      true ->
        # All good
        {:ok, nil}
    end
  end

  @doc """
  You cannot have all welcome lobby name if there are restrictions
  Returns {:ok, nil}
  Or {:error, msg}
  """
  def check_lobby_name(name, consul_state) do
    cond do
      has_restrictions?(consul_state) and allwelcome_name?(name) ->
        {:error,
         "* You cannot declare a lobby to be all welcome if there are player restrictions"}

      is_noob_title?(name) ->
        {:ok,  get_noob_looby_tips()}

      true ->
        {:ok, nil}
    end
  end

  defp get_noob_looby_tips() do
    [
      @splitter, "Noob lobby tips", @splitter,
      "To restrict this lobby to players who are new, use command:",
      "$maxchevlevel <chevlevel>",
      "To ensure new players are distributed evenly across teams, use command:",
      "$balancemode split_one_chevs"
    ]
  end

  #Check if lobby has restrictions for playing
  defp has_restrictions?(consul_state) do
    state = consul_state

    cond do
      state.maximum_rating_to_play < @rating_upper_bound -> true
      state.minimum_rating_to_play > 0 -> true
      state.minimum_rank_to_play > 0 -> true
      state.maximum_rank_to_play < @rank_upper_bound -> true
      true -> false
    end
  end

  # Teifion added code to prevent setting restrictions to All Welcome lobbies
  def allowed_to_set_restrictions(state) do
    name =
      state.lobby_id
      |> Battle.get_lobby()
      |> Map.get(:name)

    cond do
      allwelcome_name?(name) -> {:error, "You cannot set a rating limit if all are welcome to the game"}
      true -> {:ok, nil}
    end
  end

  defp allwelcome_name?(name) do
    name =
      name
      |> String.downcase()
      |> String.replace(" ", "")

    cond do
      String.contains?(name, "allwelcome") -> true
      true -> false
    end
  end

  @doc """
  Checks if the lobby title indicates a noob lobby
  """
  def is_noob_title?(title) do
    title =
      title
      |> String.downcase()

    anti_noob_regex = ~r/no (noob|newb|nub)/
    noob_regex = ~r/\b(noob|newb|nub(s|\b))/

    noob_matches =
      Regex.scan(noob_regex, title)
      |> Enum.count()

    anti_noob_matches =
      Regex.scan(anti_noob_regex, title)
      |> Enum.count()

    cond do
      noob_matches > 0 && anti_noob_matches == 0 -> true
      true -> false
    end
  end
end
