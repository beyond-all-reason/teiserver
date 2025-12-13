defmodule TeiserverWeb.Communication.ChatLive.Index do
  use TeiserverWeb, :live_view
  alias Teiserver.{Account, Coordinator, Chat}

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:site_menu_active, "chat")
      |> assign(:view_colour, Teiserver.Chat.LobbyMessageLib.colours())
      |> assign(:messages, [])
      |> assign(:usernames, %{})
      |> add_breadcrumb(name: "Chat", url: "/chat")
      |> default_filters()
      |> get_messages()

    {:ok, socket}
  end

  # @impl true
  # def handle_params(%{"tab" => tab} = params, _url, socket) do
  #   socket = socket
  #     |> assign(:tab, tab)

  #   {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  # end

  # defp apply_action(%{assigns: %{tab: "alerts"}} = socket, _, _params) do
  #   socket
  #   |> put_flash(:success, "Success flash - #{:rand.uniform(1000)}")
  #   |> put_flash(:info, "Info flash - #{:rand.uniform(1000)}")
  #   |> put_flash(:warning, "Warning flash - #{:rand.uniform(1000)}")
  #   |> put_flash(:error, "Danger/Error flash - #{:rand.uniform(1000)}")
  # end

  # defp apply_action(socket, _, _params) do
  #   socket
  # end

  @impl true
  def handle_event("filter-update", event, %{assigns: %{filters: filters}} = socket) do
    [key] = event["_target"]
    value = event[key]

    new_filters = Map.put(filters, key, value)

    socket =
      socket
      |> assign(:filters, new_filters)
      |> get_messages()

    {:noreply, socket}
  end

  defp default_filters(socket) do
    socket
    |> assign(:filters, %{
      "timeframe" => "24 hours",
      "mode" => "Lobby",
      "term" => "",
      "username" => "",
      "message-format" => "Table"
    })
  end

  defp get_messages(%{assigns: %{filters: %{"term" => ""}}} = socket) do
    socket
  end

  defp get_messages(%{assigns: %{filters: filters}} = socket) do
    mode = filters["mode"]

    inserted_after =
      case filters["timeframe"] do
        "24 hours" -> Timex.now() |> Timex.shift(hours: -24)
        "2 days" -> Timex.now() |> Timex.shift(days: -2)
        "7 days" -> Timex.now() |> Timex.shift(days: -7)
        _ -> nil
      end

    {mode, userid} =
      if filters["username"] == "" do
        {mode, nil}
      else
        uid = Account.get_userid_from_name(filters["username"])

        if uid do
          {mode, uid}
        else
          {nil, nil}
        end
      end

    excluded_ids =
      if filters["include_bots"] == "true" do
        []
      else
        [
          Coordinator.get_coordinator_userid()
        ]
      end

    messages =
      case mode do
        nil ->
          []

        "Lobby" ->
          Chat.list_lobby_messages(
            search: [
              term: filters["term"],
              user_id: userid,
              inserted_after: inserted_after,
              user_id_not_in: excluded_ids
            ],
            limit: 100,
            order_by: filters["order"]
          )

        "Room" ->
          Chat.list_room_messages(
            search: [
              term: filters["term"],
              user_id: userid,
              inserted_after: inserted_after,
              user_id_not_in: excluded_ids
            ],
            limit: 100,
            order_by: filters["order"]
          )

        "Party" ->
          Chat.list_party_messages(
            search: [
              term: filters["term"],
              user_id: userid,
              inserted_after: inserted_after,
              user_id_not_in: excluded_ids
            ],
            limit: 100,
            order_by: filters["order"]
          )
      end

    extra_usernames =
      messages
      |> Enum.map(fn m -> m.user_id end)
      |> Enum.reject(fn userid ->
        Map.has_key?(socket.assigns.usernames, userid)
      end)
      |> Map.new(fn userid ->
        {userid, Account.get_username_by_id(userid)}
      end)

    new_usernames = Map.merge(socket.assigns.usernames, extra_usernames)

    socket
    |> assign(:usernames, new_usernames)
    |> assign(:messages, messages)
  end
end
