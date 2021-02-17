defmodule CentralWeb.Admin.GroupView do
  use CentralWeb, :view

  def config_name(config_key) do
    config_key
    |> String.split(".")
    |> tl
  end

  def colours(), do: Central.Account.GroupLib.colours()
  def icon(), do: Central.Account.GroupLib.icon()
end
