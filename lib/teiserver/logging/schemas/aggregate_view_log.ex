defmodule Teiserver.Logging.AggregateViewLog do
  @moduledoc false
  use TeiserverWeb, :schema

  @primary_key false
  typed_schema "aggregate_view_logs" do
    field :date, :date, primary_key: true

    field :total_views, :integer
    field :total_uniques, :integer
    field :average_load_time, :integer

    field :guest_view_count, :integer
    field :guest_unique_ip_count, :integer

    field :percentile_load_time_95, :integer
    field :percentile_load_time_99, :integer
    field :max_load_time, :integer

    field :hourly_views, {:array, :integer}
    field :hourly_uniques, {:array, :integer}
    field :hourly_average_load_times, {:array, :integer}

    field :section_data, :map
  end

  @doc false
  def changeset(struct, attrs) do
    struct
    |> cast(attrs, [
      :date,
      :total_views,
      :total_uniques,
      :average_load_time,
      :guest_view_count,
      :guest_unique_ip_count,
      :percentile_load_time_95,
      :percentile_load_time_99,
      :max_load_time,
      :hourly_views,
      :hourly_uniques,
      :hourly_average_load_times,
      :section_data
    ])
    |> validate_required([
      :date,
      :total_views,
      :total_uniques,
      :average_load_time,
      :guest_view_count,
      :guest_unique_ip_count,
      :percentile_load_time_95,
      :percentile_load_time_99,
      :max_load_time,
      :hourly_views,
      :hourly_uniques,
      :hourly_average_load_times,
      :section_data
    ])
  end

  @spec authorize(any, Plug.Conn.t(), atom) :: boolean
  def authorize(_, conn, :delete), do: allow?(conn, "logging.aggregate.delete")
  def authorize(_, conn, _), do: allow?(conn, "logging.aggregate")
end
