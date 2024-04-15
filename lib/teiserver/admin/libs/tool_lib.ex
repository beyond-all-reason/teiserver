defmodule Teiserver.Admin.ToolLib do
  @moduledoc false
  use TeiserverWeb, :library

  @spec colours :: atom
  def colours(), do: :info

  @spec icon :: String.t()
  def icon(), do: "fa-solid fa-tools"
end
