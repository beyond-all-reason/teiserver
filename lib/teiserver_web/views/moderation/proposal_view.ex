defmodule TeiserverWeb.Moderation.ProposalView do
  @moduledoc false
  use TeiserverWeb, :view

  alias Teiserver.Moderation.ProposalLib

  @spec view_colour() :: atom
  def view_colour, do: ProposalLib.colour()

  @spec icon() :: String.t()
  def icon, do: ProposalLib.icon()
end
