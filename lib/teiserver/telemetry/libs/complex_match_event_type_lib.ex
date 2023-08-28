defmodule Teiserver.Telemetry.ComplexMatchEventTypeLib do
  @moduledoc false
  # use CentralWeb, :library
  alias Teiserver.Telemetry
  alias Teiserver.Telemetry.ComplexMatchEventType

  # Helper function
  @spec get_or_add_complex_match_event_type(String.t()) :: non_neg_integer()
  def get_or_add_complex_match_event_type(name) do
    name = String.trim(name)

    Central.cache_get_or_store(:telemetry_complex_match_event_types_cache, name, fn ->
      result = Telemetry.list_complex_match_event_types(where: [name: name], select: [:id], order_by: ["ID (Lowest first)"])
      case result do
        nil ->
          {:ok, event_type} =
            %ComplexMatchEventType{}
            |> ComplexMatchEventType.changeset(%{name: name})
            |> Repo.insert()

          event_type.id

        [%{id: id} | _] ->
          id
      end
    end)
  end
end
