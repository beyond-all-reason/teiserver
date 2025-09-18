defmodule Teiserver.Config.UserConfigLib do
  @moduledoc false
  # We can't define it as a library since the libraries
  # import get_user_config from here

  # alias Teiserver.Config

  @spec colours() :: atom
  def colours(), do: :success

  @spec icon() :: String.t()
  def icon(), do: "fa-solid fa-cog"
end
