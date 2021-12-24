defmodule TeiserverWeb.Admin.AccoladeView do
  use TeiserverWeb, :view

  @spec colours() :: {String.t(), String.t(), String.t()}
  def colours, do: Teiserver.Account.AccoladeLib.colours()

  @spec icon() :: String.t()
  def icon, do: Teiserver.Account.AccoladeLib.icon()
end
