defmodule TeiserverWeb.Moderation.BanView do
  @moduledoc false
  use TeiserverWeb, :view

  @spec view_colour() :: atom
  def view_colour, do: Teiserver.Moderation.BanLib.colour()

  @spec icon() :: String.t()
  def icon, do: Teiserver.Moderation.BanLib.icon()
end
