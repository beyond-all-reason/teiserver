defmodule TeiserverWeb.LiveComponents.CommandPalette do
  @moduledoc """
  Adds a command palette to any liveview.

  <.live_component
    module={TeiserverWeb.LiveComponents.CommandPalette}
    id="cmd-palette"
    scope={@scope}
    extra_commands={[]}
  />

  TODO:
  - More customisable commands (we have goto and search so far)
  - Ability to have favourites and recently used
  - Styling preferences
  """

  alias Teiserver.Account.AuthLib
  alias Teiserver.Account.Scope

  use TeiserverWeb, :live_component

  @command_objects [
    %{id: "goto:home", cmd: :goto, label: "Goto: Home", path: "/"},
    %{id: "goto:admin", cmd: :goto, label: "Goto: Admin", path: "/admin", allow: ["Admin"]},
    %{
      id: "goto:moderation",
      cmd: :goto,
      label: "Goto: Moderation",
      path: "/moderation",
      allow: ["Moderator"]
    },
    %{
      id: "search:users",
      cmd: :search,
      label: "Search: Users",
      path: "/moderation/users",
      allow: ["Moderator"],
      search: %{
        input: :text,
        name: "name_or_email"
      }
    },
    %{
      id: "goto:actions",
      cmd: :goto,
      label: "Goto: Reports",
      path: "/moderation/report",
      allow: ["Overwatch"]
    },
    %{
      id: "goto:actions",
      cmd: :goto,
      label: "Goto: Actions",
      path: "/moderation/action",
      allow: ["Overwatch"]
    }
  ]

  attr :id, :any
  attr :scope, Scope
  attr :extra_commands, :list, default: []

  @impl LiveComponent
  def mount(socket) do
    socket
    |> assign(
      palette_open: false,
      query: "",
      all_commands: [],
      commands: [],
      selected_idx: 0,
      mode: :list
    )
    |> ok()
  end

  @impl LiveComponent
  def update(%{scope: %Scope{} = scope} = assigns, %Socket{} = socket) do
    extra_commands = parse_extra_commands(assigns[:extra_commands] || [])

    all_commands =
      (extra_commands ++ @command_objects)
      |> Enum.filter(fn
        %{allow: perms} -> AuthLib.allow?(scope, perms)
        _other -> true
      end)

    socket
    |> assign(assigns)
    |> assign(all_commands: all_commands, commands: Enum.with_index(all_commands))
    |> ok()
  end

  @impl LiveComponent
  def handle_event("toggle", _params, %Socket{assigns: %{palette_open: true}} = socket) do
    socket
    |> assign(palette_open: false)
    |> noreply()
  end

  def handle_event(
        "toggle",
        _params,
        %Socket{assigns: %{all_commands: all_commands, palette_open: _false?}} = socket
      ) do
    socket
    |> assign(palette_open: true, query: "", commands: Enum.with_index(all_commands), mode: :list)
    |> noreply()
  end

  def handle_event("execute-command", params, %Socket{assigns: assigns} = socket) do
    command_and_idx =
      if params["id"] do
        assigns.commands
        |> Enum.find(fn {cmd, _idx} -> cmd.id == params["id"] end)
      else
        Enum.at(assigns.commands, assigns.selected_idx)
      end

    case command_and_idx do
      {%{} = command, _idx} ->
        socket
        |> assign(selected_command: command)
        |> execute(command)
        |> noreply()

      _no_command ->
        socket
        |> close()
        |> noreply()
    end
  end

  def handle_event("execute-search", params, %Socket{assigns: assigns} = socket) do
    %{selected_command: command} = assigns

    # Drop any empty/nil params
    params = Map.filter(params, fn {_key, v} -> v != nil and v != "" end)

    # If no params then we just call the path as it is
    path =
      if Enum.empty?(params) do
        command.path
      else
        query = URI.encode_query(params)
        "#{command.path}?#{query}"
      end

    socket
    |> redirect(to: path)
    |> noreply()
  end

  def handle_event("close", _params, %Socket{} = socket) do
    socket
    |> close()
    |> noreply()
  end

  # Close on Escape key
  def handle_event("list-keydown", %{"key" => "Escape"}, %Socket{} = socket) do
    socket
    |> close()
    |> noreply()
  end

  def handle_event("list-keydown", %{"key" => "ArrowUp"}, %Socket{assigns: assigns} = socket) do
    new_selected_idx =
      if assigns.selected_idx > 0 do
        assigns.selected_idx - 1
      else
        nil
      end

    socket
    |> assign(selected_idx: new_selected_idx)
    |> noreply()
  end

  def handle_event("list-keydown", %{"key" => "ArrowDown"}, %Socket{assigns: assigns} = socket) do
    new_selected_idx =
      if assigns.selected_idx do
        assigns.selected_idx + 1
      else
        0
      end

    socket
    |> assign(selected_idx: new_selected_idx)
    |> noreply()
  end

  def handle_event("list-keydown", _params, %Socket{} = socket) do
    socket
    |> noreply()
  end

  # Close on Escape key
  def handle_event("search-keydown", %{"key" => "Escape"}, %Socket{} = socket) do
    socket
    |> close()
    |> noreply()
  end

  def handle_event("search-keydown", _params, %Socket{} = socket) do
    socket
    |> noreply()
  end

  def handle_event("filter-list", %{"query" => query}, %Socket{assigns: assigns} = socket) do
    query = String.downcase(query)

    commands =
      assigns.all_commands
      |> Enum.filter(fn %{label: label} ->
        label
        |> String.downcase()
        |> String.contains?(query)
      end)
      |> Enum.with_index()

    socket
    |> assign(query: query, commands: commands, selected_idx: 0)
    |> noreply()
  end

  def handle_event("ignore", _params, %Socket{} = socket) do
    socket
    |> noreply()
  end

  defp close(%Socket{} = socket) do
    assign(socket, palette_open: false)
  end

  defp execute(%Socket{} = socket, %{cmd: :goto, path: path} = _cmd) do
    socket
    |> redirect(to: path)
  end

  defp execute(%Socket{} = socket, %{cmd: :search} = _cmd) do
    socket
    |> assign(mode: :search)
  end

  # Takes the supplied commands and ensures they work as expected
  defp parse_extra_commands(commands) do
    commands
    |> Enum.filter(fn cmd ->
      Map.has_key?(cmd, :id) and
        Map.has_key?(cmd, :label) and
        Map.has_key?(cmd, :cmd)
    end)
  end

  @impl LiveComponent
  def render(assigns) do
    ~H"""
    <div
      id="command-palette"
      phx-hook="CommandPalette"
    >
      <div
        :if={@palette_open}
        class="fixed inset-0 bg-black/50 z-1000"
        phx-click="close"
        phx-target={@myself}
      >
        <div
          class="mx-auto mt-32 w-96 rounded-lg bg-base-100 p-2 shadow-xl"
          phx-click-away="close"
          phx-target={@myself}
        >
          <.list_mode
            :if={@mode == :list}
            target={@myself}
            query={@query}
            commands={@commands}
            selected_idx={@selected_idx}
          />

          <.search_mode
            :if={@mode == :search}
            target={@myself}
            command={@selected_command}
          />
        </div>
      </div>
    </div>
    """
  end

  defp list_mode(assigns) do
    ~H"""
    <div>
      <form
        id="cmd-palette-list-form"
        phx-change="filter-list"
        phx-submit="execute-command"
        phx-target={@target}
      >
        <input
          id="cmd-palette-list-filter"
          type="text"
          name="query"
          value={@query}
          placeholder="Type to filter"
          autocomplete="off"
          phx-keydown="list-keydown"
          phx-target={@target}
          class="w-full border-0 p-3 outline-none"
        />
      </form>

      <div class="mt-2">
        <span
          :for={{%{id: id, label: label}, idx} <- @commands}
          phx-click="execute-command"
          phx-target={@target}
          phx-value-id={id}
          class={[
            "block w-full rounded p-1 pl-2 text-left hover:bg-primary",
            @selected_idx == idx && "bg-primary/50"
          ]}
        >
          <span :if={@selected_idx == idx} class="float-right">
            <Fontawesome.icon icon="arrow-right" style="regular" />
          </span>
          {label}
        </span>

        <div :if={Enum.empty?(@commands)} class="p-2 text-gray-500">
          No results
        </div>
      </div>
    </div>
    """
  end

  defp search_mode(assigns) do
    ~H"""
    <div>
      <form
        id="cmd-palette-search-form"
        phx-submit="execute-search"
        phx-change="ignore"
        phx-target={@target}
      >
        <input
          :if={@command.search.input == :text}
          id="cmd-palette-search-input"
          type="text"
          name={@command.search.name}
          value=""
          placeholder="Hit enter to search"
          autocomplete="off"
          phx-keydown="search-keydown"
          phx-target={@target}
          class="w-full border-0 p-3 outline-none"
        />
      </form>
    </div>
    """
  end
end
