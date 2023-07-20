defmodule TeiserverWeb.NavComponents do
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
end
