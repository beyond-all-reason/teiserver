defmodule TeiserverWeb.API.SpadsController do
  use CentralWeb, :controller
  alias Central.Config
  alias Teiserver.{Account, Coordinator}
  alias Teiserver.Battle.BalanceLib
  import Central.Helpers.NumberHelper, only: [int_parse: 1]
  require Logger

  @spec get_rating(Plug.Conn.t(), map) :: Plug.Conn.t()
  def get_rating(conn, %{
    "target_id" => "None",
    "type" => _
  }) do
    conn
      |> put_status(200)
      |> render("empty.json")
  end

  def get_rating(conn, %{
    "target_id" => target_id_str,
    "type" => type
  }) do
    actual_type = case type do
      "TeamFFA" -> "FFA"
      v -> v
    end

    target_id = int_parse(target_id_str)

    {rating_value, uncertainty} = BalanceLib.get_user_rating_value_uncertainty_pair(target_id, actual_type)

    conn
      |> put_status(200)
      |> assign(:rating_value, rating_value)
      |> assign(:uncertainty, uncertainty)
      |> render("rating.json")
  end

  @spec balance_battle(Plug.Conn.t(), map) :: Plug.Conn.t()
  def balance_battle(conn, params) do
    server_balance_enabled = Config.get_site_config_cache("teiserver.Enable server balance")

    raw_player_data = params["players"]
      |> String.replace(": None", ": null")
      |> String.replace("'", "\"")
      |> Jason.decode

    bot_data = params["bots"]
      |> String.replace(": None", ": null")
      |> String.replace("'", "\"")
      |> Jason.decode

    player_data = case raw_player_data do
      {:ok, data} -> data
      _ -> :error
    end

    bot_data = case bot_data do
      {:ok, data} -> data
      _ -> :error
    end

    balance_enabled = cond do
      player_data == :error -> false
      Enum.empty?(player_data) -> false
      Enum.empty?(bot_data) == false -> false
      server_balance_enabled == false -> false
      true -> true
    end

    client = if balance_enabled do
      player_names = Map.keys(player_data)
      first_player_name = hd(player_names)
      Account.get_client_by_name(first_player_name)
    end

    cond do
      client == nil ->
        conn
          |> put_status(200)
          |> render("empty.json")

      client.lobby_id == nil ->
        conn
          |> put_status(200)
          |> render("empty.json")

      balance_enabled == true ->
        team_count = int_parse(params["nbTeams"])

        opts = [
          allow_groups: params["balanceMode"] != "skill"
        ]

        balance_result = Coordinator.call_balancer(client.lobby_id, {
          :make_balance, team_count, opts
        })

        if balance_result do

          # Get some counts for later
          total_players = balance_result.team_sizes
            |> Map.values
            |> Enum.sum

          team_count = balance_result.team_sizes
            |> Enum.count

          # Calculate the rating type
          rating_type = cond do
            total_players == 2 -> "Duel"
            team_count == 2 -> "Team"
            total_players == team_count -> "FFA"
            true -> "Team FFA"
          end

          # Temporary solution until Team FFA ratings are fixed
          rating_type = case rating_type do
            "Team FFA" -> "FFA"
            v -> v
          end

          player_result = balance_result.team_players
            |> Enum.map(fn {team_id, players} ->
              players
                |> Enum.map(fn userid ->
                  rating_value = BalanceLib.get_user_rating_value(userid, rating_type)
                  {team_id, rating_value, userid, Account.get_username_by_id(userid)}
                end)
            end)
            |> List.flatten
            |> Enum.sort(&>=/2)
            |> Enum.with_index()
            |> Map.new(fn {{team_id, _, _, username}, idx} ->
              {username, %{
                "team" => team_id - 1,
                "id" => idx
              }}
            end)

          bot_result = %{}

          conn
            |> put_status(200)
            |> assign(:deviation, balance_result.deviation)
            |> assign(:players, player_result)
            |> assign(:bots, bot_result)
            |> render("balance_battle.json")

        else
          # No balance result
          conn
            |> put_status(200)
            |> render("empty.json")
        end

      true ->
        conn
          |> put_status(200)
          |> render("empty.json")
    end
  end
end
