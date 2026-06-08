defmodule TeiserverWeb.Moderation.ActionLive.SmurfLink do
  @moduledoc false
  alias Teiserver.Account
  alias Teiserver.Account.UserLib

  use TeiserverWeb, :live_view

  @impl LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl LiveView
  def handle_params(%{"user_id" => user_id}, _url, socket) do
    user = Account.get_user!(user_id)

    case UserLib.has_access(user, socket) do
      {true, _role} ->
        socket
        |> assign(user: user, page_title: "Smurf link - #{user.name}")
        |> noreply()

      _no_access ->
        socket
        |> put_flash(:warning, "No access to that user")
        |> redirect(to: ~p"/moderation")
        |> noreply()
    end
  end
end
