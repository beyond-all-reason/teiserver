defmodule Teiserver.Logging.SafeLogger do
  @moduledoc """
  A wrapper around Logger that sanitizes sensitive data before logging.

  This module provides functions to safely log messages by removing or redacting
  sensitive information like passwords, tokens, API keys, and other credentials.

  ## Usage

      alias Teiserver.Logging.SafeLogger

      # Instead of:
      Logger.info("User logged in with params: \#{inspect(params)}")

      # Use:
      SafeLogger.info("User logged in with params: \#{inspect(params)}")

      # Or sanitize data directly:
      safe_data = SafeLogger.sanitize(sensitive_data)

  ## Configuration

  The list of sensitive keys can be extended via application config:

      config :teiserver, Teiserver.Logging.SafeLogger,
        additional_sensitive_keys: ["custom_secret", "my_api_key"]

  """

  require Logger

  @default_sensitive_keys ~w(
    password
    password_hash
    password_confirmation
    token
    access_token
    refresh_token
    secret
    secret_key
    api_key
    apikey
    cookie
    authorization
    bearer
    credential
    session
    session_id
    private_key
    client_secret
  )

  @redacted_value "[REDACTED]"

  # Patterns for detecting sensitive data in strings
  # Character class excludes: quotes, whitespace, comma, braces, brackets, ampersand
  @sensitive_patterns [
    # password=value, password: value, "password": "value"
    {~r/(?i)(password|passwd|pwd)[=:]\s*["']?[^"'\s,}\]&]+["']?/, "\\1=#{@redacted_value}"},
    # token=value patterns
    {~r/(?i)(token|access_token|refresh_token|api_key|apikey|secret|secret_key)[=:]\s*["']?[^"'\s,}\]&]+["']?/,
     "\\1=#{@redacted_value}"},
    # Bearer token in authorization headers
    {~r/(?i)Bearer\s+[A-Za-z0-9\-_\.]+/, "Bearer #{@redacted_value}"},
    # Basic auth
    {~r/(?i)Basic\s+[A-Za-z0-9\+\/=]+/, "Basic #{@redacted_value}"},
    # Cookie values
    {~r/(?i)(cookie|session)[=:]\s*["']?[^"'\s,}\]&]+["']?/, "\\1=#{@redacted_value}"}
  ]

  @doc """
  Logs an info message after sanitizing sensitive data.
  """
  @spec info(String.t() | iodata()) :: :ok
  def info(message) do
    Logger.info(sanitize(message))
  end

  @doc """
  Logs a debug message after sanitizing sensitive data.
  """
  @spec debug(String.t() | iodata()) :: :ok
  def debug(message) do
    Logger.debug(sanitize(message))
  end

  @doc """
  Logs a warning message after sanitizing sensitive data.
  """
  @spec warning(String.t() | iodata()) :: :ok
  def warning(message) do
    Logger.warning(sanitize(message))
  end

  @doc """
  Logs an error message after sanitizing sensitive data.
  """
  @spec error(String.t() | iodata()) :: :ok
  def error(message) do
    Logger.error(sanitize(message))
  end

  @doc """
  Sanitizes data by removing or redacting sensitive information.

  Handles strings, maps, keyword lists, and lists. For other data types,
  returns the data unchanged.

  ## Examples

      iex> SafeLogger.sanitize(%{"password" => "secret123", "username" => "john"})
      %{"password" => "[REDACTED]", "username" => "john"}

      iex> SafeLogger.sanitize("password=secret123&user=john")
      "password=[REDACTED]&user=john"

      iex> SafeLogger.sanitize([password: "secret", name: "john"])
      [password: "[REDACTED]", name: "john"]

  """
  @spec sanitize(any()) :: any()
  def sanitize(data) when is_binary(data) do
    sanitize_string(data)
  end

  def sanitize(data) when is_map(data) do
    sanitize_map(data)
  end

  def sanitize(data) when is_list(data) do
    if Keyword.keyword?(data) do
      sanitize_keyword_list(data)
    else
      Enum.map(data, &sanitize/1)
    end
  end

  def sanitize(data) when is_tuple(data) do
    data
    |> Tuple.to_list()
    |> Enum.map(&sanitize/1)
    |> List.to_tuple()
  end

  def sanitize(data), do: data

  @doc """
  Returns the list of sensitive keys that will be redacted.
  """
  @spec sensitive_keys() :: [String.t()]
  def sensitive_keys do
    additional_keys =
      Application.get_env(:teiserver, __MODULE__, [])
      |> Keyword.get(:additional_sensitive_keys, [])

    @default_sensitive_keys ++ additional_keys
  end

  @doc """
  Checks if a key is considered sensitive.
  """
  @spec sensitive_key?(String.t() | atom()) :: boolean()
  def sensitive_key?(key) when is_atom(key) do
    sensitive_key?(Atom.to_string(key))
  end

  def sensitive_key?(key) when is_binary(key) do
    normalized_key = String.downcase(key)

    Enum.any?(sensitive_keys(), fn sensitive_key ->
      String.contains?(normalized_key, sensitive_key)
    end)
  end

  # Private functions

  defp sanitize_string(str) do
    Enum.reduce(@sensitive_patterns, str, fn {pattern, replacement}, acc ->
      Regex.replace(pattern, acc, replacement)
    end)
  end

  defp sanitize_map(map) do
    Map.new(map, fn {key, value} ->
      if sensitive_key?(key) do
        {key, @redacted_value}
      else
        {key, sanitize(value)}
      end
    end)
  end

  defp sanitize_keyword_list(keyword_list) do
    Enum.map(keyword_list, fn {key, value} ->
      if sensitive_key?(key) do
        {key, @redacted_value}
      else
        {key, sanitize(value)}
      end
    end)
  end
end
