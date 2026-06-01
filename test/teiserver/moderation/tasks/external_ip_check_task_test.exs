defmodule Teiserver.Moderation.Tasks.ExternalIpCheckTaskTest do
  alias Req.Response
  alias Teiserver.Config
  alias Teiserver.Moderation.Tasks.ExternalIPCheckTask

  use Teiserver.DataCase, async: false

  import ExUnit.CaptureLog
  import Mock

  describe "external IP check query" do
    setup [:setup_for_mock]

    test "calls when enabled" do
      with_mock(Req,
        get: fn "endpoint", [params: [q: q, key: _key]] ->
          case q do
            "happy" ->
              {:ok, %Response{body: %{"is_vpn" => false}}}

            "unhappy" ->
              {:ok, %Response{body: %{"is_vpn" => true}}}

            "wrong_type" ->
              {:ok, %Response{body: %{"is_vpn" => 3}}}

            "empty" ->
              {:ok, %Response{body: %{}}}

            "error" ->
              {:error, "Some error"}
          end
        end
      ) do
        assert ExternalIPCheckTask.query_ip("happy") == []
        assert ExternalIPCheckTask.query_ip("unhappy") == [:is_vpn]

        # When the wrong type we skip the value because we test for
        # `true` rather than truthy
        assert ExternalIPCheckTask.query_ip("wrong_type") == []
        assert ExternalIPCheckTask.query_ip("empty") == []

        # We expect this to generate an error log and return an empty list
        {result, log} =
          with_log(fn ->
            ExternalIPCheckTask.query_ip("error")
          end)

        assert result == []
        assert log =~ "[error] Failed to lookup ip error - \"Some error\""
      end
    end

    test "does not call when disabled" do
      Config.update_site_config("teiserver.External IP check enabled", false)
      assert ExternalIPCheckTask.query_ip("192.0.1.168") == [:not_enabled]
    end

    test "does not call when key or endpoint are missing" do
      # Enable the check itself
      Config.update_site_config("teiserver.External IP check enabled", true)

      # Endpoint but no key
      Config.delete_site_config("teiserver.External IP check key")
      Config.update_site_config("teiserver.External IP check endpoint", "123")
      assert ExternalIPCheckTask.query_ip("192.0.1.168") == [:not_configured]

      # Key but no endpoint
      Config.update_site_config("teiserver.External IP check endpoint", "123")
      Config.delete_site_config("teiserver.External IP check key")
      assert ExternalIPCheckTask.query_ip("192.0.1.168") == [:not_configured]
    end
  end

  defp setup_for_mock(_state) do
    Config.update_site_config("teiserver.External IP check enabled", true)
    Config.update_site_config("teiserver.External IP check key", "key")
    Config.update_site_config("teiserver.External IP check endpoint", "endpoint")
  end
end
