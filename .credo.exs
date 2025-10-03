%{
  configs: [
    %{
      name: "default",
      checks: [
        {Credo.Check.Warning.MissedMetadataKeyInLoggerConfig,
         [
           metadata_keys: [:request_id, :user_id, :pid, :actor_type, :actor_id]
         ]}
      ]
    }
  ]
}
