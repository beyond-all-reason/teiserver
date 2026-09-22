defmodule TeiserverWeb.LiveComponents.CmdPalette do
  @moduledoc """
  Adds a command palette to any liveview.

  <.live_component
    module={TeiserverWeb.LiveComponents.CmdPalette}
    id="cmd-palette"
    scope={@scope}
  />

  TODO:
  - Bound selected_idx to the number of commands listed
  - The moving up or down feels oddly slow, can't work out why
  - Add a way for additional contextual commands to be given to the component
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
      id: "goto:users-moderation",
      cmd: :goto,
      label: "Goto: Users (Moderation)",
      path: "/moderation/users",
      allow: ["Moderator"]
    },
    %{
      id: "goto:users-admin",
      cmd: :goto,
      label: "Goto: Users (Admin)",
      path: "/teiserver/admin/users",
      allow: ["Admin"]
    }
  ]

  attr :id, :any
  attr :scope, Scope

  @impl LiveComponent
  def mount(socket) do
    socket
    |> assign(palette_open: false, query: "", all_commands: [], commands: [], selected_idx: 0)
    |> ok()
  end

  @impl LiveComponent
  def update(%{scope: %Scope{} = scope} = assigns, %Socket{} = socket) do
    all_commands =
      @command_objects
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
    |> assign(palette_open: true, query: "", commands: Enum.with_index(all_commands))
    |> noreply()
  end

  def handle_event("execute", _params, %Socket{assigns: assigns} = socket) do
    case Enum.at(assigns.commands, assigns.selected_idx) do
      {%{} = command, _idx} ->
        socket
        |> execute(command)
        |> noreply()

      _no_command ->
        socket
        |> close()
        |> noreply()
    end
  end

  def handle_event("close", _params, %Socket{} = socket) do
    socket
    |> close()
    |> noreply()
  end

  # Close on Escape key
  def handle_event("keyup", %{"key" => "Escape"}, %Socket{} = socket) do
    socket
    |> close()
    |> noreply()
  end

  def handle_event("keyup", %{"key" => "ArrowUp"}, %Socket{assigns: assigns} = socket) do
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

  def handle_event("keyup", %{"key" => "ArrowDown"}, %Socket{assigns: assigns} = socket) do
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

  def handle_event("keyup", _params, %Socket{} = socket) do
    socket
    |> noreply()
  end

  def handle_event("search", %{"query" => query}, %Socket{assigns: assigns} = socket) do
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

  defp close(%Socket{} = socket) do
    assign(socket, palette_open: false)
  end

  defp execute(%Socket{} = socket, %{cmd: :goto, path: path} = _cmd) do
    socket
    |> redirect(to: path)
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
        class="fixed inset-0 bg-black/50"
        phx-click="close"
        phx-target={@myself}
      >
        <div
          class="mx-auto mt-32 w-96 rounded-lg bg-base-100 p-2 shadow-xl"
          phx-click-away="close"
          phx-target={@myself}
        >
          <form
            id="cmd-palette-form"
            phx-change="search"
            phx-submit="execute"
            phx-target={@myself}
          >
            <input
              id="cmd-palette-input"
              type="text"
              name="query"
              value={@query}
              placeholder=">"
              autocomplete="off"
              phx-keyup="keyup"
              phx-target={@myself}
              class="w-full border-0 p-3 outline-none"
            />
          </form>

          <div class="mt-2">
            <span
              :for={{%{id: id, label: label}, idx} <- @commands}
              phx-click="execute"
              phx-target={@myself}
              phx-value-id={id}
              class={[
                "block w-full rounded p-1 text-left hover:bg-primary",
                @selected_idx == idx && "bg-primary/50"
              ]}
            >
              {label}
            </span>

            <div :if={Enum.empty?(@commands)} class="p-2 text-gray-500">
              No results
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
