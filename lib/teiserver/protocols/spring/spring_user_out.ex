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

  def do_reply(:closeness, {username, closeness}, _state) do
    "s.user.closeness userName=#{username}\t#{closeness}\n"
  end

  def do_reply(:add_friend, result_list, _state) do
    result_list
    |> Enum.map_join("", fn
      {name, :success} -> "s.user.add_friend #{name}\tsuccess\n"
      {name, :no_user} -> "s.user.add_friend #{name}\failure\tno user of that name\n"
      {name, :existing} -> "s.user.add_friend #{name}\failure\texisting friend request\n"
      {name, reason} -> "s.user.add_friend #{name}\failure\tno failure catch for #{reason}\n"
    end)

  end
end
