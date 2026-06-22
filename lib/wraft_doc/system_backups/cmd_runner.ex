defmodule WraftDoc.SystemBackups.CmdRunner do
  @moduledoc """
  Behaviour seam around `System.cmd/3` so the backup engine's shell-outs
  (pg_dump, pg_restore, tar, age, df) can be mocked in tests — the same
  compile-env indirection `WraftDoc.Client.Minio` uses for ExAws.
  """

  @callback cmd(binary(), [binary()], keyword()) :: {binary(), non_neg_integer()}

  defmodule SystemCmd do
    @moduledoc "Real implementation delegating to `System.cmd/3`."
    @behaviour WraftDoc.SystemBackups.CmdRunner

    @impl true
    def cmd(executable, args, opts), do: System.cmd(executable, args, opts)
  end
end
