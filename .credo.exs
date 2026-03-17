%{
  configs: [
    %{
      name: "default",
      checks: %{
        enabled: [
          {Credo.Check.Warning.MissedMetadataKeyInLoggerConfig,
           [
             metadata_keys: [:request_id, :user_id, :pid, :actor_type, :actor_id]
           ]},
          {Credo.Check.Refactor.CondStatements, []}
        ],
        disabled: [
          # These are all checks we would like to enable
          # move them into enabled, address the issues and
          # create aa PR with the fixes
          {Credo.Check.Design.AliasUsage, false},
          {Credo.Check.Design.AliasUsage,
           [if_nested_deeper_than: 2, if_called_more_often_than: 1]},
          {Credo.Check.Refactor.Nesting, false},
          {Credo.Check.Refactor.CyclomaticComplexity, false},
          {Credo.Check.Readability.ParenthesesOnZeroArityDefs, false},
          {Credo.Check.Readability.AliasOrder, false},
          {Credo.Check.Readability.ModuleDoc, false},
          {Credo.Check.Readability.UnnecessaryAliasExpansion, false},
          {Credo.Check.Readability.PredicateFunctionNames, false}
        ]
      }
    }
  ]
}
