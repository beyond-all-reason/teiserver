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
  @spec agent_mode() :: :ok | {:failure, String.t()}
  def agent_mode() do
    Teiserver.Agents.AgentLib.start()
  end

  @spec user_group_id() :: integer()
  def user_group_id(), do: ConCache.get(:application_metadata_cache, "teiserver_user_group")

  @spec umbrella_group_id() :: integer()
  def umbrella_group_id(), do: ConCache.get(:application_metadata_cache, "teiserver_umbrella_group")

  @spec internal_group_id() :: integer()
  def internal_group_id(), do: ConCache.get(:application_metadata_cache, "teiserver_internal_group")

  # Designed for debugging help
  def tachyon(v) do
    Teiserver.Protocols.Tachyon.decode(v)
  end
end
