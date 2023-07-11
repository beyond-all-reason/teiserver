defmodule Teiserver.Tachyon.Responses.User.UpdatedUserClientResponse do
  @moduledoc """

  """

  alias Teiserver.Data.Types, as: T
  alias Teiserver.Tachyon.Converters

  @spec generate(map()) :: {T.tachyon_command(), T.tachyon_object()}
  def generate(client) do
    object = %{
      "userid" => client.userid,
      "status" => Converters.convert(client, :client)
    }

    {"user/UpdatedUserClient/response", :success,
     %{
       "userClient" => object
     }}
  end

  @spec generate(T.userid(), map()) :: {T.tachyon_command(), T.tachyon_object()}
  def generate(userid, partial_client) do
    object = %{
      "userid" => userid,
      "status" => Converters.convert(partial_client, :client)
    }

    {"user/UpdatedUserClient/response", :success,
     %{
       "userClient" => object
     }}
  end
end
