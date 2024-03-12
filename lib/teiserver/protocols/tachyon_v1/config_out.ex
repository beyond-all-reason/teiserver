defmodule Barserver.Protocols.Tachyon.V1.ConfigOut do
  alias Barserver.Protocols.Tachyon.V1.Tachyon
  require Logger

  @spec do_reply(atom(), any) :: Map.t()

  ###########
  # Game configs
  def do_reply(:game_get, configs) do
    %{
      "cmd" => "s.config.game_get",
      "configs" => configs
    }
  end

  ###########
  # User configs
  def do_reply(:list_user_types, types) do
    %{
      "cmd" => "s.config.list_user_types",
      "types" =>
        types
        |> Enum.map(fn type -> Tachyon.convert_object(type, :user_config_type) end)
    }
  end

  def do_reply(:user_get, configs) do
    %{
      "cmd" => "s.config.user_get",
      "configs" => configs
    }
  end
end
