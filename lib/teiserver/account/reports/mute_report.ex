defmodule Teiserver.Account.MuteReport do
  alias Teiserver.{Account, User}

  @spec icon() :: String.t()
  def icon(), do: Central.Account.ReportLib.action_icon("Mute")

  @spec run(Plug.Conn.t(), map()) :: {map(), map()}
  def run(_conn, _params) do
    data = Account.list_users(select: [:id], limit: :infinity)
      |> Enum.map(fn %{id: userid} ->
        user = User.get_user_by_id(userid)
        user.ignored
      end)
      |> Enum.filter(fn ignored -> not Enum.empty?(ignored) end)
      |> List.flatten
      |> Enum.group_by(fn userid -> userid end)
      |> Enum.map(fn {userid, ids} -> {User.get_user_by_id(userid), Enum.count(ids)} end)
      |> Enum.sort_by(fn {_, c} -> c end, &<=/2)

    assigns = %{
      params: %{}
    }

    {data, assigns}
  end
end
