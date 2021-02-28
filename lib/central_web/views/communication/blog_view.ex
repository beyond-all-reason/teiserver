defmodule CentralWeb.Communication.BlogView do
  use CentralWeb, :view

  def colours(), do: Central.Communication.BlogLib.colours()
  def icon(), do: Central.Communication.BlogLib.icon()

  def get_key(url_slug), do: Central.Communication.PostLib.get_key(url_slug)

  def format_comment(c) do
    c
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\n", "<br />")
    |> raw
  end
end
