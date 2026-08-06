defmodule Teiserver.Logging.Filter do
  @moduledoc """
  Some additional logging configuration
  """

  def filter(event, _args) do
    if Map.get(event.meta, :mfa) == {Phoenix.Socket.Transport, :check_origin, 5},
      do: :stop,
      else: :ignore
  end

  @doc """
  add a filter to the loggers so that it doesn't show the very verbose message
  about a connection's host that doesn't match the origin header.
  """
  def silence_bogus_origins do
    :logger.add_primary_filter(:silence_bogus_origins, {&filter/2, []})
  end
end
