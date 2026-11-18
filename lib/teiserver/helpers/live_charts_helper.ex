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
    Returns an atom representing a chart type, defaults to `:line` if provided value is anything beside a valid [ApeCharts chart types](https://apexcharts.com/docs/chart-types/).
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
   Generates single series `%LiveCharts.Chart{}` for `LiveCharts.chart/1`.
    Expects `series` as a list of numbers:
    [1,2,3,4,5],
    Defaults to `:pie` chart type if provided `type` is not a single series type.
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
    Generates a single series map `%LiveChars.Chart{}` for `LiveCharts.chart/1`.
      Expects `series` as a map:
    %{name: "Some name", data: [1,2,3,4,5]}.
    Defaults to `:funnel` chart type if provided `type` is not a single series map type.
    [Funnel type docs](https://apexcharts.com/docs/chart-types/funnel-chart/).

  """
  @spec generate_single_series_maps_chart(map(), list(String.t()), atom(), String.t()) ::
          {:ok, Chart.t()} | {:error, String.t()}
  def generate_single_series_maps_chart(series, labels, type, title)
      when is_atom(type) do
    type =
      if type in @single_series_maps_types do
        type
      else
        :funnel
      end

    cond do
      not Map.has_key?(series, :name) ->
        {:error, "series map must contain :name ield"}

      not Map.has_key?(series, :data) ->
        {:error, "series map must contain :data ield"}

      not Enum.all?(series.data, &is_number/1) ->
        {:error, "data field must contain numbers"}

      true ->
        generate_series_maps_chart([series], labels, type, title)
    end
  end

  @doc """
    Generates a multi series map `%LiveChars.Chart{}` for `LiveCharts.chart/1`.
      Expects `series` as a list of maps:
    `[%{name: "Some name", data: [1,2,3,4,5]}, %{name: "Some other name, data: [6,7,8,9,0]}]`.
    Lists provided in `data` are allowed to vary in length.
    Defaults to `:line` chart type if provided `type` is not a multi series map type.
  """
  @spec generate_multi_series_maps_chart(list(number()), list(String.t()), atom(), String.t()) ::
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
