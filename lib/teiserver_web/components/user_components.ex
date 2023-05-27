defmodule TeiserverWeb.UserComponents do
  use Phoenix.Component
  # alias Phoenix.LiveView.JS
  # import CentralWeb.Gettext

  @doc """
  <TeiserverWeb.UserComponents.status_icon user={user} />
  """
  def status_icon(%{user: %{data: user_data}} = assigns) do
    restrictions = user_data["restrictions"] || []

    icons = [
      (if assigns.user.smurf_of_id != nil, do: {"primary", Teiserver.Moderation.ActionLib.action_icon("Smurf")}),
      (if Enum.member?(restrictions, "Login"), do: {"danger", Teiserver.Moderation.ActionLib.action_icon("Ban")}),
      (if Enum.member?(restrictions, "All chat"), do: {"danger", Teiserver.Moderation.ActionLib.action_icon("Mute")}),
      (if Enum.member?(restrictions, "Warning reminder"), do: {"warning", Teiserver.Moderation.ActionLib.action_icon("Warn")}),
      (if Enum.member?(user_data["roles"], "Trusted"), do: {"", "fa-solid fa-check"}),
      (if not Enum.member?(user_data["roles"], "Verified"), do: {"info", "fa-solid fa-square-question"}),
    ]
    |> Enum.reject(&(&1 == nil))

    status_icon_list(%{icons: icons})
  end

  defp status_icon_list(assigns) do
    ~H"""
    <div :for={{colour, icon} <- @icons} class="d-inline-block">
      <i class={"fa-fw text-#{colour} #{icon}"}></i>
    </div>
    """
  end
end
