defmodule Teiserver.Account.TournamentReport do
  alias Teiserver.{Account}
  alias Teiserver.Game.MatchRatingLib

  @spec icon() :: String.t()
  def icon(), do: Teiserver.Account.RatingLib.icon()

  @spec permissions() :: String.t()
  def permissions(), do: "teiserver.staff"

  @spec run(Plug.Conn.t(), map()) :: {nil, map()}
  def run(_conn, params) do
    params = apply_defaults(params)

    name_to_id_map =
      (params["names"] || "")
      |> String.trim()
      |> String.replace(",", "\n")
      |> String.split("\n")
      |> Map.new(fn name ->
        {String.trim(name), Account.get_userid_from_name(name)}
      end)

    if params["make_players"] == "true" do
      id_list = Map.values(name_to_id_map) |> Enum.reject(&(&1 == nil))

      Account.list_users(
        search: [id_in: id_list],
        limit: Enum.count(id_list)
      )
      |> Enum.each(fn user ->
        new_roles = ["Tournament player" | user.data["roles"] || []] |> Enum.uniq()
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
          user_id_in: Map.values(name_to_id_map)
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

    assigns = %{
      params: params,
      name_to_id_map: name_to_id_map,
      game_types: MatchRatingLib.rating_type_list(),
      no_ratings: no_ratings,
      ratings: ratings,
      csv_data: make_csv_data(ratings, params["value_type"])
    }

    {nil, assigns}
  end

  defp add_csv_headings(output, value_type) do
    headings = [
      [
        "Position",
        "UserId",
        "Player",
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
