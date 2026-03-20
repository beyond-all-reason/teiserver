defmodule TeiserverWeb.Report.ReportView do
  alias Teiserver.Helper.StylingHelper

  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: :danger

  @spec icon() :: String.t()
  def icon(), do: StylingHelper.icon(:report)

  def mins_to_hours(nil), do: 0

  def mins_to_hours(t) do
    round(t / 60)
  end
end
