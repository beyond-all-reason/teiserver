defmodule Teiserver.Tachyon.TachyonPbLib do
  @moduledoc """

  """

  @module_from_atom %{
    empty: Tachyon.Empty,
    failure: Tachyon.Failure,

    token_response: Tachyon.TokenResponse,

    token_request: Tachyon.TokenRequest,
  }

  @atom_from_module @module_from_atom
    |> Map.new(fn {k, v} -> {v, k} end)

  @spec get_module(atom) :: module()
  def get_module(atom) do
    @module_from_atom[atom]
  end

  @spec get_module(module()) :: atom
  def get_atom(module) do
    @atom_from_module[module]
  end

  # Server message wrap functions
  @spec server_wrap({atom, map}, map()) :: Tachyon.ServerMessage.t()
  def server_wrap({type, object}, attrs) do
    Tachyon.ServerMessage.new(
      id: attrs[:id],
      object: {type, object}
    )
  end

  @spec server_encode(Tachyon.ServerMessage.t()) :: binary()
  def server_encode(data) do
    Tachyon.ServerMessage.encode(data)
  end
  @spec server_wrap({atom, map}, list()) :: binary()

  def server_wrap_and_encode({type, object}, attrs) do
    server_wrap({type, object}, attrs)
    |> server_encode
  end

  # Client unwrap functions
  @spec client_unwrap(Tachyon.ClientMessage.t()) :: {{atom, map()}, map}
  def client_unwrap(%{object: {type, object}} = data) do
    metadata = Map.drop(data, [:__struct__, :__unknown_fields__, :object])

    {{type, object}, metadata}
  end

  @spec client_decode(binary()) :: Tachyon.ClientMessage.t()
  def client_decode(data) do
    Tachyon.ClientMessage.decode(data)
  end

  @spec client_decode_and_unwrap(binary()) :: {{atom, map()}, map}
  def client_decode_and_unwrap(data) do
    Tachyon.ClientMessage.decode(data)
    |> client_unwrap
  end
end
