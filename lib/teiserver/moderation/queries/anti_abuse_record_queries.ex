defmodule Teiserver.Moderation.AntiAbuseRecordQueries do
  @moduledoc false
  alias Ecto.Query
  alias Teiserver.Moderation.AntiAbuseRecord

  use TeiserverWeb, :queries

  @type t :: Query.t()

  @spec anti_abuse_records() :: t()
  def anti_abuse_records do
    from(anti_abuse_records in AntiAbuseRecord, as: :anti_abuse_records)
  end

  @spec where_id(t(), AntiAbuseRecord.id()) :: t()
  def where_id(query, id) do
    from anti_abuse_records in query,
      where: anti_abuse_records.id == ^id
  end
end
