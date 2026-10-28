defmodule TeiserverWeb.ModerationLive.User.SetGDPRForget do
  @moduledoc false
  alias Teiserver.Account
  alias Teiserver.Account.UserLib
  alias TeiserverWeb.ModerationLive.UserComponents

  use TeiserverWeb, :live_view

  @impl LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl LiveView
  def handle_params(%{"id" => id}, _url, socket) when is_connected?(socket) do
    user = Account.get_user(id)

    case UserLib.has_access(user, socket) do
      {true, _role} ->
        user
        |> UserLib.make_favourite()
        |> insert_recently(socket)

      _no_access ->
        socket
        |> put_flash(:error, "Unable to access this user")
        |> redirect(to: ~p"/moderation/users")
    end

    socket
    |> assign(user: user, page_title: "User details: #{user.name}")
    |> noreply()
  end

  def handle_params(_params, _url, socket) do
    socket
    |> assign(user: nil, page_title: "User details")
    |> noreply()
  end

  @impl LiveView
  def handle_event("perform-set", _params, %Socket{assigns: assigns} = socket) do
    result = UserLib.set_gdpr_forget(assigns.user, assigns.scope)

    case result do
      {:ok, _any} ->
        socket
        |> put_flash(:info, "GDPR forget set")
        |> redirect(to: ~p"/moderation/users/#{assigns.user.id}")
        |> noreply()

      _other ->
        socket
        |> put_flash(:error, "Error setting GDPR forget flag")
        |> noreply()
    end
  end
end
