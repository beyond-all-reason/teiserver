defmodule Central.Logging.LoggingPlug do
  @moduledoc false
  alias Plug.Conn
  alias Central.Logging.PageViewLog
  alias Central.Repo

  @behaviour Plug

  def init(_opts) do
    %{}
  end

  @spec call(Plug.Conn.t(), List.t()) :: Plug.Conn.t()
  def call(conn, _ops) do
    start_tick = :os.system_time(:micro_seconds)

    ip = get_ip_from_conn(conn) || "Error finding IP"

    # conn = Map.put(conn, :remote_ip, ip)
    # new_peer = {ip, conn.peer |> elem(1)}
    # conn = Map.put(conn, :peer, new_peer)

    Conn.register_before_send(conn, fn conn ->
      if conn.status == 500 do
        # log_error(conn)
      else
        log_view(conn, start_tick, ip |> Tuple.to_list() |> Enum.join("."))
      end

      conn
    end)
  end

  @spec convert_from_x_real_ip(String.t()) :: Tuple.t()
  defp convert_from_x_real_ip(ip) do
    ip
    |> String.split(".")
    |> Enum.map(&String.to_integer/1)
    |> List.to_tuple()
  end

  @spec get_user_id(Plug.Conn.t()) :: nil | Integer.t()
  defp get_user_id(conn) do
    if conn.assigns[:current_user] == nil do
      nil
    else
      conn.assigns[:current_user].id
    end
  end

  defp log_view(conn, start_tick, ip) do
    user_id = get_user_id(conn)

    [_, section | path] = String.split(conn.request_path, "/")

    # Log as seconds
    # load_time = (:os.system_time(:micro_seconds) - start_tick)/1000000

    # Log as milli seconds (1/1000th)
    # load_time = (:os.system_time(:micro_seconds) - start_tick)/1000

    # Log as micro seconds
    load_time = :os.system_time(:micro_seconds) - start_tick

    page_log =
      PageViewLog.changeset(%PageViewLog{}, %{
        section: section,
        path: Enum.join(path, "/"),
        method: conn.method,
        ip: ip,
        load_time: load_time,
        user_id: user_id,
        status: conn.status
      })

    if conn.assigns[:do_not_log] == nil do
      Repo.insert!(page_log)
    end
  end

  def get_ip_from_conn(conn) do
    case List.keyfind(conn.req_headers, "x-real-ip", 0) do
      {_, ip} -> convert_from_x_real_ip(ip)
      nil -> conn.remote_ip
      _ -> nil
    end
  end
end
