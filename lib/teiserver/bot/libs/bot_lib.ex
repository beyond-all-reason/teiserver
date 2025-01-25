defmodule Teiserver.BotLib do
  @spec icon :: String.t()
  def icon, do: "fa-solid fa-robot"

  @spec colours :: atom
  def colours, do: :success2
end
