defmodule Teiserver.Tachyon.SchemaResolver do
  @moduledoc """
  JSV resolver https://hexdocs.pm/jsv/JSV.Resolver.html
  """

  alias Teiserver.Tachyon.Schema

  @behaviour JSV.Resolver

  @tachyon_schema "https://schema.beyondallreason.dev/tachyon/"

  @impl JSV.Resolver

  @doc """
  Turns a URI like https://schema.beyondallreason.dev/tachyon/definitions/allyTeam.json
  into the corresponding local JSON schema
  """
  def resolve(@tachyon_schema <> path, opts) do
    major_version = Keyword.fetch!(opts, :major_version)
    command_id = Path.dirname(path)
    type = Path.basename(path, ".json")

    case Schema.parse_schema(major_version, command_id, type) do
      {:ok, json} -> {:normal, json}
      {:missing_schema, cmd_id, _type} -> {:error, {:ref_not_found, cmd_id}}
      {:error, err} -> {:error, err}
    end
  end

  def resolve(uri, _opts), do: {:error, {:unsupported_uri, uri}}
end
