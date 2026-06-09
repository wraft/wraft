defmodule WraftDoc.RateLimiter do
  @moduledoc """
  ETS-backed rate limiter (Hammer).

  Note: the ETS backend is per-node — limits are not shared across BEAM
  nodes. Revisit with a Redis/DB backend if production runs multiple nodes.
  """
  use Hammer, backend: :ets
end
