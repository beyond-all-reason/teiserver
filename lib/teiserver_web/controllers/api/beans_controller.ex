defmodule TeiserverWeb.API.BeansController do
  use CentralWeb, :controller
  alias Teiserver.{Account, User}

  plug(Bodyguard.Plug.Authorize,
    policy: Teiserver.API.BeansAuth,
    action: {Phoenix.Controller, :action_name},
    user: {Central.Account.AuthLib, :current_user}
  )

  @spec create_user(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create_user(conn, params) do
    email = params["email"] <> "@beans"

    result = case Account.get_user_by_email(email) do
      nil ->
        case User.register_user(params["name"], email, params["password"]) do
          :success ->
            user = Account.get_user!(nil, search: [email: email])
            Central.Account.update_user(user, params["permissions"], :permissions)

          {:error, reason} ->
            %{
              result: "Failure",
              stage: "User.register_user",
              reason: reason
            }
        end
      user ->
        %{userid: user.id}
    end

    conn
      |> put_status(201)
      |> assign(:result, result)
      |> render("create_user.json", %{outcome: :success, id: 1})
  end
end

defmodule Teiserver.API.BeansAuth do
  @spec authorize(Atom.t(), Plug.Conn.t(), Map.t()) :: Boolean.t()
  def authorize(_, _, _) do
    Application.get_env(:central, Teiserver)[:enable_beans]
  end
end
