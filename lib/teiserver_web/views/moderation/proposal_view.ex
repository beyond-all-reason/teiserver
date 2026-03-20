defmodule TeiserverWeb.Moderation.ProposalView do
  @moduledoc false

  alias Teiserver.Moderation.ProposalLib

  use TeiserverWeb, :view

  @spec view_colour() :: atom
  def view_colour, do: ProposalLib.colour()

  @spec icon() :: String.t()
  def icon, do: ProposalLib.icon()
end
