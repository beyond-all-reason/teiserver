# This file contains permissions for the non-admin version of various types
defmodule Central.Account.PublicGroup do
  def authorize(_, _, _) do
    Teiserver.Config.get_site_config_cache("user.Enable account group pages")
  end
end
