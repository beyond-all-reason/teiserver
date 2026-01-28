defmodule Teiserver.Logging.SafeLoggerTest do
  @moduledoc """
  Tests for the SafeLogger module.

  Note: Full sanitization logic is not yet implemented. These tests verify
  the basic interface is working correctly.
  """
  use ExUnit.Case, async: true

  alias Teiserver.Logging.SafeLogger

  describe "sanitize/1" do
    test "returns strings unchanged (sanitization not yet implemented)" do
      input = "some log message"
      assert SafeLogger.sanitize(input) == input
    end

    test "returns maps unchanged (sanitization not yet implemented)" do
      input = %{"key" => "value"}
      assert SafeLogger.sanitize(input) == input
    end

    test "returns other types unchanged" do
      assert SafeLogger.sanitize(123) == 123
      assert SafeLogger.sanitize(:atom) == :atom
      assert SafeLogger.sanitize(nil) == nil
    end
  end
end
