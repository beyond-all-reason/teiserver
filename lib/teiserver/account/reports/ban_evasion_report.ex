defmodule Teiserver.Account.BanEvasionReport do
  @moduledoc """

  """
  alias Teiserver.{Account}
  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]
  require Logger

  @spec icon() :: String.t()
  def icon(), do: "fa-solid fa-user-ninja"

  @spec permissions() :: String.t()
  def permissions(), do: "Moderator"

  @spec run(Plug.Conn.t(), map()) :: map()
  def run(_conn, params) do
    params = apply_defaults(params)
    valid_types = get_valid_key_types()

    moderated_user_ids =
      Account.list_users(
        search: [
          mod_action: "Muted or banned"
        ],
        select: [:id],
        limit: :infinity,
        order_by: "Newest first"
      )
      |> Enum.map(fn %{id: id} -> id end)

    moderated_keys =
      Account.list_smurf_keys(
        search: [
          user_id_in: moderated_user_ids,
          type_id_in: valid_types
        ],
        limit: :infinity,
        select: [:user_id, :value]
      )

    # Extract purely the values
    moderated_key_values =
      moderated_keys
      |> Enum.map(fn %{value: value} -> value end)
      |> Enum.uniq()

    # Now search for keys of existing users
    relevant_evader_ids =
      Account.list_smurf_keys(
        search: [
          value_in: moderated_key_values,
          not_user_id_in: moderated_user_ids,
          type_id_in: valid_types
        ],
        select: [:user_id],
        limit: :infinity
      )
      |> Enum.map(fn %{user_id: user_id} -> user_id end)

    _max_play_age =
      params["max_play_age"]
      |> int_parse()

    max_account_age =
      params["max_account_age"]
      |> int_parse()

    relevant_evaders =
      Account.list_users(
        search: [
          id_in: relevant_evader_ids,
          mod_action: "not muted or banned",
          # last_played_after: Timex.now() |> Timex.shift(days: -max_play_age),
          inserted_after: Timex.now() |> Timex.shift(days: -max_account_age),
          smurf_of: "Non-smurf"
        ],
        order_by: ["Last played", "Last logged in"],
        limit: :infinity
      )

    user_stats =
      relevant_evaders
      |> Map.new(fn u ->
        {u.id, Account.get_user_stat_data(u.id)}
      end)

    # Now filter out smurf origins
    relevant_evaders =
      relevant_evaders
      |> Enum.filter(fn u ->
        stats = user_stats[u.id]

        cond do
          (stats["smurf_count"] || 0) > 0 -> false
          true -> true
        end
      end)

    %{
      relevant_evaders: relevant_evaders,
      user_stats: user_stats,
      params: params
    }
  end

  defp get_valid_key_types() do
    Account.list_smurf_key_types(
      search: [
        name_in: ["chobby_mac_hash"]
      ],
      limit: :infinity
    )
    |> Enum.map(fn %{id: id} -> id end)
  end

  defp apply_defaults(params) do
    Map.merge(
      %{
        "require_games" => "false",
        "max_account_age" => "90",
        "max_played_age" => "7"
      },
      Map.get(params, "report", %{})
    )
  end
end
