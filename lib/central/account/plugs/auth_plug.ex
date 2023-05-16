defmodule Central.Account.AuthPlug do
  @moduledoc false
  import Plug.Conn

  alias Central.Account
  alias Central.Account.Guardian
  require Logger

  def init(_opts) do
    # Keyword.fetch!(opts, :repo)
  end

  def call(conn, _opts) do
    user =
      case Guardian.resource_from_token(conn.cookies["guardian_default_token"]) do
        {:ok, user, _claims} -> Account.get_user!(user.id)
        _ -> nil
      end

    user_id = if user, do: user.id, else: nil

    user_token =
      if user do
        Guardian.Plug.current_token(conn)
        # Phoenix.Token.sign(conn, "user socket", user.id)
      else
        ""
      end

    if user != nil do
      Logger.metadata([user_id: user.id] ++ Logger.metadata())
    end

    conn
    |> Map.put(:current_user, user)
    |> Map.put(:user_id, user_id)
    |> assign(:user_token, user_token)
    |> assign(:current_user, user)
    |> assign(:documentation, [])
    |> assign(:flags, [])
  end

  def live_call(socket, session) do
    user =
      case Guardian.resource_from_token(session["guardian_default_token"]) do
        {:ok, user, _claims} -> Account.get_user!(user.id)
        _ -> nil
      end

    user_id = if user, do: user.id, else: nil

    if user != nil do
      request_id = ExULID.ULID.generate()
      Logger.metadata([request_id: request_id, user_id: user.id] ++ Logger.metadata())
    end

    socket
    |> Phoenix.LiveView.Utils.assign(:current_user, user)
    |> Phoenix.LiveView.Utils.assign(:user_id, user_id)
  end
end
