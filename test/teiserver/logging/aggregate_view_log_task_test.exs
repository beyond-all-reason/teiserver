defmodule Teiserver.Logging.AggregateViewLogsTaskTest do
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.Logging.AggregateViewLogsTask
  alias Teiserver.Logging.LoggingTestLib

  use Teiserver.DataCase, async: true

  setup do
    GeneralTestLib.data_setup()
    |> LoggingTestLib.logging_setup()
  end

  test "run task" do
    AggregateViewLogsTask.perform(%{})
  end
end
