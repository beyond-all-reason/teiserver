defmodule TeiserverWeb.API.SpadsView do
  use TeiserverWeb, :view

  def render("rating.json", assigns) do
    %{rating: assigns.rating}
  end
end
