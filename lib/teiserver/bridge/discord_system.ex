defmodule Teiserver.Bridge.DiscordSystem do
  @moduledoc false
  alias Nostrum.Token
  alias Teiserver.Communication

  use DynamicSupervisor
  use Task

  require Logger

  def start_link(_init_arg) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl DynamicSupervisor
  def init(_init_arg) do
    {:ok, sup_flags} = DynamicSupervisor.init(strategy: :one_for_one)

    Task.Supervisor.start_child(Teiserver.TaskSupervisor, &start_and_log/0)

    {:ok, sup_flags}
  end

  defp start_and_log do
    case start() do
      {:error, reason} ->
        reason |> start_error_message() |> Logger.error()

      _other ->
        :ok
    end

    :ok
  end

  @doc false
  @spec start_error_message(term()) :: String.t()
  def start_error_message({:invalid_token, message}) do
    "Discord bridge not started, TEI_DISCORD_BOT_TOKEN is missing or malformed: #{message}"
  end

  def start_error_message(reason) do
    # Nostrum raises this while fetching the gateway url, so by the time we see
    # it, it is buried in nested supervisor start errors.
    # TODO: once https://github.com/Kraigie/nostrum/pull/736 is released and we
    # upgrade, match on %Nostrum.Error.ApiError{status_code: 401} instead of the text.
    if inspect(reason, limit: :infinity) =~ "Authentication rejected" do
      "Discord bridge not started, Discord rejected TEI_DISCORD_BOT_TOKEN (invalid or revoked token)"
    else
      "Failed to start Discord bridge: #{inspect(reason)}"
    end
  end

  @spec start :: Supervisor.on_start_child() | {:error, {:invalid_token, String.t()}} | :disabled
  def start do
    if Communication.use_discord?() do
      case check_token() do
        :ok ->
          DynamicSupervisor.start_child(
            __MODULE__,
            Supervisor.child_spec(Teiserver.Bridge.DiscordBotSupervisor, restart: :temporary)
          )

        {:error, _reason} = error ->
          error
      end
    else
      :disabled
    end
  end

  # Nostrum raises on a missing or malformed token when it boots, which would
  # otherwise surface as an opaque supervisor start error.
  defp check_token do
    Token.check_token!()
  rescue
    e -> {:error, {:invalid_token, Exception.message(e)}}
  end

  @spec restart(String.t()) :: Supervisor.on_start_child() | :disabled
  def restart(reason) do
    Logger.info("Restarting discord system")

    case Process.whereis(Teiserver.Bridge.DiscordBotSupervisor) do
      x when is_pid(x) ->
        DynamicSupervisor.terminate_child(
          __MODULE__,
          x
        )

      _other ->
        :ok
    end

    result = start()
    Logger.info("Discord system restarted: #{reason}, result: #{inspect(result)}")

    message =
      case result do
        {:ok, _pid} -> "Discord bridge restarted: #{reason}"
        {:ok, _pid, _info} -> "Discord bridge restarted: #{reason}"
        other -> "Error restarting discord bridge #{reason}: #{inspect(other)}"
      end

    Communication.new_discord_message("Server updates", message)

    result
  end
end
