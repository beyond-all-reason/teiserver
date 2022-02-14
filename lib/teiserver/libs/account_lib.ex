defmodule Teiserver.AccountLib do
  # Functions
  @spec icon :: String.t()
  def icon, do: "far fa-user"

  @spec colours :: atom
  def colours, do: :success
end
