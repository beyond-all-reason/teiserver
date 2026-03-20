defmodule TeiserverWeb.Moderation.ActionView do
  @moduledoc false

  alias Teiserver.Moderation.ActionLib

  use TeiserverWeb, :view

  import TeiserverWeb.PaginationComponents, only: [pagination: 1]

  @spec view_colour() :: atom
  def view_colour, do: ActionLib.colour()

  @spec icon() :: String.t()
  def icon, do: ActionLib.icon()
end
