%{
  configs: [
    %{
      name: "default",
      #
      # These are the files included in the analysis:
      files: %{
        #
        # You can give explicit globs or simply directories.
        # In the latter case `**/*.{ex,exs}` will be used.
        #
        included: [
          "credo/",
          "lib/",
          "priv/",
          "scripts/",
          "test/"
        ],
        excluded: [
          ~r"/_build/",
          ~r"/deps/",
          ~r"/node_modules/"
        ]
      },
      #
      # Load and configure plugins here:
      #
      plugins: [],
      #
      # If you create your own checks, you must specify the source files for
      # them here, so they can be loaded by Credo before running the analysis.
      #
      requires: [],
      #
      # If you want to enforce a style guide and need a more traditional linting
      # experience, you can change `strict` to `true` below:
      #
      strict: true,
      #
      # To modify the timeout for parsing files, change this value:
      #
      parse_timeout: 5000,
      #
      # If you want to use uncolored output by default, you can change `color`
      # to `false` below:
      #
      color: true,
      #
      # You can customize the parameters of any check by adding a second element
      # to the tuple.
      #
      # To disable a check put `false` as second element:
      #
      #     {Credo.Check.Design.DuplicatedCode, false}
      #
      checks: %{
        enabled: [
          {Credo.Check.Consistency.ExceptionNames, []},
          {Credo.Check.Consistency.LineEndings, []},
          {Credo.Check.Consistency.MultiAliasImportRequireUse, []},
          {Credo.Check.Consistency.ParameterPatternMatching, []},
          {Credo.Check.Consistency.SpaceAroundOperators, []},
          {Credo.Check.Consistency.SpaceInParentheses, []},
          {Credo.Check.Consistency.TabsOrSpaces, []},

          # We would like to enable this but it would be far too noisy
          # {Credo.Check.Consistency.UnusedVariableNames, [force: :meaningful]},
          #
          {Credo.Check.Design.AliasUsage, []},
          {Credo.Check.Design.TagFIXME, []},
          {Credo.Check.Readability.AliasOrder, []},
          {Credo.Check.Readability.BlockPipe, []},
          {Credo.Check.Readability.FunctionNames, []},
          # {Credo.Check.Readability.ImplTrue, []},

          {Credo.Check.Readability.MultiAlias, []},
          {Credo.Check.Readability.SeparateAliasRequire, []},
          {Credo.Check.Design.AliasUsage, []},
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
