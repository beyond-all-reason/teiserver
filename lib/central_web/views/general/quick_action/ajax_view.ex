defmodule CentralWeb.General.QuickAction.AjaxView do
  use CentralWeb, :view

  def render("response.json", %{data: data}) do
    data
  end
end
