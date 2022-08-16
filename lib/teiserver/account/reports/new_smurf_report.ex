defmodule Teiserver.Account.NewSmurfReport do
  alias Central.Helpers.DatePresets
  alias Teiserver.{Account}

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-face-angry-horns"

  @spec permissions() :: String.t()
  def permissions(), do: "teiserver.admin"

  @spec run(Plug.Conn.t(), map()) :: {map(), map()}
  def run(_conn, params) do
    params = apply_defaults(params)

    # Date range
    {start_date, _end_date} = DatePresets.parse(
      params["date_preset"],
      params["start_date"],
      params["end_date"]
    )

    # Get new users first
    new_users = Account.list_users(
      search: [
        inserted_after: start_date |> Timex.to_datetime,
        verified: "Verified"
      ],
      order_by: "Newest first"
    )

    # Extract list of ids
    new_user_ids = new_users
      |> Enum.map(fn %{id: id} -> id end)

    # Get all the keys for the new users
    new_user_keys = Account.list_smurf_keys(
      search: [
        user_id_in: new_user_ids
      ],
      limit: :infinity,
      select: [:user_id, :value]
    )

    # Extract purely the values
    key_values = new_user_keys
      |> Enum.map(fn %{value: value} -> value end)

    # Now search for keys of existing users
    found_keys = Account.list_smurf_keys(
      search: [
        value_in: key_values,
        not_user_id_in: new_user_ids
      ],
      select: [:value],
      limit: :infinity
    )

    # Extract the found values
    found_values = found_keys
      |> Enum.map(fn %{value: value} -> value end)

    # Now run through the new_keys and keep only those with a match
    relevant_new_user_ids = new_user_keys
      |> Enum.filter(fn %{value: value} -> Enum.member?(found_values, value) end)
      |> Enum.map(fn %{user_id: user_id} -> user_id end)
      |> Enum.uniq

    relevant_new_users = new_users
      |> Enum.filter(fn %{id: id} -> Enum.member?(relevant_new_user_ids, id) end)

    assigns = %{
      params: params,
      presets: DatePresets.long_ranges(),
      relevant_new_users: relevant_new_users
    }

    {%{}, assigns}
  end

  defp apply_defaults(params) do
    Map.merge(%{
      "date_preset" => "This week",
      "start_date" => "",
      "end_date" => "",
      "mode" => ""
    }, Map.get(params, "report", %{}))
  end
end
