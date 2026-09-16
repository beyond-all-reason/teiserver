defmodule Teiserver.LoggingFixtures do
  @moduledoc false
  alias Teiserver.AccountFixtures
  alias Teiserver.Logging

  @doc """
  Generate an AuditLog.
  """
  def audit_log_fixture(attrs \\ %{}) do
    {:ok, audit_log} =
      attrs
      |> Enum.into(%{
        action: "test-action",
        ip: "127.0.0.1",
        details: %{},
        user_id: AccountFixtures.user_fixture().id
      })
      |> Logging.create_audit_log()

    audit_log
  end
end
