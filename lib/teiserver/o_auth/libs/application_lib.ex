defmodule Teiserver.OAuth.ApplicationLib do
  @spec icon :: String.t()
  def icon, do: "fa-solid fa-passport"

  @spec colours :: atom
  def colours, do: :success2
end
