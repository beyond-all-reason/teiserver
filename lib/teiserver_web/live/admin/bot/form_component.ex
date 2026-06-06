defmodule TeiserverWeb.Admin.BotLive.FormComponent do
  alias Teiserver.Bot

  use TeiserverWeb, :live_component

  @impl LiveComponent
  def render(assigns) do
    ~H"""
    <div>
      <.header>{@title}</.header>
      <.simple_form
        for={@form}
        id="bot-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />
        <:actions>
          <.button phx-disable-with="Saving...">Save</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl LiveComponent
  def update(%{bot: bot} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn -> to_form(Bot.change_bot(bot)) end)}
  end

  @impl LiveComponent
  def handle_event("validate", %{"bot" => params}, socket) do
    changeset = Bot.change_bot(socket.assigns.bot, params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"bot" => params}, socket) do
    case socket.assigns.action do
      :new -> save(socket, Bot.create_bot(params))
      :edit -> save(socket, Bot.update_bot(socket.assigns.bot, params))
    end
  end

  defp save(socket, {:ok, bot}) do
    send(self(), {__MODULE__, {:saved, bot}})

    {:noreply,
     socket
     |> put_flash(:info, "Saved!")
     |> push_patch(to: socket.assigns.patch)}
  end

  defp save(socket, {:error, changeset}) do
    {:noreply, assign(socket, form: to_form(changeset))}
  end
end
