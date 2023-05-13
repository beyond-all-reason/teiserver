defmodule Teiserver.Account.MuteReport do
  @moduledoc false
  alias Teiserver.{Account, User}
  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-microphone-slash"

  @spec permissions() :: String.t()
  def permissions(), do: "Reviewer"

  @spec run(Plug.Conn.t(), map()) :: {list(), map()}
  def run(_conn, params) do
    params = apply_defaults(params)

    searches =
      if params["exclude_banned"] == "true" do
        [mod_action: "Not banned"]
      else
        []
      end

    days = int_parse(params["days"])

    start_date =
      Timex.now()
      |> Timex.shift(days: -days)
      |> Timex.to_unix()

    start_date = round(start_date / 60)

    x_ignores_y =
      Account.list_users(
        search:
          [
            data_not: {"ignored", "[]"},
            data_greater_than: {"last_login", to_string(start_date)}
          ] ++ searches,
        select: [:id, :data],
        limit: :infinity
      )
      |> Enum.map(fn %{id: userid, data: data} ->
        {userid, data["ignored"]}
      end)
      |> Enum.filter(fn {_userid, ignores} ->
        not Enum.empty?(ignores)
      end)
      |> Enum.map(fn {userid, ignores} ->
        ignores
        |> Enum.map(fn ignored -> {userid, ignored} end)
      end)
      |> List.flatten()
      |> Enum.reject(fn {userid1, userid2} ->
        user1 = Account.get_user_by_id(userid1)
        user2 = Account.get_user_by_id(userid2)

        cond do
          params["exclude_banned"] == "true" and User.is_restricted?(user1, ["Login"]) -> true
          params["exclude_banned"] == "true" and User.is_restricted?(user2, ["Login"]) -> true
          user1.last_login < start_date -> true
          user2.last_login < start_date -> true
          true -> false
        end
      end)

    usernames =
      x_ignores_y
      |> Enum.map(fn {x, y} -> [x, y] end)
      |> List.flatten()
      |> Enum.uniq()
      |> Map.new(fn userid -> {userid, User.get_username(userid)} end)

    ignored_by_lists =
      x_ignores_y
      |> Enum.group_by(
        fn {_, y} ->
          y
        end,
        fn {x, _} ->
          x
        end
      )

    data =
      x_ignores_y
      |> Enum.map(fn {_, ignored} -> ignored end)
      |> Enum.group_by(fn userid -> userid end)
      |> Enum.map(fn {userid, ids} -> {userid, Enum.count(ids)} end)
      |> Enum.sort_by(fn {_, c} -> c end, &>=/2)

    assigns = %{
      ignored_by_lists: ignored_by_lists,
      usernames: usernames,
      params: params
    }

    {data, assigns}
  end

  defp apply_defaults(params) do
    Map.merge(
      %{
        "exclude_banned" => "true",
        "days" => "31"
      },
      Map.get(params, "report", %{})
    )
  end
end
