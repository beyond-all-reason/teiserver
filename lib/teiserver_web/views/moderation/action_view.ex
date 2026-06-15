defmodule TeiserverWeb.Moderation.ActionView do
  @moduledoc false

  alias Teiserver.Moderation.ActionLib

  use TeiserverWeb, :view

  import TeiserverWeb.PaginationComponents, only: [pagination: 1]

  @spec view_colour() :: atom
  def view_colour, do: ActionLib.colour()

  @spec icon() :: String.t()
  def icon, do: ActionLib.icon()

  def action_status(assigns) do
    ~H"""
    <%= cond do %>
      <% @action.expires != nil and NaiveDateTime.compare(NaiveDateTime.utc_now(), @action.expires) == :gt -> %>
        <td>Expired</td>
        <td>{duration_to_str(@action.inserted_at, @action.expires)}</td>
      <% @action.expires != nil -> %>
        <td>{@action.expires |> date_to_str(format: :ymd_hms24)}</td>
        <td>{duration_to_str(@action.inserted_at, @action.expires)}</td>
      <% @action.duration != nil -> %>
        <td class="text-info">Pending acknowledgement</td>
        <td>{format_duration(@action.duration)}</td>
      <% true -> %>
        <td colspan="2" class="text-warning">Permanent</td>
    <% end %>
    """
  end

  @spec format_duration(integer() | nil) :: String.t()
  def format_duration(nil), do: "Permanent"

  def format_duration(seconds) do
    cond do
      seconds >= 86_400 * 365 -> "#{div(seconds, 86_400 * 365)} year(s)"
      seconds >= 86_400 * 30 -> "#{div(seconds, 86_400 * 30)} month(s)"
      seconds >= 86_400 -> "#{div(seconds, 86_400)} day(s)"
      seconds >= 3_600 -> "#{div(seconds, 3_600)} hour(s)"
      true -> "#{div(seconds, 60)} minute(s)"
    end
  end

  @spec seconds_to_duration_input(integer() | nil) :: String.t()
  def seconds_to_duration_input(nil), do: ""

  def seconds_to_duration_input(seconds) do
    cond do
      rem(seconds, 86_400 * 365) == 0 -> "#{div(seconds, 86_400 * 365)}y"
      rem(seconds, 86_400 * 30) == 0 -> "#{div(seconds, 86_400 * 30)}m"
      rem(seconds, 86_400) == 0 -> "#{div(seconds, 86_400)}d"
      rem(seconds, 3_600) == 0 -> "#{div(seconds, 3_600)}h"
      true -> "#{seconds}s"
    end
  end
end
