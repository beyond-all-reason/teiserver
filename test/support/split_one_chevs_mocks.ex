defmodule Teiserver.SplitOneChevsMocks do
  alias Teiserver.Account
  #Split one chevs needs to hit the database to determine the rank of a user
  #So instead of hitting the database we will use mocks
  def get_mocks() do
    {Account, [:passthrough],
     [
       get_user_by_id: fn member_id -> get_user_by_id_mock(member_id) end,
       get_username_by_id: fn member_id -> member_id end
     ]}
  end

  defp get_user_by_id_mock(member_id) when is_number(member_id) do
    %{
      rank: 1
    }
  end

  # If a user's id contains the word noob, they will be rank 0 or one chev
  defp get_user_by_id_mock(member_id) when is_bitstring(member_id) do
    if(member_id |> String.downcase() |> String.contains?("noob")) do
      %{
        rank: 0
      }
    else
      %{
        rank: 1
      }
    end
  end
end
