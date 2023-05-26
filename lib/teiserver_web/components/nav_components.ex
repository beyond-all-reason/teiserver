defmodule TeiserverWeb.NavComponents do
  use Phoenix.Component
  # alias Phoenix.LiveView.JS
  # import CentralWeb.Gettext

  @doc """
  <TeiserverWeb.NavComponents.top_nav_item active={active} route={route} icon={icon} />
  """
  def top_nav_item(assigns) do
    active = if assigns[:active], do: "active", else: ""

    assigns = assigns
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
end
