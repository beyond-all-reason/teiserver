defmodule TeiserverWeb.StaffLive.TextCallbackComponents do
  @moduledoc false
  alias Teiserver.Account.Scope
  alias Teiserver.Communication

  use TeiserverWeb, :component

  import TeiserverWeb.CoreComponents, only: [simple_form: 1, input_tw: 1]
  import TeiserverWeb.NavComponents, only: [section_menu_link: 1]

  @doc """
  <TeiserverWeb.Staff.TextCallbackComponents.search_form
    :if={assigns[:search]}
    params={@search}
  />

  You will need to implement the following event handlers:

  handle_event("update-search", params, %Socket{} = socket)
  handle_event("validate-search", params, %Socket{} = socket)
  handle_event("reset-search", _params, %Socket{} = socket)
  """
  attr :params, :map, required: true
  attr :changed?, :boolean, default: false

  def search_form(%{params: params} = assigns) do
    form = to_form(params)

    categories = generate_category_options()

    assigns =
      assigns
      |> assign(form: form, categories: categories)

    ~H"""
    <.simple_form
      for={@form}
      phx-change="validate-search"
      phx-submit="update-search"
      id="text_callback-search-form"
    >
      <div class="grid grid-flow-row-dense grid-cols-3">
        <div class="m-2">
          <.input_tw
            type="text"
            field={@form[:name]}
            label="Name (contains)"
          />
        </div>

        <div class="m-2">
          <.input_tw
            type="text"
            field={@form[:response]}
            label="Response (contains)"
          />
        </div>

        <div class="m-2">
          <.input_tw
            type="select"
            field={@form[:category]}
            label="Category"
            options={@categories}
          />
        </div>

        <div class="m-2">
          <.input_tw
            type="select"
            field={@form[:enabled]}
            label="Enabled"
            options={[{"Any", ""}, {"Only enabled", "true"}, {"Only disabled", "false"}]}
          />
        </div>

        <div class="m-2">
          <.input_tw
            type="select"
            field={@form[:order_by]}
            label="Order by"
            options={["Newest first", "Oldest first", "Alphabetical (A-Z)", "Alphabetical (Z-A)"]}
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

  defp generate_category_options do
    options =
      Communication.list_text_callback_categories()
      |> Enum.map(&{&1, &1})

    [{"All categories", ""}] ++ options
  end

  @doc """
  <TextCallbackComponents.section_menu
    active="some-link"
    scope={@scope}
  />

  <TextCallbackComponents.section_menu
    active="some-link"
    scope={@scope}
  >
    <:left_links>
      <li>Link goes here</li>
    </:left_links>
    <:right_links>
      <li>Link goes here</li>
    </:right_links>
  </TextCallbackComponents.section_menu>
  """
  attr :scope, Scope, required: true
  attr :active, :string, required: true
  slot :extra_links, doc: "Slot for extra links for the left side of the menu bar"
  slot :inner_block, doc: "Slot for content for the right side of the menu bar"

  def section_menu(assigns) do
    ~H"""
    <div class="section-menu-bar">
      <ul class="menu menu-horizontal">
        <.section_menu_link
          icon="fa-arrow-left"
          url={~p"/staff"}
        >
          Staff
        </.section_menu_link>

        <.section_menu_link
          icon={StylingHelper.icon(:list)}
          url={~p"/staff/text_callbacks"}
          active={@active == "list"}
        >
          List
        </.section_menu_link>

        <.section_menu_link
          :if={@active == "show"}
          icon={StylingHelper.icon(:show)}
          url="#"
          active={true}
        >
          Show
        </.section_menu_link>

        {render_slot(@extra_links)}
      </ul>

      <div class="section-menu-bar-inner_block">
        <ul class="menu menu-horizontal">
          {render_slot(@inner_block)}
        </ul>
      </div>
    </div>
    """
  end

  @doc """
  <UserComponents.quick_search />
  """
  def quick_search(assigns) do
    ~H"""
    <form action={~p"/staff/text_callbacks"} method="GET" class="inline-block">
      <.input_tw
        type="text"
        value=""
        name="name"
        placeholder="Search by name"
        class="input input-sm"
        fieldset?={false}
      />
    </form>
    """
  end
end
