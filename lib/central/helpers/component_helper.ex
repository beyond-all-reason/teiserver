defmodule Central.Helpers.ComponentHelper do
  @moduledoc """
  # http://blog.danielberkompas.com/2017/01/17/reusable-templates-in-phoenix.html
  #
  # Example usage:
  # <%= central_component "tabs" do %>
  #   <%= central_component "tab", name: "All Products" %>
  #   <%= central_component "tab", name: "Featured" %>
  # <% end %>
  """

  def central_component(template, assigns \\ %{}) do
    CentralWeb.ComponentView.render(template <> ".html", assigns)
  end

  def central_component(template, assigns, do: block) do
    CentralWeb.ComponentView.render(template <> ".html", Keyword.merge(assigns, do: block))
  end
end
