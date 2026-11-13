defmodule Teiserver.Helpers.LiveChartsHelper do
  @doc false

  def get_chart_types do
    [:line,
:area,
:bar,
:pie,
:donut,
:radialBar,
:scatter,
:bubble,
:heatmap,
:candlestick,
:boxPlot,
:radar,
:polarArea,
:rangeBar,
:rangeArea,
:violin,
:histogram,
:treemap,
:sunburst,
:icicle,
:funnel,
:pyramid,
:gauge]
  end
end
