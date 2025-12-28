defmodule TeiserverWeb.Account.SettingsLive.Index do
  @moduledoc false
  use TeiserverWeb, :live_view

  alias Teiserver.Config

  @impl true
  def mount(_, _session, socket) do
    socket =
      socket
      |> assign(:tab, nil)
      |> assign(:site_menu_active, "teiserver_account")
      |> assign(:view_colour, Teiserver.Account.UserLib.colours())
      |> assign(:show_descriptions, false)
      |> assign(:temp_value, nil)
      |> assign(:selected_key, nil)
      |> load_config_types()
      |> load_user_configs()

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, _live_action, _params) do
    socket
    |> assign(:page_title, "Settings")
  end

  @impl true
  def handle_event("open-form", %{"key" => key}, %{assigns: assigns} = socket) do
    new_key =
      if assigns.selected_key == key do
        nil
      else
        key
      end

    current_value = assigns.config_values[key] || Config.get_user_config_default(key)

    {:noreply,
     socket
     |> assign(:selected_key, new_key)
     |> assign(:temp_value, current_value)}
  end

  def handle_event(
        "reset-value",
        _,
        %{assigns: %{selected_key: key, current_user: user}} = socket
      ) do
    case Config.get_user_config(user.id, key) do
      nil ->
        :ok

      user_config ->
        Config.delete_user_config(user_config)
    end

    new_config_values = Map.put(socket.assigns.config_values, key, nil)

    {:noreply,
     socket
     |> assign(:config_values, new_config_values)
     |> assign(:selected_key, nil)
     |> assign(:temp_value, nil)}
  end

  def handle_event("set-" <> _, _, %{assigns: %{selected_key: nil}} = socket) do
    {:noreply, socket}
  end

  def handle_event("set-true", _, %{assigns: %{selected_key: key, current_user: user}} = socket) do
    new_value = "true"
    insert_or_update_config(user.id, key, new_value)

    new_config_values = Map.put(socket.assigns.config_values, key, new_value)

    {:noreply,
     socket
     |> assign(:config_values, new_config_values)
     |> assign(:selected_key, nil)
     |> assign(:temp_value, nil)}
  end

  def handle_event("set-false", _, %{assigns: %{selected_key: key, current_user: user}} = socket) do
    new_value = "false"
    insert_or_update_config(user.id, key, new_value)

    new_config_values = Map.put(socket.assigns.config_values, key, new_value)

    {:noreply,
     socket
     |> assign(:config_values, new_config_values)
     |> assign(:selected_key, nil)
     |> assign(:temp_value, nil)}
  end

  def handle_event(
        "set-to",
        %{"value" => new_value},
        %{assigns: %{selected_key: key, current_user: user}} = socket
      ) do
    insert_or_update_config(user.id, key, new_value)

    new_config_values = Map.put(socket.assigns.config_values, key, new_value)

    {:noreply,
     socket
     |> assign(:config_values, new_config_values)
     |> assign(:selected_key, nil)
     |> assign(:temp_value, nil)}
  end

  def handle_event(_string, _event, socket) do
    {:noreply, socket}
  end

  defp insert_or_update_config(userid, key, value) do
    case Config.get_user_config(userid, key) do
      nil ->
        {:ok, _config} =
          Config.create_user_config(%{
            "user_id" => userid,
            "key" => key,
            "value" => "true"
          })

      user_config ->
        {:ok, _config} =
          Config.update_user_config(user_config, %{
            "value" => value
          })
    end
  end

  defp load_config_types(socket) do
    config_types = Config.get_grouped_user_configs()

    socket
    |> assign(:config_types, config_types)
  end

  defp load_user_configs(%{assigns: %{current_user: user}} = socket) do
    config_values = Config.get_user_configs!(user.id)

    socket
    |> assign(:config_values, config_values)
  end
end
