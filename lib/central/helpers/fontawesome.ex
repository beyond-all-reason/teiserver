defmodule Fontawesome do
  @moduledoc """
  Example usage:

  <Fontawesome.icon icon="arrow-left" style="regular" />
  """
  use Phoenix.Component

  attr :icon, :string, required: true
  attr :class, :string, default: ""
  attr :style, :string, default: "regular"

  @spec icon(map) :: Phoenix.LiveView.Rendered.t()
  def icon(assigns) do
    style =
      case assigns[:style] do
        "fa-" <> s -> s
        s -> s
      end

    icon =
      case assigns[:icon] do
        "fa-" <> ic -> ic
        ic -> ic
      end

    class = "fa-fw fa-#{style} fa-#{icon} #{assigns[:class]}"
    assigns = assign(assigns, :class, class)

    ~H"""
    <i class={@class}></i>
    """
  end
end
