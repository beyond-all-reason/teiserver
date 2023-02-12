defmodule Teiserver.Tachyon.Endpoint do
  use GRPC.Endpoint

  intercept GRPC.Server.Interceptors.Logger
  run Tachyon.Greeter.Server
  run Tachyon.Account.Server
end

defmodule Tachyon.Greeter.Server do
  use GRPC.Server, service: Tachyon.Greeter.Service

  @spec say_hello(Tachyon.HelloRequest.t, GRPC.Server.Stream.t) :: Tachyon.HelloReply.t
  def say_hello(request, _stream) do
    Tachyon.HelloReply.new(message: "Hello #{request.name}")
  end
end

defmodule Tachyon.Account.Server do
  use GRPC.Server, service: Tachyon.Account.Service
  alias Teiserver.Account

  # @spec say_hello(Tachyon.HelloRequest.t, GRPC.Server.Stream.t) :: Tachyon.HelloReply.t
  def get_users_from_ids(%{id_list: id_list}, _stream) do
    users = id_list
      |> Account.list_users_from_cache()
      |> Enum.map(&convert_user/1)

    Tachyon.UserList.new(user_list: users)
  end

  defp convert_user(user) do
    Map.merge(
      Map.take(user, ~w(id name bot clan_id country)a),
      %{"icons" => Teiserver.Account.UserLib.generate_user_icons(user)}
    )
  end


  defp testit do
    {:ok, channel} = GRPC.Stub.connect("localhost:8203")
    request = Tachyon.HelloRequest.new(name: "grpc-elixir")
    {:ok, reply} = channel |> Tachyon.Greeter.Stub.say_hello(request)


    {:ok, channel} = GRPC.Stub.connect("localhost:8203")
    request = Tachyon.IdList.new(id_list: [1,2,3])
    {:ok, reply} = channel |> Tachyon.Account.Stub.get_users_from_ids(request)


    {:ok, channel} = GRPC.Stub.connect("localhost:8203", interceptors: [GRPC.Logger.Client])
  end
end
