%{
  configs: [
    %{
      name: "default",
      checks: [
        {Credo.Check.Warning.MissedMetadataKeyInLoggerConfig,
         [
           metadata_keys: [:request_id, :user_id, :pid, :actor_type, :actor_id]
         ]},
        # TODO: Enable this check and fix the issues
        {Credo.Check.Design.AliasUsage, false},
        # {Credo.Check.Design.AliasUsage, [if_nested_deeper_than: 2, if_called_more_often_than: 1]}
        # TODO: Enable this check by deleting the line below, then fix the issues
        {Credo.Check.Refactor.Nesting, false},
        # TODO: Enable this check by deleting the line below, then fix the issues
        {Credo.Check.Refactor.CyclomaticComplexity, false},
        # TODO: Enable this check by deleting the line below, then fix the issues
        {Credo.Check.Refactor.CondStatements, false}
      ]
    }
  ]
}
