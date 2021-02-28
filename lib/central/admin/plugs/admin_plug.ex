defmodule Central.Admin.AdminPlug do
  # alias Plug.Conn
  # alias Central.Logging.ErrorLogLib
  # alias Central.Repo

  # import Central.Account.AuthLib, only: [allow?: 2]
  import Plug.Conn, only: [assign: 3]

  @behaviour Plug

  def init(_) do
  end

  def call(conn, _ops) do
    conn
    |> assign(:error_log_count, 0)

    # TODO: Implement this correctly

    # cond do
    #   conn.assigns[:current_user] == nil -> conn
    #   allow?(conn, "admin.dev.developer") == false -> conn
    #   true ->
    #     conn
    #     |> assign(:centaur_error_count, ErrorLogLib.get_error_log_count())
    # end
  end
end
