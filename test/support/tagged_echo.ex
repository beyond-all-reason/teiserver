defmodule Teiserver.Support.TaggedEcho do
  @moduledoc """
  Simple process that forward all received messages to another process
  wrapped in a tuple {tag, message}
  This is useful to disambiguate messages in a test process
  """

  alias ExUnit.Callbacks

  def start(tag, forward_to \\ self()) do
    Supervisor.child_spec({Task, fn -> loop(tag, forward_to) end}, id: {__MODULE__, tag})
    |> Callbacks.start_supervised()
  end

  def loop(tag, forward_to) do
    receive do
      x -> send(forward_to, {tag, x})
    end

    loop(tag, forward_to)
  end
end
