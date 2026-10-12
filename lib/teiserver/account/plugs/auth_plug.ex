defmodule Teiserver.Account.AuthPlug do
  @moduledoc false

  alias ExULID.ULID
  alias Phoenix.Controller
  alias Phoenix.LiveView
  alias Phoenix.LiveView.Utils
  alias Teiserver.Account
  alias Teiserver.Account.Guardian
  alias Teiserver.Account.Guardian.Plug, as: GuardianPlug
  alias Teiserver.Account.TOTPLib
  alias Teiserver.Account.User

  use TeiserverWeb, :verified_routes

  import Plug.Conn

  def init(_opts) do
    # Keyword.fetch!(opts, :repo)
  end

  def call(conn, _opts) do
    user =
      case Guardian.resource_from_token(conn.cookies["guardian_default_token"]) do
        {:ok, user, _claims} -> Account.get_user!(user.id)
        _error -> nil
      end

    user_token =
      if user do
        GuardianPlug.current_token(conn)
      else
        ""
      end

    if user != nil do
      Logger.metadata([user_id: user.id] ++ Logger.metadata())
    end

    totp_status =
      case user do
        nil -> nil
        _user -> TOTPLib.get_user_totp_status(user.id)
      end

    cond do
      # If we have a user but no token then we have a cookie issue
      # and we want to force a re-login
      user != nil and user_token == nil ->
        conn
        |> assign(:current_user, nil)
        |> assign(:user_token, nil)
        |> assign(:totp_status, nil)
        |> Controller.put_flash(:info, "There was an error logging you in, please try again.")
        |> GuardianPlug.sign_out(clear_remember_me: true)
        |> Controller.redirect(to: ~p"/logout")

      banned_user?(user) ->
        conn
        |> assign(:current_user, nil)
        |> assign(:user_token, nil)
        |> assign(:totp_status, nil)
        |> Controller.put_flash(:danger, "You are banned")
        |> GuardianPlug.sign_out(clear_remember_me: true)
        |> Controller.redirect(to: ~p"/logout")

      true ->
        conn
        |> assign(:user_token, user_token)
        |> assign(:current_user, user)
        |> assign(:totp_status, totp_status)
    end
  end

  def live_call(socket, session) do
    user =
      case Guardian.resource_from_token(session["guardian_default_token"]) do
        {:ok, user, _claims} -> Account.get_user!(user.id)
        _error -> nil
      end

    if user != nil do
      request_id = ULID.generate()
      Logger.metadata([request_id: request_id, user_id: user.id] ++ Logger.metadata())
    end

    if banned_user?(user) do
      socket
      |> Utils.assign(:current_user, nil)
      |> Utils.assign(:user_token, nil)
      |> LiveView.redirect(to: ~p"/logout")
    else
      socket
      |> Utils.assign(:current_user, user)
    end
  end

  defp banned_user?(nil), do: false

  defp banned_user?(%User{} = user) do
    cond do
      Account.restricted?(user.id, ["Login"]) ->
        true

      user.smurf_of_id != nil ->
        true

      true ->
        false
    end
  end
end
