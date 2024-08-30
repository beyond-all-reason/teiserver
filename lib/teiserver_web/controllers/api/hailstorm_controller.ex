defmodule TeiserverWeb.API.HailstormController do
  use TeiserverWeb, :controller
  alias Teiserver.{Account, CacheUser, Config, Coordinator, Lobby}
  alias Teiserver.Game.MatchRatingLib
  alias Teiserver.Battle.BalanceLib
  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]

  plug(Bodyguard.Plug.Authorize,
    policy: Teiserver.API.HailstormAuth,
    action: {Phoenix.Controller, :action_name},
    user: {Teiserver.Account.AuthLib, :current_user}
  )

  @spec start(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def start(conn, _params) do
    conn
    |> put_status(201)
    |> assign(:result, %{up: true})
    |> render("result.json")
  end

  @spec create_user(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create_user(conn, params) do
    email = params["email"] || params["name"]
    name = params["name"] <> "_hailstorm"

    result =
      case Account.get_user_by_email(email) do
        nil ->
          case CacheUser.register_user(name, email, params["password"]) do
            :success ->
              db_user = Account.get_user!(nil, search: [email: email])
              Account.script_update_user(db_user, params["permissions"] || [])

              # Specific updates
              CacheUser.add_roles(db_user.id, params["roles"])

              %{userid: db_user.id}

            {:error, reason} ->
              %{
                result: "failure",
                stage: "CacheUser.register_user",
                reason: reason
              }
          end

        user ->
          # Update the user
          CacheUser.add_roles(user.id, params["roles"])

          CacheUser.set_flood_level(user.id, 0)
          %{userid: user.id}
      end

    conn
    |> put_status(201)
    |> assign(:result, result)
    |> render("result.json")
  end

  @spec db_update_user(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def db_update_user(conn, %{"email" => email, "attrs" => attrs}) do
    result =
      case Account.get_user_by_email(email) do
        nil ->
          %{
            "result" => "failure",
            "stage" => "get_user_by_email",
            "error" => "No user found"
          }

        user ->
          db_user = Account.get_user(user.id)

          case Account.update_user(db_user, attrs) do
            {:ok, _user} ->
              %{"result" => "success"}

            {:error, changeset} ->
              %{
                "result" => "failure",
                "stage" => "update_user",
                "error" => Kernel.inspect(changeset)
              }
          end
      end

    conn
    |> put_status(201)
    |> assign(:result, result)
    |> render("result.json")
  end

  @spec update_site_config(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update_site_config(conn, %{"key" => key, "value" => value}) do
    Config.update_site_config(key, value)

    conn
    |> put_status(201)
    |> assign(:result, %{})
    |> render("result.json")
  end

  @spec ts_update_user(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def ts_update_user(conn, %{"email" => email, "attrs" => attrs}) do
    result =
      case Account.get_user_by_email(email) do
        nil ->
          %{
            "result" => "failure",
            "stage" => "get_user_by_email",
            "error" => "No user found"
          }

        user ->
          new_user =
            user
            |> Map.new(fn {k, v} ->
              str_k = to_string(k)

              {
                k,
                Map.get(attrs, str_k, v)
              }
            end)

          Account.update_cache_user(user.id, new_user)
          %{"result" => "success"}
      end

    conn
    |> put_status(201)
    |> assign(:result, result)
    |> render("result.json")
  end

  @spec update_user_rating(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def update_user_rating(conn, params) do
    rating_type_id = MatchRatingLib.rating_type_name_lookup()[params["rating_type"]]
    skill = int_parse(params["skill"])
    uncertainty = int_parse(params["uncertainty"])

    rating_value = BalanceLib.calculate_rating_value(skill, uncertainty)
    leaderboard_rating = BalanceLib.calculate_leaderboard_rating(skill, uncertainty)

    {:ok, rating} =
      Account.create_or_update_rating(%{
        user_id: params["userid"],
        rating_type_id: rating_type_id,
        rating_value: rating_value,
        skill: skill,
        uncertainty: uncertainty,
        leaderboard_rating: leaderboard_rating,
        last_updated: Timex.now()
      })

    result =
      Map.take(
        rating,
        ~w(user_id rating_type_id rating_value skill uncertainty leaderboard_rating last_updated)a
      )

    conn
    |> put_status(201)
    |> assign(:result, result)
    |> render("result.json")
  end

  @spec get_server_state(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def get_server_state(conn, %{"server" => server, "id" => id_str}) do
    id = int_parse(id_str)

    result =
      case server do
        "client" ->
          client = Account.get_client_by_id(id)
          user = Account.get_user_by_id(id)
          Map.put(client, :user, user)

        "lobby" ->
          Lobby.get_lobby(id)

        "balance" ->
          pid = Coordinator.get_balancer_pid(id)
          state = :sys.get_state(pid)

          current_balance = Map.get(state.hashes, state.last_balance_hash, nil)
          Map.put(state, "current_balance", current_balance)

        _ ->
          raise "No server of type #{server}"
      end

    conn
    |> put_status(201)
    |> assign(:result, result)
    |> render("result.json")
  end
end

defmodule Teiserver.API.HailstormAuth do
  @spec authorize(Atom.t(), Plug.Conn.t(), map()) :: Boolean.t()
  def authorize(_, _, _) do
    Application.get_env(:teiserver, Teiserver)[:enable_hailstorm]
  end
end
