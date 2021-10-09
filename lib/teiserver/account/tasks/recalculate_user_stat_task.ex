defmodule Teiserver.Account.RecalculateUserStatTask do
  use Oban.Worker, queue: :cleanup

  alias Teiserver.{Account, Telemetry}

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
    |> Enum.each(fn {userid, data_rows} ->
      data = data_rows
      |> Enum.reduce(@empty_row, fn (row, acc) ->
        combine_row(row, acc)
      end)

      hw_fingerprint = (Account.get_user_stat(userid) || %{data: %{}})
      |> Map.get(:data)
      |> calculate_hw_fingerprint()

      Account.update_user_stat(userid, %{
        hw_fingerprint: hw_fingerprint,
        menu_minutes: data.menu,
        lobby_minutes: data.lobby,
        spectator_minutes: data.spectator,
        player_minutes: data.player,
        total_minutes: data.menu + data.lobby + data.spectator + data.player
      })

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

  def calculate_hw_fingerprint(data) do
    base = ~w(hardware:cpuinfo hardware:gpuinfo hardware:osinfo hardware:raminfo)
    |> Enum.map(fn hw_key -> Map.get(data, hw_key, "") end)
    |> Enum.join("")

    if base == "" do
      ""
    else
      :crypto.hash(:md5, base)
        |> Base.encode64()
        |> String.trim
    end
  end
end
