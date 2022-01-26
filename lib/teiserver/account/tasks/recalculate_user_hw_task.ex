defmodule Teiserver.Account.RecalculateUserHWTask do
  use Oban.Worker, queue: :cleanup

  alias Teiserver.{Account, Telemetry, User}

  # Teiserver.Account.RecalculateUserHWTask.perform(%{})

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    Telemetry.list_server_day_logs(limit: :infinity)
    |> Enum.map(fn log ->
      Map.keys(log.data["minutes_per_user"]["total"])
    end)
    |> List.flatten
    |> Enum.uniq
    |> Enum.filter(fn userid_str ->
      username = User.get_username(userid_str)
      username != nil
    end)
    |> Enum.each(fn userid_str ->
      userid = String.to_integer(userid_str)
      hw_fingerprint = Account.get_user_stat_data(userid)
      |> calculate_hw_fingerprint()

      Account.update_user_stat(userid, %{
        hw_fingerprint: hw_fingerprint,
      })

      user = User.get_user_by_id(userid)
      User.update_user(%{user | hw_hash: hw_fingerprint}, persist: true)
    end)

    :ok
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
