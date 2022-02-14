defmodule CentralWeb.Communication.BlogFileView do
  use CentralWeb, :view

  import Central.Helpers.FileHelper, only: [file_type: 1, ext_icon: 2, mem_normalize: 1]

  @spec view_colour :: {String.t(), String.t(), String.t()}
  def view_colour(), do: Central.Communication.BlogFileLib.colours()

  @spec icon :: String.t()
  def icon(), do: Central.Communication.BlogFileLib.icon()
end
