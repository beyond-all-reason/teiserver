defmodule Central.Logging.AggregateViewLogsTaskTest do
  use Central.DataCase, async: true

  alias Central.Logging.AggregateViewLogsTask

  alias Central.Helpers.GeneralTestLib
  alias Central.Logging.LoggingTestLib

  setup do
    GeneralTestLib.data_setup()
    |> LoggingTestLib.logging_setup()
  end

  test "run task" do
    AggregateViewLogsTask.perform(%{})
  end
end
