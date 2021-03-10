defmodule Teiserver do
  @moduledoc false
  def icon(), do: "fad fa-robot"

  def icon(:relationship), do: "fas fa-users"
  def icon(:friend), do: "fas fa-user-friends"
  def icon(:friend_request), do: "fas fa-question"
  def icon(:ignore), do: "fas fa-volume-mute"
end
