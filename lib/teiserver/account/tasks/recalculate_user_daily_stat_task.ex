defmodule Teiserver.Account.RecalculateUserDailyStatTask do
  @moduledoc """
  Goes through every user that logged on in the last 24 hours (it's meant to run every 12 hours)
  and cache certain values from server day logs
  """
  use Oban.Worker, queue: :cleanup

  alias Teiserver.Repo
  import Ecto.Query, warn: false
  alias Teiserver.Account
  alias Teiserver.Logging.UserActivityDayLog

  # Teiserver.Account.RecalculateUserDailyStatTask.perform(nil)

  @empty_row %{
    menu: 0,
    lobby: 0,
    spectator: 0,
    player: 0
  }

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    start_date =
      Timex.now()
      |> Timex.shift(hours: -26)
      |> Timex.to_unix()

    start_date = round(start_date / 60)

    user_ids =
      Account.list_users(
        search: [
          data_greater_than: {"last_login_mins", start_date |> to_string()},
          data_equal: {"bot", "false"},
          smurf_of: false
        ],
        limit: :infinity,
        select: [:id]
      )
      |> Enum.map(fn %{id: id} -> id end)

    query = from(logs in UserActivityDayLog)

    stream = Repo.stream(query, max_rows: 50)

    {:ok, _result} =
      Repo.transaction(fn ->
        stream
        |> Enum.map(&convert_to_user_log/1)
        |> List.flatten()
        |> Enum.group_by(
          fn {userid, _} ->
            userid
          end,
          fn {_, user_data} ->
            user_data
          end
        )
        |> Enum.filter(fn {userid, _} ->
          if Enum.member?(user_ids, userid) do
            Account.get_username(userid) != nil
          end
        end)
        |> Enum.each(fn {userid, data_rows} ->
          data =
            data_rows
            |> Enum.reduce(@empty_row, fn row, acc ->
              combine_row(row, acc)
            end)

          Account.update_user_stat(userid, %{
            menu_minutes: data.menu,
            lobby_minutes: data.lobby,
            spectator_minutes: data.spectator,
            player_minutes: data.player,
            total_minutes: data.menu + data.lobby + data.spectator + data.player
          })
        end)
      end)

    :ok
  end

  # Take the log of the day and extract the user related data we actually
  # want to aggregate
  defp convert_to_user_log(%{data: user_data}) do
    Map.keys(user_data["total"])
    |> Enum.map(fn userid_str ->
      userid = String.to_integer(userid_str)

      user_data = %{
        menu: user_data["menu"][userid_str] || 0,
        lobby: user_data["lobby"][userid_str] || 0,
        spectator: user_data["spectator"][userid_str] || 0,
        player: user_data["player"][userid_str] || 0
      }

      {userid, user_data}
    end)
  end

  defp combine_row(row, acc) do
    %{
      menu: row.menu + acc.menu,
      lobby: row.lobby + acc.lobby,
      player: row.player + acc.player,
      spectator: row.spectator + acc.spectator
    }
  end
end
