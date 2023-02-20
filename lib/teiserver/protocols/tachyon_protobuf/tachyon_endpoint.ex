defmodule Teiserver.Tachyon.Endpoint do
  use GRPC.Endpoint

  intercept GRPC.Server.Interceptors.Logger
  run Tachyon.Authentication.Server
end

defmodule Tachyon.Authentication.Server do
  use GRPC.Server, service: Tachyon.Authentication.Service

  @spec get_token(Tachyon.TokenRequest.t, GRPC.Server.Stream.t) :: Tachyon.TokenReply.t
  def get_token(%{email: email, password: password}, _stream) do
    case password do
      "password" ->
        Tachyon.TokenReply.new(token: "token-value")

      "not_found" ->
        raise GRPC.RPCError, status: GRPC.Status.not_found, message: "error message"

      "permission_denied" ->
        raise GRPC.RPCError, status: GRPC.Status.permission_denied, message: "error message"

      "unauthenticated" ->
        raise GRPC.RPCError, status: GRPC.Status.unauthenticated, message: "error message"

      _ ->
        raise GRPC.RPCError, status: GRPC.Status.unknown, message: "error message"
    end
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
