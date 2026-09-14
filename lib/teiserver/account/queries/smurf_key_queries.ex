defmodule Teiserver.Account.SmurfKeyQueries do
  @moduledoc false
  alias Ecto.Query
  alias Teiserver.Account.SmurfKey

  use TeiserverWeb, :queries

  @type t :: Query.t()

  @spec smurf_keys() :: t()
  def smurf_keys do
    from(smurf_keys in SmurfKey, as: :smurf_keys)
  end

  # Where id
  @spec where_id(t(), pos_integer() | String.t()) :: t()
  def where_id(query, id) do
    from smurf_keys in query,
      where: smurf_keys.id == ^id
  end

  # Where user_id
  @spec where_user_id(t(), pos_integer() | String.t()) :: t()
  def where_user_id(query, user_id) do
    from smurf_keys in query,
      where: smurf_keys.user_id == ^user_id
  end
end
