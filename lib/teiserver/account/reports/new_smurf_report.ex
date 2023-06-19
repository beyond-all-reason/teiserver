defmodule Teiserver.Account.NewSmurfReport do
  alias Teiserver.{Account, User}
  import Central.Helpers.NumberHelper, only: [int_parse: 1]
  require Logger

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-face-angry-horns"

  @spec permissions() :: String.t()
  def permissions(), do: "Moderator"

  @spec run(Plug.Conn.t(), map()) :: {map(), map()}
  def run(_conn, params) do
    params = apply_defaults(params)

    max_age =
      params["age"]
      |> int_parse

    # Get new users first
    new_users =
      Account.list_users(
        search: [
          last_played_after: Timex.now() |> Timex.shift(days: -max_age),
          smurf_of: false,
          verified: true
        ],
        limit: 1000,
        order_by: "Newest first"
      )

    # Extract list of ids
    new_user_ids =
      new_users
      |> Enum.map(fn %{id: id} -> id end)

    valid_types =
      Account.list_smurf_key_types(
        search: [
          name_in: ["chobby_mac_hash"]
        ],
        limit: :infinity
      )
      |> Enum.map(fn %{id: id} -> id end)

    # Get all the keys for the new users
    new_user_keys =
      Account.list_smurf_keys(
        search: [
          user_id_in: new_user_ids,
          type_id_in: valid_types
        ],
        limit: :infinity,
        select: [:user_id, :value]
      )

    # Extract purely the values
    key_values =
      new_user_keys
      |> Enum.map(fn %{value: value} -> value end)

    # Now search for keys of existing users
    found_keys =
      Account.list_smurf_keys(
        search: [
          value_in: key_values,
          not_user_id_in: new_user_ids,
          type_id_in: valid_types
        ],
        select: [:value, :user_id],
        limit: :infinity
      )
      |> Enum.filter(fn %{user_id: userid} ->
        User.is_verified?(userid)
      end)

    # Extract the found values
    found_values =
      found_keys
      |> Enum.map(fn %{value: value} -> value end)

    # Now run through the new_keys and keep only those with a match
    relevant_new_user_ids =
      new_user_keys
      |> Enum.filter(fn %{value: value} -> Enum.member?(found_values, value) end)
      |> Enum.map(fn %{user_id: user_id} -> user_id end)
      |> Enum.uniq()

    relevant_new_users =
      new_users
      |> Enum.filter(fn user -> Enum.member?(relevant_new_user_ids, user.id) end)
      |> Enum.reject(fn user ->
        if params["ignore_banned"] == "true" do
          Enum.member?(user.data["restrictions"], "Login")
        end
      end)

    user_stats =
      relevant_new_users
      |> Map.new(fn u ->
        {u.id, Account.get_user_stat_data(u.id)}
      end)

    assigns = %{
      relevant_new_users: relevant_new_users,
      user_stats: user_stats,
      params: params
    }

    {%{}, assigns}
  end

  defp apply_defaults(params) do
    Map.merge(
      %{
        "ignore_banned" => "true",
        "age" => "31"
      },
      Map.get(params, "report", %{})
    )
  end
end
