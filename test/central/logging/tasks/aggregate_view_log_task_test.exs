defmodule Teiserver.Logging.AggregateViewLogsTaskTest do
  use Teiserver.DataCase, async: true

  alias Teiserver.Logging.AggregateViewLogsTask

  alias Central.Helpers.GeneralTestLib
  alias Teiserver.Logging.LoggingTestLib

  setup do
    GeneralTestLib.data_setup()
    |> LoggingTestLib.logging_setup()
  end

  test "run task" do
    AggregateViewLogsTask.perform(%{})
  end
end
