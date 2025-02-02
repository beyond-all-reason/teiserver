defmodule TeiserverWeb.API.Admin.AssetView do
  use TeiserverWeb, :view

  def render("error.json", _conn) do
    %{}
  end

  def render("map_updated_error.json", conn) do
    errors =
      for {name, {err_msg, _}} <- conn.changeset.errors do
        "#{name}: #{err_msg}"
      end

    reason = "Operation #{conn.op_name} failed: #{errors}"

    %{
      status: :failed,
      reason: reason
    }
  end

  def render("map_updated.json", conn) do
    %{
      status: :success,
      created_count: conn.result.created_count,
      deleted_count: conn.result.deleted_count
    }
  end
end
