defmodule TeiserverWeb.General.HomeLive.Index do
  use TeiserverWeb, :live_view
  # alias Teiserver.{Account, Battle}

  @impl true
  def mount(_params, _session, socket) do
    socket = socket
      |> add_breadcrumb(name: "Teiserver", url: ~p"/")

    {:ok, socket}
  end

  # @impl true
  # def handle_event(_cmd, _event, %{assigns: _assigns} = socket) do
  #   {:noreply, socket}
  # end
end
