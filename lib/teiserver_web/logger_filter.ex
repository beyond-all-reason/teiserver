defmodule TeiserverWeb.LoggerFilter do
  @moduledoc "Custom `:logger` primary filters."

  @primary_filter_name :teiserver_bodyguard_not_authorized

  @doc """
  Installs every primary `:logger` filter defined in this module.

  Called from `Teiserver.Application.start/2`. Doing this at app start (rather
  than in `config/*.exs`) guarantees that this module is loaded by the time
  `:logger` is asked to call into it.
  """
  @spec install_primary!() :: :ok
  def install_primary! do
    case :logger.add_primary_filter(
           @primary_filter_name,
           {&__MODULE__.drop_bodyguard_not_authorized/2, []}
         ) do
      :ok -> :ok
      {:error, {:already_exists, @primary_filter_name}} -> :ok
    end
  end

  @doc """
  Drops Ranch "request process exit" logs whose exit reason is a
  `Bodyguard.NotAuthorizedError`.

  These fire whenever an authenticated user without the required role hits a
  protected URL. Phoenix has already returned a 403 to the client by the time
  the process exits, so the stack trace in the error log is just noise.
  See #1068.

  Cowboy emits this log via `cowboy:log/2` (see `cowboy_stream_h.erl` and
  `cowboy.erl`). With the default Plug.Cowboy setup, that routes through
  `:error_logger.error_msg/2`, which in OTP 26 produces a structured report
  (see `kernel/src/error_logger.erl`):

      %{level: :error,
        msg: {:report,
              %{label: {:error_logger, :error_msg},
                format: ~c"... had its request process ~p exit with reason ~0p~n",
                args:   [Ref, ConnPid, StreamID, ReqPid, Reason]}}, ...}

  We match the report shape, the cowboy signature substring in the format
  string, the exact 5-arg list cowboy emits, and a
  `%Bodyguard.NotAuthorizedError{}` found while walking only the `Reason`
  argument structurally. The legacy `{Format, Args}` shape (what would arrive
  if Cowboy were configured with `logger: :logger` somewhere) is also handled
  so the filter still works under that path.

  Returns `:stop` to drop the event, `:ignore` to let it flow to handlers.
  """
  @spec drop_bodyguard_not_authorized(:logger.log_event(), term()) :: :stop | :ignore
  def drop_bodyguard_not_authorized(%{level: :error, msg: msg}, _opts) do
    case extract_cowboy_request_exit(msg) do
      {format, [_ref, _conn_pid, _stream_id, _req_pid, reason]} ->
        if cowboy_request_exit_log?(format) and has_not_authorized?(reason),
          do: :stop,
          else: :ignore

      _other ->
        :ignore
    end
  end

  def drop_bodyguard_not_authorized(_event, _opts), do: :ignore

  # `error_logger:error_msg/2` path — cowboy's default through Plug.Cowboy.
  defp extract_cowboy_request_exit(
         {:report, %{label: {:error_logger, :error_msg}, format: format, args: args}}
       )
       when is_list(format) and is_list(args),
       do: {format, args}

  # Direct `:logger.error(format, args)` path — used if Cowboy is configured
  # with `logger: :logger`.
  defp extract_cowboy_request_exit({format, args})
       when is_list(format) and is_list(args),
       do: {format, args}

  defp extract_cowboy_request_exit(_msg), do: nil

  # Signature substring of cowboy_stream_h:149's format string. Stable in
  # cowboy for years; if cowboy ever rephrases it, the e2e test will fail on
  # the next dependency bump and we can update.
  defp cowboy_request_exit_log?(format) do
    format
    |> IO.chardata_to_string()
    |> String.contains?("had its request process")
  end

  defp has_not_authorized?(%Bodyguard.NotAuthorizedError{}), do: true

  defp has_not_authorized?(value) when is_tuple(value) do
    value |> Tuple.to_list() |> Enum.any?(&has_not_authorized?/1)
  end

  defp has_not_authorized?(value) when is_list(value),
    do: Enum.any?(value, &has_not_authorized?/1)

  defp has_not_authorized?(_value), do: false
end
