defmodule Teiserver.Helper.HashHelper do
  @doc """
  Returns Argon2 hash of the given value using the known salt from config.
  """
  @spec hash_with_fixed_salt(String.t()) :: binary()
  def hash_with_fixed_salt(value) do
    Argon2.Base.hash_password(value, Application.get_env(:teiserver, :argon2_salt))
  end
end
