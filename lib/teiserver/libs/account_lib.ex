defmodule Teiserver.AccountLib do
  @moduledoc false
  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-solid fa-user"

  @spec colours :: atom
  def colours, do: :success
end
