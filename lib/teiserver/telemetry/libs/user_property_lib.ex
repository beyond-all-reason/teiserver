defmodule Teiserver.Telemetry.UserPropertyLib do
  @moduledoc false
  use CentralWeb, :library
  alias Teiserver.Telemetry
  alias Teiserver.Telemetry.{UserProperty, UserPropertyQueries}
  alias Phoenix.PubSub

  @broadcast_property_types ~w(hardware:cpuinfo hardware:macAddrHash hardware:sysInfoHash)

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-regular fa-???"

  @spec colours :: atom
  def colours, do: :default

  @spec log_user_property(T.userid, String.t, String.t) :: {:error, Ecto.Changeset} | {:ok, UserProperty}
  def log_user_property(userid, property_type_name, value) do
    property_type_id = Telemetry.get_or_add_property_type(property_type_name)

    result = upsert_user_property(%{
      user_id: userid,
      property_type_id: property_type_id,
      value: value,
      last_updated: Timex.now(),
    })

    case result do
      {:ok, _property} ->
        if Enum.member?(@broadcast_property_types, property_type_name) do
          PubSub.broadcast(
            Teiserver.PubSub,
            "telemetry_user_properties",
            %{
              channel: "telemetry_user_properties",
              event: :upserted_property,
              userid: userid,
              property_type_name: property_type_name,
              value: value
            }
          )
        end

        result

      _ ->
        result
    end
  end

  # case property_name do
  #     "hardware:cpuinfo" ->
  #       Account.merge_update_client(userid, %{app_status: :accepted})
  #       client = Account.get_client_by_id(userid)

  #       if client do
  #         send(client.tcp_pid, {:put, :app_status, :accepted})
  #         Teiserver.Account.create_smurf_key(userid, "chobby_hash", hash)
  #         Teiserver.Account.update_cache_user(userid, %{chobby_hash: hash})
  #       end

  #     "hardware:macAddrHash" ->
  #       Teiserver.Account.create_smurf_key(userid, "chobby_mac_hash", value)
  #       Teiserver.Account.update_cache_user(userid, %{chobby_mac_hash: value})

  #     "hardware:sysInfoHash" ->
  #       Teiserver.Account.create_smurf_key(userid, "chobby_sysinfo_hash", value)
  #       Teiserver.Account.update_cache_user(userid, %{chobby_sysinfo_hash: value})

  #     _ ->
  #       :ok
  #   end

  @doc """
  Returns the list of user_properties.

  ## Examples

      iex> list_user_properties()
      [%UserProperty{}, ...]

  """
  @spec list_user_properties(list) :: list
  def list_user_properties(args \\ []) do
    args
    |> UserPropertyQueries.query_user_properties()
    |> Repo.all()
  end

  @doc """
  Gets a single user_property.

  Raises `Ecto.NoResultsError` if the UserProperty does not exist.

  ## Examples

      iex> get_user_property!(123)
      %UserProperty{}

      iex> get_user_property!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user_property!(id), do: Repo.get!(UserProperty, id)

  def get_user_property!(id, args) do
    args = args ++ [id: id]

    args
    |> UserPropertyQueries.query_user_properties()
    |> Repo.one!()
  end

  @doc """
  Creates a user_property.

  ## Examples

      iex> create_user_property(%{field: value})
      {:ok, %UserProperty{}}

      iex> create_user_property(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user_property(attrs \\ %{}) do
    %UserProperty{}
    |> UserProperty.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user_property.

  ## Examples

      iex> update_user_property(user_property, %{field: new_value})
      {:ok, %UserProperty{}}

      iex> update_user_property(user_property, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_property(%UserProperty{} = user_property, attrs) do
    user_property
    |> UserProperty.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user_property.

  ## Examples

      iex> delete_user_property(user_property)
      {:ok, %UserProperty{}}

      iex> delete_user_property(user_property)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user_property(%UserProperty{} = user_property) do
    Repo.delete(user_property)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user_property changes.

  ## Examples

      iex> change_user_property(user_property)
      %Ecto.Changeset{data: %UserProperty{}}

  """
  def change_user_property(%UserProperty{} = user_property, attrs \\ %{}) do
    UserProperty.changeset(user_property, attrs)
  end

  @doc """
  Updates or inserts a UserProperty.

  ## Examples

      iex> upsert(%{field: value})
      {:ok, %Relationship{}}

      iex> upsert(%{field: value})
      {:error, %Ecto.Changeset{}}

  """
  def upsert_user_property(attrs) do
    %UserProperty{}
    |> UserProperty.changeset(attrs)
    |> Repo.insert(
      on_conflict: [set: [
        last_updated: Map.get(attrs, "last_updated", Map.get(attrs, :last_updated, nil)),
        value: Map.get(attrs, "value", Map.get(attrs, :value, nil))
      ]],
      conflict_target: ~w(user_id property_type_id)a
    )
  end
end
