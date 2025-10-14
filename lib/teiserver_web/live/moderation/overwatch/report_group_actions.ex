defmodule TeiserverWeb.Moderation.ReportGroupActions do
  use TeiserverWeb, :html

  attr :targets, :list, required: true
  attr :path, :string, required: true

  def report_group_actions(assigns) do
    ~H"""
    <div class="dropdown-menu show">
      <%= for target <- @targets do %>
        <a class="dropdown-item" href={"#{@path}#{target.id}"}>
          <Fontawesome.icon icon={Teiserver.Moderation.BanLib.icon()} style="solid" />
          &nbsp; {target.name}
        </a>
      <% end %>
    </div>
    """
  end
end
