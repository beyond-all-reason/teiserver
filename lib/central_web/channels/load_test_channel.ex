defmodule CentralWeb.LoadTest.Channel do
  use Phoenix.Channel

  alias Central.General.LoadTest.Server

  def join("load_test:cnc", _params, socket) do
    {:ok, socket}
  end

  def join("load_test:tester:" <> _uid, _params, socket) do
    {:ok, socket}
  end

  # CNC
  def handle_in(subject, params, %{topic: "load_test:cnc"} = socket) do
    uid = params["uid"]

    case subject do
      "cnc hello" ->
        CentralWeb.Endpoint.broadcast(
          "load_test:endpoints:#{uid}",
          "cnc hello",
          %{msg: "Hello, DC 357 knows you're here."}
        )

      "cnc alter" ->
        CentralWeb.Endpoint.broadcast(
          "load_test:endpoints:#{uid}",
          "cnc alter",
          %{}
        )

      "cnc email" ->
        CentralWeb.Endpoint.broadcast(
          "load_test:endpoints:#{uid}",
          "cnc email",
          %{}
        )
    end

    {:reply, :ok, socket}
  end

  # Testers
  def handle_in(subject, params, %{topic: "load_test:tester:" <> _uid} = socket) do
    case subject do
      "register tester" ->
        Server.register_tester(params)

      "tester broadcast" ->
        Server.tester_broadcast(params)

      "tester ping update" ->
        Server.tester_ping_update(params)
    end

    {:reply, :ok, socket}
  end
end
