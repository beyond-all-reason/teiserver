defmodule Central.Logging.Helpers do
  alias Central.Repo
  use Timex

  alias Central.Logging
  alias Central.Logging.ErrorLog

  @spec add_anonymous_audit_log(String.t(), Map.t()) :: Central.Logging.AuditLog.t()
  def add_anonymous_audit_log(action, details) do
    attrs = %{
      user_id: nil,
      action: action,
      details: details,
      ip: "-"
    }

    {:ok, the_log} = Logging.create_audit_log(attrs)

    the_log
  end

  @spec add_anonymous_audit_log(Plug.Conn.t(), String.t(), Map.t()) ::
          Central.Logging.AuditLog.t()
  def add_anonymous_audit_log(conn, action, details) do
    attrs = %{
      user_id: if(conn.assigns[:current_user], do: conn.assigns[:current_user].id, else: nil),
      action: action,
      details: details,
      ip: conn.remote_ip |> Tuple.to_list() |> Enum.join(".")
    }

    {:ok, the_log} = Logging.create_audit_log(attrs)

    the_log
  end

  @spec add_audit_log(Plug.Conn.t(), String.t(), Map.t()) :: Central.Logging.AuditLog.t()
  def add_audit_log(conn, action, details) do
    {:ok, the_log} =
      Logging.create_audit_log(%{
        action: action,
        user_id: conn.assigns[:current_user].id,
        group_id: conn.assigns[:current_user].admin_group_id,
        details: details,
        ip: conn.remote_ip |> Tuple.to_list() |> Enum.join(".")
      })

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
  end
end
