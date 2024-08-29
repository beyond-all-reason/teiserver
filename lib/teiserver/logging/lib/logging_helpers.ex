defmodule Teiserver.Logging.Helpers do
  @moduledoc false
  use Timex
  alias Teiserver.Logging

  @spec add_anonymous_audit_log(String.t(), map()) :: Teiserver.Logging.AuditLog.t()
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

  @spec add_anonymous_audit_log(Plug.Conn.t(), String.t(), map()) ::
          Teiserver.Logging.AuditLog.t()
  def add_anonymous_audit_log(conn, action, details) do
    attrs = %{
      action: action,
      user_id: if(conn.assigns[:current_user], do: conn.assigns[:current_user].id, else: nil),
      details: details,
      ip: conn.remote_ip |> Tuple.to_list() |> Enum.join(".")
    }

    {:ok, the_log} = Logging.create_audit_log(attrs)

    the_log
  end

  @spec add_audit_log(Plug.Conn.t() | Phoenix.LiveView.Socket.t(), String.t(), map()) ::
          Teiserver.Logging.AuditLog.t()
  def add_audit_log(%Phoenix.LiveView.Socket{} = socket, action, details) do
    {:ok, the_log} =
      Logging.create_audit_log(%{
        action: action,
        user_id:
          if(socket.assigns[:current_user], do: socket.assigns[:current_user].id, else: nil),
        details: details,
        ip: "."
      })

    the_log
  end

  def add_audit_log(conn, action, details) do
    {:ok, the_log} =
      Logging.create_audit_log(%{
        action: action,
        user_id: if(conn.assigns[:current_user], do: conn.assigns[:current_user].id, else: nil),
        details: details,
        ip: conn.remote_ip |> Tuple.to_list() |> Enum.join(".")
      })

    the_log
  end

  @spec add_audit_log(nil | non_neg_integer(), nil | String.t(), String.t(), map()) ::
          Teiserver.Logging.AuditLog.t()
  def add_audit_log(userid, ip, action, details) when is_integer(userid) do
    {:ok, the_log} =
      Logging.create_audit_log(%{
        action: action,
        user_id: userid,
        details: details,
        ip: ip
      })

    the_log
  end

  def add_audit_log(nil, ip, action, details) do
    {:ok, the_log} =
      Logging.create_audit_log(%{
        action: action,
        details: details,
        ip: ip
      })

    the_log
  end
end
