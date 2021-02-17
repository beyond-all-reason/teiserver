defmodule Central.Logging.LoggingPlug do
  alias Plug.Conn
  alias Central.Logging.PageViewLog
  alias Central.Repo

  @behaviour Plug

  def init(_opts) do
    %{}
  end

  def call(conn, _ops) do
    start_tick = :os.system_time(:micro_seconds)

    ip = case List.keyfind(conn.req_headers, "x-real-ip", 0) do
      {_, ip} -> convert_from_x_real_ip(ip)
      nil     -> conn.remote_ip
      _       -> "Error finding IP"
    end

    # conn = Map.put(conn, :remote_ip, ip)
    # new_peer = {ip, conn.peer |> elem(1)}
    # conn = Map.put(conn, :peer, new_peer)

    Conn.register_before_send(conn, fn conn ->
      if conn.status == 500 do
        # log_error(conn)
      else
        log_view(conn, start_tick, ip |> Tuple.to_list |> Enum.join("."))
      end

      conn
    end)
  end

  defp convert_from_x_real_ip(ip) do
    ip
    |> String.split(".")
    |> Enum.map(&String.to_integer/1)
    |> List.to_tuple()
  end

  defp get_user_id(conn) do
    if conn.assigns[:current_user] == nil do
      nil
    else
      conn.assigns[:current_user].id
    end
  end

  defp log_view(conn, start_tick, ip) do
    user_id = get_user_id(conn)

    [_, section | path] =  String.split(conn.request_path, "/")

    # Log as seconds
    # load_time = (:os.system_time(:micro_seconds) - start_tick)/1000000

    # Log as milli seconds (1/1000th)
    # load_time = (:os.system_time(:micro_seconds) - start_tick)/1000

    # Log as micro seconds
    load_time = (:os.system_time(:micro_seconds) - start_tick)

    page_log = PageViewLog.changeset(%PageViewLog{}, %{
      section: section,
      path: Enum.join(path, "/") || "",
      method: conn.method,
      ip: ip,
      load_time: load_time,
      user_id: user_id,
      status: conn.status,
    })

    if conn.assigns[:do_not_log] == nil do
      the_log = Repo.insert!(page_log)

      if conn.assigns[:current_user] do
        data = %{
          username: conn.assigns[:current_user].name,
          user_id: the_log.user_id,
          path: conn.request_path,
          ip: the_log.ip,
          log_id: the_log.id,
          timestamp: Central.Helpers.TimexHelper.date_to_str(Timex.local(), :hms),
        }

        # Overwatch usage
        CentralWeb.Endpoint.broadcast(
          "overwatch:usage:#{the_log.user_id}",
          "page view",
          data
        )

        CentralWeb.Endpoint.broadcast(
          "overwatch:usage:all",
          "page view",
          data
        )

        # TODO: Have this pick up on party instead?
        # if conn.assigns[:current_user].admin_group_id do
        #   CentralWeb.Endpoint.broadcast(
        #     "event:logging.Page view log:#{conn.assigns[:current_user].admin_group_id}",
        #     "new data",
        #     Map.put(data, :room, "logging.Page view log")
        #   )
        # end
      end
    else
      nil
    end
  end

end