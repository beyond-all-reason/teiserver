defmodule TeiserverWeb.User.FpChannel do
  @moduledoc false
  use Phoenix.Channel
  alias Teiserver.Account

  def join("fp", _params, socket) do
    {:ok, socket}
  end

  def handle_in("fp-value", %{"value" => value}, %{assigns: %{current_user: %{id: userid}}} = socket) do
    # Account.create_smurf_key(userid, "wb1", to_string(value))
    {:noreply, socket}
  end

  def handle_in(_topic, _params, socket) do
    {:noreply, socket}
  end
end
