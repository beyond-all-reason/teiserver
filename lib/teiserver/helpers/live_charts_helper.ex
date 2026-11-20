defmodule Teiserver.Helpers.LiveChartsHelper do
  @moduledoc false
  alias LiveCharts.Chart

  # taken from https://apexcharts.com/docs/chart-types/
  @single_series_chart_types [:pie, :donut, :radialBar, :gauge]
  @single_series_maps_types [:funnel, :pyramid]
  @multi_series_maps_types [:line, :area, :bar, :radar, :heatmap]

  def get_single_series_chart_types, do: @single_series_chart_types
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
        `:rangeBar`,
        `:funnel`,
        `:pyramid`,
        `:gauge`,
        `:line`.
        If provided type is not supported, returns `:line`.
  """
  @spec get_atom(String.t()) :: atom()
  def get_atom(type) do
    case type do
      "area" ->
        :area

      "bar" ->
        :bar

      "pie" ->
        :pie

      "donut" ->
        :donut

      "radialBar" ->
        :radialBar

      "heatmap" ->
        :heatmap

      "radar" ->
        :radar

      "rangeBar" ->
        :rangeBar

      "funnel" ->
        :funnel

      "pyramid" ->
        :pyramid

      "gauge" ->
        :gauge

      _type ->
        :line
    end
  end

  @doc """
    Generates a `%LiveCharts.Chart{}` for `LiveCharts.chart/1`.
    Expects `series` as a list of numbers.
    Supported types: `:pie`, `:donut`, `:radialBar`, `:gauge`.
    If provided type is not supported, returns `:pie`.
    ## Examples:
      iex: series = [30, 40, 50, 60, 40, 10, 25]
      iex: labels = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
      iex: Teiserver.Helpers.LiveChartsHelper.generate_single_series_chart(series, label, :donut, "Minutes Jogging")

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
    type =
      if type in @single_series_chart_types do
        type
      else
        :pie
      end

    if Enum.all?(series, &is_number/1) do
      cond do
        type in [:gauge, :radialBar] ->
          generate_gauge_radialbar_chart(series, labels, type, title)

        type in [:donut, :pie] ->
          generate_donut_pie_chart(series, labels, type, title)
      end
    else
      {:error, "series must contain numbers"}
    end
  end

  @doc """
    Generates a `%LiveChars.Chart{}` for `LiveCharts.chart/1`.
    Expects `series` as a map  with `:name` and `:data` keys.
    Supported types: `:funnel`, `:pyramid`.
    If provided type is not supported, returns `:funnel`.
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
    type =
      if type in @single_series_maps_types do
        type
      else
        :funnel
      end

    cond do
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
    If provided type is not supported, returns `:line`.
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
    type =
      if type in @multi_series_maps_types do
        type
      else
        :line
      end

    cond do
      not Enum.all?(series, fn s -> Map.has_key?(s, :data) end) ->
        {:error, "series must contain :data field"}

      not Enum.all?(series, fn s -> Map.has_key?(s, :name) end) ->
        {:error, "series must contain :name field"}

      not Enum.all?(series, fn d -> Enum.all?(d.data, &is_number/1) end) ->
        {:error, "data field/s must contain numbers"}

      true ->
        generate_series_maps_chart(series, labels, type, title)
    end
  end

  defp generate_series_maps_chart(series, labels, type, title) do
    chart =
      LiveCharts.build(%{
        id: title <> " " <> Atom.to_string(type),
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
        id: title <> " " <> Atom.to_string(type),
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
        id: title <> " " <> Atom.to_string(type),
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
