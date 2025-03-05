defmodule TeiserverWeb.ChatComponents do
  @moduledoc false
  use Phoenix.Component
  # alias Phoenix.LiveView.JS
  # import TeiserverWeb.Gettext

  @doc """
  <TeiserverWeb.ChatComponents.message_list messages={@messages} />
  """
  def message_list(assigns) do
    ~H"""
    <div id="messages" phx-update="stream">
      <div id="infinite-scroll-marker" phx-hook="InfiniteScroll"></div>
      <div
        :for={{dom_id, message} <- @messages}
        id={dom_id}
        style={"background-color: #{Teiserver.Helper.ColourHelper.rgba_css(message.user.colour, 0.08)}"}
      >
        <div
          :if={not message.same_poster}
          class="time-and-user"
          style={"border-color: #{message.user.colour}; color: #{message.user.colour}"}
        >
          {Teiserver.Helper.TimexHelper.date_to_str(message.inserted_at, format: :hms)} &nbsp;
          <Fontawesome.icon icon={message.user.icon} style="regular" />
          <strong>{message.user.name}</strong>
        </div>
        <div class="message-content">
          {message.content}
        </div>
        <%!-- <.message_meta message={message} /> --%>
        <%!-- <.message_content message={message} /> --%>
      </div>
    </div>
    """
  end
end
