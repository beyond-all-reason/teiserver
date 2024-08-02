defmodule Teiserver.Player do
  @moduledoc """
  Context to handle anything player related when it comes to tachyon

  This context essentially bundles two concepts: connection and session.
  A connection is the actual websocket process that communicate with a player.
  A session is: TODO!
  """

  alias Teiserver.Data.Types, as: T

  @doc """
  Returns the pid of the connection registered with a given user id
  """
  @spec lookup_connection(T.userid()) :: pid() | nil
  def lookup_connection(user_id) do
    Teiserver.Player.Registry.lookup(user_id)
  end

  @spec connection_via_tuple(T.userid()) :: GenServer.name()
  def connection_via_tuple(user_id) do
    Teiserver.Player.Registry.via_tuple(user_id)
  end
end
