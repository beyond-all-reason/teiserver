defmodule Teiserver.Admin.ToolLib do
  @moduledoc false
  use CentralWeb, :library

  @spec colours :: atom
  def colours(), do: :info

  @spec icon :: String.t()
  def icon(), do: "fa-regular fa-tools"
end
