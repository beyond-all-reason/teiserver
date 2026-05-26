defmodule Teiserver.Moderation.BannedIP do
  @moduledoc """
  An IP address or subnet that is banned from accessing the game.
  """
  alias IP.Subnet

  use TeiserverWeb, :schema

  typed_schema "banned_ips" do
    field :cidr, :string

    timestamps()
  end

  @doc false
  def changeset(banned_ip, attrs) do
    banned_ip
    |> cast(attrs, [:cidr])
    |> validate_required([:cidr])
    |> validate_change(:cidr, &validate_cidr/2)
    |> unique_constraint([:cidr])
  end

  defp validate_cidr(:cidr, value) do
    case Subnet.from_string(value) do
      {:ok, _ip} -> []
      _any -> [cidr: "must be a valid cidr"]
    end
  end

  def cidr_to_subnet(cidr) do
    case Subnet.from_string(cidr) do
      {:ok, subnet} ->
        subnet

      {:error, _reason} ->
        case IP.from_string(cidr) do
          {:ok, _ip} -> cidr_to_subnet(cidr <> "/32")
          other -> other
        end
    end
  end
end
