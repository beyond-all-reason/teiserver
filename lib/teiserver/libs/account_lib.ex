defmodule Barserver.AccountLib do
  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-regular fa-user"

  @spec colours :: atom
  def colours, do: :success
end
