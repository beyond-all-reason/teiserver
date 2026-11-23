defmodule Teiserver.Helpers.LiveChartsHelper do
  @moduledoc """
  Helper functions for constructing charts using `LiveCharts` and [ApexCharts](https://apexcharts.com/docs) adapter.

  Handles chart construction and input validation, allowing callers to prepare datasets without having to construct a `LiveCharts.Chart` struct or configure the chart library directly.

  When rendering multiple charts make sure to pass unique titles as they are used to generate ids, otherwise DOM id collistions will occur.
  """
  alias LiveCharts.Chart

  # taken from https://apexcharts.com/docs/chart-types/
  @single_series_types [:pie, :donut, :radialBar, :gauge]
  @single_series_maps_types [:funnel, :pyramid]
  @multi_series_maps_types [:line, :area, :bar, :radar, :heatmap]
  @chart_type_map Map.new(
                    @single_series_types ++ @single_series_maps_types ++ @multi_series_maps_types,
                    fn type ->
                      {Atom.to_string(type), type}
                    end
                  )

  def get_single_series_chart_types, do: @single_series_types
  def get_single_series_maps_chart_types, do: @single_series_maps_types
  def get_multi_series_maps_chart_types, do: @multi_series_maps_types

  @doc """
    Returns an atom representing a chart type. Supported types:
        `:area`,
        `:bar`,
        `:pie`,
        `:donut`,
        `:radialBar`,
        `:heatmap`,
        `:radar`,
        `:funnel`,
        `:pyramid`,
        `:gauge`,
        `:line`.
  """
  @spec to_chart_type(String.t()) :: atom() | nil
  def to_chart_type(type) do
    Map.get(@chart_type_map, type)
  end

  @doc """
    Generates a `%LiveCharts.Chart{}` for `LiveCharts.chart/1`.
    Expects `series` as a list of numbers.
    Supported types: `:pie`, `:donut`, `:radialBar`, `:gauge`.

    ## Examples:
      iex: series = [30, 40, 50, 60, 40, 10, 25]
      iex: labels = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
      iex: Teiserver.Helpers.LiveChartsHelper.generate_single_series_chart(series, labels, :donut, "Minutes Jogging")

      {:ok,
      %LiveCharts.Chart{
        id: "Minutes Jogging donut",
        type: :donut,
        series: [30, 40, 50, 60, 40, 10, 25],
        options: %{
          title: %{text: "Minutes Jogging", style: %{}, align: "center"},
          labels: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday",
            "Saturday", "Sunday"],
          chart: %{width: 500},
          legend: %{position: "bottom", show: true}
        },
        adapter: LiveCharts.Adapter.ApexCharts
      }}

  """
  @spec generate_single_series_chart(list(number()), list(String.t()), atom(), String.t()) ::
          {:ok, Chart.t()} | {:error, String.t()}
  def generate_single_series_chart(series, labels, type, title)
      when is_atom(type) do
    cond do
      type not in @single_series_types ->
        {:error, "invalid type"}

      not is_list(series) ->
        {:error, "series must be a list"}

      Enum.empty?(series) ->
        {:error, "series cannot be empty"}

      not Enum.all?(series, &is_number/1) ->
        {:error, "series must contain numbers"}

      type in [:gauge, :radialBar] ->
        generate_gauge_radialbar_chart(series, labels, type, title)

      type in [:donut, :pie] ->
        generate_donut_pie_chart(series, labels, type, title)
    end
  end

  @doc """
    Generates a `%LiveCharts.Chart{}` for `LiveCharts.chart/1`.
    Expects `series` as a map with `:name` and `:data` keys.
    Supported types: `:funnel`, `:pyramid`.
    [Funnel type docs](https://apexcharts.com/docs/chart-types/funnel-chart/).


  ## Examples:

      iex: series = %{name: "Income", data: [5,10,15,20]}
      iex: labels = ["week 1", "week 2", "week 3", "week 4"]
      iex: Teiserver.Helpers.LiveChartsHelper.generate_proportional_stage_chart(series, labels, :funnel, "Income")

      {:ok,
      %LiveCharts.Chart{
        id: "Income funnel",
        type: :funnel,
        series: [%{data: [5, 10, 15, 20], name: "Currency"}],
        options: %{
          title: %{text: "Income", align: "center"},
          legend: %{position: "bottom", show: true},
          xaxis: %{categories: ["week 1", "week 2", "week 3", "week 4"]}
        },
        adapter: LiveCharts.Adapter.ApexCharts
      }}


  """
  @spec generate_proportional_stage_chart(map(), list(String.t()), atom(), String.t()) ::
          {:ok, Chart.t()} | {:error, String.t()}
  def generate_proportional_stage_chart(series, labels, type, title)
      when is_atom(type) do
    cond do
      not is_map(series) ->
        {:error, "series must be a map"}

      type not in @single_series_maps_types ->
        {:error, "invalid type"}

      not Map.has_key?(series, :name) ->
        {:error, "series map must contain :name field"}

      not Map.has_key?(series, :data) ->
        {:error, "series map must contain :data field"}

      not Enum.all?(series.data, &is_number/1) ->
        {:error, "data field must contain numbers"}

      true ->
        generate_series_maps_chart([series], labels, type, title)
    end
  end

  @doc """
    Generates a `%LiveChars.Chart{}` for `LiveCharts.chart/1`.
    Expects `series` as a list of maps with `:name` and `:data` keys.
    Lists provided in `data` are allowed to vary in length.
    Supported types: `:line`, `:area`, `:bar`, `:radar`, `:heatmap`.

  ## Examples:
      iex: series = [%{name: "Accepted", data: [30, 40, 50, 60, 40, 10, 25]},%{name: "Rejected", data: [0, 4, 0, 2, 12, 5, 0]},%{name: "Postponed", data: [3, 6 ,0, 0, 2, 4, 2]}]
      iex: labels = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
      iex: Teiserver.Helpers.LiveChartsHelper.generate_multi_series_maps_chart(series, labels, :bar, "Inquiries")

      {:ok,
      %LiveCharts.Chart{
        id: "Inquiries bar",
        type: :bar,
        series: [
          %{data: [30, 40, 50, 60, 40, 10, 25], name: "Accepted"},
          %{data: [0, 4, 0, 2, 12, 5, 0], name: "Rejected"},
          %{data: [3, 6, 0, 0, 2, 4, 2], name: "Postponed"}
        ],
        options: %{
          title: %{text: "Inquiries", align: "center"},
          legend: %{position: "bottom", show: true},
          xaxis: %{
            categories: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday",
              "Saturday", "Sunday"]
          }
        },
        adapter: LiveCharts.Adapter.ApexCharts
      }}

  """
  @spec generate_multi_series_maps_chart(list(map()), list(String.t()), atom(), String.t()) ::
          {:ok, Chart.t()} | {:error, String.t()}
  def generate_multi_series_maps_chart(series, labels, type, title)
      when is_atom(type) do
    cond do
      type not in @multi_series_maps_types ->
        {:error, "invalid type"}

      not is_list(series) ->
        {:error, "series must be a list"}

      Enum.empty?(series) ->
        {:error, "series cannot be empty"}

      not Enum.all?(series, &is_map/1) ->
        {:error, "series must contain maps"}

      not Enum.all?(series, fn s -> Map.has_key?(s, :data) end) ->
        {:error, "series maps must contain :data field"}

      not Enum.all?(series, fn s -> Map.has_key?(s, :name) end) ->
        {:error, "series maps must contain :name field"}

      not Enum.all?(series, fn d -> Enum.all?(d.data, &is_number/1) end) ->
        {:error, "data fields must contain numbers"}

      true ->
        generate_series_maps_chart(series, labels, type, title)
    end
  end

  defp generate_series_maps_chart(series, labels, type, title) do
    chart =
      LiveCharts.build(%{
        id: "#{title} #{type}",
        type: type,
        series: series,
        options: %{
          legend: show_legend(),
          title: %{text: title, align: "center"},
          xaxis: %{
            categories: labels
          }
        },
        adapter: LiveCharts.Adapter.ApexCharts
      })

    {:ok, chart}
  end

  defp show_legend do
    %{
      show: true,
      position: "bottom"
    }
  end

  defp generate_gauge_radialbar_chart(series, labels, type, title)
       when type in [:gauge, :radialBar] do
    chart =
      LiveCharts.build(%{
        id: "#{title} #{type}",
        type: type,
        series: series,
        options: %{
          title: %{text: title, align: "center"},
          labels: labels,
          chart: %{
            height: 500
          },
          plotOptions: %{
            radialBar: %{
              dataLabels: %{
                total: %{
                  show: true,
                  label: "Total"
                }
              }
            }
          },
          legend: show_legend()
        },
        adapter: LiveCharts.Adapter.ApexCharts
      })

    {:ok, chart}
  end

  defp generate_donut_pie_chart(series, labels, type, title) when type in [:donut, :pie] do
    chart =
      LiveCharts.build(%{
        id: "#{title} #{type}",
        type: type,
        series: series,
        options: %{
          title: %{text: title, align: "center", style: %{}},
          labels: labels,
          chart: %{
            width: 500
          },
          legend: show_legend()
        },
        adapter: LiveCharts.Adapter.ApexCharts
      })

    {:ok, chart}
  end
end
