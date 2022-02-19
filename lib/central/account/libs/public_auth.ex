# This file contains permissions for the non-admin version of various types
defmodule Central.Account.PublicGroup do
  def authorize(_, _, _) do
    Application.get_env(:central, Central)[:enabled_account_group_pages]
  end
end
