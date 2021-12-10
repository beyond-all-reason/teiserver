defmodule CentralWeb.Communication.NotificationChannel do
  @moduledoc false
  use Phoenix.Channel

  def join("communication_notification:" <> user_id, _params, socket) do
    if socket.assigns[:current_user].id == user_id |> String.to_integer() do
      {:ok, socket}
    else
      {:error, "Permission denied"}
    end
  end

  # Used to follow when an update to a piece of content happens
  # no sensetive data is sent here so we don't need to worry about
  # authing
  def join("communication_reloads:" <> _, _params, socket) do
    {:ok, socket}
  end
end
