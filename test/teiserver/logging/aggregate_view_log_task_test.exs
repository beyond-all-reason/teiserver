defmodule Barserver.Logging.AggregateViewLogsTaskTest do
  use Barserver.DataCase, async: true

  alias Barserver.Logging.AggregateViewLogsTask

  alias Central.Helpers.GeneralTestLib
  alias Barserver.Logging.LoggingTestLib

  setup do
    GeneralTestLib.data_setup()
    |> LoggingTestLib.logging_setup()
  end

  test "run task" do
    AggregateViewLogsTask.perform(%{})
  end
end
