defmodule Teiserver.Tachyon.Endpoint do
  use GRPC.Endpoint

  intercept GRPC.Server.Interceptors.Logger
  run Tachyon.Greeter.Server
  run Tachyon.Account.Server
  run Tachyon.Authentication.Server
end

defmodule Tachyon.Greeter.Server do
  use GRPC.Server, service: Tachyon.Greeter.Service

  @spec say_hello(Tachyon.HelloRequest.t, GRPC.Server.Stream.t) :: Tachyon.HelloReply.t
  def say_hello(request, _stream) do
    Tachyon.HelloReply.new(message: "Hello #{request.name}")
  end
end

defmodule Tachyon.Authentication.Server do
  use GRPC.Server, service: Tachyon.Authentication.Service

  @spec get_token(Tachyon.TokenRequest.t, GRPC.Server.Stream.t) :: Tachyon.TokenReply.t
  def get_token(%{email: email, password: password}, _stream) do
    if email == password do
      Tachyon.TokenReply.new(token: "token-value")
    else
      raise GRPC.RPCError, status: GRPC.Status.unknown, message: "error message"
    end
  end
end

defmodule Tachyon.Account.Server do
  use GRPC.Server, service: Tachyon.Account.Service
  alias Teiserver.Account

  # @spec say_hello(Tachyon.HelloRequest.t, GRPC.Server.Stream.t) :: Tachyon.HelloReply.t
  def get_users_from_ids(%{token: token, id_list: id_list}, _stream) do
    if token != "token-value" do
      raise GRPC.RPCError, status: GRPC.Status.unauthenticated, message: "unauth"
    end

    users = id_list
      |> Account.list_users_from_cache()
      |> Enum.map(&convert_user/1)

    Tachyon.UserList.new(user_list: users)
  end

  defp convert_user(user) do
    Map.merge(
      Map.take(user, ~w(id name bot clan_id)a),
      %{"icons" => Teiserver.Account.UserLib.generate_user_icons(user)}
    )
  end

  defp testit do
    {:ok, channel} = GRPC.Stub.connect("localhost:8203")
    request = Tachyon.IdList.new(id_list: [1,2,3])
    {:ok, reply} = channel |> Tachyon.Account.Stub.get_users_from_ids(request)


    {:ok, channel} = GRPC.Stub.connect("localhost:8203")

    # Bad request
    channel |> Tachyon.Authentication.Stub.get_token(
      Tachyon.TokenRequest.new(email: "email", password: "incorrect")
    )

    # Good request
    channel |> Tachyon.Authentication.Stub.get_token(
      Tachyon.TokenRequest.new(email: "email", password: "email")
    )

    # Unauthd
    channel |> Tachyon.Account.Stub.get_users_from_ids(
      Tachyon.AuthdIdList.new(token: "bad", id_list: [1, 3])
    )

    # Authd
    channel |> Tachyon.Account.Stub.get_users_from_ids(
      Tachyon.AuthdIdList.new(token: "token-value", id_list: [1, 3])
    )

    {:ok, channel} = GRPC.Stub.connect("localhost:8203", interceptors: [GRPC.Logger.Client])
  end
end
