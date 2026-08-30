defmodule Teiserver.Autohost.Types.Player do
  @moduledoc """
  Representation of a player in the start script
  """

  alias Teiserver.Account.User

  @enforce_keys [:user_id, :name, :password]
  defstruct [:user_id, :name, :password]

  @type t() :: %__MODULE__{
          user_id: User.id(),
          name: String.t(),
          password: String.t()
        }

  def new(user_id, name) do
    password = :crypto.strong_rand_bytes(16) |> Base.encode16()

    %__MODULE__{
      user_id: user_id,
      name: name,
      password: password
    }
  end
end
