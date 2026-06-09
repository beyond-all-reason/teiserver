defmodule TeiserverWeb.Moderation.ActionView do
  @moduledoc false

  alias Teiserver.Moderation.ActionLib

  use TeiserverWeb, :view

  import TeiserverWeb.PaginationComponents, only: [pagination: 1]

  @spec view_colour() :: atom
  def view_colour, do: ActionLib.colour()

  @spec icon() :: String.t()
  def icon, do: ActionLib.icon()

  @spec format_duration(integer() | nil) :: String.t()
  def format_duration(nil), do: "—"

  def format_duration(seconds) do
    cond do
      seconds >= 86_400 * 365 -> "#{div(seconds, 86_400 * 365)} year(s)"
      seconds >= 86_400 * 30 -> "#{div(seconds, 86_400 * 30)} month(s)"
      seconds >= 86_400 -> "#{div(seconds, 86_400)} day(s)"
      seconds >= 3_600 -> "#{div(seconds, 3_600)} hour(s)"
      true -> "#{div(seconds, 60)} minute(s)"
    end
  end
end
