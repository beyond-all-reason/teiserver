defmodule Teiserver.Helper.StylingHelper do
  @moduledoc false
  alias HTMLIcons

  @spec colours(atom) :: {String.t(), String.t(), String.t()}
  def colours(a), do: colours(a, false)

  @spec colours(atom, boolean) :: {String.t(), String.t(), String.t()}
  # Light mode false
  def colours(:default, false), do: {"#555555", "#111", "secondary"}

  def colours(:primary, false), do: {"#274aAf", "#002", "primary"}
  def colours(:primary2, false), do: {"#3498db", "#012", "primary2"}

  def colours(:info, false), do: {"#008987", "#022", "info"}
  def colours(:info2, false), do: {"#A90088", "#220011", "info2"}

  def colours(:success, false), do: {"#108c1a", "#020", "success"}
  def colours(:success2, false), do: {"#005c0a", "#010", "success2"}

  def colours(:warning, false), do: {"#c37c02", "#210", "warning"}
  def colours(:warning2, false), do: {"#CC4400", "#110", "warning2"}

  def colours(:danger, false), do: {"#a4382c", "#200", "danger"}
  def colours(:danger2, false), do: {"#800000", "#100", "danger2"}

  # Light mode true
  def colours(:default, true), do: {"#555555", "#E5E5E5", "secondary"}

  def colours(:primary, true), do: {"#007bff", "#DDEEFF", "primary"}
  def colours(:primary2, true), do: {"#990088", "#FFEEFF", "primary2"}

  def colours(:info, true), do: {"#22AACC", "#EEFAFF", "info"}
  def colours(:info2, true), do: {"#17b0ad", "#DDF5F5", "info2"}

  def colours(:success, true), do: {"#22AA44", "#EEFFEE", "success"}
  def colours(:success2, true), do: {"#079110", "#CFD", "success2"}

  def colours(:warning, true), do: {"#ffb606", "#FFEEBB", "warning"}
  def colours(:warning2, true), do: {"#CC4400", "#FFDDCC", "warning2"}

  def colours(:danger, true), do: {"#e74c3c", "#FFF5F5", "danger"}
  def colours(:danger2, true), do: {"#AA1122", "#FEE", "danger2"}

  @spec get_fg(atom) :: String.t()
  def get_fg(colour), do: elem(colours(colour), 0)

  @spec get_bg(atom) :: String.t()
  def get_bg(colour), do: elem(colours(colour), 1)

  @spec get_bsname(atom) :: String.t()
  def get_bsname(colour), do: elem(colours(colour), 2)

  @spec icon(atom) :: String.t()
  def icon(nil), do: nil
  def icon(atom), do: icon(atom, "solid")

  @spec icon(atom, String.t()) :: String.t()
  def icon(nil, _), do: nil
  def icon(:report, fa_type), do: "fa-#{fa_type} fa-signal"
  def icon(:up, fa_type), do: "fa-#{fa_type} fa-level-up"
  def icon(:back, fa_type), do: "fa-#{fa_type} fa-arrow-left"

  def icon(:list, _fa_type), do: "fa-bars"
  def icon(:show, fa_type), do: "fa-#{fa_type} fa-eye"
  def icon(:search, fa_type), do: "fa-#{fa_type} fa-search"
  def icon(:new, fa_type), do: "fa-#{fa_type} fa-plus"
  def icon(:edit, fa_type), do: "fa-#{fa_type} fa-wrench"
  def icon(:delete, fa_type), do: "fa-#{fa_type} fa-trash"
  def icon(:export, fa_type), do: "fa-#{fa_type} fa-download"
  def icon(:structure, fa_type), do: "fa-#{fa_type} fa-cubes"
  def icon(:documentation, fa_type), do: "fa-#{fa_type} fa-book"
  def icon(:chat, fa_type), do: "fa-#{fa_type} fa-comment"
  def icon(:live_view, _fa_type), do: "fa-brands fa-phoenix-framework"

  def icon(:admin, fa_type), do: "fa-#{fa_type} fa-user-crown"
  def icon(:moderation, fa_type), do: "fa-#{fa_type} fa-gavel"

  def icon(:overview, fa_type), do: "fa-#{fa_type} fa-expand-alt"
  def icon(:detail, fa_type), do: "fa-#{fa_type} fa-file-alt"
  def icon(:user, fa_type), do: "fa-#{fa_type} fa-user"

  def icon(:filter, fa_type), do: "fa-#{fa_type} fa-filter"

  def icon(:summary, fa_type), do: "fa-#{fa_type} fa-clipboard-list"

  def icon(:chart, _fa_type), do: "fa-solid fa-chart-line"

  def icon(:day, _fa_type), do: ""
  def icon(:week, _fa_type), do: ""
  def icon(:month, _fa_type), do: ""
  def icon(:quarter, _fa_type), do: ""
  def icon(:year, _fa_type), do: ""

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
      bat cat crow deer dog dolphin dove duck elephant fish horse kiwi-bird otter pig rabbit sheep squirrel turtle unicorn
      car truck plane paper-plane rocket ship space-shuttle truck-monster
      beer bowl-hot flask martini-glass wine-bottle paw-claws
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

  # Stand out colours
  @spec bright_hex_colour_list() :: [String.t()]
  def bright_hex_colour_list() do
    [
      "#CC0000",
      "#00CC00",
      "#0000CC",
      "#CC00CC",
      "#00CCCC",
      "#CCCC00"
    ]
  end

  @spec random_colour() :: String.t()
  def random_colour() do
    Enum.random(hex_colour_list())
  end

  @spec random_styling() :: map()
  def random_styling() do
    %{
      "icon" => "fa-solid fa-" <> random_icon(),
      "colour" => random_colour()
    }
  end

  @spec random_styling(map()) :: map()
  def random_styling(input_dict) do
    Map.merge(random_styling(), input_dict)
  end
end
