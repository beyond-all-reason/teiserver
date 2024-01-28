defmodule BarserverWeb.Moderation.ActionView do
  @moduledoc false
  use BarserverWeb, :view

  @spec view_colour() :: atom
  def view_colour, do: Barserver.Moderation.ActionLib.colour()

  @spec icon() :: String.t()
  def icon, do: Barserver.Moderation.ActionLib.icon()
end
