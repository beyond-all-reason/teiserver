defmodule TeiserverWeb.API.BeansView do
  use TeiserverWeb, :view

  def render("result.json", assigns) do
    assigns.result
  end
end
