defmodule BarserverWeb.Account.LiveComponents.UserPicker do
  # In Phoenix apps, the line is typically: use MyAppWeb, :live_component
  use BarserverWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="hero"><%= @content %></div>
    """
  end
end
