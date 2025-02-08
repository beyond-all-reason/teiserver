defmodule Teiserver.Messaging do
  alias Teiserver.Messaging.Message

  @type message :: Message.t()
  @type entity :: Message.entity()

  @spec send(message(), entity()) :: :ok | {:error, :invalid_recipient}
  def send(_message, _recipient) do
    :ok
  end
end
