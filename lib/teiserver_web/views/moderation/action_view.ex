defmodule TeiserverWeb.Moderation.ActionView do
  @moduledoc false
  use TeiserverWeb, :view
  import TeiserverWeb.PaginationComponents, only: [pagination: 1]

  alias Teiserver.Moderation.ActionLib

  @spec view_colour() :: atom
  def view_colour, do: ActionLib.colour()

  @spec icon() :: String.t()
  def icon, do: ActionLib.icon()
end
