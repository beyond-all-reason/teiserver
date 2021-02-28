defmodule Central.Helpers.ColourHelper do
  @moduledoc """
  """

  alias Central.Helpers.ColourHelper

  defstruct red: 0,
            green: 0,
            blue: 0,
            alpha: 0

  defp hexc(v), do: String.to_integer(v, 16)

  # FROM RGB
  # def new(r, g, b, a) when is_integer(r) do
  #   %ColourHelper{red: r, green: g, blue: b, alpha: a}
  # end

  # FROM HEX
  # def new(r, g, b, a) do
  #   %ColourHelper{
  #     red: hexc(r),
  #     green: hexc(g),
  #     blue: hexc(b),
  #     alpha: a
  #   }
  # end

  # FROM RGB
  # def new(r, g, b) when is_integer(r) do
  #   %ColourHelper{red: r, green: g, blue: b, alpha: 1}
  # end

  # FROM HEX
  def new(r, g, b) do
    %ColourHelper{
      red: hexc(r),
      green: hexc(g),
      blue: hexc(b),
      alpha: 1
    }
  end

  # def new(nil), do: new("#000000")
  # def new(""), do: new("#000000")
  # def new("primary"), do: new("#007bff")
  # def new("primary2"), do: new("#990088")

  # def new("info"), do: new("#22AACC")
  # def new("info2"), do: new("#17b0ad")

  # def new("success"), do: new("#22AA44")
  # def new("success2"), do: new("#079110")

  # def new("warning"), do: new("#ffb606")
  # def new("warning2"), do: new("#CC4400")

  # def new("danger"), do: new("#e74c3c")
  # def new("danger2"), do: new("#AA1122")

  # def new("negative"), do: new("#AAAAAA")
  # def new("negative2"), do: new("#777777")

  def new(rgb_string) do
    rgb_list =
      rgb_string
      |> String.replace("#", "")
      |> String.split("", trim: true)

    [r, rr, g, gg, b, bb] =
      case Enum.count(rgb_list) do
        3 ->
          [r, g, b] = rgb_list
          [r, r, g, g, b, b]

        6 ->
          rgb_list
      end

    new("#{r}#{rr}", "#{g}#{gg}", "#{b}#{bb}")
  end

  # def as_rgb(c) do
  #   [c.red, c.green, c.blue]
  # end

  # def as_rgba(c) do
  #   [c.red, c.green, c.blue, c.alpha]
  # end

  def as_css_style(c) do
    "rgba(#{c.red}, #{c.green}, #{c.blue}, #{c.alpha})"
  end

  def as_css_style(c, custom_alpha) do
    "rgba(#{c.red}, #{c.green}, #{c.blue}, #{custom_alpha})"
  end

  def rgba_css(nil), do: ""

  def rgba_css(colour, custom_alpha \\ 0.1) do
    colour
    |> new
    |> as_css_style(custom_alpha)
  end
end
