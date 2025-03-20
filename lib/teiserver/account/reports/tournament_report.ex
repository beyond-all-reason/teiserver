defmodule Teiserver.Account.TournamentReport do
  @moduledoc false
  alias Teiserver.{Account}
  alias Teiserver.Game.MatchRatingLib
  alias Teiserver.Helper.TimexHelper
  import Teiserver.Helper.NumberHelper, only: [round: 2]

  @spec icon() :: String.t()
  def icon(), do: Teiserver.Account.RatingLib.icon()

  @spec permissions() :: String.t()
  def permissions(), do: "Moderator"

  defp get_player_id("#" <> id_str), do: String.to_integer(id_str)

  defp get_player_id(name) do
    Account.get_userid_from_name(name)
  end

  @spec make_split_data(String.t()) :: %{non_neg_integer => {String.t(), non_neg_integer()}}
  defp make_split_data(data) do
    data
    |> String.trim()
    |> String.split("\n")
    |> Enum.with_index()
    |> Map.new(fn {row, team_idx} ->
      id_map =
        row
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.filter(fn
          "" -> false
          _ -> true
        end)
        |> Enum.map(fn name ->
          {String.trim(name), get_player_id(name)}
        end)
        |> Enum.reject(fn {_, n} -> n == nil end)

      {team_idx, id_map}
    end)
  end

  @spec run(Plug.Conn.t(), map()) :: {nil, map()}
  def run(_conn, params) do
    params = apply_defaults(params)

    # First we take our lines and break them into teams
    split_data = make_split_data(params["names"] || "")

    name_to_id_map =
      split_data
      |> Map.values()
      |> List.flatten()
      |> Map.new()

    missing_names =
      (params["names"] || "")
      |> String.trim()
      |> String.replace(",", "\n")
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(fn name ->
        Map.has_key?(name_to_id_map, name)
      end)

    if params["make_players"] == "true" do
      id_list = name_to_id_map |> Map.values() |> Enum.reject(&(&1 == nil))

      Account.list_users(
        search: [id_in: id_list],
        limit: Enum.count(id_list)
      )
      |> Enum.each(fn user ->
        new_roles = ["Tournament" | user.roles || []] |> Enum.uniq()
        new_data = user.data |> Map.put("roles", new_roles)

        Account.update_user(user, %{"data" => new_data})
        Account.recache_user(user.id)
      end)

      :timer.sleep(500)
    end

    type_name = params["game_type"]

    {type_id, _type_name} =
      case MatchRatingLib.rating_type_name_lookup()[type_name] do
        nil ->
          type_name = hd(MatchRatingLib.rating_type_list())
          {MatchRatingLib.rating_type_name_lookup()[type_name], type_name}

        v ->
          {v, type_name}
      end

    order_by =
      case params["value_type"] do
        "Leaderboard rating" -> "Leaderboard rating high to low"
        "Game rating" -> "Rating value high to low"
        "Skill value" -> "Skill high to low"
      end

    ratings =
      Account.list_ratings(
        search: [
          rating_type_id: type_id,
          user_id_in: Map.values(name_to_id_map),
          season: MatchRatingLib.active_season()
        ],
        order_by: order_by,
        preload: [:user],
        limit: Enum.count(name_to_id_map)
      )

    found_ids =
      ratings
      |> Enum.map(fn r -> r.user_id end)

    no_ratings =
      name_to_id_map
      |> Enum.reject(fn {_, id} -> id == nil or Enum.member?(found_ids, id) end)
      |> Map.new()
      |> Map.keys()

    teams_as_ids =
      split_data
      |> Map.values()
      |> Enum.map_join("\n", fn team_data ->
        team_data
        |> Enum.map_join(", ", fn {_name, id} -> "##{id}" end)
      end)

    rating_values =
      ratings
      |> Map.new(fn rating ->
        value =
          case params["value_type"] do
            "Leaderboard rating" -> rating.leaderboard_rating
            "Game rating" -> rating.rating_value
            "Skill value" -> rating.skill
          end

        {rating.user_id, value}
      end)

    %{
      params: params,
      name_to_id_map: name_to_id_map,
      game_types: MatchRatingLib.rating_type_list(),
      no_ratings: no_ratings,
      ratings: ratings,
      missing_names: missing_names,
      teams_as_ids: teams_as_ids,
      team_data: make_team_data(split_data, rating_values),
      csv_data: make_csv_data(ratings, params["value_type"])
    }
  end

  defp make_team_data(split_data, rating_values) do
    split_data
    |> Map.new(fn {team_id, members} ->
      name_rating_pairs =
        members
        |> Enum.map(fn {name, userid} -> {name, rating_values[userid]} end)
        |> Enum.reject(fn {_, rating} -> rating == nil end)

      aggregate_data =
        name_rating_pairs
        |> Enum.map(fn {_, rating} -> rating end)
        |> aggregate_team_ratings

      captain =
        name_rating_pairs
        |> Enum.sort_by(fn {_, rating} -> rating end, &>=/2)
        |> Enum.take(1)

      aggregate_data =
        case captain do
          [{name, rating}] ->
            Map.merge(aggregate_data, %{
              captain_name: name,
              captain_rating: rating |> round(2)
            })

          _ ->
            aggregate_data
        end

      {team_id, aggregate_data}
    end)
  end

  defp aggregate_team_ratings([]) do
    %{
      mean: 0,
      median: 0,
      stdev: 0,
      count: 0,
      max: 0,
      min: 0,
      captain_name: "",
      captain_rating: 0
    }
  end

  defp aggregate_team_ratings(ratings) do
    %{
      mean: Statistics.mean(ratings) |> round(2),
      median: Statistics.median(ratings) |> round(2),
      stdev: Statistics.stdev(ratings) |> round(2),
      count: Enum.count(ratings),
      max: Enum.max(ratings) |> round(2),
      min: Enum.min(ratings) |> round(2),
      captain_name: "",
      captain_rating: 0
    }
  end

  defp add_csv_headings(output, value_type) do
    headings = [
      [
        "Position",
        "UserId",
        "Player",
        "Registration date",
        value_type
      ]
    ]

    headings ++ output
  end

  defp make_csv_data(ratings, value_type) do
    ratings
    |> Enum.with_index()
    |> Enum.map(fn {rating, index} ->
      value =
        case value_type do
          "Leaderboard rating" -> rating.leaderboard_rating
          "Game rating" -> rating.rating_value
          "Skill value" -> rating.skill
        end

      [
        index + 1,
        rating.user.id,
        rating.user.name,
        TimexHelper.date_to_str(rating.user.inserted_at, format: :ymd),
        value
      ]
    end)
    |> add_csv_headings(value_type)
    |> CSV.encode(separator: ?\t)
    |> Enum.to_list()
  end

  defp apply_defaults(params) do
    Map.merge(
      %{
        "game_type" => MatchRatingLib.rating_type_list() |> hd,
        "value_type" => "Leaderboard rating"
      },
      Map.get(params, "report", %{})
    )
  end
end
