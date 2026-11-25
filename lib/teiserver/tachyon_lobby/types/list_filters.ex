defmodule Teiserver.TachyonLobby.Types.ListFilters do
  @moduledoc false

  alias Teiserver.Account
  alias Teiserver.Account.User
  alias Teiserver.Party
  alias Teiserver.Player.SessionRegistry
  alias Teiserver.TachyonLobby.Types, as: LT

  @type range() :: %{optional(:min) => number(), optional(:max) => number()}

  @type t() :: %{
          optional(:has_friend?) => boolean(),
          optional(:has_party_member?) => boolean(),
          optional(:map_names) => MapSet.t(String.t()),
          optional(:player_count) => range(),
          optional(:ally_teams) => range(),
          optional(:name) => String.t(),
          optional(:tags) => MapSet.t(String.t()),
          optional(:battle_in_progress?) => boolean(),
          optional(:bosses_enabled?) => boolean(),
          optional(:engine_versions) => MapSet.t(String.t()),
          optional(:game_versions) => MapSet.t(String.t())
        }

  # empty filters match every lobby
  @spec filter(LT.Types.id(), LT.ListOverview.t(), t(), User.t(), Party.id() | nil) :: boolean()
  def filter(lobby_id, %LT.ListOverview{} = lobby, filters, %User{} = user, party_id) do
    Enum.all?(filters, fn
      {:has_friend?, expected} -> has_friend?(lobby_id, user) == expected
      {:has_party_member?, expected} -> has_party_member?(lobby_id, user, party_id) == expected
      filter -> matches?(lobby, filter)
    end)
  end

  defp has_friend?(lobby_id, user) do
    user.id |> Account.list_friend_ids_of_user() |> any_in_lobby?(lobby_id)
  end

  defp has_party_member?(_lobby_id, _user, nil), do: false

  defp has_party_member?(lobby_id, user, party_id) do
    case Party.get_overview(party_id) do
      nil ->
        false

      party ->
        party.members |> Map.keys() |> List.delete(user.id) |> any_in_lobby?(lobby_id)
    end
  end

  defp any_in_lobby?(user_ids, lobby_id),
    do: Enum.any?(user_ids, &(SessionRegistry.get_lobby_id(&1) == lobby_id))

  defp matches?(lobby, {:map_names, names}), do: MapSet.member?(names, lobby.map_name)
  defp matches?(lobby, {:player_count, range}), do: in_range?(lobby.player_count, range)
  defp matches?(lobby, {:ally_teams, range}), do: in_range?(lobby.ally_team_count, range)

  defp matches?(lobby, {:name, name}),
    do: lobby.name |> String.downcase() |> String.contains?(name)

  defp matches?(lobby, {:tags, tags}), do: Enum.any?(tags, &is_map_key(lobby.tags, &1))

  defp matches?(lobby, {:battle_in_progress?, expected}),
    do: lobby.current_battle != nil == expected

  defp matches?(lobby, {:bosses_enabled?, expected}), do: lobby.boss_enabled? == expected

  defp matches?(lobby, {:engine_versions, versions}),
    do: MapSet.member?(versions, lobby.engine_version)

  defp matches?(lobby, {:game_versions, versions}),
    do: MapSet.member?(versions, lobby.game_version)

  defp matches?(_lobby, {_filter, _value}), do: true

  # Both min and max are inclusive
  defp in_range?(value, range),
    do: value >= Map.get(range, :min, value) and value <= Map.get(range, :max, value)
end
