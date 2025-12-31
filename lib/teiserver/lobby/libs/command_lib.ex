defmodule Teiserver.Lobby.CommandLib do
  @moduledoc """

  """

  alias Teiserver.{Account, Battle}
  alias Teiserver.Lobby.ChatLib
  alias Teiserver.Data.Types, as: T
  require Logger

  @spec handle_command(T.lobby_server_state(), T.userid(), String.t()) :: T.lobby_server_state()
  def handle_command(state, userid, message) do
    [name | args] = String.split(message, " ")
    name = String.downcase(name)

    command = %{
      raw: message,
      name: name,
      args: args,
      silent: false,
      error: nil,
      userid: userid
    }

    module = get_command_module(name)
    module.execute(state, command)
  end

  @spec get_command_module(String.t()) :: module
  def get_command_module(name) do
    Teiserver.store_get(:lobby_command_cache, name) ||
      Teiserver.store_get(:lobby_command_cache, "no_command")
  end

  @spec cache_lobby_commands() :: :ok
  def cache_lobby_commands() do
    {:ok, module_list} = :application.get_key(:teiserver, :modules)

    lookup =
      module_list
      # credo:disable-for-lines:14 Credo.Check.Refactor.FilterFilter
      |> Enum.filter(fn m ->
        m |> Module.split() |> Enum.take(3) == ["Teiserver", "Lobby", "Commands"]
      end)
      |> Enum.filter(fn m ->
        Code.ensure_loaded(m)

        exports = function_exported?(m, :name, 0) && function_exported?(m, :execute, 2)

        # if not exports do
        #   Logger.error("LobbyCommand #{inspect m} does not export all the required functions")
        # end

        exports
      end)
      |> Enum.reduce(%{}, fn module, acc ->
        Map.put(acc, module.name(), module)
      end)

    old = Teiserver.store_get(:lobby_command_cache, "all") || []

    # Store all keys, we'll use it later for removing old ones
    Teiserver.store_put(:lobby_command_cache, "all", Map.keys(lookup))

    # Now store our lookups
    lookup
    |> Enum.each(fn {key, func} ->
      Teiserver.store_put(:lobby_command_cache, key, func)
    end)

    # Special case
    no_command_module = Teiserver.Lobby.Commands.NoCommand
    Teiserver.store_put(:lobby_command_cache, "no_command", no_command_module)

    # Delete out-dated keys
    old
    |> Enum.reject(fn old_key ->
      Map.has_key?(lookup, old_key)
    end)
    |> Enum.each(fn old_key ->
      Teiserver.store_delete(:lobby_command_cache, old_key)
    end)

    :ok
  end

  @spec say_command(map(), T.lobby_id()) :: any()
  def say_command(%{silent: true} = cmd, state), do: log_command(cmd, state)

  def say_command(cmd, lobby_id) do
    message = "$ " <> command_as_message(cmd)
    Battle.say(cmd.userid, message, lobby_id)
  end

  @spec log_command(map, T.lobby_id()) :: any()
  def log_command(cmd, lobby_id) do
    message = "$ " <> command_as_message(cmd)
    sender = Account.get_user_by_id(cmd.userid)
    ChatLib.persist_message(sender, message, lobby_id, :say)
  end

  @spec command_as_message(map()) :: String.t()
  def command_as_message(cmd) do
    remaining = if Map.get(cmd, :remaining), do: " #{cmd.remaining}", else: ""
    error = if Map.get(cmd, :error), do: " Error: #{cmd.error}", else: ""

    "#{cmd.name}#{remaining}#{error}"
    |> String.trim()
  end
end
