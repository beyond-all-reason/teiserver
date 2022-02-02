defmodule Central.Communication.BlogLib do
  @moduledoc false
  use CentralWeb, :library

  def colours(), do: Central.Helpers.StylingHelper.colours(:primary)
  def icon(), do: "fad fa-rss"
end
