defmodule Teiserver.Account.AccoladeReport do
  alias Teiserver.Helper.DatePresets
  alias Teiserver.{Account, CacheUser}
  alias Teiserver.Account.BadgeTypeLib

  @spec icon() :: String.t()
  def icon(), do: Teiserver.Account.AccoladeLib.icon()

  @spec permissions() :: String.t()
  def permissions(), do: "Admin"

  @spec run(Plug.Conn.t(), map()) :: {map(), map()}
  def run(_conn, params) do
    params = apply_defaults(params)

    # Date range
    {start_date, end_date} =
      DatePresets.parse(
        params["date_preset"],
        params["start_date"],
        params["end_date"]
      )

    badge_types =
      Account.list_badge_types()
      |> Map.new(fn bt -> {bt.id, bt} end)
      |> Map.put(nil, BadgeTypeLib.nil_badge_type())

    accolades =
      Account.list_accolades(
        search: [
          inserted_after: start_date |> Timex.to_datetime(),
          inserted_before: end_date |> Timex.to_datetime()
        ],
        limit: :infinity
      )

    counts =
      accolades
      |> Enum.group_by(
        fn a ->
          a.badge_type_id
        end,
        fn _ ->
          1
        end
      )
      |> Map.new(fn {k, v} -> {k, Enum.count(v)} end)

    giver_leaderboard =
      get_giver_leaderboard(accolades, 3)
      |> Map.drop([nil])

    recipient_leaderboard =
      get_recipient_leaderboard(accolades, 3)
      |> Map.drop([nil])

    giver_ids =
      giver_leaderboard
      |> Enum.map(fn {_, leaders} ->
        leaders
        |> Enum.map(fn {userid, _} -> userid end)
      end)
      |> List.flatten()

    recipient_ids =
      recipient_leaderboard
      |> Enum.map(fn {_, leaders} ->
        leaders
        |> Enum.map(fn {userid, _} -> userid end)
      end)
      |> List.flatten()

    give_take_ratios = get_give_take_ratios(accolades)

    top_takers =
      give_take_ratios
      |> Enum.sort_by(fn {_, _, got, ratio} -> {ratio, got} end, &>=/2)
      |> Enum.take(10)

    top_givers =
      give_take_ratios
      |> Enum.sort_by(fn {_, gave, _, ratio} -> {-ratio, gave} end, &>=/2)
      |> Enum.take(10)

    taker_userids = top_takers |> Enum.map(fn {userid, _, _, _} -> userid end)
    giver_userids = top_givers |> Enum.map(fn {userid, _, _, _} -> userid end)

    users =
      (giver_ids ++ recipient_ids ++ taker_userids ++ giver_userids)
      |> Enum.uniq()
      |> Map.new(fn userid -> {userid, CacheUser.get_user_by_id(userid)} end)

    assigns = %{
      counts: counts,
      badge_types: badge_types,
      giver_leaderboard: giver_leaderboard,
      recipient_leaderboard: recipient_leaderboard,
      top_takers: top_takers,
      top_givers: top_givers,
      users: users,
      params: params,
      presets: DatePresets.long_ranges()
    }

    {%{
       start_date: start_date,
       end_date: end_date
     }, assigns}
  end

  defp apply_defaults(params) do
    Map.merge(
      %{
        "date_preset" => "This month",
        "start_date" => "",
        "end_date" => "",
        "mode" => ""
      },
      Map.get(params, "report", %{})
    )
  end

  defp get_giver_leaderboard(accolades, positions) do
    accolades
    |> Enum.group_by(fn a -> a.badge_type_id end)
    |> Map.new(fn {b_id, accs} -> {b_id, get_giver_leaderboard_for_badge(accs, positions)} end)
  end

  defp get_giver_leaderboard_for_badge(accolades, positions) do
    accolades
    |> Enum.group_by(fn a -> a.giver_id end)
    |> Enum.map(fn {giver, accs} -> {giver, Enum.count(accs)} end)
    |> Enum.sort_by(fn {_, acc_count} -> acc_count end, &>=/2)
    |> Enum.take(positions)
  end

  defp get_recipient_leaderboard(accolades, positions) do
    accolades
    |> Enum.group_by(fn a -> a.badge_type_id end)
    |> Map.new(fn {b_id, accs} ->
      {b_id, get_recipient_leaderboard_for_badge(accs, positions)}
    end)
  end

  defp get_recipient_leaderboard_for_badge(accolades, positions) do
    accolades
    |> Enum.group_by(fn a -> a.recipient_id end)
    |> Enum.map(fn {recipient, accs} -> {recipient, Enum.count(accs)} end)
    |> Enum.sort_by(fn {_, acc_count} -> acc_count end, &>=/2)
    |> Enum.take(positions)
  end

  defp get_give_take_ratios(accolades) do
    given =
      accolades
      |> Enum.group_by(fn a -> a.giver_id end, fn _ -> :ok end)
      |> Map.new(fn {userid, accs} -> {userid, Enum.count(accs)} end)

    received =
      accolades
      |> Enum.group_by(fn a -> a.recipient_id end, fn _ -> :ok end)
      |> Map.new(fn {userid, accs} -> {userid, Enum.count(accs)} end)

    Enum.uniq(Map.keys(given) ++ Map.keys(received))
    |> Enum.map(fn userid ->
      {userid, Map.get(given, userid, 0), Map.get(received, userid, 0),
       Map.get(received, userid, 0) / Map.get(given, userid, 1)}
    end)
  end
end
