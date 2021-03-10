defmodule Central.General.LoadTestStat do
  use CentralWeb, :schema

  schema "load_test_stats" do
    field :timeid, :utc_datetime
    field :data, :map
  end

  @doc false
  def changeset(struct, params) do
    struct
    |> cast(params, [:timeid, :data])
    |> validate_required([:timeid, :data])
  end

  def authorize(_, _, _), do: false
end

"""
CREATE TABLE "load_test_stats" (
  "id" bigserial,
  "timeid" timestamp(0) NOT NULL,
  "data" jsonb NOT NULL,
  PRIMARY KEY ("id")
);
"""
