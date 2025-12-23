defmodule Teiserver.KvStore.Queries do
  use TeiserverWeb, :queries

  alias Teiserver.KvStore.Blob

  @spec put(store :: String.t(), key :: String.t(), value :: binary()) ::
          :ok | {:error, Ecto.Changeset.t()}
  def put(store, key, value) do
    res =
      %Blob{}
      |> Blob.changeset(%{store: store, key: key, value: value, updated_at: DateTime.utc_now()})
      |> Repo.insert(
        on_conflict: {:replace, [:store, :key, :value, :updated_at]},
        conflict_target: [:store, :key]
      )

    case res do
      {:ok, _} -> :ok
      x -> x
    end
  end

  @doc """
  same as put, but for batch insert. If any insertion fails, none will
  be commited (all or nothing)
  Doesn't return anything (for now?) since the order can be messed up
  and it would require more network transfer from db.
  I can't see why it would be useful to get back the object either.
  """
  @spec put_many([%{store: String.t(), key: String.t(), value: binary()}]) ::
          :ok | {:error, [Ecto.Changeset.t()]}
  def put_many(vals) do
    now = DateTime.utc_now()

    {oks, errs} =
      vals
      |> Enum.reduce({[], []}, fn attrs, {oks, errs} ->
        attrs = attrs |> Map.put(:inserted_at, now) |> Map.put(:updated_at, now)
        cs = Blob.changeset(%Blob{}, attrs) |> Ecto.Changeset.apply_action(:insert)

        case cs do
          {:ok, struct} -> {[Map.from_struct(struct) |> Map.delete(:__meta__) | oks], errs}
          {:error, err} -> {oks, [err | errs]}
        end
      end)

    case errs do
      [] ->
        Repo.insert_all(Blob, oks,
          on_conflict: :replace_all,
          conflict_target: [:store, :key]
        )

        :ok

      errs ->
        {:error, errs}
    end
  end

  @spec get(store :: String.t(), key :: String.t()) :: Blob.t() | nil
  def get(store, key) do
    from(blob in Blob,
      as: :blob,
      where: blob.store == ^store,
      where: blob.key == ^key
    )
    |> Repo.one()
  end

  @spec scan(store :: String.t()) :: [Blob.t()]
  def scan(store) do
    from(blob in Blob,
      as: :blob,
      where: blob.store == ^store
    )
    |> Repo.all()
  end

  @spec delete(store :: String.t(), key :: String.t()) :: :ok | {:error, Ecto.Changeset.t()}
  def delete(store, key) do
    case Repo.delete(%Blob{store: store, key: key}, allow_stale: true) do
      {:ok, _} -> :ok
      x -> x
    end
  end

  @spec delete_many([{store :: String.t(), key :: String.t()}]) :: non_neg_integer()
  def delete_many(keys) do
    Enum.reduce(keys, Blob, fn {store, k}, q ->
      from blob in q, or_where: blob.store == ^store and blob.key == ^k
    end)
    |> Repo.delete_all()
    |> elem(0)
  end
end
