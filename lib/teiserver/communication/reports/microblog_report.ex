defmodule Teiserver.Communication.MicroblogReport do
  @moduledoc false

  @spec icon() :: String.t()
  def icon(), do: Teiserver.Microblog.PostLib.icon()

  @spec permissions() :: String.t()
  def permissions(), do: "Reviewer"

  @spec run(Plug.Conn.t(), map()) :: map
  def run(_conn, params) do
    %{
      params: params
    }
  end
end
