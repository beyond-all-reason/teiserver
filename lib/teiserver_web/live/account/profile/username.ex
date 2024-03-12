defmodule BarserverWeb.Account.ProfileLive.Username do
  @moduledoc false
  use BarserverWeb, :live_view
  alias Barserver.Account

  @impl true
  def mount(%{"username" => username}, _session, socket) do
    userid = Account.get_userid_from_name(username)

    if userid do
      {:ok,
       socket
       |> redirect(to: ~p"/profile/#{userid}")}
    else
      {:ok,
       socket
       |> put_flash(:info, "No user of that name")
       |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_event(_string, _event, socket) do
    {:noreply, socket}
  end
end
