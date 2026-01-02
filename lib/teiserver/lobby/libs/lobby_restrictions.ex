defmodule Teiserver.Lobby.LobbyRestrictions do
  @moduledoc """
  Helper methods for lobby policies
  """
  alias Teiserver.{CacheUser, Config}
  require Logger
  alias Teiserver.Battle.{BalanceLib, MatchLib}
  alias Teiserver.Battle

  @rank_upper_bound 1000
  @rating_upper_bound 1000
  @splitter "------------------------------------------------------"
  @spec rank_upper_bound() :: number
  def rank_upper_bound, do: @rank_upper_bound
  def rating_upper_bound, do: @rating_upper_bound

  def get_lobby_restrictions_welcome_text(state) do
    play_level_bounds = get_rating_bounds_for_title(state)
    play_rank_bounds = get_rank_bounds_for_title(state)

    cond do
      play_level_bounds == nil && play_rank_bounds == nil ->
        []

      true ->
        ["This lobby has the following play restrictions:", play_level_bounds, play_rank_bounds]
        |> Enum.filter(fn x -> x != nil end)
    end
  end

  def get_rank_bounds_for_title(consul_state) when consul_state == nil do
    nil
  end

  def get_rank_bounds_for_title(consul_state) do
    max_rank_to_play = Map.get(consul_state, :maximum_rank_to_play, @rank_upper_bound)
    min_rank_to_play = Map.get(consul_state, :minimum_rank_to_play, 0)

    # Chevlevel stuff here
    cond do
      # Default chev levels
      max_rank_to_play >= @rank_upper_bound &&
          min_rank_to_play <= 0 ->
        nil

      # Just a max rating
      max_rank_to_play < @rank_upper_bound &&
          min_rank_to_play <= 0 ->
        "Max chev: #{max_rank_to_play + 1}"

      # Just a min rating
      max_rank_to_play >= @rank_upper_bound &&
          min_rank_to_play > 0 ->
        "Min chev: #{min_rank_to_play + 1}"

      # Chev range
      # It shouldn't go here
      max_rank_to_play < @rank_upper_bound ||
          min_rank_to_play > 0 ->
        "Chev between: #{min_rank_to_play} - #{max_rank_to_play}"

      true ->
        nil
    end
  end

  def get_rating_bounds_for_title(consul_state) when consul_state == nil do
    nil
  end

  def get_rating_bounds_for_title(consul_state) do
    max_rating_to_play = Map.get(consul_state, :maximum_rating_to_play, @rating_upper_bound)
    min_rating_to_play = Map.get(consul_state, :minimum_rating_to_play, 0)

    cond do
      # Default ratings
      max_rating_to_play >= @rating_upper_bound &&
          min_rating_to_play <= 0 ->
        nil

      # Just a max rating
      max_rating_to_play < @rating_upper_bound &&
          min_rating_to_play <= 0 ->
        "Max rating: #{max_rating_to_play}"

      # Just a min rating
      max_rating_to_play >= @rating_upper_bound &&
          min_rating_to_play > 0 ->
        "Min rating: #{min_rating_to_play}"

      # Rating range
      max_rating_to_play < @rating_upper_bound ||
          min_rating_to_play > 0 ->
        "Rating: #{min_rating_to_play}-#{max_rating_to_play}"

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

  def get_failed_rating_check_text(
        player_rating,
        consul_state,
        rating_type,
        is_rating_hidden \\ false
      ) do
    bounds = get_rating_bounds_for_title(consul_state)
    player_rating_text = player_rating |> Decimal.from_float() |> Decimal.round(2)

    if is_rating_hidden do
      [
        @splitter,
        "This lobby has rating restrictions (#{bounds}). You won't be able to join until you play enough #{rating_type} matches for your rating to be visible."
      ]
    else
      [
        @splitter,
        "You don't meet the rating requirements for this lobby (#{bounds}). Your #{rating_type} match rating is #{player_rating_text}. Learn more about rating here:",
        "https://www.beyondallreason.info/guide/rating-and-lobby-balance#openskill"
      ]
    end
  end

  defp allow_bypass_rank_check?(user) do
    method = Config.get_site_config_cache("profile.Rank method")
    # When using Role method for ranks,
    # contributors auto pass since their ranks are not defined on playtime. To be fixed seperately.
    method == "Role" && CacheUser.is_contributor?(user)
  end

  @spec check_rank_to_play(any(), any()) :: :ok | {:error, iodata()}
  def check_rank_to_play(user, consul_state) do
    state = consul_state

    if allow_bypass_rank_check?(user) do
      :ok
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
          :ok
      end
    end
  end

  @doc """
  Determining the rating type is slightly different for lobby restrictions compared to rating a match.
  When rating a match we want to use the number of players and team count in the match.
  But with the lobby, we want to use the target team size/count defined by the dropdowns in the lobby.
  So if there are two players in the lobby, but the team size dropdown is 8, we want to use the "Large Team" rating.
  """
  @spec check_rating_to_play(any(), any()) :: :ok | {:error, iodata()}
  def check_rating_to_play(user_id, consul_state) do
    state = consul_state
    team_size = state.host_teamsize
    team_count = state.host_teamcount

    rating_type = MatchLib.game_type(team_size, team_count)

    {player_rating, player_uncertainty} =
      BalanceLib.get_user_rating_value_uncertainty_pair(user_id, rating_type)

    max_uncertainty =
      Config.get_site_config_cache("teiserver.Uncertainty required to show rating")

    is_rating_hidden = player_uncertainty > max_uncertainty

    player_rating =
      if is_rating_hidden do
        0
      else
        player_rating
      end

    cond do
      state.minimum_rating_to_play != nil and player_rating < state.minimum_rating_to_play ->
        msg = get_failed_rating_check_text(player_rating, state, rating_type, is_rating_hidden)
        {:error, msg}

      state.maximum_rating_to_play != nil and player_rating > state.maximum_rating_to_play ->
        msg = get_failed_rating_check_text(player_rating, state, rating_type, is_rating_hidden)
        {:error, msg}

      true ->
        # All good
        :ok
    end
  end

  @doc """
  You cannot have all welcome lobby name if there are restrictions
  """
  @spec check_lobby_name(String.t(), any()) ::
          {:error, String.t()} | {:ok, String.t()} | {:ok, nil}
  def check_lobby_name(name, consul_state) do
    cond do
      has_restrictions?(consul_state) and allwelcome_name?(name) ->
        {:error,
         "* You cannot declare a lobby to be all welcome if there are player restrictions"}

      true ->
        {:ok, get_tips(name)}
    end
  end

  defp get_tips(name) do
    tips = [] ++ get_noob_looby_tips(name) ++ get_rotato_tips(name)

    case length(tips) do
      0 -> nil
      _ -> tips
    end
  end

  defp get_noob_looby_tips(lobby_title) do
    case is_noob_title?(lobby_title) do
      true ->
        [
          @splitter,
          "Useful commands for Noob lobbies",
          @splitter,
          "To restrict this lobby to players who are new, use either:",
          "!maxchevlevel <chevlevel>",
          "!maxratinglevel <rating>",
          ""
        ]

      false ->
        []
    end
  end

  defp get_rotato_tips(lobby_title) do
    case is_rotato_title?(lobby_title) do
      true ->
        [
          # Temporary tips until this is part of Chobby UI
          @splitter,
          "Useful commands for map rotation",
          @splitter,
          "To turn on/off auto map rotation at end of each match:",
          "!rotationEndGame <(random|off)>",
          ""
        ]

      false ->
        []
    end
  end

  # Check if lobby has restrictions for playing
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
  @spec allowed_to_set_restrictions(map()) :: :ok | {:error, String.t()}
  def allowed_to_set_restrictions(state) do
    name =
      state.lobby_id
      |> Battle.get_lobby()
      |> Map.get(:name)

    cond do
      not state.ranked and not Config.get_site_config_cache("lobby.Unranked lobby restrictions") ->
        {:error, "You cannot set a limit if the lobby is unranked"}

      allwelcome_name?(name) ->
        {:error, "You cannot set a limit if all are welcome to the game"}

      true ->
        :ok
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
  @spec is_noob_title?(String.t()) :: boolean()
  def is_noob_title?(title) do
    anti_noob_regex = ~r/no (noob|newb|nub)/i
    noob_regex = ~r/\b(noob|newb|nub(s|\b))/i

    Regex.match?(noob_regex, title) && !Regex.match?(anti_noob_regex, title)
  end

  @spec is_rotato_title?(String.t()) :: boolean()
  def is_rotato_title?(title) do
    regex = ~r/\b(rotat)/i

    Regex.match?(regex, title)
  end
end
