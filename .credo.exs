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
        {Credo.Check.Design.AliasUsage, false}
        # {Credo.Check.Design.AliasUsage, [if_nested_deeper_than: 2, if_called_more_often_than: 1]}
      ]
    }
  ]
}
