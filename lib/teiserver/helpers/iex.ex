defmodule Teiserver.Helpers.Iex do
  @moduledoc """
  Bunch of code that is useful when remoting into a node for diagnostics
  or debugging
  alias Teiserver.Helpers.Iex, as: Dbg
  """

  @doc """
  Returns the list of keys for the given registry
  Some registries are "aliased" :lobbies, :sessions, :players, :autohosts
  """
  def list_reg_keys(reg) do
    spec = [
      {
        {:"$1", :_, :_},
        [],
        [:"$1"]
      }
    ]

    list_reg(reg, spec)
  end

  @doc """
  Returns the list of {key, pid, value} for everything under the given registry
  Some registries are "aliased" :lobbies, :sessions, :players, :autohosts
  """
  def list_reg_content(reg) do
    spec = [
      {
        {:"$1", :"$2", :"$3"},
        [],
        [{{:"$1", :"$2", :"$3"}}]
      }
    ]

    list_reg(reg, spec)
  end

  @doc """
  Same as Registry.select, but also works with Horde.Registry.
  """
  def list_reg(reg, spec) do
    reg =
      case reg do
        :lobbies -> Teiserver.TachyonLobby.Registry
        :sessions -> Teiserver.Player.SessionRegistry
        :players -> Teiserver.Player.Registry
        :autohosts -> Teiserver.Autohost.SessionRegistry
        x -> x
      end

    try do
      Horde.Registry.select(reg, spec)
    rescue
      ArgumentError -> Registry.select(reg, spec)
    end
  end
end
