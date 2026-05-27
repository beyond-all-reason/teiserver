defmodule Teiserver.Lobby.LobbyRestrictions do
  @moduledoc """
  Helper methods for lobby policies
  """

  alias Teiserver.Account.Auth
  alias Teiserver.Battle
  alias Teiserver.Battle.BalanceLib
  alias Teiserver.Battle.MatchLib
  alias Teiserver.Config
  alias Teiserver.Helper.StringHelper

  require Logger

  @rank_upper_bound 7
  @rating_upper_bound 1000
  @splitter "------------------------------------------------------"

  @unranked_title_error "You cannot set a limit if the lobby is unranked."
  @all_welcome_title_error "Games declaring all are welcome cannot have player restrictions."
  @pro_title_error "You cannot set a maximum limit for lobby names referencing pros."
  @noob_title_error "You cannot set a minimum limit for lobby names referencing new players."

  @spec rank_upper_bound() :: number
  def rank_upper_bound, do: @rank_upper_bound
  def rating_upper_bound, do: @rating_upper_bound

  def get_lobby_restrictions_welcome_text(state) do
    play_level_bounds = get_rating_bounds_for_title(state)
    play_rank_bounds = get_rank_bounds_for_title(state)

    if is_nil(play_level_bounds) && is_nil(play_rank_bounds) do
      []
    else
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
    # contributors auto pass since their ranks are not defined
    # on playtime. To be fixed separately.
    method == "Role" && Auth.contributor?(user)
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
          {:error, String.t()} | :ok
  def check_lobby_name(name, consul_state) do
    restrictions = restriction_types(consul_state)

    cond do
      allwelcome_title?(name) and not Enum.empty?(restrictions) ->
        {:error, @all_welcome_title_error}

      pro_title?(name) and Enum.member?(restrictions, :max) ->
        {:error, @pro_title_error}

      noob_title?(name) and Enum.member?(restrictions, :min) ->
        {:error, @noob_title_error}

      true ->
        :ok
    end
  end

  @spec get_tips(String.t()) :: [String.t()] | nil
  def get_tips(name) do
    tips = [] ++ get_noob_looby_tips(name) ++ get_rotato_tips(name)

    case length(tips) do
      0 -> nil
      _count -> tips
    end
  end

  defp get_noob_looby_tips(lobby_title) do
    case noob_title?(lobby_title) do
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
    case rotato_title?(lobby_title) do
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

  # Return a list of the restriction types (min, max) defining
  # play boundaries for the lobby
  defp restriction_types(consul_state) do
    state = consul_state

    [
      if(state.maximum_rating_to_play < @rating_upper_bound, do: :max),
      if(state.minimum_rating_to_play > 0, do: :min),
      if(state.minimum_rank_to_play > 0, do: :min),
      if(state.maximum_rank_to_play < @rank_upper_bound, do: :max)
    ]
    |> Enum.reject(&is_nil(&1))
    |> Enum.uniq()
  end

  @spec allowed_to_set_restrictions(map(), :max | :min | :any) :: :ok | {:error, String.t()}
  def allowed_to_set_restrictions(state, :any) do
    case allowed_to_set_restrictions(state, :max) do
      :ok -> allowed_to_set_restrictions(state, :min)
      result -> result
    end
  end

  def allowed_to_set_restrictions(state, :max) do
    name =
      (Battle.get_lobby(state.lobby_id) || %{})
      |> Map.get(:name)

    cond do
      not state.ranked and not Config.get_site_config_cache("lobby.Unranked lobby restrictions") ->
        {:error, @unranked_title_error}

      allwelcome_title?(name) ->
        {:error, @all_welcome_title_error}

      pro_title?(name) ->
        {:error, @pro_title_error}

      true ->
        :ok
    end
  end

  def allowed_to_set_restrictions(state, :min) do
    name =
      (Battle.get_lobby(state.lobby_id) || %{})
      |> Map.get(:name)

    cond do
      not state.ranked and not Config.get_site_config_cache("lobby.Unranked lobby restrictions") ->
        {:error, @unranked_title_error}

      allwelcome_title?(name) ->
        {:error, @all_welcome_title_error}

      noob_title?(name) ->
        {:error, @noob_title_error}

      true ->
        :ok
    end
  end

  defp allwelcome_title?(nil), do: false

  defp allwelcome_title?(title) do
    title = StringHelper.leet_replace(title)

    # Matches against all welcome and a couple of typo'd versions
    Regex.match?(~r/all?\s?well?come/, title)
  end

  @spec pro_title?(String.t()) :: boolean()
  def pro_title?(title) do
    title = StringHelper.leet_replace(title)
    pattern = ~r/\b(pro|professional)\b/i

    Regex.match?(pattern, title)
  end

  @doc """
  Checks if the lobby title indicates a noob lobby, returns false if
  no noob reference detected or a negation of a noob reference is
  detected.
  """
  @spec noob_title?(String.t()) :: boolean()
  def noob_title?(title) do
    title = StringHelper.leet_replace(title)

    # Attempts to match a negation and a reference to noobs
    anti_noob_regex = ~r/(?:\b(no)\s)?(new\splayer|noobs?|newb|nub(?:z|s| ))/

    case Regex.scan(anti_noob_regex, title) do
      [[_full, _no_noob, ""]] ->
        # Not matching on the noob part at all
        false

      [[_full, "", _noob_in_title]] ->
        # This matches on the noob part but not the negative
        true

      [[_full, _no_noob, _noob_in_title]] ->
        # Matching the negative
        false

      _no_valid_match ->
        false
    end
  end

  @spec rotato_title?(String.t()) :: boolean()
  def rotato_title?(title) do
    regex = ~r/\b(rotat)/i

    Regex.match?(regex, title)
  end
end
