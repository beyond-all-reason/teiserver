defmodule TeiserverWeb.Battle.MatchLive.Chat do
  @moduledoc false
  use TeiserverWeb, :live_view
  alias Teiserver.{Account, Battle, Chat}
  alias Teiserver.Battle.MatchLib

  @impl true
  def mount(params, _session, socket) do
    socket =
      socket
      |> mount_require_all(["Overwatch"])
      |> assign(:site_menu_active, "match")
      |> assign(:view_colour, Teiserver.Battle.MatchLib.colours())
      |> assign(:tab, "details")
      |> assign(:highlight_map, %{})
      |> assign(:extra_url_parts, "")
      |> default_filters(params)
      |> update_highlight_map_at_mount()

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    socket =
      socket
      |> assign(:id, String.to_integer(id))
      |> get_match()
      |> get_messages()
      |> assign(:tab, socket.assigns.live_action)

    {:noreply, socket}
  end

  # @impl true
  # def handle_info({TeiserverWeb.CategoryLive.FormComponent, {:saved, category}}, socket) do
  #   {:noreply, stream_insert(socket, :categories, category)}
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

  def handle_event("change-user-highlight", event, socket) do
    [key] = event["_target"]
    value = event[key]

    new_filters = Map.put(socket.assigns.filters, key, value)

    highlight_map =
      String.trim(value || "")
      |> String.split(",")
      |> Enum.map(fn username ->
        Account.get_userid_from_name(username)
      end)
      |> Enum.reject(&(&1 == nil))
      |> Enum.with_index()
      |> Map.new()

    {:noreply,
     socket
     |> assign(:highlight_map, highlight_map)
     |> assign(:filters, new_filters)}
  end

  def handle_event("format-update", event, socket) do
    [key] = event["_target"]
    value = event[key]

    new_filters = Map.put(socket.assigns.filters, key, value)

    {:noreply,
     socket
     |> assign(:filters, new_filters)}
  end

  defp get_messages(%{assigns: %{id: match_id, filters: filters}} = socket) do
    user_id_list =
      String.trim(filters["user-raw-filter"] || "")
      |> String.split(",")
      |> Enum.map(fn username ->
        Account.get_userid_from_name(username)
      end)
      |> Enum.reject(&(&1 == nil))

    user_exclude_list =
      String.trim(filters["user-raw-exclude"] || "")
      |> String.split(",")
      |> Enum.map(fn username ->
        Account.get_userid_from_name(username)
      end)
      |> Enum.reject(&(&1 == nil))

    contains_filter =
      filters["message-contains"]
      |> String.trim()

    messages =
      Chat.list_lobby_messages(
        search: [
          match_id: match_id,
          user_id_in: user_id_list,
          user_id_not_in: user_exclude_list
        ],
        preload: [:user],
        limit: 1_000,
        order_by: filters["order_by"]
      )
      |> Enum.filter(fn %{content: content} ->
        # I was thinking to do this via the DB but it is really slow even though
        # we use match_id first
        if contains_filter != "" do
          String.contains?(content, contains_filter)
        else
          true
        end
      end)

    socket
    |> assign(:messages, messages)
  end

  defp get_match(%{assigns: %{id: id, current_user: _current_user}} = socket) do
    if connected?(socket) do
      match =
        Battle.get_match!(id,
          preload: []
        )

      match_name = MatchLib.make_match_name(match)

      next_match = Battle.get_next_match(match)
      prev_match = Battle.get_prev_match(match)

      lobby = Battle.get_lobby_by_match_id(match.id)

      socket
      |> assign(:match, match)
      |> assign(:next_match, next_match)
      |> assign(:prev_match, prev_match)
      |> assign(:match_name, match_name)
      |> assign(:lobby, lobby)
    else
      socket
      |> assign(:match, nil)
      |> assign(:lobby, nil)
      |> assign(:match_name, "Loading...")
    end
  end

  defp update_highlight_map_at_mount(%{assigns: %{filters: filters}} = socket) do
    highlight_map =
      String.trim(filters["user-raw-highlight"] || "")
      |> String.split(",")
      |> Enum.map(fn username ->
        Account.get_userid_from_name(username)
      end)
      |> Enum.reject(&(&1 == nil))
      |> Enum.with_index()
      |> Map.new()

    socket |> assign(:highlight_map, highlight_map)
  end

  defp default_filters(socket, params) do
    highlight_names =
      params
      |> Map.get("userids", [])
      |> Enum.map(fn userid_str ->
        Account.get_username_by_id(userid_str)
      end)
      |> Enum.reject(&(&1 == nil))
      |> Enum.join(", ")

    extra_url_parts =
      params
      |> Map.get("userids", [])

    socket
    |> assign(:filters, %{
      "bot-messages" => "Include bot messages",
      "message-format" => "Table",
      "user-raw-filter" => "",
      "user-raw-exclude" => "Coordinator",
      "user-raw-highlight" => highlight_names,
      "message-contains" => "",
      "order_by" => "Oldest first"
    })
    |> assign(:extra_url_parts, extra_url_parts)
  end
end
