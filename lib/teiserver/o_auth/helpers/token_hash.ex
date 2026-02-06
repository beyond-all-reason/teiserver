defmodule Teiserver.OAuth.TokenHash do
  @moduledoc """
  Hashing for OAuth token verifiers using SHA-256.
  """

  @spec hash_verifier(String.t()) :: String.t()
  def hash_verifier(verifier) do
    :crypto.hash(:sha256, verifier) |> Base.encode16(case: :lower)
  end

  @spec verify_verifier(String.t(), String.t()) :: boolean()
  def verify_verifier(verifier, stored_hash) do
    Plug.Crypto.secure_compare(hash_verifier(verifier), stored_hash)
  end

  @doc """
  Returns {selector, hashed_verifier, full_token}.
  """
  @spec generate_token() :: {String.t(), String.t(), String.t()}
  def generate_token do
    selector = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
    verifier = :crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower)
    {selector, hash_verifier(verifier), "#{selector}.#{verifier}"}
  end

  @doc """
  Like generate_token/0 but also returns the raw verifier. Only for testing.
  """
  @spec generate_token_for_test() :: {String.t(), String.t(), String.t(), String.t()}
  def generate_token_for_test do
    selector = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
    verifier = :crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower)
    {selector, verifier, hash_verifier(verifier), "#{selector}.#{verifier}"}
  end

  @spec parse_token(String.t()) :: {:ok, {String.t(), String.t()}} | :error
  def parse_token(token) when is_binary(token) do
    case String.split(token, ".", parts: 2) do
      [selector, verifier] when byte_size(selector) > 0 and byte_size(verifier) > 0 ->
        {:ok, {selector, verifier}}

      _ ->
        :error
    end
  end

  def parse_token(_), do: :error
end
