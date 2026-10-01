defmodule TeiserverWeb.StaffLive.TextCallback.List do
  @moduledoc false
  alias Teiserver.Communication
  alias Teiserver.Communication.TextCallback
  alias Teiserver.Communication.TextCallbackQueries
  alias Teiserver.Helper.QueryHelpers
  alias Teiserver.Repo
  alias TeiserverWeb.StaffLive.TextCallback.FormComponent
  alias TeiserverWeb.StaffLive.TextCallback.PreferencesComponent
  alias TeiserverWeb.StaffLive.TextCallbackComponents

  use TeiserverWeb, :live_view

  import Teiserver.Helpers.EnumHelper, only: [intersects?: 2]

  import Teiserver.Config, only: [get_user_config_cache: 2, set_user_config: 3]

  @page_size_config_key "last_used.text_callback_search_page_size"
  @max_page_size 100

  @impl LiveView
  def mount(params, _session, %Socket{} = socket) when is_connected?(socket) do
    preferences = PreferencesComponent.get_preferences(socket.assigns.scope)

    socket
    |> assign(page: 0, preferences: preferences)
    |> init_search_params(params)
    |> get_text_callbacks()
    |> get_text_callback_count()
    |> ok()
  end

  def mount(_params, _session, %Socket{} = socket) do
    socket
    |> assign(
      text_callback_count: 0,
      page: 0,
      page_count: 1,
      search: %{},
      search_changed?: false,
      preferences: nil,
      text_callbacks: []
    )
    |> ok()
  end

  @impl LiveView
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Text callback")
    |> assign(:text_callback, Communication.get_text_callback!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Text callback")
    |> assign(:text_callback, %TextCallback{})
  end

  defp apply_action(socket, :list, _params) do
    socket
    |> assign(:page_title, "Listing Text callbacks")
    |> assign(:text_callback, nil)
  end

  @impl LiveView
  def handle_info({FormComponent, {:saved, text_callback}}, socket) do
    new_text_callbacks =
      socket.assigns.text_callbacks
      |> Enum.reject(&(&1.id == text_callback.id))

    socket
    |> assign(text_callbacks: [text_callback | new_text_callbacks])
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
    |> get_text_callbacks()
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
      intersects?(["order_by", "page_size", "category", "enabled"], diff_keys)

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
    |> get_text_callback_count()
    |> get_text_callbacks()
    |> noreply()
  end

  def handle_event("reset-search", _params, %Socket{} = socket) do
    socket
    |> init_search_params(%{})
    |> get_text_callback_count()
    |> get_text_callbacks()
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
      "response" => params["response"] || "",
      "category" => params["category"] || "",
      "enabled" => boolean_from_form(params["enabled"]),
      "order_by" => params["order_by"] || "Newest first",
      "page_size" => min(maybe_to_integer(params["page_size"]), @max_page_size)
    }
  end

  defp text_callback_query(%Socket{assigns: %{search: search}} = _socket) do
    TextCallbackQueries.text_callbacks()
    |> TextCallbackQueries.where_name_like(search["name"])
    |> TextCallbackQueries.where_response_like(search["response"])
    |> TextCallbackQueries.where_category(search["category"])
    |> TextCallbackQueries.where_enabled(search["enabled"])
  end

  defp get_text_callbacks(%Socket{assigns: %{page: page, search: search}} = socket) do
    text_callbacks =
      text_callback_query(socket)
      |> TextCallbackQueries.order_by_from_string(search["order_by"])
      |> QueryHelpers.paginate(page, search["page_size"])
      |> Repo.all()

    socket
    |> assign(text_callbacks: text_callbacks)
  end

  defp get_text_callback_count(%Socket{assigns: assigns} = socket) do
    ip_count =
      text_callback_query(socket)
      |> QueryHelpers.count()

    page_count = :math.ceil(ip_count / assigns.search["page_size"]) |> round()

    socket
    |> assign(text_callback_count: ip_count)
    |> assign(page_count: page_count)
  end
end
