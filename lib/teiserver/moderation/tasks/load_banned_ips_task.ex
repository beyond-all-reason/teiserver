defmodule Teiserver.Moderation.LoadBannedIPsTask do
  @moduledoc """
  Loads the list of banned IPs from the database into the cache.
  """
  alias IP.Subnet
  alias Teiserver.Helpers.CacheHelper
  alias Teiserver.Moderation
  alias Teiserver.Moderation.BannedIP

  def perform do
    blocked_ip_ranges =
      Moderation.list_banned_ip_ranges()
      |> Enum.map(fn %BannedIP{cidr: cidr} -> Subnet.from_string(cidr) end)
      |> Enum.filter(fn {status, _value} -> status == :ok end)
      |> Enum.map(fn {_status, value} -> value end)

    CacheHelper.store_put(
      :application_metadata_cache,
      "blocked_ip_ranges",
      blocked_ip_ranges
    )
  end
end
