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
    style = fa_prefix(assigns[:style])
    size = fa_prefix(assigns[:size])
    weight = fa_prefix(assigns[:weight])

    icon_name = if is_atom(assigns[:icon]) do
      icon_lookup(assigns[:icon])
    else
      fa_prefix(assigns[:icon])
    end

    assigns = assigns
      |> assign(:class, "fa-fw #{style} #{size} #{weight} #{icon_name} #{assigns[:class]}")

    ~H"""
    <i class={@class}></i>
    """
  end

  defp fa_prefix("fa-" <> s), do: "fa-" <> s
  defp fa_prefix(nil), do: ""
  defp fa_prefix(s), do: "fa-" <> s

  @spec icon_lookup(atom) :: String.t()
  def icon_lookup(:report), do: "fa-signal"
  def icon_lookup(:up), do: "fa-level-up"
  def icon_lookup(:back), do: "fa-arrow-left"

  def icon_lookup(:list), do: "fa-bars"
  def icon_lookup(:show), do: "fa-eye"
  def icon_lookup(:search), do: "fa-search"
  def icon_lookup(:new), do: "fa-plus"
  def icon_lookup(:edit), do: "fa-wrench"
  def icon_lookup(:delete), do: "fa-trash"
  def icon_lookup(:export), do: "fa-download"
  def icon_lookup(:structure), do: "fa-cubes"
  def icon_lookup(:documentation), do: "fa-book"
  def icon_lookup(:live_view), do: "fa-brands fa-phoenix-framework"

  def icon_lookup(:chat), do: "fa-comment"

  def icon_lookup(:admin), do: "fa-user-crown"
  def icon_lookup(:moderation), do: "fa-gavel"

  def icon_lookup(:overview), do: "fa-expand-alt"
  def icon_lookup(:detail), do: "fa-file-alt"
  def icon_lookup(:user), do: "fa-user"

  def icon_lookup(:filter), do: "fa-filter"

  def icon_lookup(:summary), do: "fa-user-chart"

  def icon_lookup(:chart), do: "fa-chart-line"

  def icon_lookup(:day), do: "fa-calendar-day"
  def icon_lookup(:week), do: "fa-calendar-week"
  def icon_lookup(:month), do: "fa-calendar-range"
  def icon_lookup(:quarter), do: "fa-calendar"
  def icon_lookup(:year), do: "fa-circle-calendar"
end
