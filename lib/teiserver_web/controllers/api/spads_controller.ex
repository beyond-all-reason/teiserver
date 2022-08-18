defmodule TeiserverWeb.API.SpadsController do
  use CentralWeb, :controller
  alias Teiserver.{Account, Coordinator}
  alias Teiserver.Battle.BalanceLib
  import Central.Helpers.NumberHelper, only: [int_parse: 1]
  require Logger

  # plug(Bodyguard.Plug.Authorize,
  #   policy: Teiserver.Battle.ApiAuth,
  #   action: {Phoenix.Controller, :action_name},
  #   user: {Central.Account.AuthLib, :current_user}
  # )

  @spec get_rating(Plug.Conn.t(), map) :: Plug.Conn.t()
  def get_rating(conn, %{
    "target_id" => target_id_str,
    "type" => type
  }) do
    actual_type = case type do
      "TeamFFA" -> "Team"
      "FFA" -> "Duel"
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
    player_data = params["players"]
      |> String.replace(": None", ": null")
      |> String.replace("'", "\"")
      |> Jason.decode

    bot_data = params["bots"]
      |> String.replace(": None", ": null")
      |> String.replace("'", "\"")
      |> Jason.decode

    case player_data do
      {:ok, data} ->
        player_names = data |> Map.keys

        if Enum.member?(player_names, "Teifion") do
          first_player_name = hd(player_names)

          client = Account.get_client_by_name(first_player_name)

          Logger.warn("Teifion present, balancing game")

          team_count = int_parse(params["nbTeams"])
          balance_result = Coordinator.call_balancer(client.lobby_id, {
            :make_balance, player_data, bot_data, team_count
          })

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

          # Temporary solution until FFA and Team FFA ratings are fixed
          rating_type = case rating_type do
            "Team FFA" -> "Team"
            "FFA" -> "Duel"
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
            |> Enum.sort
            |> Enum.with_index()
            |> Map.new(fn {{team_id, _, _, username}, idx} ->
              {username, %{
                "team" => team_id,
                "id" => idx
              }}
            end)

          bot_result = %{}

          # Logger.warn("Game balanced: #{Kernel.inspect balance_result}")

          conn
            |> put_status(200)
            |> assign(:deviation, balance_result.deviation)
            |> assign(:players, player_result)
            |> assign(:bots, bot_result)
            |> render("balance_battle.json")
        else
          conn
            |> put_status(200)
            |> render("empty.json")
        end

      {:error, error} ->
        Logger.error("Error at: #{__ENV__.file}:#{__ENV__.line}\nplayers decode error: #{Kernel.inspect error}")

        conn
          |> put_status(200)
          |> render("empty.json")
    end
  end
end
