defmodule Teiserver.OAuth.ApplicationLib do
  @moduledoc false
  @spec icon :: String.t()
  def icon, do: "fa-solid fa-passport"

  @spec colours :: atom
  def colours, do: :success2
end
