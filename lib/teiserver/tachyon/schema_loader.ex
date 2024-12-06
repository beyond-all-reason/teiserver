defmodule Teiserver.Tachyon.SchemaLoader do
  @moduledoc """
  Loader for json_xema: https://hexdocs.pm/json_xema/loader.html
  to resolve the references for tachyon json schemas
  """

  @behaviour Xema.Loader

  @impl Xema.Loader
  @doc """
  Turns a url like https://schema.beyondallreason.dev/tachyon/definitions/allyTeam.json
  into a Xema that can be used for validation
  """
  def fetch(%URI{} = uri) do
    with def_id when not is_nil(def_id) <- String.split(uri.path, "/") |> List.last(),
         name <- Path.basename(def_id, ".json"),
         {:ok, json} <- Teiserver.Tachyon.Schema.parse_schema("definitions", name) do
      # For some obscure reason, if the ref has an $id, it'll mess up the way
      # it is resolved by json_xema and basically won't work.
      # so drop it
      {:ok, Map.drop(json, ["$id"])}
    else
      {:missing_schema, _cmd_id, _type} ->
        {:error, {:ref_not_found, uri}}

      err ->
        {:error, {:invalid_type, inspect(err)}}
    end
  end
end
