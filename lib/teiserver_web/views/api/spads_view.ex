defmodule TeiserverWeb.API.SpadsView do
  use TeiserverWeb, :view

  def render("rating.json", assigns) do
    %{
      rating: assigns.rating_value,
      rating_value: assigns.rating_value,
      uncertainty: assigns.uncertainty
    }
  end
end
