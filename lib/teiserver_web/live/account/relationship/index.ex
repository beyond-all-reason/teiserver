defmodule TeiserverWeb.Account.RelationshipLive.Index do
  use TeiserverWeb, :live_view
  alias Teiserver.{Account}

  @impl true
  def mount(_params, _session, socket) do
    socket = socket
      |> assign(:site_menu_active, "account")
      |> assign(:view_colour, Teiserver.Account.RelationshipLib.colours())
      |> get_relationships

    {:ok, socket}
  end

  # @impl true
  # def handle_event(_cmd, _event, %{assigns: _assigns} = socket) do
  #   {:noreply, socket}
  # end

  defp get_relationships(%{assigns: %{current_user: current_user}} = socket) do
    relationships = Account.list_relationships(
      where: [
        from_user_id: current_user.id
      ],
      preload: [:to_user]
    )

    incoming_friend_requests = Account.list_relationships(
      where: [
        to_user_id: current_user.id,
        state: "friend request"
      ],
      preload: [:from_user]
    )

    friends = relationships
      |> Enum.filter(fn r ->
        r.state == "friend"
      end)

    outgoing_friend_requests = relationships
      |> Enum.filter(fn r ->
        r.state == "friend request"
      end)

    ignores = relationships
      |> Enum.filter(fn r ->
        r.state == "ignore"
      end)

    avoids = relationships
      |> Enum.filter(fn r ->
        r.state == "avoid"
      end)

    blocks = relationships
      |> Enum.filter(fn r ->
        r.state == "block"
      end)

    socket
      |> assign(:incoming_friend_requests, incoming_friend_requests)
      |> assign(:outgoing_friend_requests, outgoing_friend_requests)
      |> assign(:friends, friends)
      |> assign(:avoids, avoids)
      |> assign(:ignores, ignores)
      |> assign(:blocks, blocks)
  end
end
