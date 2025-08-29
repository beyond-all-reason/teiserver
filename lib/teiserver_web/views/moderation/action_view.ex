defmodule TeiserverWeb.Moderation.ActionView do
  @moduledoc false
  use TeiserverWeb, :view
  import TeiserverWeb.PaginationComponents, only: [pagination: 1]

  @spec view_colour() :: atom
  def view_colour, do: Teiserver.Moderation.ActionLib.colour()

  @spec icon() :: String.t()
  def icon, do: Teiserver.Moderation.ActionLib.icon()
end
