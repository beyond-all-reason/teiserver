defmodule Teiserver.Helper.ColourHelper do
  @moduledoc false

  alias Teiserver.Helper.ColourHelper

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
    |> new()
    |> as_css_style(custom_alpha)
  end
end
