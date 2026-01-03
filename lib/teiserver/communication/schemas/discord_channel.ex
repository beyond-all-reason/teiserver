defmodule Teiserver.Communication.DiscordChannel do
  @moduledoc false
  use TeiserverWeb, :schema

  typed_schema "communication_discord_channels" do
    field :name, :string
    field :channel_id, :integer

    field :view_permission, :string
    field :post_permission, :string

    field :colour, :string
    field :icon, :string

    timestamps()
  end

  @doc """
  Builds a changeset based on the `struct` and `params`.
  """
  @spec changeset(map(), map()) :: Ecto.Changeset.t()
  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, ~w(name channel_id colour icon view_permission post_permission)a)
    |> validate_required(~w(name channel_id colour icon)a)
    |> unique_constraint(:name)
  end

  @spec authorize(atom, Plug.Conn.t(), map()) :: boolean
  def authorize(_action, conn, _params), do: allow?(conn, "Server")
end
