defmodule TeiserverWeb.API.BeansController do
  use CentralWeb, :controller
  alias Central.Config
  alias Teiserver.{Account, User}

  plug(Bodyguard.Plug.Authorize,
    policy: Teiserver.API.BeansAuth,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}
  )

  @spec up(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def up(conn, _params) do
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
          case User.register_user(name, email, params["password"]) do
            :success ->
              db_user = Account.get_user!(nil, search: [email: email])
              Central.Account.update_user(db_user, params["permissions"], :permissions)
              %{userid: db_user.id}

            {:error, reason} ->
              %{
                result: "failure",
                stage: "User.register_user",
                reason: reason
              }
          end

        user ->
          User.set_flood_level(user.id, 0)
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
end

defmodule Teiserver.API.BeansAuth do
  @spec authorize(Atom.t(), Plug.Conn.t(), Map.t()) :: Boolean.t()
  def authorize(_, _, _) do
    Application.get_env(:central, Teiserver)[:enable_hailstorm]
  end
end
