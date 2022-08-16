defmodule TeiserverWeb.API.SpadsView do
  use TeiserverWeb, :view
  import Central.Helpers.NumberHelper, only: [round: 2]

  def render("rating.json", assigns) do
    %{
      # rating: assigns.rating_value |> round(2),
      rating_value: assigns.rating_value |> round(2),
      uncertainty: assigns.uncertainty |> round(2)
    }
  end
end
