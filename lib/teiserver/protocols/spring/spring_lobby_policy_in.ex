defmodule Teiserver.Protocols.Spring.LobbyPolicyIn do
  @moduledoc false
  alias Teiserver.Game
  alias Teiserver.Protocols.SpringIn
  require Logger
  import Teiserver.Protocols.SpringOut, only: [reply: 5]

  @spec do_handle(String.t(), String.t(), String.t() | nil, map()) :: map()
  def do_handle(_cmd, _data, _msg_id, %{userid: nil} = state), do: state

  def do_handle("list", _data, msg_id, state) do
    policies =
      Game.list_cached_lobby_policies()
      |> Enum.map(fn lp ->
        Map.take(lp, ~w(name preset icon colour enabled agent_name_list)a)
      end)

    reply(:lobby_policy, :list, policies, msg_id, state)
  end

  def do_handle(cmd, data, msg_id, state) do
    SpringIn._no_match(state, "c.lobby_policy." <> cmd, msg_id, data)
  end
end
