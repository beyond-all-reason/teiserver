defmodule Teiserver.Telemetry.ComplexServerEventType do
  @moduledoc false
  use TeiserverWeb, :schema

  typed_schema "telemetry_complex_server_event_types" do
    field :name, :string
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, ~w(name)a)
    |> validate_required(~w(name)a)
  end

  @spec authorize(atom, Plug.Conn.t(), map()) :: boolean
  def authorize(_action, conn, _params), do: allow?(conn, "Server")
end
