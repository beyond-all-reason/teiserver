defmodule Teiserver.Protocols.Spring.TelemetryIn do
  alias Teiserver.Telemetry
  alias Teiserver.Protocols.SpringIn
  require Logger
  import Teiserver.Protocols.SpringOut, only: [reply: 5]
  # import Central.Helpers.NumberHelper, only: [int_parse: 1]

  # TODO: Less nested hackyness
  @spec do_handle(String.t(), String.t(), String.t() | nil, Map.t()) :: Map.t()
  def do_handle("upload_infolog", data, msg_id, state) do
    case Regex.run(~r/(\S+) (\S+) (\S+) (\S+)/, data) do
      [_, log_type, user_hash, metadata64, contents64] ->
        case decode_value(metadata64) do
          {:ok, metadata} ->
            case Base.decode64(contents64) do
              {:ok, compressed_contents} ->
                case unzip(compressed_contents) do
                  {:ok, contents} ->
                    params = %{
                      user_hash: user_hash,
                      user_id: state.userid,
                      log_type: log_type,

                      timestamp: Timex.now(),
                      metadata: metadata,
                      contents: contents
                    }
                    case Telemetry.create_infolog(params) do
                      {:ok, infolog} ->
                        reply(:spring, :okay, "upload_infolog - id:#{infolog.id}", msg_id, state)
                      {:error, changeset} ->
                        Logger.error(Kernel.inspect changeset)
                        reply(:spring, :no, "upload_infolog - db error", msg_id, state)
                    end
                  {:error, _} ->
                    reply(:spring, :no, "upload_infolog - infolog gzip error", msg_id, state)
                end
              _ ->
                reply(:spring, :no, "upload_infolog - infolog decode64 error", msg_id, state)
            end

          {:error, reason} ->
            reply(:spring, :no, "upload_infolog - metadata - #{reason}", msg_id, state)
        end
      nil ->
        reply(:spring, :no, "upload_infolog - no match", msg_id, state)
    end
  end

  def do_handle("update_client_property", data, _msg_id, state) do
    client_property(data, state)
    state
  end

  def do_handle("update_client_property_test", data, msg_id, state) do
    result = client_property(data, state)
    reply(:spring, :okay, result, msg_id, state)
  end

  def do_handle("log_client_event", data, _msg_id, state) do
    client_event(data, state)
    state
  end

  def do_handle("log_client_event_test", data, msg_id, state) do
    result = client_event(data, state)
    reply(:spring, :okay, result, msg_id, state)
  end

  def do_handle(cmd, data, msg_id, state) do
    SpringIn._no_match(state, "c.telemetry." <> cmd, msg_id, data)
  end

  @spec decode_value(String.t()) :: {:ok, any} | {:error, String.t()}
  defp decode_value(raw) do
    case Base.decode64(raw) do
      {:ok, string} ->
        case Jason.decode(string) do
          {:ok, json} ->
            {:ok, json}
          {:error, %Jason.DecodeError{position: position, data: _data}} ->
            {:error, "Json decode error at position #{position}"}
        end

      _ ->
        {:error, "Base64 decode error"}
    end
  end

  defp client_event(data, state) do
    if String.length(data) < 1024 do
      case Regex.run(~r/(\S+) (\S+) (\S+)/, data) do
        [_, event, value64, hash] ->
          case decode_value(value64) do
            {:ok, value} ->
              Telemetry.log_client_event(state.userid, event, value, hash)
              "success"
            {:error, reason} ->
              Logger.error("log_client_event:#{reason} - #{data}")
              reason
          end
        nil ->
          Logger.error("log_client_event:no match - #{data}")
          "no match"
      end
    else
      "exceeds max_length"
    end
  end

  defp client_property(data, state) do
    if String.length(data) < 1024 do
      case Regex.run(~r/(\S+) (\S+) (\S+)/, data) do
        [_, event, value64, hash] ->
          value = Base.decode64(value64)

          if value != :error do
            {:ok, value} = value

            Telemetry.log_client_property(state.userid, event, value, hash)
            "success"
          else
            Logger.error("update_client_property:bad base64 value - #{data}")
            "bad base64 value"
          end
        nil ->
          Logger.error("update_client_property:no match - #{data}")
          "no match"
      end
    else
      "exceeds max_length"
    end
  end

  defp unzip(data) do
    try do
      result = :zlib.gunzip(data)
      {:ok, result}
    rescue
      _ ->
        {:error, :gzip_decompress}
    end
  end
end
