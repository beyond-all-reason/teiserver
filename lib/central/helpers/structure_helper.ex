defmodule Central.Helpers.StructureHelper do
  @moduledoc """
  A module to make import/export of JSON objects easier. Currently only tested with a single parent object and multiple sets of child objects.
  Designed to not take the IDs with it as they are liable to change based on the database they go into.
  """
  alias Central.Repo
  import Ecto.Query, warn: false

  @skip_export_fields [:__meta__, :inserted_at, :updated_at]
  @skip_import_fields ~w(id)

  defp query_obj(module, id) do
    query =
      from objects in module,
        where: objects.id == ^id

    Repo.one!(query)
  end

  defp cast_many(object, field, parent_module) do
    association = parent_module.__schema__(:association, field)
    object_module = association.queryable

    case association.relationship do
      :parent ->
        :skip

      :child ->
        Repo.preload(object, field)
        |> Map.get(field)
        |> Enum.map(fn item -> cast_one(item, object_module) end)
    end
  end

  defp cast_one(object, module) do
    skip_fields =
      if Kernel.function_exported?(module, :structure_export_skips, 0) do
        module.structure_export_skips()
      else
        []
      end

    object
    |> Map.from_struct()
    |> Enum.filter(fn {k, _} ->
      not Enum.member?(@skip_export_fields, k) and not Enum.member?(skip_fields, k)
    end)
    |> Enum.map(fn {k, v} ->
      cond do
        module.__schema__(:field_source, k) -> {k, v}
        module.__schema__(:association, k) -> {k, cast_many(object, k, module)}
      end
    end)
    |> Enum.filter(fn {_, v} -> v != :skip end)
    |> Map.new()
  end

  def export(module, id) do
    query_obj(module, id)
    |> cast_one(module)
  end

  defp import_assoc(parent_module, field, data, parent_id) when is_list(data) do
    field = String.to_existing_atom(field)
    assoc = parent_module.__schema__(:association, field)

    data
    |> Enum.map(fn item_params ->
      import_assoc(assoc, item_params, parent_id)
    end)
  end

  defp import_assoc(assoc, params, parent_id) when is_map(params) do
    key = assoc.related_key |> to_string

    params =
      Map.put(params, key, parent_id)
      |> Enum.filter(fn {k, _} -> not Enum.member?(@skip_import_fields, k) end)
      |> Map.new()

    module = assoc.queryable

    {:ok, _new_object} =
      module.changeset(module.__struct__, params)
      |> Repo.insert()
  end

  # Given the root module and the data, this should create everything you need
  def import(module, data) do
    assocs =
      module.__schema__(:associations)
      |> Enum.map(&to_string/1)

    # First, create and insert the core object
    core_params =
      data
      |> Enum.filter(fn {k, _} ->
        not Enum.member?(assocs, k) and not Enum.member?(@skip_import_fields, k)
      end)
      |> Map.new()

    {:ok, core_object} =
      module.changeset(module.__struct__, core_params)
      |> Repo.insert()

    # Now, lets add the assocs
    data
    |> Enum.filter(fn {k, _} -> Enum.member?(assocs, k) end)
    |> Enum.each(fn {k, v} -> import_assoc(module, k, v, core_object.id) end)

    core_object
  end
end
