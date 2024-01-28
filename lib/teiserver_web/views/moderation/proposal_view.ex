defmodule BarserverWeb.Moderation.ProposalView do
  @moduledoc false
  use BarserverWeb, :view

  @spec view_colour() :: atom
  def view_colour, do: Barserver.Moderation.ProposalLib.colour()

  @spec icon() :: String.t()
  def icon, do: Barserver.Moderation.ProposalLib.icon()
end
