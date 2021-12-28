defmodule Teiserver.Account.AccoladeChatServer do
  @moduledoc """
  Each chat server is for a specific user, when the chat server has done it's job it self-terminates.
  """

  use GenServer
  alias Teiserver.{User}
  alias Teiserver.Account.AccoladeLib
  alias Teiserver.Data.Types, as: T

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  @spec empty_state(T.userid()) :: map()
  def empty_state(_userid) do
    %{
      accolade_bot_id: AccoladeLib.get_accolade_bot_userid()
    }
  end

  # Doesn't do anything at this stage
  def handle_info(:startup, state) do
    {:noreply, state}
  end

  def terminate(_reason, state) do
    ConCache.delete(:teiserver_accolade_pids, state.userid)
  end

  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(opts) do
    userid = opts[:userid]

    # Update the queue pids cache to point to this process
    ConCache.put(:teiserver_accolade_pids, userid, self())
    :timer.send_interval(10_000, :tick)
    send(self(), :startup)
    {:ok, empty_state(userid)}
  end
end
