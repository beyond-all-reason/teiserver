defmodule Teiserver.Account.RelationshipReport do
  @moduledoc false
  alias Teiserver.Repo
  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]
  alias Teiserver.Account.RelationshipLib

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-arrow-down-up-across-line"

  @spec permissions() :: String.t()
  def permissions(), do: "Reviewer"

  @spec run(Plug.Conn.t(), map()) :: map()
  def run(_conn, params) do
    params = apply_defaults(params)

    # Excludes banned users
    exclude_banned =
      if params["exclude_banned"] == "true" do
        """
          AND not from_user.data -> 'restrictions' @> '\"Login\"'
          AND not to_user.data -> 'restrictions' @> '\"Login\"'
        """
      else
        ""
      end

    state_type = params["state"] |> String.downcase

    days = int_parse(params["days"])

    start_date =
      Timex.now()
      |> Timex.shift(days: -days)

    limit = int_parse(params["limit"])

    main_where = case state_type do
      "ignore" -> "AND rels.ignore = true"

      "follow" -> "AND rels.state = 'follow'"
      "avoid" -> "AND rels.state IN ('block', 'avoid')"
      "block" -> "AND rels.state = 'avoid'"
      _ -> raise "No handler for state_type of `#{state_type}`"
    end

    query = """
      SELECT
        to_user.id AS userid,
        to_user.name AS username,
        COUNT(rels.to_user_id) as counter,
        ARRAY_AGG(from_user.name) AS names
      FROM account_relationships rels
      JOIN account_users AS to_user
        ON to_user.id = rels.to_user_id
      JOIN account_users AS from_user
        ON from_user.id = rels.from_user_id
      WHERE
        from_user.last_played > $1
        AND from_user.smurf_of_id is null
        AND to_user.smurf_of_id is null
        #{main_where}
        #{exclude_banned}
      GROUP BY to_user.id, to_user.name
      ORDER BY counter DESC
      LIMIT $2
    """

    results = case Ecto.Adapters.SQL.query(Repo, query, [start_date, limit]) do
      {:ok, results} ->
        results.rows

      {a, b} ->
        raise "ERR: #{a}, #{b}"
    end

    state_past_tense = RelationshipLib.past_tense_of_state(state_type)

    %{
      params: params,
      state_past_tense: state_past_tense,
      results: results
    }
  end

  defp apply_defaults(params) do
    Map.merge(
      %{
        "exclude_banned" => "true",
        "state" => "Ignore",
        "days" => "31",
        "limit" => "100"
      },
      Map.get(params, "report", %{})
    )
  end
end
