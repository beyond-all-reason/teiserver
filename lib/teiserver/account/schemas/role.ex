defmodule Teiserver.Account.Role do
  @moduledoc """
  A struct representing a role which can be held by user accounts.

  - name: The name of the role
  - contains: A list of roles contained within this role, permissions from all contained
      roles are combined
  - description: A description of the nature of the role
  - edit_permission: The permission required to edit the presence of the role on a user
  - group: An atom for semantically grouping roles together

  badge, colour and icon are currently in use but will be deprecated
  """

  alias Teiserver.Account.Role

  @enforce_keys [:name]
  defstruct [
    :name,
    :colour,
    :icon,
    :group,
    :edit_permission,
    contains: [],
    badge: false,
    description: ""
  ]

  @type t() :: %Role{
          name: String.t(),
          colour: String.t(),
          icon: String.t(),
          contains: [String.t()],
          description: String.t(),
          edit_permission: String.t(),
          group: atom()
        }
end
