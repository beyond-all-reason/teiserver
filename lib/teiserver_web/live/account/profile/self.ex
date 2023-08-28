defmodule TeiserverWeb.Account.ProfileLive.Self do
  @moduledoc false
  use TeiserverWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns.current_user do
      {:ok,
        socket
        |> redirect(to: ~p"/profile/#{socket.assigns.current_user.id}")
      }
    else
      {:ok,
        socket
        |> put_flash(:info, "You need to be logged in to view your own profile")
        |> redirect(to: ~p"/")
      }
    end
  end

  @impl true
  def handle_event(_string, _event, socket) do
    {:noreply, socket}
  end
end
