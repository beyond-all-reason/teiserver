defmodule Teiserver do
  @moduledoc false
  # def icon(), do: "fad fa-robot"
  def icon(), do: "fad fa-server"

  @spec icon(:friend | :friend_request | :ignore | :relationship) :: String.t()
  def icon(:relationship), do: "fas fa-users"
  def icon(:friend), do: "fas fa-user-friends"
  def icon(:friend_request), do: "fas fa-question"
  def icon(:ignore), do: "fas fa-volume-mute"

  @doc """
  Activates agent mode (if allowed by config)
  """
  @spec agent_mode() :: :ok | :failure
  def agent_mode() do
    Teiserver.Agents.AgentLib.start()
  end
end
