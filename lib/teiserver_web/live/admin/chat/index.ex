defmodule TeiserverWeb.Admin.ChatLive.Index do
  use TeiserverWeb, :live_view
  alias Teiserver.{Account, Coordinator, Chat}

  @impl true
  def mount(_params, _session, socket) do
    case allow?(socket.assigns[:current_user], "Reviewer") do
      true ->
        socket =
          socket
          |> assign(:site_menu_active, "chat")
          |> assign(:view_colour, Teiserver.Chat.LobbyMessageLib.colours())
          |> assign(:messages, [])
          |> assign(:usernames, %{})
          |> add_breadcrumb(name: "Admin", url: "/teiserver/admin")
          |> add_breadcrumb(name: "Chat", url: "/admin/chat")
          |> default_filters()
          |> assign(:searching, false)
          |> assign(:usernames, %{})
          |> assign(:messages, [])

        {:ok, socket}

      false ->
        {:ok,
         socket
         |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_params(params, _url, %{assigns: %{filters: filters}} = socket) do
    filters =
      if params["userid"] do
        user = Account.get_user_by_id(params["userid"])

        Map.merge(filters, %{
          "username" => user.name,
          "user-raw-filter" => user.name,
          "userids" => [user.id]
        })
      else
        filters
      end

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> get_messages()}
  end

  @impl true
  def handle_info(:do_get_messages, socket) do
    socket = get_messages(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_event("filter-update", event, %{assigns: %{filters: filters}} = socket) do
    [key] = event["_target"]
    value = event[key]

    new_filters = Map.put(filters, key, value)

    new_filters =
      case key do
        "user-raw-filter" ->
          userids =
            value
            |> String.split(",")
            |> Enum.map(fn name ->
              Account.get_userid_from_name(name)
            end)
            |> Enum.reject(&(&1 == nil))

          Map.put(new_filters, "userids", userids)

        _ ->
          new_filters
      end

    socket =
      socket
      |> assign(:filters, new_filters)
      |> assign(:searching, true)
      |> get_messages()

    {:noreply, socket}
  end

  def handle_event("format-update", event, socket) do
    [key] = event["_target"]
    value = event[key]

    new_filters = Map.put(socket.assigns.filters, key, value)

    {:noreply,
     socket
     |> assign(:filters, new_filters)}
  end

  defp default_filters(socket) do
    socket
    |> assign(:filters, %{
      "timeframe" => "24 hours",
      "mode" => "Lobby",
      "term" => "",
      "username" => "",
      "order" => "Newest first",
      "message-format" => "Table"
    })
  end

  defp get_messages(%{assigns: %{filters: %{"term" => "", "userid" => nil}}} = socket) do
    socket
    |> assign(:searching, false)
  end

  defp get_messages(%{assigns: %{filters: filters}} = socket) when is_connected?(socket) do
    mode = filters["mode"]

    inserted_after =
      case filters["timeframe"] do
        "24 hours" -> Timex.now() |> Timex.shift(hours: -24)
        "2 days" -> Timex.now() |> Timex.shift(days: -2)
        "7 days" -> Timex.now() |> Timex.shift(days: -7)
        _ -> nil
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
              user_id_in: filters["userids"],
              user_id_not_in: excluded_ids,
              inserted_after: inserted_after,
              term: filters["term"]
            ],
            limit: 100,
            order_by: filters["order"]
          )

        "Room" ->
          Chat.list_room_messages(
            search: [
              user_id_in: filters["userids"],
              user_id_not_in: excluded_ids,
              inserted_after: inserted_after,
              term: filters["term"]
            ],
            limit: 100,
            order_by: filters["order"]
          )

        "Party" ->
          Chat.list_party_messages(
            search: [
              user_id_in: filters["userids"],
              user_id_not_in: excluded_ids,
              inserted_after: inserted_after,
              term: filters["term"]
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
    |> assign(:searching, false)
  end

  defp get_messages(socket) do
    socket
    |> assign(:searching, false)
  end
end
