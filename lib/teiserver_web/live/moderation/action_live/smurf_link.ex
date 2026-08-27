defmodule TeiserverWeb.Moderation.ActionLive.SmurfLink do
  @moduledoc false
  alias Teiserver.Account
  alias Teiserver.Account.User
  alias Teiserver.Account.UserLib

  use TeiserverWeb, :live_view

  require Logger

  @impl LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl LiveView
  def handle_params(%{"user_id" => user_id}, _url, socket) do
    user = Account.get_user(user_id)
    existing_smurf_of = user.smurf_of_id && Account.get_user(user.smurf_of_id)

    case UserLib.has_access(user, socket) do
      {true, _role} ->
        socket
        |> assign(
          user: user,
          existing_smurf_of: existing_smurf_of,
          page_title: "Smurf link - #{user.name}"
        )
        |> assign_new(:form, fn ->
          to_form(%{
            "smurf_user_id" => nil
          })
        end)
        |> noreply()

      _no_access ->
        socket
        |> put_flash(:warning, "No access to that user")
        |> redirect(to: ~p"/moderation")
        |> noreply()
    end
  end

  @impl LiveView
  def handle_event("validate", params, socket) do
    socket
    |> assign(valid: valid?(params))
    |> noreply()
  end

  def handle_event("save", params, socket) do
    if origin = valid?(params) do
      case UserLib.has_access(origin, socket) do
        {true, _role} ->
          %{
            user: smurf,
            current_user: moderator
          } = socket.assigns

          result = UserLib.mark_user_as_smurf_of(moderator, %{origin: origin, smurf: smurf})

          case result do
            :ok ->
              socket
              |> redirect(to: ~p"/teiserver/admin/user/#{smurf.id}")
              |> put_flash(:info, "Smurf link created")
              |> noreply()

            _result ->
              Logger.error("Error saving smurf link form: #{inspect(result)}")

              socket
              |> put_flash(:warning, "Internal error")
              |> noreply()
          end

        _no_access ->
          new_form =
            socket.assigns.form
            |> to_form(errors: [smurf_user_id: {"You do not have authority over this user", []}])

          socket
          |> assign(:form, new_form)
          |> noreply()
      end
    else
      new_form =
        socket.assigns.form
        |> to_form(errors: [smurf_user_id: {"Must be a valid ID", []}])

      socket
      |> assign(:form, new_form)
      |> noreply()
    end
  end

  defp valid?(%{"smurf_user_id" => ""}), do: false

  defp valid?(%{"smurf_user_id" => smurf_user_id}) do
    case Account.get_user(smurf_user_id) do
      %User{} = user -> user
      _any -> false
    end
  end
end
