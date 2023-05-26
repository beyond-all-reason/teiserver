defmodule TeiserverWeb.UserComponents do
  use Phoenix.Component
  # alias Phoenix.LiveView.JS
  # import CentralWeb.Gettext

  @doc """
  <TeiserverWeb.UserComponents.status_icon user={user} />
  """
  def status_icon(%{user: %{data: user_data}} = assigns) do
    restrictions = user_data["restrictions"] || []

    cond do
      assigns.user.smurf_of_id != nil -> _status_icon(%{icon: :smurf})
      Enum.member?(restrictions, "Login") -> _status_icon(%{icon: :banned})
      Enum.member?(restrictions, "All chat") -> _status_icon(%{icon: :muted})
      Enum.member?(restrictions, "Warning reminder") -> _status_icon(%{icon: :warned})
      not Enum.member?(user_data["roles"], "Verified") -> _status_icon(%{icon: :unverified})
      true -> _status_icon(%{icon: nil})
    end
  end

  defp _status_icon(%{icon: :smurf} = assigns) do
    ~H"""
      <i class={"fa-fw text-primary #{Teiserver.Moderation.ActionLib.action_icon("Smurf")}"}></i>
    """
  end

  defp _status_icon(%{icon: :banned} = assigns) do
    ~H"""
      <i class={"fa-fw text-danger #{Teiserver.Moderation.ActionLib.action_icon("Ban")}"}></i>
    """
  end

  defp _status_icon(%{icon: :muted} = assigns) do
    ~H"""
      <i class={"fa-fw text-danger #{Teiserver.Moderation.ActionLib.action_icon("Mute")}"}></i>
    """
  end

  defp _status_icon(%{icon: :warned} = assigns) do
    ~H"""
      <i class={"fa-fw text-warning #{Teiserver.Moderation.ActionLib.action_icon("Warn")}"}></i>
    """
  end

  defp _status_icon(%{icon: :unverified} = assigns) do
    ~H"""
      <i class={"fa-fw text-info fa-solid fa-square-question"}></i>
    """
  end

  defp _status_icon(%{icon: nil} = assigns) do
    ~H"""
      &nbsp;
    """
  end
end
