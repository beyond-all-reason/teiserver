defmodule Teiserver.Tachyon.AccountHandler do
  alias Teiserver.Account
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Protocols.Tachyon.V1.TachyonProtobuf
  alias Teiserver.Tachyon.TachyonPbLib

  @spec handle_myself_request(Tachyon.MyselfRequest.t(), map()) :: Tachyon.MyselfResponse.t()
  def handle_myself_request(_, %{userid: userid} = conn) do
    user = Account.get_user_by_id(userid)

    Tachyon.MyselfResponse.new(
      user: TachyonProtobuf.make_private_user(user)
    )
  end
end
