defmodule TeiserverWeb.AdminLive.DiscordChannel.PreferencesComponent do
  @moduledoc """
  <.live_component
    :if={@preferences}
    module={PreferencesComponent}
    id="user-list-preferences-form"
    preferences={@preferences}
    scope={@scope}

    # Optionally
    update_parent={true}
  />

  If update parent is set then you will need a handle_info like so:
  @impl LiveView
  def handle_info({:updated_preference, key, value}, %Socket{} = socket) do
    new_preferences =
      socket.assigns.preferences
      |> Map.put(key, value)

    socket
    |> assign(preferences: new_preferences)
    |> noreply()
  end

  If you want to use live updates for preferences then you cannot have
  a streamed table, you must use an assign.
  """
  alias Teiserver.Account.Scope

  use TeiserverWeb, :live_component

  import Teiserver.Config, only: [get_user_config_cache: 2, set_user_config: 3]

  @prefix "col_pref.admin_discord_channels"

  attr :preferences, :map, required: true
  attr :scope, Scope, required: true
  attr :update_parent, :boolean, default: false

  @impl LiveComponent
  def render(assigns) do
    ~H"""
    <div>
      <h3>
        <span
          class={["btn btn-secondary px-2", not @show_form && "btn-soft"]}
          phx-click="toggle-form"
          phx-target={@myself}
        >
          <Fontawesome.icon icon="gear" size="lg" />
        </span>

        <span :if={@show_form} class="text-lg pl-2">
          Table preferences
        </span>
      </h3>
      <.simple_form
        :if={@show_form}
        for={@form}
        phx-change="update-preferences"
        phx-submit="submit-preferences"
        phx-target={@myself}
        id="discord_channel-list-preferences-form"
      >
        <div class="form-input-grid">
          <div class="m-2">
            <.input_tw
              type="select"
              field={@form[:show_link]}
              options={[
                {"Row click", "row-click"},
                {"Row click and button", "row-click + button"},
                {"Just button", "button"}
              ]}
              label="Click to show"
            />
          </div>
        </div>
      </.simple_form>
    </div>
    """
  end

  @impl LiveComponent
  def mount(socket) do
    socket
    |> assign(show_form: false)
    |> ok()
  end

  @impl LiveComponent
  def update(assigns, socket) do
    form =
      assigns[:preferences]
      |> Map.new(fn {k, v} -> {to_string(k), v} end)
      |> to_form()

    user_id = assigns.scope.user.id

    socket
    |> assign(assigns)
    |> assign(form: form, user_id: user_id)
    |> ok()
  end

  @impl LiveComponent
  def handle_event("update-preferences", %{"_target" => target_list} = params, socket) do
    # target_list is typically something like ["email"], we only care about the first
    # thing that changed

    target = List.first(target_list)
    key = "#{@prefix}.#{target}"
    value = params[target]

    user_id = socket.assigns.user_id
    set_user_config(user_id, key, value)

    if socket.assigns[:update_parent] do
      atom_key = String.to_existing_atom(target)
      converted_value = get_user_config_cache(user_id, key)

      send(self(), {:updated_preference, atom_key, converted_value})
    end

    socket
    |> noreply()
  end

  def handle_event("toggle-form", _params, socket) do
    socket
    |> assign(show_form: !socket.assigns[:show_form])
    |> noreply()
  end

  def handle_event(_event, _params, socket) do
    socket
    |> noreply()
  end

  def get_preferences(%Scope{user: user}) do
    [
      :show_link
    ]
    |> Map.new(fn key ->
      value = get_user_config_cache(user.id, "#{@prefix}.#{key}")
      {key, value}
    end)
  end
end
