defmodule Teiserver.Logging.Helpers do
  @moduledoc false
  use Timex
  alias Teiserver.Logging

  @spec add_anonymous_audit_log(String.t(), Map.t()) :: Teiserver.Logging.AuditLog.t()
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

  @spec add_audit_log(Plug.Conn.t(), String.t(), Map.t()) :: Teiserver.Logging.AuditLog.t()
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

  @spec add_audit_log(non_neg_integer(), String.t(), String.t(), Map.t()) ::
          Teiserver.Logging.AuditLog.t()
  def add_audit_log(userid, ip, action, details) when is_integer(userid) do
    {:ok, the_log} =
      Logging.create_audit_log(%{
        action: action,
        user_id: userid,
        group_id: nil,
        details: details,
        ip: ip
      })

    the_log
  end
end
