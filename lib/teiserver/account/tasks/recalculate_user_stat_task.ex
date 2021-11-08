defmodule Teiserver.Account.RecalculateUserStatTask do
  use Oban.Worker, queue: :cleanup

  alias Teiserver.{User, Account, Telemetry}

  # Teiserver.Account.RecalculateUserStatTask.perform(%{})

  @empty_row %{
    menu: 0,
    lobby: 0,
    spectator: 0,
    player: 0,
  }

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    Telemetry.list_telemetry_day_logs(limit: :infinity)
    |> Enum.map(&convert_to_user_log/1)
    |> List.flatten
    |> Enum.group_by(fn {userid, _} ->
      userid
    end, fn {_, user_data} ->
      user_data
    end)
    |> Enum.filter(fn {userid, _} ->
      username = User.get_username(userid)
      username != nil
    end)
    |> Enum.each(fn {userid, data_rows} ->
      data = data_rows
      |> Enum.reduce(@empty_row, fn (row, acc) ->
        combine_row(row, acc)
      end)

      Account.update_user_stat(userid, %{
        menu_minutes: data.menu,
        lobby_minutes: data.lobby,
        spectator_minutes: data.spectator,
        player_minutes: data.player,
        total_minutes: data.menu + data.lobby + data.spectator + data.player
      })

      user = User.get_user_by_id(userid)
      User.update_user(%{user | rank: User.calculate_rank(user.id)}, persist: true)

      Account.update_user_roles(Account.get_user!(userid))
    end)

    :ok
  end

  # Take the log of the day and extract the user related data we actually
  # want to aggregrate
  defp convert_to_user_log(%{data: data}) do
    user_data = data["minutes_per_user"]

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
      spectator: row.spectator + acc.spectator,
    }
  end
end
