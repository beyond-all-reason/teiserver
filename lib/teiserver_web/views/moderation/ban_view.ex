defmodule BarserverWeb.Moderation.BanView do
  @moduledoc false
  use BarserverWeb, :view

  @spec view_colour() :: atom
  def view_colour, do: Barserver.Moderation.BanLib.colour()

  @spec icon() :: String.t()
  def icon, do: Barserver.Moderation.BanLib.icon()
end
