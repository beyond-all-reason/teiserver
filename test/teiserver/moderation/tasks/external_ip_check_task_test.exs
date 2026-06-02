defmodule Teiserver.Moderation.Tasks.ExternalIpCheckTaskTest do
  alias ExUnit.Callbacks

  alias Teiserver.Config
  alias Teiserver.IpCheck.Stub
  alias Teiserver.Moderation.Tasks.ExternalIPCheckTask

  use Teiserver.DataCase, async: false

  describe "return ban reason when config enabled" do
    test "abuser" do
      setup_config("teiserver.external_ip_ban_is_abuser", true)
      assert ExternalIPCheckTask.get_ban_reasons(Stub.abuser_ip()) == [:is_abuser]
    end

    test "bogon" do
      setup_config("teiserver.external_ip_ban_is_bogon", true)
      assert ExternalIPCheckTask.get_ban_reasons(Stub.bogon_ip()) == [:is_bogon]
    end

    test "crawler" do
      setup_config("teiserver.external_ip_ban_is_crawler", true)
      assert ExternalIPCheckTask.get_ban_reasons(Stub.crawler_ip()) == [:is_crawler]
    end

    test "datacenter" do
      setup_config("teiserver.external_ip_ban_is_datacenter", true)
      assert ExternalIPCheckTask.get_ban_reasons(Stub.datacenter_ip()) == [:is_datacenter]
    end

    test "proxy" do
      setup_config("teiserver.external_ip_ban_is_proxy", true)
      assert ExternalIPCheckTask.get_ban_reasons(Stub.proxy_ip()) == [:is_proxy]
    end

    test "tor" do
      setup_config("teiserver.external_ip_ban_is_tor", true)
      assert ExternalIPCheckTask.get_ban_reasons(Stub.tor_ip()) == [:is_tor]
    end

    test "vpn" do
      setup_config("teiserver.external_ip_ban_is_vpn", true)
      assert ExternalIPCheckTask.get_ban_reasons(Stub.vpn_ip()) == [:is_vpn]
    end
  end

  test "ignore result if config disabled" do
    setup_config("teiserver.external_ip_ban_is_vpn", false)
    assert ExternalIPCheckTask.get_ban_reasons(Stub.vpn_ip()) == []
  end

  test "doesn't raise on error" do
    assert ExternalIPCheckTask.get_ban_reasons(Stub.error_ip()) == []
  end

  defp setup_config(key, value) do
    original_value = Config.get_site_config_cache(key)
    Config.update_site_config(key, value)
    Callbacks.on_exit(fn -> Config.update_site_config(key, original_value) end)
  end
end
