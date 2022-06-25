defmodule Teiserver.Protocols.Tachyon.V1.ConfigIn do
  alias Central.Config
  alias Teiserver.{Account}
  alias Teiserver.Protocols.Tachyon.V1.Tachyon
  import Teiserver.Protocols.Tachyon.V1.TachyonOut, only: [reply: 4]
  alias Teiserver.Data.Types, as: T

  @spec do_handle(String.t(), Map.t(), T.tachyon_tcp_state()) :: T.tachyon_tcp_state()

  # Game config
  def do_handle("game_set", %{"configs" => configs}, state) do
    configs = configs
      |> Map.new(fn {key, value} -> {"game_config.#{key}", value} end)

    Account.update_user_stat(state.userid, configs)

    state
  end

  def do_handle("game_get", %{"keys" => keys}, state) do
    keys = keys
      |> Enum.map(fn key -> "game_config.#{key}" end)

    configs = Account.get_user_stat_data(state.userid)
      |> Enum.filter(fn {key, _value} ->
        Enum.member?(keys, key)
      end)
      |> Map.new(fn {"game_config." <> key, value} ->
        {key, value}
      end)

    reply(:config, :game_get, configs, state)
  end

  def do_handle("game_delete", %{"keys" => keys}, state) do
    keys = keys
      |> Enum.map(fn key -> "game_config.#{key}" end)

    Account.delete_user_stat_keys(state.userid, keys)

    state
  end


  # User config
  def do_handle("list_user_types", _, state) do
    types = Config.get_user_config_types
      |> Enum.filter(fn {_key, type} ->
        type.permissions == [] or type.permissions == ["teiserver"]
      end)
      |> Enum.map(fn {_key, type} -> type end)

    reply(:config, :list_user_types, types, state)
  end

  def do_handle("user_set", %{"configs" => configs}, state) do
    configs
      |> Enum.filter(fn {key, _value} ->
        type = Config.get_user_config_type(key)
        cond do
          type == nil -> false
          type.permissions == [] -> true
          type.permissions == ["teiserver"] -> true
          true -> false
        end
      end)
      |> Enum.each(fn {key, value} ->
        Config.set_user_config(state.userid, key, value)
      end)

    state
  end

  def do_handle("user_get", %{"keys" => keys}, state) do
    configs = keys
      |> Enum.filter(fn key ->
        type = Config.get_user_config_type(key)
        cond do
          type == nil -> false
          type.permissions == [] -> true
          type.permissions == ["teiserver"] -> true
          true -> false
        end
      end)
      |> Map.new(fn key ->
        {key, Config.get_user_config_cache(state.userid, key)}
      end)

    reply(:config, :user_get, configs, state)
  end

  def do_handle(cmd, data, state) do
    reply(:system, :error, %{location: "auth.handle", error: "No match for cmd: '#{cmd}' with data '#{Kernel.inspect data}'"}, state)
  end
end
