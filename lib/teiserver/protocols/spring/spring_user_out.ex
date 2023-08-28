defmodule Teiserver.Protocols.Spring.UserOut do
  @moduledoc false

  @spec do_reply(atom(), nil | String.t() | tuple() | list(), map()) :: String.t()
  def do_reply(_, _, %{userid: nil}), do: ""

  def do_reply(:list_relationships, data, _state) do
    encoded_data =
      data
      |> Jason.encode!()
      |> Base.encode64(padding: false)

    "s.user.list_relationships #{encoded_data}\n"
  end
end
