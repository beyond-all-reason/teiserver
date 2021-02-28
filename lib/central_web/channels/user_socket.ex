defmodule CentralWeb.UserSocket do
  use Phoenix.Socket

  alias Central.Account.Guardian

  ## Channels
  # channel "room:*", CentralWeb.RoomChannel

  channel("load_test:*", CentralWeb.LoadTest.Channel)
  channel("live_search:*", CentralWeb.LiveSearch.Channel)
  channel("chat:*", CentralWeb.Chat.Channel)
  channel("communication_notification:*", CentralWeb.Communication.NotificationChannel)
  channel("communication_reloads:*", CentralWeb.Communication.NotificationChannel)

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  # To deny connection, return `:error`.
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
  # def connect(_params, socket, _connect_info) do
  #   {:ok, socket}
  # end

  # Guests would fire this function
  @impl true
  def connect(%{"token" => ""}, socket) do
    {:ok, socket}
  end

  # Accounts seeking to say they are someone use this
  @impl true
  def connect(%{"token" => token}, socket) do
    case Guardian.resource_from_token(token) do
      {:error, _error} ->
        :error

      {:ok, user, _claims} ->
        {:ok,
         socket
         |> assign(:current_user, user)}
    end
  end

  @impl true
  def connect(_params, _socket) do
    :error
  end

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     CentralWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  @impl true
  def id(_socket), do: nil
end
