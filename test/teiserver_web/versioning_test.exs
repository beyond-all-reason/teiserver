defmodule TeiserverWeb.Tachyon.VersioningTest do
  alias TeiserverWeb.Tachyon.Versioning

  use ExUnit.Case, async: true

  @server_supported_versions [1, 2]

  test "tachyon version negotiation" do
    # Higher major version is selected
    assert {:ok, "v2.tachyon", {2, 0}} =
             Versioning.negotiate_version(
               ["v1.tachyon", "v2.tachyon"],
               @server_supported_versions
             )

    # Higher minor version is accepted
    assert {:ok, "v1.3.tachyon", {1, 3}} =
             Versioning.negotiate_version(
               ["v0.3.tachyon", "v1.3.tachyon"],
               @server_supported_versions
             )

    # Higher or lower versions than the server supports are rejected
    assert {:error, :no_shared_versions} =
             Versioning.negotiate_version(
               ["v0.tachyon", "v3.tachyon"],
               @server_supported_versions
             )

    # Invalid format is rejected
    assert {:error, :no_shared_versions} =
             Versioning.negotiate_version(
               ["v0", "v1.1.1.tachyon"],
               @server_supported_versions
             )
  end
end
