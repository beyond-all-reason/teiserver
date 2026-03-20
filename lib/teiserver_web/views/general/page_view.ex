defmodule TeiserverWeb.General.PageView do
  alias Teiserver.Config.UserConfigLib
  alias Teiserver.Helper.StylingHelper

  use TeiserverWeb, :view

  def view_colour(), do: StylingHelper.colours(:default)

  def view_colour("home"), do: view_colour()
  def view_colour("account"), do: view_colour()
  def view_colour("user_configs"), do: UserConfigLib.colours()
end
