defmodule TeiserverWeb.ChatComponents do
  @moduledoc false
  use Phoenix.Component
  # alias Phoenix.LiveView.JS
  # import CentralWeb.Gettext

  @doc """
  <TeiserverWeb.ChatComponents.message_list messages={@messages} />
  """
  def message_list(assigns) do
    ~H"""
    <div id="messages" phx-update="stream">
      <div id="infinite-scroll-marker" phx-hook="InfiniteScroll"></div>
      <div :for={{dom_id, message} <- @messages} id={dom_id}>
        <%= Teiserver.Helper.TimexHelper.date_to_str(message.inserted_at, format: :hms) %> <%= message.content %>
        <%!-- <.message_meta message={message} /> --%>
        <%!-- <.message_content message={message} /> --%>
      </div>
    </div>
    """
  end

end
