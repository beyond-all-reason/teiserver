defmodule CentralWeb.Admin.CodeView do
  use CentralWeb, :view

  @spec colours() :: {String.t(), String.t(), String.t()}
  def colours(), do: Central.Account.CodeLib.colours()

  @spec icon() :: String.t()
  def icon(), do: Central.Account.CodeLib.icon()
end
