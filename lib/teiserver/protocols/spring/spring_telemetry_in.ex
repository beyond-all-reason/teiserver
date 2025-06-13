defmodule Teiserver.Protocols.Spring.TelemetryIn do
  alias Teiserver.Telemetry
  alias Teiserver.Protocols.{Spring, SpringIn}
  require Logger
  alias Teiserver.Bridge.DiscordBridgeBot
  import Teiserver.Protocols.SpringOut, only: [reply: 5]
  # import Teiserver.Helper.NumberHelper, only: [int_parse: 1]

  # TODO: Less nested hackyness
  @spec do_handle(String.t(), String.t(), String.t() | nil, map()) :: map()
  def do_handle("upload_infolog", data, msg_id, state) do
    case Regex.run(~r/(\S+) (\S+) (\S+) (\S+)/u, data) do
      [_, log_type, user_hash, metadata64, contents64] ->
        case Spring.decode_value(metadata64) do
          {:ok, metadata} ->
            case Base.url_decode64(contents64) do
              {:ok, compressed_contents} ->
                case Spring.unzip(compressed_contents) do
                  {:ok, contents} ->
                    if String.valid?(contents) do
                      params = %{
                        user_hash: user_hash,
                        user_id: state.userid,
                        log_type: log_type,
                        timestamp: Timex.now(),
                        metadata: metadata,
                        contents: contents,
                        size: String.length(contents)
                      }

                      case Telemetry.create_infolog(params) do
                        {:ok, infolog} ->
                          if Teiserver.Communication.use_discord?() do
                            DiscordBridgeBot.new_infolog(infolog)
                          end

                          reply(
                            :spring,
                            :okay,
                            "upload_infolog - id:#{infolog.id}",
                            msg_id,
                            state
                          )

                        {:error, _changeset} ->
                          reply(:spring, :no, "upload_infolog - db error", msg_id, state)
                      end
                    else
                      Logger.error(
                        "#{state.userid} #{log_type} upload_infolog - contents contain invalid characters"
                      )

                      reply(
                        :spring,
                        :no,
                        "upload_infolog - contents contain invalid characters",
                        msg_id,
                        state
                      )
                    end

                  {:error, _} ->
                    reply(:spring, :no, "upload_infolog - infolog gzip error", msg_id, state)
                end

              _ ->
                reply(
                  :spring,
                  :no,
                  "upload_infolog - infolog contents url_decode64 error",
                  msg_id,
                  state
                )
            end

          {:error, reason} ->
            reply(:spring, :no, "upload_infolog - metadata decode - #{reason}", msg_id, state)
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
    do_complex_client_event(data, state)
    state
  end

  def do_handle("log_client_event_test", data, msg_id, state) do
    result = do_complex_client_event(data, state)
    reply(:spring, :okay, result, msg_id, state)
  end

  def do_handle("simple_client_event", data, _msg_id, state) do
    do_simple_client_event(data, state)
    state
  end

  def do_handle("complex_client_event", data, _msg_id, state) do
    do_complex_client_event(data, state)
  end

  def do_handle("live_client_event", data, _msg_id, state) do
    do_live_client_event(data, state)
  end

  def do_handle(cmd, data, msg_id, state) do
    SpringIn._no_match(state, "c.telemetry." <> cmd, msg_id, data)
  end

  defp do_simple_client_event(data, state) do
    if String.length(data) < 1024 do
      case Regex.run(~r/(\S+) (\S+)/u, data) do
        [_, event_name, hash] ->
          if state.userid do
            Telemetry.log_simple_client_event(state.userid, event_name)
          else
            Telemetry.log_simple_anon_event(hash, event_name)
          end

          "success"

        nil ->
          "no match"
      end
    else
      "exceeds max_length"
    end
  end

  defp do_complex_client_event(data, state) do
    if String.length(data) < 1024 do
      case Regex.run(~r/(\S+) (\S+) (\S+)/u, data) do
        [_, event_name, value64, hash] ->
          case Spring.decode_value(value64) do
            {:ok, value} ->
              if state.userid do
                Telemetry.log_complex_client_event(state.userid, event_name, value)
              else
                Telemetry.log_complex_anon_event(hash, event_name, value)
              end

              "success"

            {:error, reason} ->
              # Logger.error("log_client_event:#{reason} - #{data}")
              reason
          end

        nil ->
          # Logger.error("log_client_event:no match - #{data}")
          "no match"
      end
    else
      "exceeds max_length"
    end
  end

  defp do_live_client_event(data, state) do
    if String.length(data) < 1024 do
      case Regex.run(~r/(\S+) (\S+)/u, data) do
        [_, _event_name, value64] ->
          case Spring.decode_value(value64) do
            {:ok, _value} ->
              if state.userid do
                # TODO: Do stuff with live client events
                # Telemetry.log_live_client_event(state.userid, event_name, value)
                # for now, they're prefixed with underscores to silence warnings
                :ok
              end

              "success"

            {:error, reason} ->
              reason
          end

        nil ->
          "no match"
      end
    else
      "exceeds max_length"
    end
  end

  defp client_property(data, state) do
    if String.length(data) < 1024 do
      case Regex.run(~r/(\S+) (\S+) (\S+)/u, data) do
        [_, event, value64, hash] ->
          value = Base.url_decode64(value64)

          if value != :error do
            {:ok, value} = value

            if String.valid?(value) do
              if state.userid do
                Telemetry.log_user_property(state.userid, event, value)
              else
                Telemetry.log_anon_property(hash, event, value)
              end

              "success"
            else
              if state.userid do
                Logger.error(
                  "#{state.userid} update_client_property - contents contain invalid characters, data: #{value}"
                )
              else
                Logger.error(
                  "update_client_property - contents contain invalid characters, data: #{value}"
                )
              end

              "contain invalid characters"
            end
          else
            # Logger.error("update_client_property:bad base64 value - #{data}")
            "bad base64 value"
          end

        nil ->
          # Logger.error("update_client_property:no match - #{data}")
          "no match"
      end
    else
      "exceeds max_length"
    end
  end
end
