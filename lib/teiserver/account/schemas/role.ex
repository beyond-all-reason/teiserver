defmodule Teiserver.Account.Role do
  @moduledoc """
  A struct representing a role which can be held by user accounts.
  """

  alias Teiserver.Account.Role

  @enforce_keys [:name]
  defstruct [:name, :colour, :icon, contains: [], badge: false]

  @type t() :: %Role{
          name: String.t(),
          colour: String.t(),
          icon: String.t(),
          contains: [String.t()]
        }
end
