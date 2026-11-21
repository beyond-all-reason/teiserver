defmodule TeiserverWeb.AdminLive.OAuthApplication.List do
  @moduledoc false
  alias Teiserver.Helper.QueryHelpers
  alias Teiserver.OAuth
  alias Teiserver.OAuth.Application
  alias Teiserver.OAuth.ApplicationQueries
  alias Teiserver.Repo
  alias TeiserverWeb.AdminLive.OAuthApplication.FormComponent
  alias TeiserverWeb.AdminLive.OAuthApplication.PreferencesComponent
  alias TeiserverWeb.AdminLive.OAuthApplicationComponents

  use TeiserverWeb, :live_view

  import Teiserver.Helpers.EnumHelper, only: [intersects?: 2]

  import Teiserver.Config, only: [get_user_config_cache: 2, set_user_config: 3]

  @page_size_config_key "last_used.oauth_application_search_page_size"
  @max_page_size 100

  @impl LiveView
  def mount(params, _session, %Socket{} = socket) when is_connected?(socket) do
    preferences = PreferencesComponent.get_preferences(socket.assigns.scope)

    socket
    |> assign(page: 0, preferences: preferences)
    |> init_search_params(params)
    |> get_oauth_applications()
    |> get_oauth_application_count()
    |> generate_cmd_palette_commands()
    |> ok()
  end

  def mount(_params, _session, %Socket{} = socket) do
    socket
    |> assign(
      oauth_application_count: 0,
      page: 0,
      page_count: 1,
      search: %{},
      search_changed?: false,
      preferences: nil,
      oauth_applications: []
    )
    |> ok()
  end

  @impl LiveView
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit OAuth application")
    |> assign(:oauth_application, OAuth.get_application_by_id(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New OAuth application")
    |> assign(:oauth_application, %Application{
      owner_id: socket.assigns.scope.user.id,
      confidential?: true,
      name: "Generic Lobby Client",
      uid: "generic_lobby",
      scopes: OAuth.allowed_scopes()
    })
  end

  defp apply_action(socket, :list, _params) do
    socket
    |> assign(:page_title, "Listing OAuth applications")
    |> assign(:oauth_application, nil)
  end

  @impl LiveView
  def handle_info({FormComponent, {:saved, _oauth_application}}, socket) do
    # Normally we'd manually insert it here but because we zip the result it's better to
    # re-query them
    socket
    |> get_oauth_applications()
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
    |> get_oauth_applications()
    |> generate_cmd_palette_commands()
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
    |> get_oauth_application_count()
    |> get_oauth_applications()
    |> generate_cmd_palette_commands()
    |> noreply()
  end

  def handle_event("reset-search", _params, %Socket{} = socket) do
    socket
    |> init_search_params(%{})
    |> get_oauth_application_count()
    |> get_oauth_applications()
    |> generate_cmd_palette_commands()
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
      "order_by" => params["order_by"] || "Newest first",
      "page_size" => min(maybe_to_integer(params["page_size"]), @max_page_size)
    }
  end

  defp oauth_application_query(%Socket{assigns: %{search: search}} = _socket) do
    ApplicationQueries.applications()
    |> ApplicationQueries.where_name_like(search["name"])
  end

  defp get_oauth_applications(%Socket{assigns: %{page: page, search: search}} = socket) do
    oauth_applications =
      oauth_application_query(socket)
      |> ApplicationQueries.load_owner()
      |> ApplicationQueries.order_by_from_string(search["order_by"])
      |> QueryHelpers.paginate(page, search["page_size"])
      |> Repo.all()

    stats = oauth_applications |> Enum.map(fn app -> app.id end) |> ApplicationQueries.get_stats()

    socket
    |> assign(
      app_and_stats: Enum.zip(oauth_applications, stats),
      oauth_applications: oauth_applications
    )
  end

  defp get_oauth_application_count(%Socket{assigns: assigns} = socket) do
    ip_count =
      oauth_application_query(socket)
      |> QueryHelpers.count()

    page_count = :math.ceil(ip_count / assigns.search["page_size"]) |> round()

    socket
    |> assign(oauth_application_count: ip_count)
    |> assign(page_count: page_count)
  end

  defp generate_cmd_palette_commands(%Socket{assigns: assigns} = socket) do
    first_application = Enum.at(assigns.app_and_stats, 0)

    extra_commands =
      if is_nil(first_application) do
        []
      else
        {app, _stats} = first_application

        [
          %{
            id: "goto:first_application",
            cmd: :goto,
            label: "View application: #{app.name}",
            path: ~p"/admin/oauth_applications/#{app.id}"
          }
        ]
      end

    socket
    |> assign(extra_commands: extra_commands)
  end
end
