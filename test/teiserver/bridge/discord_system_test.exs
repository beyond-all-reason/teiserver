defmodule Teiserver.Bridge.DiscordSystemTest do
  alias Nostrum.Util
  alias Teiserver.Bridge.DiscordSystem

  use ExUnit.Case, async: false

  setup do
    teiserver_env = Application.get_env(:teiserver, Teiserver)
    nostrum_token = Application.get_env(:nostrum, :token)

    on_exit(fn ->
      Application.put_env(:teiserver, Teiserver, teiserver_env)

      if is_nil(nostrum_token),
        do: Application.delete_env(:nostrum, :token),
        else: Application.put_env(:nostrum, :token, nostrum_token)
    end)

    :ok
  end

  defp set_bridge(enabled) do
    env =
      Application.get_env(:teiserver, Teiserver) |> Keyword.put(:enable_discord_bridge, enabled)

    Application.put_env(:teiserver, Teiserver, env)
  end

  test "does nothing when the bridge is disabled" do
    set_bridge(false)
    assert DiscordSystem.start() == :disabled
  end

  test "reports a missing token without starting the bot" do
    set_bridge(true)
    Application.delete_env(:nostrum, :token)

    assert {:error, {:invalid_token, message}} = DiscordSystem.start()
    assert message =~ "bot token needs to be supplied"
  end

  test "reports a malformed token without starting the bot" do
    set_bridge(true)
    Application.put_env(:nostrum, :token, "not-a-token")

    assert {:error, {:invalid_token, message}} = DiscordSystem.start()
    assert message =~ "Invalid token format"
  end

  describe "start_error_message/1" do
    test "explains a missing or malformed token" do
      assert DiscordSystem.start_error_message({:invalid_token, "oops"}) =~
               "missing or malformed: oops"
    end

    test "recognises a token rejected by Discord" do
      # shape of the real error returned by start_child when Discord answers 401
      reason =
        {:shutdown,
         {:failed_to_start_child, Nostrum.Application,
          {:shutdown,
           {:failed_to_start_child, Nostrum.Shard.Supervisor,
            {:EXIT, {%RuntimeError{message: "Authentication rejected, invalid token"}, []}}}}}}

      assert DiscordSystem.start_error_message(reason) =~ "Discord rejected"
    end

    test "falls back to the raw reason for other failures" do
      assert DiscordSystem.start_error_message(:boom) ==
               "Failed to start Discord bridge: :boom"
    end
  end

  test "nostrum still raises the error text we use to recognise a rejected token" do
    # start_error_message/1 matches on this text, if a nostrum upgrade changes it
    # this fails and the matching needs to be updated.
    # TODO: remove this test together with the text matching once
    # https://github.com/Kraigie/nostrum/pull/736 is released and we upgrade.
    source = :compile |> Util.module_info() |> Keyword.fetch!(:source) |> to_string()
    assert File.read!(source) =~ "Authentication rejected"
  end
end
