defmodule TeiserverWeb.AdminLive.SiteConfig.List do
  @moduledoc false
  alias Teiserver.Config
  alias Teiserver.Helper.StringHelper
  alias TeiserverWeb.AdminLive.SiteConfig.FormComponent
  alias TeiserverWeb.AdminLive.SiteConfigComponents

  use TeiserverWeb, :live_view

  @impl LiveView
  def mount(_params, _session, %Socket{} = socket) when is_connected?(socket) do
    socket
    |> assign(search: "")
    |> get_site_configs()
    |> get_values()
    |> ok()
  end

  def mount(_params, _session, %Socket{} = socket) do
    socket
    |> assign(
      search: "",
      site_configs: [],
      values: %{}
    )
    |> ok()
  end

  @impl LiveView
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"key" => key}) do
    config_type = Config.get_site_config_type(key)
    config_value = Config.get_site_config_val(key)

    socket
    |> assign(
      page_title: "Edit Site config",
      config_value: config_value,
      config_type: config_type
    )
  end

  defp apply_action(socket, :list, _params) do
    socket
    |> assign(:page_title, "Listing Site configs")
    |> assign(:site_config, nil)
  end

  @impl LiveView
  def handle_info({FormComponent, {:saved, {key, value}}}, socket) do
    new_values =
      socket.assigns.values
      |> Map.put(key, value)

    socket
    |> assign(values: new_values)
    |> noreply()
  end

  @impl LiveView
  def handle_event("update-search", params, %Socket{assigns: _assigns} = socket) do
    socket
    |> assign(search: params["name"])
    |> get_site_configs()
    |> get_values()
    |> noreply()
  end

  defp get_site_configs(%Socket{assigns: %{search: search, scope: scope}} = socket) do
    search = String.downcase(search)

    # We filter based on both search criteria but also permissions
    site_configs =
      Config.get_grouped_site_configs()
      |> Enum.map(fn {group, group_configs} ->
        new_group_configs =
          group_configs
          |> Enum.filter(fn config ->
            (search == "" or config.key |> String.downcase() |> String.contains?(search)) and
              allow?(scope, config.permissions)
          end)

        {group, new_group_configs}
      end)
      |> Enum.reject(fn {_group, group_configs} -> Enum.empty?(group_configs) end)

    socket
    |> assign(site_configs: site_configs)
  end

  defp get_values(%Socket{assigns: %{site_configs: site_configs}} = socket) do
    values =
      site_configs
      |> Enum.map(fn {_group, configs} -> configs end)
      |> List.flatten()
      |> Map.new(fn the_config ->
        {the_config.key, Config.get_site_config_cache(the_config.key)}
      end)

    socket
    |> assign(values: values)
  end
end
