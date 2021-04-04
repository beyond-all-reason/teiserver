Currently a selection of notes and "things to keep in mind" when writing a new protocol
- Always use tabs as separators
- Use namespaces to categorise commands
- Have some way to easily distinguish if a command is Server -> Client or Client -> Server, don't just reuse the same command name
- Command specifications should have parameter types defined
- Have versioned documentation, if someone wants to implement an older version there should be documentation for it
- No bitparsing
- If there's anything remotely confusing like bitparsing, have example test data for people writing their own implementation
- Should not need to use a regex to parse commands (maybe specific arguments but never the command as a whole)
