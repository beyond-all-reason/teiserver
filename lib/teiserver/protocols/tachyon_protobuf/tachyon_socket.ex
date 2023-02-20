defmodule Tachyon.TachyonSocket do
  @behaviour Phoenix.Socket.Transport

  def child_spec(opts) do
    # We won't spawn any process, so let's return a dummy task
    %{id: __MODULE__, start: {Task, :start_link, [fn -> :ok end]}, restart: :transient}
  end

  def connect(state) do
    # Callback to retrieve relevant data from the connection.
    # The map contains options, params, transport and endpoint keys.
    {:ok, state}
  end

  def init(state) do
    # Now we are effectively inside the process that maintains the socket.
    {:ok, state}
  end

  def handle_in({text, opts}, state) do
    IO.puts ""
    IO.inspect text
    IO.inspect opts
    IO.puts ""

    token = Tachyon.TokenReply.new(token: "token")
    Tachyon.WireMessageAny.new(object: token) |> Tachyon.WireMessageAny.encode() |> Tachyon.WireMessageAny.decode()

    Tachyon.WireMessageOneof.new(object: {:token_reply, token}) |> Tachyon.WireMessageOneof.encode() |> Tachyon.WireMessageOneof.decode()



    tokena = Tachyon.TokenReplyA.new(tokena: "token")
    tokenb = Tachyon.TokenReplyB.new(tokenb: "token")

    encoded_tokena = Tachyon.TokenReplyA.new(tokena: "token") |> Tachyon.TokenReplyA.encode()

    Tachyon.WireMessageAny.new(object: tokena) |> Tachyon.WireMessageAny.encode() |> Tachyon.WireMessageAny.decode()
    Tachyon.WireMessageAny.new(object: encoded_tokena) |> Tachyon.WireMessageAny.encode() |> Tachyon.WireMessageAny.decode()

    Tachyon.WireMessageOneof.new(object: tokena) |> Tachyon.WireMessageOneof.encode() |> Tachyon.WireMessageOneof.decode()

    tokena = Tachyon.TokenReplyA.new(tokena: "token")
    tokenb = Tachyon.TokenReplyB.new(tokenb: "token")

    Tachyon.WireMessage.new(object: tokena) |> Tachyon.WireMessage.encode() |> Tachyon.WireMessage.decode()
    Tachyon.WireMessage.new(object: tokenb) |> Tachyon.WireMessage.encode()

    Tachyon.TokenReplyA.new(tokena: "token") |> Tachyon.TokenReplyA.encode()
    Tachyon.TokenReplyB.new(tokenb: "token") |> Tachyon.TokenReplyB.encode()

    {:reply, :ok, {:text, text}, state}
  end

  def handle_info(msg, state) do
    IO.puts ""
    IO.inspect msg
    IO.puts ""

    {:ok, state}
  end

  def terminate(_reason, _state) do
    :ok
  end
end
