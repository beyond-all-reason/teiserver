defmodule TeiserverWeb.LiveComponents.UserPicker do
  @moduledoc """
  Designed to be used as part of a form as an input. When compressed it will show a text field but when in selection mode it will expand to allow for searching of users.

  It will submit the ID value of the selected user but will display the ID and name of the user.

  <.live_component
      module={TeiserverWeb.LiveComponents.UserPicker}
      id="user-picker"
      field={@form[:smurf_user_id]}
      label="User to link to:"
    />
  """
  alias Teiserver.Account.User
  alias Teiserver.Account.UserQueries
  alias Teiserver.Repo
  alias TeiserverWeb.CoreComponents

  use TeiserverWeb, :live_component

  import Ecto.Query, only: [limit: 2]

  @display_limit 10
  @debounce 250

  attr :id, :any

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:user]",
    default: nil

  attr :name, :any
  attr :label, :any, default: nil
  attr :value, User, default: nil
  attr :ignore_ids, :list, default: []
  attr :search_term, :string, default: ""

  def render(assigns) do
    ~H"""
    <div>
      <div>
        <CoreComponents.label :if={@label} for={@id}>{@label}</CoreComponents.label>

        <div class="w-full inline-flex border rounded-lg">
          <div
            class="w-15 text-center pt-3 bg-green-400 text-green-900 dark:bg-green-800 dark:text-green-50 cursor-pointer rounded-l-lg user-picker-search-button"
            phx-click={
              JS.push("show-picker")
              |> JS.toggle(to: "##{@uniq_id}-picker-form")
              |> JS.focus(to: "##{@uniq_id}-search-input")
            }
            phx-target={@myself}
          >
            <i class="fa-solid fa-lg fa-fw fa-magnifying-glass"></i>
          </div>

          <.input_tw
            name="none"
            value={@shown_value}
            placeholder="Click green button to search"
          />
          <.input_tw
            field={@field}
            value={@actual_value}
            type="hidden"
          />
        </div>

        <.picker_form
          show={@show_form?}
          search_term={@search_term}
          myself={@myself}
          users={@users}
          uniq_id={@uniq_id}
        />
      </div>
    </div>
    """
  end

  def mount(socket) do
    socket
    |> assign(users: [], show_form?: false, uniq_id: generate_id(), ignore_ids: [])
    |> ok()
  end

  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> update_input_values()
    |> update_search()
    |> ok()
  end

  def handle_event("show-picker", _params, socket) do
    socket
    |> assign(show_form?: true)
    |> noreply()
  end

  def handle_event("hide-picker", _params, socket) do
    socket
    |> assign(show_form?: false)
    |> noreply()
  end

  def handle_event("update-search", %{"value" => search_term}, socket) do
    socket
    |> assign(search_term: search_term)
    |> update_search()
    |> noreply()
  end

  def handle_event("select-user", %{"user_id" => str_id}, socket) do
    user_id = String.to_integer(str_id)

    user =
      socket.assigns.users
      |> Enum.find(fn user -> user.id == user_id end)

    socket
    |> assign(value: user, show_form?: false, users: [])
    |> update_input_values()
    |> noreply()
  end

  # We use this to allow us to have multiple pickers on the same page
  # and their IDs won't overlap
  defp generate_id do
    alphabet = ~c"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

    1..20
    |> Enum.map(fn _idx -> Enum.random(alphabet) end)
    |> List.to_string()
  end

  defp update_input_values(%{assigns: assigns} = socket) do
    shown_value =
      case assigns[:value] do
        nil -> nil
        %User{id: id, name: name} -> "##{id} - #{name}"
      end

    actual_value =
      case assigns[:value] do
        nil -> nil
        %User{id: id} -> id
      end

    socket
    |> assign(shown_value: shown_value, actual_value: actual_value)
  end

  defp update_search(
         %{
           assigns: %{
             search_term: raw_search_term,
             ignore_ids: ignore_ids
           }
         } = socket
       ) do
    search_term = String.trim(raw_search_term)

    found_user = search_by_id(search_term, ignore_ids)
    exact_matches = search_for_exact_name_match(search_term, ignore_ids)

    # If we found a user through ID search we want to put that at the front
    # of the exact matches
    exact_matches = Enum.reject([found_user | exact_matches], &is_nil(&1))
    found_ids = Enum.map(exact_matches, & &1.id)

    users = search_by_name_like(search_term, found_ids ++ ignore_ids)

    socket
    |> assign(users: exact_matches ++ users)
  end

  # No search term
  defp update_search(socket), do: socket

  defp search_by_id("", _ignore_ids), do: nil

  defp search_by_id(search_term, ignore_ids) do
    case Integer.parse(search_term) do
      {number, _rem} ->
        UserQueries.users()
        |> UserQueries.where_id(number)
        |> UserQueries.where_id_not_in(ignore_ids)
        |> limit(1)
        |> Repo.one()

      _error ->
        nil
    end
  end

  # Case sensitive name match
  defp search_for_exact_name_match("", _ignore_ids), do: []

  defp search_for_exact_name_match(search_term, ignore_ids) do
    UserQueries.users()
    |> UserQueries.where_name(search_term)
    |> UserQueries.where_id_not_in(ignore_ids)
    |> Repo.all()
  end

  defp search_by_name_like("", _ignore_ids), do: []

  defp search_by_name_like(search_term, ignore_ids) do
    # We display at most N users, exact matches always come first
    query_limit = @display_limit - Enum.count(ignore_ids)

    UserQueries.users()
    |> UserQueries.where_name_like(search_term)
    |> UserQueries.where_id_not_in(ignore_ids)
    |> UserQueries.order_by_name()
    |> limit(^query_limit)
    |> Repo.all()
  end

  @doc """
  <.picker_form
    show={@show_form?}
    search_term={@search_term}
    myself={@myself}
    users={@users}
    uniq_id={@uniq_id}
  />
  """
  attr :uniq_id, :string
  attr :search_term, :string, default: ""
  attr :myself, :any, required: true
  attr :show, :boolean, required: false
  attr :users, :list, default: []

  def picker_form(assigns) do
    assigns =
      assigns
      |> assign(debounce: @debounce)

    ~H"""
    <div class={["mt-2", not @show && "hidden"]} id={"#{@uniq_id}-picker-form"}>
      Search for user by name or ID, search will take place as soon as you stop typing
      <.input
        id={"#{@uniq_id}-search-input"}
        name="user-search-term"
        value={@search_term}
        phx-keyup="update-search"
        phx-debounce={@debounce}
        phx-target={@myself}
        class="w-full input user-picker-search-input"
        placeholder="Search by name"
      />

      <.table
        :if={not Enum.empty?(@users)}
        id="users-table"
        rows={@users}
        table_class="table-sm table-hover user-picker-search-results"
      >
        <:col :let={user} label="Name">
          <div
            class="cursor-pointer"
            phx-click={
              JS.push("select-user", value: %{user_id: to_string(user.id)})
              |> JS.toggle(to: "##{@uniq_id}-picker-form")
            }
            phx-value-user_id={user.id}
            phx-target={@myself}
          >
            <i class={"fa-fw fa-solid #{user.icon} fa-lg"} style={"color: #{user.colour}"} />
            {user.name}
          </div>
        </:col>
      </.table>
    </div>
    """
  end
end
