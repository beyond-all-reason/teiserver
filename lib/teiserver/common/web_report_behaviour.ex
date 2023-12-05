defmodule Teiserver.Common.WebReportBehaviour do
  @moduledoc """
  A module used to generate reports for the ReportController(s)
  """

  @doc """
  The name of the report
  """
  @callback name() :: String.t()

  @doc """
  The icon used for the report.
  """
  @callback icon() :: String.t()

  @doc """
  The permission(s) required to be able to use the report.
  """
  @callback permissions() :: String.t() | [String.t()]

  @doc """
  The main function executed.; each report is able to return data in whatever form it wants.
  The web controller will place the returned map straight into the assigns.
  """
  @callback run(conn :: Plug.Conn.t(), params :: map()) :: map()
end
