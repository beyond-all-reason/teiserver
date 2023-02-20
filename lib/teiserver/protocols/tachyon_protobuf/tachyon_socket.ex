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

    token_request = Tachyon.TokenRequest.new(email: "email", password: "password")
    # token_request |> Tachyon.TokenRequest.encode()
    # <<10, 5, 101, 109, 97, 105, 108, 18, 8, 112, 97, 115, 115, 119, 111, 114, 100>>

    msg = Tachyon.ClientMessage.new(object: {:token_request, token_request})
    enc_msg = Tachyon.ClientMessage.encode(msg)

    # Now decode it
    msg = Tachyon.ClientMessage.decode(enc_msg)




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
