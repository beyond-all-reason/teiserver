defmodule TeiserverWeb.LoggerFilterTest do
  alias TeiserverWeb.LoggerFilter

  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  # The format string and args list cowboy_stream_h actually emits when a
  # request process exits abnormally (see deps/cowboy/src/cowboy_stream_h.erl).
  @cowboy_format ~c"Ranch listener ~p, connection process ~p, stream ~p had its request process ~p exit with reason ~0p~n"

  defp not_authorized_error,
    do: %Bodyguard.NotAuthorizedError{
      message: "not authorized",
      status: 403,
      reason: {:error, :unauthorized}
    }

  defp cowboy_args(reason), do: [:listener_ref, self(), 1, self(), reason]

  describe "drop_bodyguard_not_authorized/2 — error_logger report shape (cowboy default path)" do
    test "drops the report whose 5th arg is a reason carrying the error" do
      err = not_authorized_error()
      reason = {{err, [{SomeMod, :call, 1, []}]}, {TeiserverWeb.Endpoint, :call, [:conn]}}

      event = %{
        level: :error,
        msg:
          {:report,
           %{
             label: {:error_logger, :error_msg},
             format: @cowboy_format,
             args: cowboy_args(reason)
           }}
      }

      assert :stop = LoggerFilter.drop_bodyguard_not_authorized(event, [])
    end

    test "drops when the error is nested deeper in the reason term" do
      err = not_authorized_error()
      reason = [:a, [:b, [{:nested, [err]}]], :c]

      event = %{
        level: :error,
        msg:
          {:report,
           %{
             label: {:error_logger, :error_msg},
             format: @cowboy_format,
             args: cowboy_args(reason)
           }}
      }

      assert :stop = LoggerFilter.drop_bodyguard_not_authorized(event, [])
    end

    test "ignores reports whose reason is a different exception" do
      reason = {{%RuntimeError{message: "boom"}, []}, {Mod, :call, []}}

      event = %{
        level: :error,
        msg:
          {:report,
           %{
             label: {:error_logger, :error_msg},
             format: @cowboy_format,
             args: cowboy_args(reason)
           }}
      }

      assert :ignore = LoggerFilter.drop_bodyguard_not_authorized(event, [])
    end

    test "ignores reports whose format does not contain cowboy's signature" do
      err = not_authorized_error()
      reason = {{err, []}, {Mod, :call, []}}

      event = %{
        level: :error,
        msg:
          {:report,
           %{
             label: {:error_logger, :error_msg},
             format: ~c"some unrelated library log: ~p~n",
             args: cowboy_args(reason)
           }}
      }

      assert :ignore = LoggerFilter.drop_bodyguard_not_authorized(event, [])
    end

    test "ignores reports whose label is not error_logger error_msg" do
      err = not_authorized_error()
      reason = {{err, []}, {Mod, :call, []}}

      event = %{
        level: :error,
        msg: {:report, %{reason: reason, format: @cowboy_format, args: cowboy_args(reason)}}
      }

      assert :ignore = LoggerFilter.drop_bodyguard_not_authorized(event, [])
    end

    test "ignores reports with an args list whose length is not 5" do
      err = not_authorized_error()
      reason = {{err, []}, {Mod, :call, []}}

      event = %{
        level: :error,
        msg:
          {:report,
           %{
             label: {:error_logger, :error_msg},
             format: @cowboy_format,
             args: [:only, :three, reason]
           }}
      }

      assert :ignore = LoggerFilter.drop_bodyguard_not_authorized(event, [])
    end

    test "ignores reports at non-error levels" do
      err = not_authorized_error()
      reason = {{err, []}, {Mod, :call, []}}

      event = %{
        level: :warning,
        msg:
          {:report,
           %{
             label: {:error_logger, :error_msg},
             format: @cowboy_format,
             args: cowboy_args(reason)
           }}
      }

      assert :ignore = LoggerFilter.drop_bodyguard_not_authorized(event, [])
    end
  end

  describe "drop_bodyguard_not_authorized/2 — direct {format, args} shape" do
    test "drops the cowboy format+args event whose exit reason carries the error" do
      err = not_authorized_error()
      reason = {{err, []}, {TeiserverWeb.Endpoint, :call, [:conn]}}
      event = %{level: :error, msg: {@cowboy_format, cowboy_args(reason)}}

      assert :stop = LoggerFilter.drop_bodyguard_not_authorized(event, [])
    end

    test "ignores non-cowboy format+args events even when args contain the error" do
      err = not_authorized_error()
      args = [:something, err, :else, :pad, :pad]
      event = %{level: :error, msg: {~c"some other library log: ~p", args}}

      assert :ignore = LoggerFilter.drop_bodyguard_not_authorized(event, [])
    end
  end

  describe "drop_bodyguard_not_authorized/2 — malformed input" do
    test "ignores malformed events without crashing" do
      assert :ignore = LoggerFilter.drop_bodyguard_not_authorized(%{msg: nil}, [])
      assert :ignore = LoggerFilter.drop_bodyguard_not_authorized(%{}, [])
    end
  end

  describe "registered as :logger primary filter" do
    test "filter is installed by Teiserver.Application.start/2" do
      names =
        :logger.get_primary_config().filters
        |> Enum.map(fn {name, _filter} -> name end)

      assert :teiserver_bodyguard_not_authorized in names
    end

    test "real cowboy path via :error_logger.error_msg/2 is suppressed end-to-end" do
      err = not_authorized_error()
      reason = {{err, []}, {TeiserverWeb.Endpoint, :call, [:conn]}}

      log =
        capture_log(fn ->
          # Mirrors what cowboy.erl line 228 does by default: cowboy:log/4 falls
          # back to error_logger:error_msg/2 because Plug.Cowboy does not set the
          # `logger` protocol option.
          :error_logger.error_msg(@cowboy_format, cowboy_args(reason))
        end)

      refute log =~ "Bodyguard.NotAuthorizedError"
    end

    test "unrelated cowboy-shaped error_logger reports still flow through" do
      reason = {{%RuntimeError{message: "boom"}, []}, {Mod, :call, []}}

      log =
        capture_log(fn ->
          :error_logger.error_msg(@cowboy_format, cowboy_args(reason))
        end)

      assert log =~ "RuntimeError"
    end
  end
end
