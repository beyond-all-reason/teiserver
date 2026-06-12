defmodule TeiserverWeb.LiveComponents.UserPicker do
  @moduledoc """
  Designed to be used as part of a form as an input. When compressed it will show a text field but when in selection mode it will expand to allow for searching of users.

  <.live_component module={TeiserverWeb.LiveComponents.UserPicker}
    id="user-picker"
    name="user-picker"
    label="User search:"
    field={@form[:email]}
  />

  <.live_component
      module={TeiserverWeb.LiveComponents.UserPicker}
      id="user-picker"
      name="user-picker"
      label="User search:"
      value={}
    />
  """
  alias Teiserver.Account.User
  alias Teiserver.Account.UserQueries
  alias Teiserver.Repo
  alias TeiserverWeb.CoreComponents

  use TeiserverWeb, :live_component

  import Ecto.Query, only: [limit: 2]

  @display_limit 10

  attr :id, :any

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:user]",
    default: nil

  attr :name, :any
  attr :label, :any, default: nil
  attr :value, User, default: nil
  attr :search_term, :string, default: ""

  def render(%{field: nil} = assigns) do
    ~H"""
    <div>
      <CoreComponents.label :if={@label} for={@id}>{@label}</CoreComponents.label>
      <div class="input-group">
        <span class="input-group-prepend">
          <span
            class="input-group-addon btn-primary btn-outline btn"
            phx-click="show-picker"
            phx-target={@myself}
          >
            <i class="fa-solid fa-fw fa-magnifying-glass"></i>
          </span>
        </span>
        <.input
          name={@name}
          value={@input_value}
          disabled="disabled"
          placeholder=""
        />

        <.picker_form :if={@show_form?} search_term={@search_term} myself={@myself} users={@users} />
      </div>
    </div>
    """
  end

  # Render with a field, need to have the value we show be useful to the user
  # but the value submitted be the ID
  def render(assigns) do
    ~H"""
    <div>
      Not implemented yet
    </div>
    """
  end

  def mount(socket) do
    socket
    |> assign(users: [], show_form?: false)
    |> ok()
  end

  def update(assigns, socket) do
    socket
    |> assign(assigns)
    |> update_input_value()
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
    |> assign(value: user, show_form?: false)
    |> update_input_value()
    |> noreply()
  end

  defp update_input_value(%{assigns: assigns} = socket) do
    input_value =
      case assigns[:value] do
        nil -> nil
        %User{id: id, name: name} -> "##{id} - #{name}"
      end

    socket
    |> assign(input_value: input_value)
  end

  defp update_search(%{assigns: %{search_term: raw_search_term}} = socket) do
    search_term = String.trim(raw_search_term)

    found_user = search_by_id(search_term)
    exact_matches = search_for_exact_name_match(search_term)

    # If we found a user through ID search we want to put that at the front
    # of the exact matches
    exact_matches = Enum.reject([found_user | exact_matches], &is_nil(&1))
    found_ids = Enum.map(exact_matches, & &1.id)

    users = search_by_name_like(search_term, found_ids)

    socket
    |> assign(users: exact_matches ++ users)
  end

  # No search term
  defp update_search(socket), do: socket

  defp search_by_id(""), do: nil

  defp search_by_id(search_term) do
    case Integer.parse(search_term) do
      {number, _rem} ->
        UserQueries.users()
        |> UserQueries.where_id(number)
        |> limit(1)
        |> Repo.one()

      _error ->
        nil
    end
  end

  # Case sensitive name match
  defp search_for_exact_name_match(""), do: []

  defp search_for_exact_name_match(search_term) do
    UserQueries.users()
    |> UserQueries.where_name(search_term)
    |> Repo.all()
  end

  defp search_by_name_like("", _ids), do: []

  defp search_by_name_like(search_term, found_ids) do
    # We display at most N users, exact matches always come first
    query_limit = @display_limit - Enum.count(found_ids)

    UserQueries.users()
    |> UserQueries.where_name_like(search_term)
    |> UserQueries.where_id_not_in(found_ids)
    |> UserQueries.order_by_name()
    |> limit(^query_limit)
    |> Repo.all()
  end

  @doc """
  <.picker_form name={"name"} />
  """
  attr :search_term, :string, default: ""
  attr :myself, :any, required: true
  attr :users, :list, default: []

  def picker_form(assigns) do
    ~H"""
    <.modal id="user-picker-search" on_cancel={JS.push("hide-picker", target: @myself)}>
      Search for user by name or ID
      <.input
        id="user-picker-search-input"
        name="user-search-term"
        value={@search_term}
        phx-keyup="update-search"
        phx-debounce="500"
        phx-target={@myself}
        placeholder="Search by name"
      />

      <.table
        :if={not Enum.empty?(@users)}
        id="users-table"
        rows={@users}
        table_class="table-sm table-hover"
      >
        <:col :let={user} label="Name">
          <div
            class="cursor-pointer"
            phx-click="select-user"
            phx-value-user_id={user.id}
            phx-target={@myself}
          >
            <i class={"fa-fw fa-solid #{user.icon} fa-lg"} style={"color: #{user.colour}"} />
            {user.name}
          </div>
        </:col>
      </.table>
    </.modal>
    """
  end
end
