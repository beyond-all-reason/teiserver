defmodule TeiserverWeb.Moderation.LobbyLogComponents do
  @moduledoc false
  alias Teiserver.Account.Scope
  alias Teiserver.Moderation.LobbyLog
  alias TeiserverWeb.LiveComponents.UserPicker

  use TeiserverWeb, :component

  import TeiserverWeb.CoreComponents, only: [simple_form: 1, input_tw: 1]
  import TeiserverWeb.NavComponents, only: [section_menu_link: 1]

  @doc """
  <TeiserverWeb.Moderation.LobbyLogComponents.search_form
    params={@search}
    changed?={@search_changed?}
  />

  You will need to implement the following event handlers:

  handle_event("update-search", params, %Socket{} = socket)
  handle_event("validate-search", params, %Socket{} = socket)
  handle_event("reset-search", _params, %Socket{} = socket)
  """
  attr :params, :map, required: true
  attr :changed?, :boolean, default: false

  def search_form(%{params: params} = assigns) do
    assigns = assign(assigns, form: to_form(params))

    ~H"""
    <.simple_form
      for={@form}
      id="lobby-log-search-form"
      phx-change="validate-search"
      phx-submit="update-search"
    >
      <div class="grid grid-flow-row-dense grid-cols-3">
        <div class="m-2">
          <div class="fieldset w-full">
            <.live_component
              module={UserPicker}
              id="user_id-user-picker"
              field={@form[:user_id]}
              label="User:"
            />
          </div>
        </div>

        <div class="m-2">
          <div class="fieldset w-full">
            <.live_component
              module={UserPicker}
              id="target_id-user-picker"
              field={@form[:target_id]}
              label="Target:"
            />
          </div>
        </div>

        <div class="m-2">
          <.input_tw
            type="text"
            field={@form[:lobby_id]}
            label="Lobby ID"
          />
        </div>

        <div class="m-2">
          <.input_tw
            type="select"
            field={@form[:event_type]}
            label="Event"
            options={["Any" | LobbyLog.event_types()]}
          />
        </div>

        <div class="m-2">
          <.input_tw
            type="select"
            field={@form[:order_by]}
            label="Order by"
            options={["Newest first", "Oldest first"]}
          />
        </div>

        <div class="m-2">
          <.input_tw
            type="select"
            field={@form[:page_size]}
            label="Records per page"
            options={[5, 10, 25, 50, 100]}
          />
        </div>
      </div>

      <div class="float-right">
        <div phx-click="reset-search" class="btn-reset-form">
          <Fontawesome.icon icon="rotate-left" style="regular" /> Reset
        </div>
        <button class={["btn btn-primary", not @changed? && "btn-soft"]}>
          <Fontawesome.icon icon="search" style="regular" /> Update results
        </button>
      </div>
    </.simple_form>
    """
  end

  attr :scope, Scope, required: true
  attr :active, :string, required: true

  def section_menu(assigns) do
    ~H"""
    <div class="section-menu-bar">
      <ul class="menu menu-horizontal">
        <.section_menu_link
          icon="fa-arrow-left"
          url={~p"/moderation"}
        >
          Moderation
        </.section_menu_link>

        <.section_menu_link
          icon={StylingHelper.icon(:list)}
          url={~p"/moderation/lobby_logs"}
          active={@active == "list"}
        >
          List
        </.section_menu_link>
      </ul>
    </div>
    """
  end
end
