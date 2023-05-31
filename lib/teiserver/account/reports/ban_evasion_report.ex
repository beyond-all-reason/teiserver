defmodule Teiserver.Account.BanEvasionReport do
  @moduledoc """

  """
  alias Teiserver.{Account, User}
  require Logger

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-user-ninja"

  @spec permissions() :: String.t()
  def permissions(), do: "teiserver.admin"

  @spec run(Plug.Conn.t(), map()) :: {map(), map()}
  def run(_conn, params) do
    params = apply_defaults(params)
    valid_types = get_valid_key_types()

    moderated_users =
      Account.list_users(
        search: [
          mod_action: "Any action"
        ],
        limit: :infinity,
        order_by: "Newest first"
      )
      |> Enum.reject(fn user ->
        user.data["restrictions"] == ["Bridging"]
      end)

    moderated_user_ids =
      moderated_users
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

    # Now search for keys of existing users
    evader_keys =
      Account.list_smurf_keys(
        search: [
          value_in: moderated_key_values,
          not_user_id_in: moderated_user_ids,
          type_id_in: valid_types
        ],
        select: [:value, :user_id],
        limit: :infinity
      )
      |> Enum.filter(fn %{user_id: userid} ->
        User.is_verified?(userid)
      end)

    # Extract the evader values
    evader_values =
      evader_keys
      |> Enum.map(fn %{value: value} -> value end)

    # Now run through the new_keys and keep only those with a match
    relevant_evader_ids =
      moderated_keys
      |> Enum.filter(fn %{value: value} -> Enum.member?(evader_values, value) end)
      |> Enum.map(fn %{user_id: user_id} -> user_id end)
      |> Enum.uniq()

    evaders =
      Account.list_users(
        search: [
          id_in: relevant_evader_ids
        ],
        limit: :infinity
      )

    relevant_evaders =
      evaders
      |> Enum.filter(fn user -> Enum.member?(relevant_evader_ids, user.id) end)
      |> Enum.reject(fn user ->
        User.is_restricted?(user.data["restrictions"], [
          "Login",
          "All chat",
          "Room chat",
          "All lobbies"
        ])
      end)

    user_stats =
      relevant_evaders
      |> Map.new(fn u ->
        {u.id, Account.get_user_stat_data(u.id)}
      end)

    # Now apply filters that require us to have their stats
    relevant_evaders =
      relevant_evaders
      |> Enum.reject(fn user ->
        if params["require_games"] == "true" do
          stats = user_stats[user.id]

          total =
            ~w(recent_count.duel recent_count.ffa recent_count.team)
            |> Enum.reduce(0, fn key, acc ->
              Map.get(stats, key, 0) + acc
            end)

          total == 0
        end
      end)
      |> Enum.sort_by(fn user -> user.data["last_login"] end, &>=/2)

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
        "age" => "31"
      },
      Map.get(params, "report", %{})
    )
  end
end
