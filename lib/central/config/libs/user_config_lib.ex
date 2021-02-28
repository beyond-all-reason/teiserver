defmodule Central.Config.UserConfigLib do
  # We can't define it as a library since the libraries
  # import get_user_config from here

  # alias Central.Config

  def colours(), do: Central.Helpers.StylingHelper.colours(:success)
  def icon(), do: "far fa-cog"
end
