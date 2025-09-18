defmodule Teiserver.Config.SiteConfigLib do
  @moduledoc false
  # We can't define it as a library since the libraries import get_site_config from here

  @spec colours() :: atom
  def colours(), do: :success2

  @spec icon() :: String.t()
  def icon(), do: "fa-solid fa-cogs"
end
