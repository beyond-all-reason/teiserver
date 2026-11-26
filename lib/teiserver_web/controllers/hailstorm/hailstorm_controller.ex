defmodule TeiserverWeb.Hailstorm.AccountController do
  alias Teiserver.Account
  alias Teiserver.Helper.StringHelper
  alias Teiserver.OAuth.Tasks.GenToken

  use TeiserverWeb, :controller

  def create_user(conn, _params) do
    name = StringHelper.random_name()

    {:ok, user} =
      Account.create_user(%{
        name: name,
        email: "#{name}@hailstorm.bar",
        password: "hailstorm-password",
        roles: ["Hailstorm", "Verified"]
      })

    {:ok, token} = GenToken.create_token(user.email, "generic_lobby")

    resp = %{
      user: %{
        id: user.id
      },
      token: %{
        value: token.value
      }
    }

    conn
    |> put_status(201)
    |> json(resp)
  end

  def create_token(conn, %{"id" => user_id}) do
    user = Account.get_user!(user_id)

    if user && Enum.member?(user.roles, "Hailstorm") do
      result = GenToken.create_token(user.email, "generic_lobby")

      case result do
        {:ok, token} ->
          conn
          |> put_status(201)
          |> json(%{token: %{value: token.value}})

        _any ->
          raise "Error creating token: #{inspect(result)}"
      end
    else
      raise "Can only create tokens for Hailstorm users"
    end
  end
end
