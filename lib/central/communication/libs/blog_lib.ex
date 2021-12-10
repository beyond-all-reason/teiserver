defmodule Central.Communication.BlogLib do
  @moduledoc false
  use CentralWeb, :library

  def colours(), do: {"#007bff", "#DDEEFF", "primary"}
  def icon(), do: "fad fa-rss"
end
