defmodule Central.Helpers.StylingHelper do
  @moduledoc false
  alias HTMLIcons

  @spec colours(atom) :: {String.t(), String.t(), String.t()}
  def colours(:default), do: {"#555555", "#111", "secondary"}
  def colours(:report), do: colours(:danger)

  def colours(:primary), do: {"#274aAf", "#002", "primary"}
  def colours(:primary2), do: {"#3498db", "#012", "primary2"}

  def colours(:info), do: {"#008987", "#022", "info"}
  def colours(:info2), do: {"#A90088", "#011", "info2"}

  def colours(:success), do: {"#108c1a", "#020", "success"}
  def colours(:success2), do: {"#005c0a", "#010", "success2"}

  def colours(:warning), do: {"#c37c02", "#210", "warning"}
  def colours(:warning2), do: {"#CC4400", "#110", "warning2"}

  def colours(:danger), do: {"#a4382c", "#200", "danger"}
  def colours(:danger2), do: {"#800000", "#100", "danger2"}

  def colours(:negative), do: {"#", "#", "negative"}
  def colours(:negative2), do: {"#", "#", "negative2"}

  @spec get_fg(atom) :: String.t()
  def get_fg(colour), do: elem(colours(colour), 0)

  @spec get_bg(atom) :: String.t()
  def get_bg(colour), do: elem(colours(colour), 1)

  @spec get_bsname(atom) :: String.t()
  def get_bsname(colour), do: elem(colours(colour), 2)

  @spec icon(atom) :: String.t()
  def icon(atom), do: icon(atom, "solid")

  @spec icon(atom, String.t()) :: String.t()
  def icon(:report, fa_type), do: "fa-#{fa_type} fa-signal"
  def icon(:up, fa_type), do: "fa-#{fa_type} fa-level-up"
  def icon(:back, fa_type), do: "fa-#{fa_type} fa-arrow-left"

  def icon(:list, fa_type), do: "fa-#{fa_type} fa-bars"
  def icon(:show, fa_type), do: "fa-#{fa_type} fa-eye"
  def icon(:search, fa_type), do: "fa-#{fa_type} fa-search"
  def icon(:new, fa_type), do: "fa-#{fa_type} fa-plus"
  def icon(:edit, fa_type), do: "fa-#{fa_type} fa-wrench"
  def icon(:delete, fa_type), do: "fa-#{fa_type} fa-trash"
  def icon(:export, fa_type), do: "fa-#{fa_type} fa-download"
  def icon(:structure, fa_type), do: "fa-#{fa_type} fa-cubes"
  def icon(:documentation, fa_type), do: "fa-#{fa_type} fa-book"

  def icon(:admin, fa_type), do: "fa-#{fa_type} fa-user-crown"
  def icon(:moderation, fa_type), do: "fa-#{fa_type} fa-gavel"

  def icon(:overview, fa_type), do: "fa-#{fa_type} fa-expand-alt"
  def icon(:detail, fa_type), do: "fa-#{fa_type} fa-eye"

  def icon(:summary, fa_type), do: "fa-#{fa_type} fa-user-chart"

  # defp split_colour(c) do
  #   {r, _} = c |> String.slice(1, 2) |> Integer.parse(16)
  #   {g, _} = c |> String.slice(3, 2) |> Integer.parse(16)
  #   {b, _} = c |> String.slice(5, 2) |> Integer.parse(16)

  #   {r, g, b}
  # end

  # defp colour_steps({r1, g1, b1}, {r2, g2, b2}, step_count) do
  #   {
  #     (r2 - r1) / step_count,
  #     (g2 - g1) / step_count,
  #     (b2 - b1) / step_count
  #   }
  # end

  # def spinner_css({a, b}) do
  #   steps = 5

  #   {r1, g1, b1} = a = split_colour(a)
  #   b = split_colour(b)

  #   {rstep, gstep, bstep} = colour_steps(a, b, steps)

  #   0..steps
  #   |> Enum.map(fn step ->
  #     [
  #       r1 + (rstep * step),
  #       g1 + (gstep * step),
  #       b1 + (bstep * step),
  #     ]
  #     |> Enum.map(fn i ->
  #        i
  #        |> round
  #        |> Integer.to_string(16)
  #        |> to_string
  #        |> String.pad_leading(2, "0")
  #     end)
  #     |> Enum.join("")
  #   end)
  #   |> Enum.with_index
  #   |> Enum.map(fn {c, i} ->
  #     ".spinner .rect#{i} {background-color: ##{c};}"
  #   end)
  #   |> Enum.join("\n")
  # end

  @random_icons ~w(
      club diamond heart spade
      bat cat crow deer dog dove duck fish horse pig rabbit unicorn
      car truck plane paper-plane rocket ship truck-monster
      beer flask glass-martini wine-bottle paw-claws
      bed suitcase star badge shovel handshake shopping-cart camera cube hammer-war lightbulb
      utensil-fork utensil-knife utensil-spoon
      chess-pawn chess-bishop chess-knight chess-rook chess-king chess-queen
      hat-cowboy mitten
      apple-alt birthday-cake bread-slice carrot cheese drumstick gingerbread-man hamburger lemon salad taco ice-cream
      bullhorn spa tree-palm
      cloud moon snowflake umbrella volcano sun-haze)

  @spec random_icon() :: String.t()
  def random_icon() do
    Enum.random(@random_icons)
  end

  # If you are using a dark theme it's probably best to call the light list
  @spec hex_colour_list() :: [String.t()]
  def hex_colour_list(), do: light_hex_colour_list()

  # For light mode, darker colours
  @spec dark_hex_colour_list() :: [String.t()]
  def dark_hex_colour_list() do
    [
      "#AA3333",
      "#990505",
      "#DD8833",
      "#572500",
      "#33AA33",
      "#009900",
      "#3333AA",
      "#112299",
      "#AA33AA",
      "#4E00A8",
      "#A80051",
      "#33AACC",
      "#00978C",
      "#000000",
      "#444455"
    ]
  end

  # For dark mode, lighter colours
  @spec light_hex_colour_list() :: [String.t()]
  def light_hex_colour_list() do
    [
      "#FF7777",
      "#CC4433",
      "#FFCC00",
      "#DD8833",
      "#AA5522",
      "#33CC33",
      "#00AA00",
      "#8888FF",
      "#3344FF",
      "#FF44FF",
      "#C82261",
      "#33AACC",
      "#00878C",
      "#FFFFFF",
      "#9999AA"
    ]
  end

  @spec random_colour() :: String.t()
  def random_colour() do
    Enum.random(hex_colour_list())
  end

  @spec random_styling() :: Map.t()
  def random_styling() do
    %{
      "icon" => "far fa-" <> random_icon(),
      "colour" => random_colour()
    }
  end

  @spec random_styling(Map.t()) :: Map.t()
  def random_styling(input_dict) do
    Map.merge(random_styling(), input_dict)
  end
end
