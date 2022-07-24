defmodule Teiserver.Account.WinnersReport do
  alias Teiserver.{Account, User}

  @spec icon() :: String.t()
  def icon(), do: "fa-solid fa-trophy"

  @spec permissions() :: String.t()
  def permissions(), do: "teiserver.staff.moderator"

  @spec run(Plug.Conn.t(), map()) :: {list(), map()}
  def run(_conn, _params) do
    recent_players = []


    data = []

    assigns = %{
      params: %{}
    }

    {data, assigns}
  end
end
