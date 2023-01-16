defmodule Teiserver.Account.MuteReport do
  @moduledoc false
  alias Teiserver.{Account, User}

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-microphone-slash"

  @spec permissions() :: String.t()
  def permissions(), do: "teiserver.staff.reviewer"

  @spec run(Plug.Conn.t(), map()) :: {list(), map()}
  def run(_conn, _params) do
    x_ignores_y = Account.list_users(
      search: [
        data_not: {"ignored", "[]"},
      ],
      select: [:id, :data],
      limit: :infinity
    )
      |> Enum.map(fn %{id: userid, data: data} ->
        {userid, data["ignored"]}
      end)
      |> Enum.filter(fn {_, ignores} -> not Enum.empty?(ignores) end)
      |> Enum.map(fn {userid, ignores} ->
        ignores
        |> Enum.map(fn ignored -> {userid, ignored} end)
      end)
      |> List.flatten

    usernames = x_ignores_y
      |> Enum.map(fn {x, y} -> [x, y] end)
      |> List.flatten
      |> Enum.uniq
      |> Map.new(fn userid -> {userid, User.get_username(userid)} end)

    ignored_by_lists = x_ignores_y
      |> Enum.group_by(fn {_, y} ->
        y
      end, fn {x, _} ->
        x
      end)

    data = x_ignores_y
      |> Enum.map(fn {_, ignored} -> ignored end)
      |> Enum.group_by(fn userid -> userid end)
      |> Enum.map(fn {userid, ids} -> {userid, Enum.count(ids)} end)
      |> Enum.sort_by(fn {_, c} -> c end, &>=/2)

    assigns = %{
      ignored_by_lists: ignored_by_lists,
      usernames: usernames,
      params: %{}
    }

    {data, assigns}
  end
end
