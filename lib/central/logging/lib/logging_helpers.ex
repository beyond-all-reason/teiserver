defmodule Central.Logging.Helpers do
  alias Central.Repo
  use Timex

  alias Central.Logging
  alias Central.Logging.ErrorLog
  alias Central.Helpers.TimexHelper

  def add_anonymous_audit_log(conn, action, details) do
    attrs = %{
      user_id: 1,
      action: action,
      details: details,
      ip: conn.remote_ip |> Tuple.to_list() |> Enum.join(".")
    }

    {:ok, the_log} = Logging.create_audit_log(attrs)

    the_log
  end

  def add_audit_log(conn, action, details) do
    {:ok, the_log} =
      Logging.create_audit_log(%{
        action: action,
        user_id: conn.assigns[:current_user].id,
        group_id: conn.assigns[:current_user].admin_group_id,
        details: details,
        ip: conn.remote_ip |> Tuple.to_list() |> Enum.join(".")
      })

    # data = %{
    #   username: conn.assigns[:current_user].name,
    #   user_id: the_log.user_id,
    #   path: conn.request_path,
    #   ip: the_log.ip,
    #   log_id: the_log.id,
    #   group_id: group_id,
    #   action: action,
    #   details: details,
    #   timestamp: TimexHelper.date_to_str(Timex.local(), :hms),
    # }

    # Overwatch usage
    # CentralWeb.Endpoint.broadcast(
    #   "overwatch:usage:#{the_log.user_id}",
    #   "audit log",
    #   data
    # )

    # CentralWeb.Endpoint.broadcast(
    #   "overwatch:usage:all",
    #   "audit log",
    #   data
    # )

    the_log
  end

  def add_error_log(error) do
    conn = error.conn

    user_id = (conn.assigns[:current_user] || %{id: nil}).id

    traceback =
      try do
        error.stack
        |> Enum.map(fn {module, function, arity, kwlist} ->
          "#{kwlist[:file]}:#{kwlist[:line]}: #{module}.#{function}/#{arity}"
        end)
        |> Enum.join("\n")
      catch
        :error, _e ->
          "Error converting traceback #{error.stack |> Kernel.inspect() |> String.slice(0, 4096)}"
      end

    params =
      conn.params
      |> Enum.map(fn {k, v} ->
        {k, v |> Kernel.inspect() |> String.slice(0, 4096)}
      end)
      |> Map.new()

    the_log =
      ErrorLog.changeset(%ErrorLog{}, %{
        path: conn.request_path,
        method: conn.method,
        reason: error.reason |> Kernel.inspect() |> String.replace("\\n", "\n"),
        traceback: traceback,
        hidden: false,
        data: %{
          "params" => params
          # "cache" => conn.assigns.cache
        },
        user_id: user_id
      })
      |> Repo.insert!()

    data = %{
      username: "Error log does not have username",
      user_id: the_log.user_id,
      path: conn.request_path,
      ip: conn.remote_ip |> Tuple.to_list() |> Enum.join("."),
      log_id: the_log.id,
      timestamp: TimexHelper.date_to_str(Timex.local(), :hms)
    }

    # Overwatch usage
    CentralWeb.Endpoint.broadcast(
      "overwatch:usage:#{the_log.user_id}",
      "error log",
      data
    )

    CentralWeb.Endpoint.broadcast(
      "overwatch:usage:all",
      "error log",
      data
    )

    the_log
  end
end
