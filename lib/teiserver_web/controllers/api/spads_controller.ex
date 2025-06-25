defmodule TeiserverWeb.API.SpadsController do
  use TeiserverWeb, :controller
  alias Teiserver.Config
  alias Teiserver.{Account, Coordinator, Battle}
  alias Teiserver.Battle.{BalanceLib, MatchLib}
  alias Teiserver.Data.Types, as: T
  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]
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
    target_id = int_parse(target_id_str)
    lobby = get_member_lobby(target_id)

    host_ip =
      case lobby do
        nil -> nil
        _ -> Account.get_client_by_id(lobby.founder_id).ip
      end

    actual_type =
      case type do
        "Team FFA" -> "Large Team"
        v -> v
      end

    conn_ip =
      conn
      |> Teiserver.Logging.LoggingPlug.get_ip_from_conn()
      |> Tuple.to_list()
      |> Enum.join(".")

    {rating_value, uncertainty} =
      if host_ip != conn_ip do
        BalanceLib.get_user_rating_value_uncertainty_pair(-1, "Duel")
      else
        BalanceLib.get_user_rating_value_uncertainty_pair(target_id, actual_type)
      end

    max_uncertainty =
      Config.get_site_config_cache("teiserver.Uncertainty required to show rating")

    rating_value =
      if uncertainty > max_uncertainty do
        0
      else
        rating_value
      end

    conn
    |> put_status(200)
    |> assign(:rating_value, rating_value)
    |> assign(:uncertainty, uncertainty)
    |> render("rating.json")
  end

  @spec balance_battle(Plug.Conn.t(), map) :: Plug.Conn.t()
  def balance_battle(conn, params) do
    server_balance_enabled = Config.get_site_config_cache("teiserver.Enable server balance")

    raw_player_data =
      params["players"]
      |> String.replace(": None", ": null")
      |> String.replace("'", "\"")
      |> Jason.decode()

    bot_data =
      params["bots"]
      |> String.replace(": None", ": null")
      |> String.replace("'", "\"")
      |> Jason.decode()

    player_data =
      case raw_player_data do
        {:ok, data} -> data
        _ -> :error
      end

    bot_data =
      case bot_data do
        {:ok, data} -> data
        _ -> :error
      end

    # first_player_id = player_data
    #   |> Map.keys()
    #   |> hd
    #   |> Account.get_userid_from_name

    # host_ip = get_member_of_lobby_host_ip(first_player_id)

    # conn_ip = conn
    #   |> Teiserver.Logging.LoggingPlug.get_ip_from_conn
    #   |> Tuple.to_list()
    #   |> Enum.join(".")

    # if host_ip != conn_ip do
    #   Logger.error("balance_battle with no ip match (#{inspect conn_ip} != #{inspect host_ip} (id = #{first_player_id})), params: #{inspect params}")
    #   # raise "Internal server error"
    # end

    team_count = int_parse(params["nbTeams"])

    balance_enabled =
      cond do
        player_data == :error -> false
        Enum.empty?(player_data) -> false
        Enum.empty?(bot_data) == false -> false
        server_balance_enabled == false -> false
        true -> true
      end

    client =
      if balance_enabled do
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
        opts = [
          # Balancing with parties in lobbies with large player counts can lead to OOM issues
          # Balancing algorithmss in these conditions can generate a large number of combinations
          # which can quickly fill up all available memory
          allow_groups: Enum.count(player_data) <= 16 and params["balanceMode"] != "skill"
        ]

        balance_result =
          Coordinator.call_balancer(client.lobby_id, {
            :make_balance,
            team_count,
            opts
          })

        if is_non_empty_balance_result?(balance_result) do
          # Get some counts for later
          team_count =
            balance_result.team_sizes
            |> Enum.count()

          team_size =
            balance_result.team_sizes
            |> Map.values()
            |> Enum.max()

          # Get the rating type
          rating_type = MatchLib.game_type(team_size, team_count)

          # Temporary solution until Team FFA ratings are fixed
          rating_type =
            case rating_type do
              "Team FFA" -> "Large Team"
              v -> v
            end

          player_result =
            balance_result.team_players
            |> Enum.map(fn {team_id, players} ->
              players
              |> Enum.map(fn userid ->
                rating_value = BalanceLib.get_user_rating_value(userid, rating_type)
                {team_id, rating_value, userid, Account.get_username_by_id(userid)}
              end)
            end)
            |> List.flatten()
            |> Enum.sort(&>=/2)
            |> Enum.with_index()
            |> Map.new(fn {{team_id, _, _, username}, idx} ->
              {username,
               %{
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

  def is_non_empty_balance_result?(balance_result) do
    cond do
      balance_result == nil -> false
      balance_result.team_sizes == %{} -> false
      true -> true
    end
  end

  @spec get_member_lobby(non_neg_integer()) :: T.lobby() | nil
  defp get_member_lobby(userid) do
    case Account.get_client_by_id(userid) do
      nil ->
        nil

      client ->
        Battle.get_lobby(client.lobby_id)
    end
  end
end
