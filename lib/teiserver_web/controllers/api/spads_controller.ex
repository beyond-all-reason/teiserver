defmodule TeiserverWeb.API.SpadsController do
  use CentralWeb, :controller
  alias Teiserver.Battle.BalanceLib
  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  # plug(Bodyguard.Plug.Authorize,
  #   policy: Teiserver.Battle.ApiAuth,
  #   action: {Phoenix.Controller, :action_name},
  #   user: {Central.Account.AuthLib, :current_user}
  # )

  @spec get_rating(Plug.Conn.t(), map) :: Plug.Conn.t()
  def get_rating(conn, %{
    "caller_id" => _caller_id_str,
    "target_id" => target_id_str,
    "type" => type
  }) do
    # caller = caller_id_str |> int_parse |> Account.get_user_by_id()
    # target = target_id_str |> int_parse |> Account.get_user_by_id()
    target_id = int_parse(target_id_str)

    rating = BalanceLib.get_user_rating_value(target_id, type)

    conn
      |> put_status(200)
      |> assign(:rating, rating)
      |> render("rating.json")
  end
end
