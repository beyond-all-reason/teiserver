defmodule TeiserverWeb.Moderation.BanView do
  @moduledoc false

  alias Teiserver.Moderation.BanLib

  use TeiserverWeb, :view

  import TeiserverWeb.PaginationComponents, only: [pagination: 1]

  @spec view_colour() :: atom
  def view_colour, do: BanLib.colour()

  @spec icon() :: String.t()
  def icon, do: BanLib.icon()
end
