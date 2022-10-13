defmodule TeiserverWeb.Moderation.ProposalView do
  @moduledoc false
  use TeiserverWeb, :view

  @spec view_colour() :: atom
  def view_colour, do: Teiserver.Moderation.ProposalLib.colour()

  @spec icon() :: String.t()
  def icon, do: Teiserver.Moderation.ProposalLib.icon()
end
