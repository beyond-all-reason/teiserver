defmodule Teiserver.Player.Types.MessagingState do
  @moduledoc """
  track subscription status for messages to the player
  """

  alias Teiserver.Helpers.BoundedQueue, as: BQ
  alias Teiserver.Messaging

  @enforce_keys [:store_messages?, :subscribed?, :buffer]
  defstruct [:store_messages?, :subscribed?, :buffer]

  @type t :: %__MODULE__{
          store_messages?: boolean(),
          subscribed?: boolean(),
          # for simplicity, only hold one buffer for everything. This may lead to
          # problems if a few sources are really noisy, they will force out
          # the other messages. We can deal with that later with a smaller
          # buffer per source, and the added complexity of having to limit
          # that total size
          buffer: BQ.t(Messaging.message())
        }

  def default do
    %__MODULE__{
      store_messages?: true,
      subscribed?: false,
      # TODO: would be better to have that as a db setting, perhaps passed as an
      # argument to init()
      buffer: BQ.new(200)
    }
  end
end
