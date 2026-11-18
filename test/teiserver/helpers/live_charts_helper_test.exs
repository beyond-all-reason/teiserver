defmodule Teiserver.Helpers.LiveChartsHelperTest do
  alias LiveCharts.Chart
  alias Teiserver.Helpers.LiveChartsHelper
  use ExUnit.Case

  setup do
    single_series = [20, 40, 10, 20, 50, 5, 15]
    single_series2 = [30, 40, 50, 60, 40, 10, 25]
    labels = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    %{single_series: single_series, single_series2: single_series2, labels: labels}
  end

  describe("get_atom/1") do
    test "returns :line when provided value a valid ApexCharts chart type." do
      assert LiveChartsHelper.get_atom("some_value") == :line
    end
  end

  describe "generate_single_series_chart/4" do
    test "generates a `%LiveCharts.Chart{}` struct for given series, labels, chart type and title",
         %{
           single_series: single_series,
           labels: labels
         } do
      chart_type = :pie
      title = "Minutes Jogging"

      {:ok, chart} =
        LiveChartsHelper.generate_single_series_chart(single_series, labels, chart_type, title)

      assert %Chart{} = chart
      assert chart.id == "Minutes Jogging pie"
      assert chart.adapter == LiveCharts.Adapter.ApexCharts
      assert chart.type == :pie
      assert chart.series == [20, 40, 10, 20, 50, 5, 15]
    end
  end

  test "when provided with incorrect series returns {:error, reason}}", %{
    labels: labels
  } do
    series = ["a", 2, :atom, []]
    chart_type = :gauge
    title = "Minutes Jogging"

    {:error, "series must contain numbers"} =
      LiveChartsHelper.generate_single_series_chart(series, labels, chart_type, title)
  end

  test "when provided with chart type that is not a single series chart type, defaults to :pie",
       %{
         labels: labels,
         single_series: single_series
       } do
    chart_type = :area
    title = "Minutes Jogging"

    {:ok, chart} =
      LiveChartsHelper.generate_single_series_chart(single_series, labels, chart_type, title)

    assert chart.type == :pie
  end

  describe "generate_single_series_maps_chart" do
    test "generates a `%LiveCharts.Chart{}` struct for given series, labels, chart type and title",
         %{labels: labels, single_series: single_series} do
      chart_type = :funnel
      title = "Daily Income"
      series = %{name: "Currency", data: single_series}

      {:ok, chart} =
        LiveChartsHelper.generate_single_series_maps_chart(series, labels, chart_type, title)

      assert %Chart{} = chart
      assert chart.id == "Daily Income funnel"
      assert chart.adapter == LiveCharts.Adapter.ApexCharts
      assert chart.type == :funnel
      assert chart.series == [%{name: "Currency", data: [20, 40, 10, 20, 50, 5, 15]}]
    end

    test "when provided with incorrect series returns {:error, reason}}",
         %{labels: labels} do
      chart_type = :funnel
      title = "Daily Income"
      series = %{name: "Currency", data: ["a", 2, :atom, []]}

      {:error, "data field must contain numbers"} =
        LiveChartsHelper.generate_single_series_maps_chart(series, labels, chart_type, title)
    end

    test "when provided with chart type that is not a single series maps chart type, defaults to :funnel",
         %{
           labels: labels,
           single_series: single_series
         } do
      chart_type = :area
      title = "Daily Income"
      series = %{name: "Currency", data: single_series}

      {:ok, chart} =
        LiveChartsHelper.generate_single_series_maps_chart(series, labels, chart_type, title)

      assert chart.type == :funnel
    end
  end

  describe "generate_multi_series_maps_chart" do
    test "generates a `%LiveCharts.Chart{}` struct for given series, labels, chart type and title",
         %{labels: labels, single_series: single_series, single_series2: single_series2} do
      chart_type = :bar
      title = "User Activity"
      series = [%{name: "Comments", data: single_series}, %{name: "Likes", data: single_series2}]

      {:ok, chart} =
        LiveChartsHelper.generate_multi_series_maps_chart(series, labels, chart_type, title)

      assert %Chart{} = chart
      assert chart.id == "User Activity bar"
      assert chart.adapter == LiveCharts.Adapter.ApexCharts
      assert chart.type == :bar

      assert chart.series == [
               %{name: "Comments", data: [20, 40, 10, 20, 50, 5, 15]},
               %{name: "Likes", data: [30, 40, 50, 60, 40, 10, 25]}
             ]
    end

    test "when provided with incorrect series returns {:error, reason}}",
         %{labels: labels, single_series: single_series} do
      chart_type = :bar
      title = "User Activity"

      series = [
        %{name: "Comments", data: single_series},
        %{name: "Likes", data: ["a", 2, :ok, []]}
      ]

      {:error, "data field/s must contain numbers"} =
        LiveChartsHelper.generate_multi_series_maps_chart(series, labels, chart_type, title)
    end

    test "when provided with chart type that is not a multi series maps chart type, defaults to :line",
         %{
           labels: labels,
           single_series: single_series,
           single_series2: single_series2
         } do
      chart_type = :wheel
      title = "User Activity"
      series = [%{name: "Comments", data: single_series}, %{name: "Likes", data: single_series2}]

      {:ok, chart} =
        LiveChartsHelper.generate_multi_series_maps_chart(series, labels, chart_type, title)

      assert chart.type == :line
    end
  end
end
