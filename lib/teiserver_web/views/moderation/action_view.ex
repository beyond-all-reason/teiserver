defmodule TeiserverWeb.Moderation.ActionView do
  @moduledoc false
  use TeiserverWeb, :view

  @spec view_colour() :: atom
  def view_colour, do: Teiserver.Moderation.ActionLib.colour()

  @spec icon() :: String.t()
  def icon, do: Teiserver.Moderation.ActionLib.icon()
end
