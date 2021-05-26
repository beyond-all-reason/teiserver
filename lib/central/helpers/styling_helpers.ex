defmodule Central.Helpers.StylingHelper do
  alias HTMLIcons

  @spec colours(atom) :: {String.t(), String.t(), String.t()}
  def colours(:default), do: {"#555555", "#E5E5E5", "secondary"}
  def colours(:report), do: {"#843534", "#f2dede", "danger"}

  def colours(:primary), do: {"#007bff", "#DDEEFF", "primary"}
  def colours(:primary2), do: {"#990088", "#FFEEFF", "primary2"}

  def colours(:info), do: {"#22AACC", "#EEFAFF", "info"}
  def colours(:info2), do: {"#17b0ad", "#DDF5F5", "info2"}

  def colours(:success), do: {"#22AA44", "#EEFFEE", "success"}
  def colours(:success2), do: {"#079110", "#CFD", "success2"}

  def colours(:warning), do: {"#ffb606", "#FFEEBB", "warning"}
  def colours(:warning2), do: {"#CC4400", "#FFDDCC", "warning2"}

  def colours(:danger), do: {"#e74c3c", "#FFF5F5", "danger"}
  def colours(:danger2), do: {"#AA1122", "#FEE", "danger2"}

  def colours(:negative), do: {"#", "#", "negative"}
  def colours(:negative2), do: {"#", "#", "negative2"}

  @spec get_fg(atom) :: String.t()
  def get_fg(colour), do: elem(colours(colour), 0)
  @spec get_bg(atom) :: String.t()
  def get_bg(colour), do: elem(colours(colour), 1)
  @spec get_bsname(atom) :: String.t()
  def get_bsname(colour), do: elem(colours(colour), 2)

  @spec icon(atom) :: String.t()
  def icon(:report), do: "fas fa-signal"
  def icon(:up), do: "fas fa-level-up"
  def icon(:back), do: "fas fa-arrow-left"

  def icon(:list), do: "fal fa-bars"
  def icon(:new), do: "fal fa-plus"
  def icon(:edit), do: "fal fa-wrench"
  def icon(:delete), do: "fal fa-trash"
  def icon(:export), do: "fal fa-download"
  def icon(:structure), do: "fal fa-cubes"
  def icon(:documentation), do: "fas fa-book"

  def icon(:admin), do: "fas fa-user-crown"
  def icon(:moderation), do: "fas fa-gavel"

  def icon(:overview), do: "fa-expand-alt"
  def icon(:detail), do: "fa-eye"

  def icon(:summary), do: "fal fa-user-chart"

  # This allows us to pass the function as a fake module for things
  # like sub_menu_icon
  def report_mod() do
    %{
      icon: icon(:report),
      colours: colours(:report)
    }
  end

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

  @spec hex_colour_list() :: [String.t()]
  def hex_colour_list() do
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
