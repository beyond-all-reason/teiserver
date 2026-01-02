defmodule Teiserver.Telemetry.ComplexAnonEvent do
  @moduledoc false
  use TeiserverWeb, :schema

  typed_schema "telemetry_complex_anon_events" do
    field :hash, :string
    belongs_to :event_type, Teiserver.Telemetry.ComplexClientEventType

    field :timestamp, :utc_datetime
    field :value, :map
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, ~w(hash event_type_id timestamp value)a)
    |> validate_required(~w(hash event_type_id timestamp value)a)
  end

  @spec authorize(atom, Plug.Conn.t(), map()) :: boolean
  def authorize(_action, conn, _params), do: allow?(conn, "Server")
end
