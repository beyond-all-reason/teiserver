defmodule TeiserverWeb.Moderation.BanView do
  @moduledoc false
  use TeiserverWeb, :view
  import TeiserverWeb.PaginationComponents, only: [pagination: 1]

  alias Teiserver.Moderation.BanLib

  @spec view_colour() :: atom
  def view_colour, do: BanLib.colour()

  @spec icon() :: String.t()
  def icon, do: BanLib.icon()
end
