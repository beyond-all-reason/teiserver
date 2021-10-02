defmodule TeiserverWeb.Admin.BanHashView do
  use TeiserverWeb, :view

  @spec colours() :: {String.t(), String.t(), String.t()}
  def colours, do: Teiserver.Account.BanHashLib.colours()

  @spec icon() :: String.t()
  def icon, do: Teiserver.Account.BanHashLib.icon()
end
