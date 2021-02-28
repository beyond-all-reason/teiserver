defmodule CentralWeb.Logging.AggregateViewLogView do
  use CentralWeb, :view

  def colours(), do: Central.Logging.AggregateViewLogLib.colours()
  # def gradient(), do: {"#112266", "#6688CC"}
  def icon(), do: Central.Logging.AggregateViewLogLib.icon()

  def convert_load_time(load_time) do
    CentralWeb.Logging.PageViewLogView.convert_load_time(load_time)
    |> to_string
  end

  def heatmap(value, maximum, "green-red") do
    percentage = value / max(maximum, 1)

    [
      105 + percentage * 150,
      105 + (150 - percentage * 150),
      50
    ]
    |> Enum.map(fn colour ->
      colour
      |> round
      |> Integer.to_string(16)
      |> to_string
      |> String.pad_leading(2, "0")
    end)
    |> Enum.join("")
  end

  def heatmap(value, maximum, "red-green") do
    percentage = value / max(maximum, 1)

    [
      105 + (150 - percentage * 150),
      105 + percentage * 150,
      50
    ]
    |> Enum.map(fn colour ->
      colour
      |> round
      |> Integer.to_string(16)
      |> to_string
      |> String.pad_leading(2, "0")
    end)
    |> Enum.join("")
  end

  def heatmap(value, maximum, "white-green") do
    percentage = value / max(maximum, 1)

    [
      255 - percentage * 200,
      255,
      255 - percentage * 200
    ]
    |> Enum.map(fn colour ->
      colour
      |> round
      |> Integer.to_string(16)
      |> to_string
      |> String.pad_leading(2, "0")
    end)
    |> Enum.join("")
  end
end
