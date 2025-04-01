defmodule Teiserver.AssetLib do
  @moduledoc """
  engine and game versions
  """

  @spec icon :: String.t()
  def icon, do: "fa-solid fa-frog"

  @spec colours :: atom
  def colours, do: :success2
end
