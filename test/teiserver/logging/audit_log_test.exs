defmodule Teiserver.Logging.AuditLogTests do
  alias Teiserver.Logging
  alias Teiserver.Logging.AuditLog
  alias Teiserver.Logging.AuditLogLib

  use Teiserver.DataCase, async: false

  test "add audit log" do
    {:ok, %AuditLog{}} =
      Logging.create_audit_log(%{
        action: "test-action",
        user_id: nil,
        details: %{foo: "test details"},
        ip: "123.123.123.123"
      })
  end

  test "list distinct action types" do
    actions = ["test-action1", "test-action2"]

    Enum.with_index(actions ++ actions)
    |> Enum.each(fn {action, idx} ->
      {:ok, _log} =
        Logging.create_audit_log(%{
          action: action,
          user_id: nil,
          details: %{idx: idx},
          ip: "123.123.123.123"
        })
    end)

    got = AuditLogLib.list_audit_types() |> Enum.sort()
    assert got == actions
  end
end
