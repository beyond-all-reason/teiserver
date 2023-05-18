defmodule TeiserverWeb.Account.PreferencesView do
  use TeiserverWeb, :view

  @spec view_colour :: atom
  def view_colour(), do: Teiserver.Config.UserConfigLib.colours()

  @spec icon() :: String.t()
  def icon(), do: Teiserver.Config.UserConfigLib.icon()

  @spec config_name(String.t()) :: String.t()
  def config_name(config_key) do
    config_key
    |> String.split(".")
    |> tl
  end
end
