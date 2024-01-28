defmodule BarserverWeb.API.HailstormView do
  use BarserverWeb, :view

  def render("result.json", assigns) do
    assigns.result
  end
end
