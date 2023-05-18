defmodule Teiserver.Protocols.V1.TachyonConfigTest do
  alias Teiserver.Config
  alias Teiserver.Account
  use Central.ServerCase

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0, _tachyon_send: 2, _tachyon_recv: 1]

  setup do
    %{socket: socket, user: user, pid: pid} = tachyon_auth_setup()
    {:ok, socket: socket, user: user, pid: pid}
  end

  test "game configs", %{user: user, socket: socket} do
    _tachyon_send(socket, %{
      cmd: "c.config.game_get",
      keys: [
        "key1",
        "key2"
      ]
    })

    [reply] = _tachyon_recv(socket)

    assert reply == %{
             "cmd" => "s.config.game_get",
             "configs" => %{}
           }

    # Now set some
    _tachyon_send(socket, %{
      cmd: "c.config.game_set",
      configs: %{
        "key1" => "Some string",
        "key2" => [1, 2, 3]
      }
    })

    reply = _tachyon_recv(socket)
    assert reply == :timeout

    # Get them again
    _tachyon_send(socket, %{
      cmd: "c.config.game_get",
      keys: [
        "key1",
        "key2",
        "key3"
      ]
    })

    [reply] = _tachyon_recv(socket)

    assert reply == %{
             "cmd" => "s.config.game_get",
             "configs" => %{
               "key1" => "Some string",
               "key2" => [1, 2, 3]
             }
           }

    # Ensure they are stored correctly
    stats = Account.get_user_stat_data(user.id)
    assert not Map.has_key?(stats, "key1")
    assert not Map.has_key?(stats, "key2")
    assert Map.has_key?(stats, "game_config.key1")
    assert Map.has_key?(stats, "game_config.key2")

    # Delete them
    _tachyon_send(socket, %{cmd: "c.config.game_delete", keys: ["key1"]})
    reply = _tachyon_recv(socket)
    assert reply == :timeout

    stats = Account.get_user_stat_data(user.id)
    assert not Map.has_key?(stats, "key1")
    assert not Map.has_key?(stats, "key2")
    assert not Map.has_key?(stats, "game_config.key1")
    assert Map.has_key?(stats, "game_config.key2")
  end

  test "user configs", %{user: user, socket: socket} do
    # List the config types
    configs = Config.list_user_configs(user.id)
    assert configs == []

    _tachyon_send(socket, %{cmd: "c.config.list_user_types"})
    [reply] = _tachyon_recv(socket)

    assert reply["cmd"] == "s.config.list_user_types"
    assert not Enum.empty?(reply["types"])

    flag_type =
      reply["types"]
      |> Enum.filter(fn t -> t["key"] == "teiserver.Show flag" end)
      |> hd

    assert flag_type == %{
             "default" => true,
             "description" =>
               "When checked the flag associated with your IP will be displayed. If unchecked your flag will be blank. This will take effect next time you login with your client.",
             "key" => "teiserver.Show flag",
             "opts" => %{},
             "section" => "Teiserver account",
             "type" => "boolean",
             "value_label" => "Value"
           }

    # Now get one with a default
    _tachyon_send(socket, %{
      cmd: "c.config.user_get",
      keys: [
        # Keys they're allowed
        "general.Colour scheme",
        "teiserver.Show flag",

        # Permission denied
        "general.Rate limit",

        # Non-existent key
        "blah blah blah"
      ]
    })

    [reply] = _tachyon_recv(socket)

    assert reply == %{
             "cmd" => "s.config.user_get",
             "configs" => %{
               "general.Colour scheme" => "Site default",
               "teiserver.Show flag" => true
             }
           }

    # Set values
    _tachyon_send(socket, %{
      cmd: "c.config.user_set",
      configs: %{
        "general.Colour scheme" => "Light",
        "teiserver.Show flag" => false,
        "some other key" => 123
      }
    })

    reply = _tachyon_recv(socket)
    assert reply == :timeout

    # Check they updated
    _tachyon_send(socket, %{
      cmd: "c.config.user_get",
      keys: [
        # Keys they're allowed
        "general.Colour scheme",
        "teiserver.Show flag",

        # Permission denied
        "general.Rate limit",

        # Non-existent key
        "blah blah blah"
      ]
    })

    [reply] = _tachyon_recv(socket)

    assert reply == %{
             "cmd" => "s.config.user_get",
             "configs" => %{
               "general.Colour scheme" => "Light",
               "teiserver.Show flag" => false
             }
           }
  end
end
