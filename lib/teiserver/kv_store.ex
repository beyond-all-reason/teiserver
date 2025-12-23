defmodule Teiserver.KvStore do
  @moduledoc """
  Simple key-value store. Intended to be used to persist some transient
  state across restart
  """

  alias Teiserver.KvStore.Queries
  alias Teiserver.KvStore.Blob

  @spec put(store :: String.t(), key :: String.t(), value :: binary()) ::
          :ok | {:error, Ecto.Changeset.t()}
  defdelegate put(store, key, value), to: Queries

  @spec get(store :: String.t(), key :: String.t()) :: Blob.t() | nil
  defdelegate get(store, key), to: Queries

  @spec scan(store :: String.t()) :: [Blob.t()]
  defdelegate scan(store), to: Queries

  @spec put_many([%{store: String.t(), key: String.t(), value: binary()}]) ::
          :ok | {:error, [Ecto.Changeset.t()]}
  defdelegate put_many(vals), to: Queries

  @spec delete(store :: String.t(), key :: String.t()) :: :ok | {:error, Ecto.Changeset.t()}
  defdelegate delete(store, key), to: Queries

  @spec delete_many([{store :: String.t(), key :: String.t()}]) :: non_neg_integer()
  defdelegate delete_many(keys), to: Queries
end
