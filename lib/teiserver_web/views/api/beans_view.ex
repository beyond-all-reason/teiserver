defmodule TeiserverWeb.API.BeansView do
  use TeiserverWeb, :view

  def render("create_user.json", assigns) do
    assigns.result
  end
end
