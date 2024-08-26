defmodule Teiserver.Support.Tachyon do
  alias WebsocketSyncClient, as: WSC
  alias Teiserver.OAuthFixtures

  @doc """
  connects the given user and returns the ws client
  """
  def connect(user) do
    %{token: token} = OAuthFixtures.setup_token(user)

    opts = connect_options(token)

    {:ok, client} = WSC.connect(tachyon_url(), opts)
    %{client: client, token: token}
  end

  def connect_options(token) do
    [
      connection_options: [
        extra_headers: [
          {"authorization", "Bearer #{token.value}"},
          {"sec-websocket-protocol", "v0.tachyon"}
        ]
      ]
    ]
  end

  def tachyon_url() do
    conf = Application.get_env(:teiserver, TeiserverWeb.Endpoint)
    "ws://#{conf[:url][:host]}:#{conf[:http][:port]}/tachyon"
  end

  @doc """
  Run the given function `f` until `pred` returns true on its result.
  Waits `wait` ms between each tries. Raise an error if `pred` returns false
  after `limit` attempts.

  This is often required due to the nature of eventually consistent state and
  lack of control over the beam scheduler.
  """
  @spec poll_until(function(), function(), limit: non_neg_integer(), wait: non_neg_integer()) ::
          term()
  def poll_until(f, pred, opts \\ []) do
    res = f.()

    if pred.(res) do
      res
    else
      limit = Keyword.get(opts, :limit, 10)

      if limit <= 0 do
        raise "poll timeout"
      end

      wait = Keyword.get(opts, :wait, 1)
      :timer.sleep(wait)
      poll_until(f, pred, limit: limit - 1, wait: wait)
    end
  end

  @doc """
  convenience function to poll until f returns a not_nil value
  """
  def poll_until_some(f, opts \\ []) do
    poll_until(f, fn x -> not is_nil(x) end, opts)
  end
end
