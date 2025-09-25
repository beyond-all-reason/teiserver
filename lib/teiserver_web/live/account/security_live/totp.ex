defmodule TeiserverWeb.Account.SecurityLive.TOTP do
  @moduledoc false
  use TeiserverWeb, :live_view
  alias Teiserver.Account.TOTPLib

  @impl true
  def mount(_params, %{"current_user" => user}, socket) do
    {status, secret} =
      case TOTPLib.get_or_generate_secret(user) do
        {:new, secret} -> {:inactive, secret}
        {:existing, secret} -> {:active, secret}
      end

    otpauth_uri =
      NimbleTOTP.otpauth_uri("Beyond all Reason:#{user.email}", secret,
        issuer: "Beyond all Reason"
      )

    {:ok,
     socket
     |> assign(:user, user)
     |> assign(:otp_status, status)
     |> assign(:secret, secret)
     |> assign(:otp_uri, otpauth_uri)
     |> assign(:otp_input, "")
     |> assign(:error, nil)}
  end

  @impl true
  def handle_event("back", _params, socket) do
    {:noreply, push_navigate(socket, to: Routes.ts_account_security_path(socket, :index))}
  end

  # Handle "Enable 2FA" or "Reset 2FA"
  def handle_event("enable_2fa", _params, socket) do
    {:noreply,
     assign(socket,
       otp_input: "",
       error: nil
     )}
  end

  # Handle OTP input change
  def handle_event("update_otp", %{"otp_input" => otp}, socket) do
    {:noreply, assign(socket, :otp_input, otp)}
  end

  # Handle "Save" button
  def handle_event("save_otp", _params, socket) do
    secret = socket.assigns.secret
    otp = socket.assigns.otp_input
    user = socket.assigns.user

    case TOTPLib.validate_totp(secret, otp) do
      {:ok, _info} ->
        case TOTPLib.set_totp(user, %{secret: secret}) do
          {:ok, _totp} ->
            {:noreply,
             socket
             |> assign(:otp_status, :active)
             |> assign(:otp_input, "")
             |> assign(:error, nil)}

          {:error, _changeset} ->
            {:noreply, assign(socket, :error, "Failed to save 2FA")}
        end

      {:error, :invalid} ->
        {:noreply, assign(socket, :error, "Invalid OTP")}
    end
  end

  # Handle "Disable 2FA" button
  def handle_event("disable_2fa", _params, socket) do
    user = socket.assigns.user

    case TOTPLib.disable_totp(user) do
      {:ok, _} ->
        {:noreply, assign(socket, :otp_status, :inactive)}

      {:error, _} ->
        {:noreply, assign(socket, :error, "Failed to disable 2FA")}
    end
  end
end
