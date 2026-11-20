defmodule Teiserver.Account.UserPolicy do
  @moduledoc false

  import Teiserver.Account.AuthLib, only: [allow?: 2]

  @behaviour Bodyguard.Policy

  def authorize(:index, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:search, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:show, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:new, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:perform_action, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:rename_form, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:rename_post, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:reset_password, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:respond_form, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:respond_post, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:smurf_search, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:smurf_merge_form, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:smurf_merge_post, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:cancel_smurf_mark, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:mark_as_smurf_of, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:delete_smurf_key, conn, _data), do: allow?(conn, "admin.dev")
  def authorize(:automod_form, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:ratings, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:ratings_form, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:ratings_post, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:set_stat, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:edit, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:update, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:applying, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:data_search, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:relationships, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:gdpr_forget, conn, _data), do: allow?(conn, "Moderator")
  def authorize(_action, conn, _data), do: allow?(conn, "admin.dev")
end
