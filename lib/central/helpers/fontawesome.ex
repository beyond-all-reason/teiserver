defmodule Fontawesome do
  @moduledoc """
  Example usage:

  <Fontawesome.icon icon="arrow-left" style="regular" />
  """
  use Phoenix.Component

  attr :icon, :string, required: true
  attr :class, :string, default: ""
  attr :size, :string, default: nil
  attr :weight, :string, default: "regular"
  attr :style, :string, default: "regular"

  @spec icon(map) :: Phoenix.LiveView.Rendered.t()
  def icon(assigns) do
    assigns = assign(assigns, :class, "fa-fw #{fa_prefix(assigns[:style])} #{fa_prefix(assigns[:size])} #{fa_prefix(assigns[:weight])} #{fa_prefix(assigns[:icon])} #{assigns[:class]}")

    ~H"""
    <i class={@class}></i>
    """
  end

  defp fa_prefix("fa-" <> s), do: "fa-" <> s
  defp fa_prefix(nil), do: ""
  defp fa_prefix(s), do: "fa-" <> s
end
