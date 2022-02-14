defmodule TeiserverWeb.Account.PreferencesView do
  use TeiserverWeb, :view
  import CentralWeb.Config.UserConfigView, only: [config_name: 1]

  @spec view_colour :: atom
  def view_colour(), do: Central.Config.UserConfigLib.colours()

  @spec icon() :: String.t()
  def icon(), do: Central.Config.UserConfigLib.icon()
end
