defmodule TeiserverWeb.ModerationLive.User.Show do
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

        socket
        |> assign(user: user, page_title: "User details: #{user.name}")
        |> set_user_alerts()
        |> noreply()

      _no_access ->
        socket
        |> put_flash(:error, "Unable to access this user")
        |> redirect(to: ~p"/moderation/users")
    end
  end

  def handle_params(_params, _url, socket) do
    socket
    |> assign(user: nil, page_title: "User details", alerts: [])
    |> noreply()
  end

  defp set_user_alerts(%Socket{assigns: %{user: nil}} = socket), do: socket

  defp set_user_alerts(%Socket{assigns: %{user: user}} = socket) do
    alerts =
      [
        not is_nil(user.gdpr_forget_after) &&
          {"alert-error", "This user is set to be forgotten under the GDPR right to be forgotten"}
      ]
      |> Enum.reject(&is_nil/1)

    socket
    |> assign(alerts: alerts)
  end
end
