defmodule TeiserverWeb.NavComponents do
  @moduledoc false
  use Phoenix.Component
  # alias Phoenix.LiveView.JS
  # import CentralWeb.Gettext

  @doc """
  <TeiserverWeb.NavComponents.top_nav_item active={active} route={route} icon={icon} />
  """
  def top_nav_item(assigns) do
    active = if assigns[:active], do: "active", else: ""

    assigns =
      assigns
      |> assign(:active, active)

    ~H"""
    <li class="nav-item">
      <a class={"nav-link #{@active}"} href={@route}>
        <%= if assigns[:icon] do %>
          <i class={"fa-fw #{@icon}"}></i>
        <% end %>
        <%= @text %>
      </a>
    </li>
    """
  end

  @doc """
  <.tab_header>
    <.tab_nav tab="h1">Header 1</.tab_nav>
    <.tab_nav tab="h2">Header 2</.tab_nav>
    <.tab_nav tab="h3">Header 3</.tab_nav>
  </.tab_header>
  """
  # attr :selected, :string, required: :true
  slot :inner_block, required: true

  def tab_header(assigns) do
    ~H"""
      <ul class="nav nav-tabs" role="tablist">
        <%= render_slot(@inner_block) %>
      </ul>
    """
  end

  attr :selected, :boolean, required: :true
  attr :url, :string, required: :true
  slot :inner_block, required: true

  def tab_nav(assigns) do
    assigns = assigns
      |> assign(:active_class, (if assigns[:selected], do: "active"))

    ~H"""
      <li class="nav-item">
        <.link
          patch={@url}
          class={"nav-link #{@active_class}"}
        >
          <%= render_slot(@inner_block) %>
        </.link>
      </li>
    """
  end

  @doc """
  <.section_menu_button bsname={bsname} icon={lib} active={true/false} url={url}>
    Text goes here
  </.section_menu_button>
  """
  attr :icon, :string, default: nil
  attr :url, :string, required: true
  attr :bsname, :string, default: "secondary"
  attr :active, :boolean, default: false
  slot :inner_block, required: true

  def section_menu_button(assigns) do
    assigns = assigns
    |> assign(:active_class, (if assigns[:active], do: "active"))

    ~H"""
    <.link
      navigate={@url}
      class={"btn btn-outline-#{@bsname} #{@active_class}"}
    >
      <Fontawesome.icon icon={@icon} style={if @active, do: "solid", else: "regular"} :if={@icon} />
      <%= render_slot(@inner_block) %>
    </.link>
    """
  end

  @doc """
  <.section_menu_button bsname={bsname} icon={lib} active={true/false} url={url}>
    Text goes here
  </.section_menu_button>
  """
  attr :icon, :string, default: nil
  attr :url, :string, required: true
  attr :bsname, :string, default: "secondary"
  attr :active, :boolean, default: false
  slot :inner_block, required: true

  def section_menu_button_patch(assigns) do
    assigns = assigns
    |> assign(:active_class, (if assigns[:active], do: "active"))

    ~H"""
    <.link
      patch={@url}
      class={"btn btn-outline-#{@bsname} #{@active_class}"}
    >
      <Fontawesome.icon icon={@icon} style={if @active, do: "solid", else: "regular"} :if={@icon} />
      <%= render_slot(@inner_block) %>
    </.link>
    """
  end
end
