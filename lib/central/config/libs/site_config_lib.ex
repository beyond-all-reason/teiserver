defmodule Central.Config.SiteConfigLib do
  # We can't define it as a library since the libraries import get_site_config from here

  def colours(), do: Central.Helpers.StylingHelper.colours(:success2)
  def icon(), do: "far fa-cogs"
end
