defmodule Central.Logging.AggregateViewLogsTaskTest do
  # , async: true
  use Central.DataCase

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
