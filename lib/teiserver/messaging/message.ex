defmodule Teiserver.Messaging.Message do
  @moduledoc false
  alias Teiserver.Account.User

  @enforce_keys [:content, :source, :timestamp, :marker]
  defstruct [:content, :source, :timestamp, :marker]

  @type entity ::
          {:player, User.id()}
          | {:party, Teiserver.Party.id(), User.id()}
          | {:lobby, Teiserver.TachyonLobby.id(), User.id()}
  @type t :: %__MODULE__{
          content: String.t(),
          source: entity(),
          timestamp: non_neg_integer(),
          marker: term()
        }

  @spec new(String.t(), entity(), non_neg_integer()) :: t()
  def new(content, source, marker) do
    # the content maximum length is enforced at the protocol layer so
    # don't do anything here
    %__MODULE__{
      content: content,
      source: source,
      timestamp: :os.system_time(:micro_seconds),
      marker: marker
    }
  end
end
