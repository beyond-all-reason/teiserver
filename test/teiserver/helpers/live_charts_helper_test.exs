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

  describe "to_chart_type/1" do
    test "returns nil when chart type is not supported" do
      assert LiveChartsHelper.to_chart_type("some_value") == nil
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

    test "when series passed is not a list returns {:error, reason}", %{labels: labels} do
      series = %{}
      chart_type = :gauge

      {:error, "series must be a list"} =
        LiveChartsHelper.generate_single_series_chart(series, labels, chart_type, "Title")
    end

    test "when passed series do not contain numbers returns {:error, reason}", %{labels: labels} do
      series = ["a", "b"]
      chart_type = :gauge

      {:error, "series must contain numbers"} =
        LiveChartsHelper.generate_single_series_chart(series, labels, chart_type, "Title")
    end

    test "when passed series are empty returns {:error, reason}", %{labels: labels} do
      series = []
      chart_type = :gauge

      {:error, "series cannot be empty"} =
        LiveChartsHelper.generate_single_series_chart(series, labels, chart_type, "Title")
    end

    test "when provided with incorrect type returns {:error, reason}", %{
      single_series: single_series,
      labels: labels
    } do
      chart_type = :echo
      title = "Minutes Jogging"

      {:error, "invalid type"} =
        LiveChartsHelper.generate_single_series_chart(single_series, labels, chart_type, title)
    end
  end

  describe "generate_proportional_stage_chart/4" do
    test "generates a `%LiveCharts.Chart{}` struct for given series, labels, chart type and title",
         %{labels: labels, single_series: single_series} do
      chart_type = :funnel
      title = "Daily Income"
      series = %{name: "Currency", data: single_series}

      {:ok, chart} =
        LiveChartsHelper.generate_proportional_stage_chart(series, labels, chart_type, title)

      assert %Chart{} = chart
      assert chart.id == "Daily Income funnel"
      assert chart.adapter == LiveCharts.Adapter.ApexCharts
      assert chart.type == :funnel
      assert chart.series == [%{name: "Currency", data: [20, 40, 10, 20, 50, 5, 15]}]
    end

    test "when provided series is not a map returns {:error, reason}",
         %{labels: labels} do
      chart_type = :funnel
      title = "Daily Income"
      series = []

      {:error, "series must be a map"} =
        LiveChartsHelper.generate_proportional_stage_chart(series, labels, chart_type, title)
    end

    test "when provided series map does not contains data key returns {:error, reason}",
         %{labels: labels} do
      chart_type = :funnel
      title = "Daily Income"
      series = %{name: "Currency"}

      {:error, "series map must contain :data field"} =
        LiveChartsHelper.generate_proportional_stage_chart(series, labels, chart_type, title)
    end

    test "when provided series map does not contains name key returns {:error, reason}",
         %{labels: labels} do
      chart_type = :funnel
      title = "Daily Income"
      series = %{data: [1, 2, 3, 4]}

      {:error, "series map must contain :name field"} =
        LiveChartsHelper.generate_proportional_stage_chart(series, labels, chart_type, title)
    end

    test "when provided series data field does not contain numbers returns {:error, reason}",
         %{labels: labels} do
      chart_type = :funnel
      title = "Daily Income"
      series = %{name: "Currency", data: [:a, :b]}

      {:error, "data field must contain numbers"} =
        LiveChartsHelper.generate_proportional_stage_chart(series, labels, chart_type, title)
    end

    test "when provided with incorrect type returns {:error, reason}",
         %{single_series: single_series, labels: labels} do
      chart_type = :rodeo
      title = "Daily Income"
      series = %{name: "Currency", data: single_series}

      {:error, "invalid type"} =
        LiveChartsHelper.generate_proportional_stage_chart(
          series,
          labels,
          chart_type,
          title
        )
    end
  end

  describe "generate_multi_series_maps_chart/4" do
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

    test "when provided series is not a list returns {:error, reason}",
         %{labels: labels} do
      chart_type = :bar
      title = "User Activity"

      series = %{}

      {:error, "series must be a list"} =
        LiveChartsHelper.generate_multi_series_maps_chart(series, labels, chart_type, title)
    end

    test "when provided series is empty returns {:error, reason}",
         %{labels: labels} do
      chart_type = :bar
      title = "User Activity"

      series = []

      {:error, "series cannot be empty"} =
        LiveChartsHelper.generate_multi_series_maps_chart(series, labels, chart_type, title)
    end

    test "when provided series does not contain a map returns {:error, reason}",
         %{labels: labels} do
      chart_type = :bar
      title = "User Activity"

      series = [[]]

      {:error, "series must contain maps"} =
        LiveChartsHelper.generate_multi_series_maps_chart(series, labels, chart_type, title)
    end

    test "when provided series maps do not contain name key returns {:error, reason}",
         %{labels: labels, single_series: single_series} do
      chart_type = :bar
      title = "User Activity"

      series = [
        %{data: single_series},
        %{neme: "Likes", data: single_series}
      ]

      {:error, "series maps must contain :name field"} =
        LiveChartsHelper.generate_multi_series_maps_chart(series, labels, chart_type, title)
    end

    test "when provided series maps do not contain data key returns {:error, reason}",
         %{labels: labels, single_series: single_series} do
      chart_type = :bar
      title = "User Activity"

      series = [
        %{name: "Dislikes", dota: single_series},
        %{name: "Likes", data: single_series}
      ]

      {:error, "series maps must contain :data field"} =
        LiveChartsHelper.generate_multi_series_maps_chart(series, labels, chart_type, title)
    end

    test "when provided data fields do not contain numbers returns {:error, reason}",
         %{labels: labels, single_series: single_series} do
      chart_type = :bar
      title = "User Activity"

      series = [
        %{name: "Dislikes", data: [:a, :b, :c]},
        %{name: "Likes", data: single_series}
      ]

      {:error, "data fields must contain numbers"} =
        LiveChartsHelper.generate_multi_series_maps_chart(series, labels, chart_type, title)
    end

    test "when provided with incorrect type returns {:error, reason}",
         %{
           labels: labels,
           single_series: single_series,
           single_series2: single_series2
         } do
      chart_type = :beam
      title = "User Activity"
      series = [%{name: "Comments", data: single_series}, %{name: "Likes", data: single_series2}]

      {:error, "invalid type"} =
        LiveChartsHelper.generate_multi_series_maps_chart(series, labels, chart_type, title)
    end
  end
end
