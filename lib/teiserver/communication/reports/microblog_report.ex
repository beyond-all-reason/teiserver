defmodule Teiserver.Communication.MicroblogReport do
  @moduledoc false
  alias Teiserver.Microblog

  @spec icon() :: String.t()
  def icon(), do: Teiserver.Microblog.PostLib.icon()

  @spec permissions() :: String.t()
  def permissions(), do: "Server"

  @spec run(Plug.Conn.t(), map()) :: map
  def run(_conn, params) do
    params = default_params(params)

    posts =
      Microblog.list_posts(
        order_by: params["order_by"],
        preload: [:poster]
      )

    %{
      posts: posts,
      params: params
    }
  end

  defp default_params(params) do
    Map.merge(
      %{
        "order_by" => "Newest first"
      },
      params
    )
  end
end
