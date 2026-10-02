defmodule TeiserverWeb.AdminLive.DiscordChannel.List do
  @moduledoc false
  alias Teiserver.Communication
  alias Teiserver.Communication.DiscordChannel
  alias Teiserver.Communication.DiscordChannelQueries
  alias Teiserver.Helper.QueryHelpers
  alias Teiserver.Repo
  alias TeiserverWeb.AdminLive.DiscordChannel.FormComponent
  alias TeiserverWeb.AdminLive.DiscordChannel.PreferencesComponent
  alias TeiserverWeb.AdminLive.DiscordChannelComponents

  use TeiserverWeb, :live_view

  import Teiserver.Helpers.EnumHelper, only: [intersects?: 2]

  import Teiserver.Config, only: [get_user_config_cache: 2, set_user_config: 3]

  @page_size_config_key "last_used.discord_channel_search_page_size"
  @max_page_size 100

  @impl LiveView
  def mount(params, _session, %Socket{} = socket) when is_connected?(socket) do
    preferences = PreferencesComponent.get_preferences(socket.assigns.scope)

    socket
    |> assign(page: 0, preferences: preferences)
    |> init_search_params(params)
    |> get_discord_channels()
    |> get_discord_channel_count()
    |> ok()
  end

  def mount(_params, _session, %Socket{} = socket) do
    socket
    |> assign(
      discord_channel_count: 0,
      page: 0,
      page_count: 1,
      search: %{},
      search_changed?: false,
      preferences: nil,
      discord_channels: []
    )
    |> ok()
  end

  @impl LiveView
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Discord channel")
    |> assign(:discord_channel, Communication.get_discord_channel!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Discord channel")
    |> assign(:discord_channel, %DiscordChannel{})
  end

  defp apply_action(socket, :list, _params) do
    socket
    |> assign(:page_title, "Listing Discord channels")
    |> assign(:discord_channel, nil)
  end

  @impl LiveView
  def handle_info({FormComponent, {:saved, discord_channel}}, socket) do
    new_discord_channels =
      socket.assigns.discord_channels
      |> Enum.reject(&(&1.id == discord_channel.id))

    socket
    |> assign(discord_channels: [discord_channel | new_discord_channels])
    |> noreply()
  end

  def handle_info({:updated_preference, key, value}, %Socket{} = socket) do
    new_preferences =
      socket.assigns.preferences
      |> Map.put(key, value)

    socket
    |> assign(preferences: new_preferences)
    |> noreply()
  end

  @impl LiveView
  def handle_event("set-page", %{"page" => page}, %Socket{} = socket) do
    page = String.to_integer(page)

    socket
    |> assign(page: page)
    |> get_discord_channels()
    |> noreply()
  end

  def handle_event("validate-search", params, %Socket{assigns: %{search: search}} = socket) do
    new_search = convert_search_params(params)

    diff_keys =
      Map.keys(new_search)
      |> Enum.filter(fn key ->
        new_value = new_search[key]
        existing_value = search[key]

        new_value != existing_value
      end)
      |> MapSet.new()

    contains_update_keys? =
      intersects?(["order_by", "page_size"], diff_keys)

    # Certain keys are things where we'll want to update the results as they type/update
    if contains_update_keys? do
      handle_event("update-search", params, socket)
    else
      socket
      |> assign(search_changed?: true)
      |> noreply()
    end
  end

  def handle_event("update-search", params, %Socket{assigns: assigns} = socket) do
    params = convert_search_params(params)

    new_search = Map.merge(assigns.search, params)

    set_user_config(socket, @page_size_config_key, params["page_size"])

    socket
    |> assign(search: new_search, search_changed?: false, page: 0)
    |> get_discord_channel_count()
    |> get_discord_channels()
    |> noreply()
  end

  def handle_event("reset-search", _params, %Socket{} = socket) do
    socket
    |> init_search_params(%{})
    |> get_discord_channel_count()
    |> get_discord_channels()
    |> noreply()
  end

  defp init_search_params(%Socket{assigns: _assigns} = socket, params) do
    params =
      params
      |> convert_search_params()
      |> Map.merge(%{
        "page_size" => get_user_config_cache(socket, @page_size_config_key),
        # Force refresh of form
        "_random" => :rand.uniform()
      })
      |> Map.reject(fn {_k, v} -> is_nil(v) end)

    socket
    |> assign(search: params, search_changed?: false)
  end

  defp convert_search_params(params) do
    %{
      "name" => params["name"] || "",
      "channel_id" => params["channel_id"] || "",
      "order_by" => params["order_by"] || "Newest first",
      "page_size" => min(maybe_to_integer(params["page_size"]), @max_page_size)
    }
  end

  defp discord_channel_query(%Socket{assigns: %{search: search}} = _socket) do
    DiscordChannelQueries.discord_channels()
    |> DiscordChannelQueries.where_name_like(search["name"])
  end

  defp get_discord_channels(%Socket{assigns: %{page: page, search: search}} = socket) do
    discord_channels =
      discord_channel_query(socket)
      |> DiscordChannelQueries.order_by_from_string(search["order_by"])
      |> QueryHelpers.paginate(page, search["page_size"])
      |> Repo.all()

    socket
    |> assign(discord_channels: discord_channels)
  end

  defp get_discord_channel_count(%Socket{assigns: assigns} = socket) do
    ip_count =
      discord_channel_query(socket)
      |> QueryHelpers.count()

    page_count = :math.ceil(ip_count / assigns.search["page_size"]) |> round()

    socket
    |> assign(discord_channel_count: ip_count)
    |> assign(page_count: page_count)
  end
end
