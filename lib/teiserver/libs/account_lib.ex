defmodule Teiserver.AccountLib do
  # Functions
  @spec icon :: String.t()
  def icon, do: "far fa-user"

  @spec colours :: {String.t(), String.t(), String.t()}
  def colours, do: Central.Helpers.StylingHelper.colours(:success)
end
