# test/test_helper.exs
ExUnit.start(formatters: [ExUnit.CLIFormatter])

# Configure Ecto sandbox
Ecto.Adapters.SQL.Sandbox.mode(WraftDoc.Repo, :manual)
