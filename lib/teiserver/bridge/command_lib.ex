defmodule Teiserver.Bridge.CommandLib do
  @moduledoc """

  """
  require Logger

  @spec handle_command(Nostrum.Struct.Interaction.t(), map()) :: map()
  def handle_command(%{data: %{name: name}} = interaction, options_map) do
    module = get_command_module(name)
    module.execute(interaction, options_map)
  end

  @spec get_command_module(String.t()) :: module
  def get_command_module(name) do
    Teiserver.store_get(:discord_command_cache, name) ||
      Teiserver.store_get(:discord_command_cache, "no_command")
  end

  @spec cache_discord_commands() :: :ok
  def cache_discord_commands() do
    {:ok, module_list} = :application.get_key(:teiserver, :modules)

    lookup =
      module_list
      # credo:disable-for-lines:17 Credo.Check.Refactor.FilterFilter
      |> Enum.filter(fn m ->
        m |> Module.split() |> Enum.take(3) == ["Teiserver", "Bridge", "Commands"]
      end)
      |> Enum.filter(fn m ->
        Code.ensure_loaded(m)

        exports =
          function_exported?(m, :name, 0) &&
            function_exported?(m, :cmd_definition, 0) &&
            function_exported?(m, :execute, 2)

        if not exports do
          Logger.error("DiscordCommand #{inspect(m)} does not export all the required functions")
        end

        exports
      end)
      |> Enum.reduce(%{}, fn module, acc ->
        Map.put(acc, module.name(), module)
      end)

    old = Teiserver.store_get(:discord_command_cache, "all") || []

    # Store all keys, we'll use it later for removing old ones
    Teiserver.store_put(:discord_command_cache, "all", Map.keys(lookup))

    # Now store our lookups
    lookup
    |> Enum.each(fn {key, m} ->
      Teiserver.store_put(:discord_command_cache, key, m)
    end)

    # Delete out-dated keys
    old
    |> Enum.reject(fn old_key ->
      Map.has_key?(lookup, old_key)
    end)
    |> Enum.each(fn old_key ->
      Teiserver.store_delete(:discord_command_cache, old_key)
    end)

    :ok
  end

  @spec re_cache_discord_command(String.t()) :: :ok
  def re_cache_discord_command(name) do
    m = get_command_module(name)

    if m do
      Code.ensure_loaded(m)

      exports =
        function_exported?(m, :name, 0) &&
          function_exported?(m, :cmd_definition, 0) &&
          function_exported?(m, :execute, 2)

      if exports do
        Teiserver.store_put(:discord_command_cache, name, m)
      else
        Logger.error(
          "DiscordCommand (recache) #{inspect(m)} does not export all the required functions"
        )
      end
    end

    :ok
  end
end
