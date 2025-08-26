defmodule Teiserver.Account.VerifiedReport do
  alias Teiserver.Helper.DatePresets
  alias Teiserver.Account

  @spec icon() :: String.t()
  def icon(), do: "fa-solid fa-check"

  @spec permissions() :: String.t()
  def permissions(), do: "Admin"

  @spec run(Plug.Conn.t(), map()) :: {map(), map()}
  def run(_conn, params) do
    params = apply_defaults(params)

    # Date range
    {start_date, _end_date} =
      DatePresets.parse(
        params["date_preset"],
        params["start_date"],
        params["end_date"]
      )

    start_date = Timex.to_datetime(start_date)

    data =
      Account.list_users(
        search: [
          inserted_after: start_date
        ],
        limit: :infinity
      )
      |> Enum.group_by(
        fn user ->
          cond do
            user.last_login == nil -> :never_logged_in
            Enum.member?(user.roles, "Verified") == false -> :unverified
            true -> :verified
          end
        end,
        fn user ->
          user.id
        end
      )
      |> Map.new(fn {k, v} -> {k, Enum.count(v)} end)

    total =
      data
      |> Enum.reduce(0, fn {_, count}, acc ->
        acc + count
      end)

    assigns = %{
      params: params,
      presets: DatePresets.short_ranges()
    }

    {%{
       rows: data,
       total: total
     }, assigns}
  end

  defp apply_defaults(params) do
    Map.merge(
      %{
        "date_preset" => "This month",
        "start_date" => "",
        "end_date" => ""
      },
      Map.get(params, "report", %{})
    )
  end
end
