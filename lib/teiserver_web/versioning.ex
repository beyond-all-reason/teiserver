defmodule TeiserverWeb.Tachyon.Versioning do
  @moduledoc false

  @type version :: {non_neg_integer(), non_neg_integer()}

  # Server supported major Tachyon versions.
  # Only major versions are listed because the minor ones are optional additional extensions
  # that the server has to accept even if it doesn't support them.
  @server_supported_versions [0]

  @subprotocol_regex ~r/^v(\d+)(?:\.(\d+))?\.tachyon$/

  def server_supported_versions, do: @server_supported_versions

  @doc """
  Client provides a list of supported versions, the server will select the highest version
  supported by both the client and the server. If the server does not support any of the
  versions specified by the client the connection will be closed.

  The subprotocol string is in the format `v{major}[.{minor}].tachyon`, where `major` and
  `minor` are integers. The `minor` part is optional, and if omitted, it is assumed to be `0`.
  Malformed subprotocols are ignored.
  e.g. v1.12.tachyon

  Because the minor versions of the protocol are only additional extensions, that are optional,
  server must accept a connection with a higher minor version than it supports
  if the major version is the same.
  """
  @spec negotiate_version([String.t()], [non_neg_integer()]) ::
          {:ok, String.t(), version()} | {:error, atom()}
  def negotiate_version(client_versions, supported_versions \\ @server_supported_versions) do
    shared_versions =
      for subprotocol <- client_versions,
          {:ok, {major, _minor} = version} <- [parse_subprotocol(subprotocol)],
          major in supported_versions,
          do: {subprotocol, version}

    case Enum.max_by(shared_versions, fn {_subprotocol, version} -> version end, fn -> nil end) do
      nil -> {:error, :no_shared_versions}
      {subprotocol, version} -> {:ok, subprotocol, version}
    end
  end

  @spec parse_subprotocol(String.t()) :: {:ok, version()} | :error
  defp parse_subprotocol(subprotocol) do
    case Regex.run(@subprotocol_regex, subprotocol, capture: :all_but_first) do
      [major] -> {:ok, {String.to_integer(major), 0}}
      [major, minor] -> {:ok, {String.to_integer(major), String.to_integer(minor)}}
      _no_match -> {:error, :no_protocol_match}
    end
  end
end
