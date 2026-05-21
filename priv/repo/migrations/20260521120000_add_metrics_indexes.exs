defmodule WraftDoc.Repo.Migrations.AddMetricsIndexes do
  use Ecto.Migration

  @moduledoc """
  Indexes that power the admin Build Metrics and Pipeline Metrics pages.

  Both `build_history` and `trigger_history` shipped without any indexes
  beyond the primary key. The metrics pages bound every query by a time
  range, optionally join through `content`/`pipeline` to filter by
  organisation, and order newest-first — without these the page degrades
  to full table scans as soon as either table accumulates non-trivial
  data.

  - `build_history(start_time DESC)` — range filter + chart bucketing.
  - `build_history(content_id)`     — org-filter join via `content` to
    `instance.organisation_id`.
  - `trigger_history(inserted_at DESC)` — range filter + ORDER BY.
  - `trigger_history(pipeline_id)`     — org-filter join via `pipeline`
    to `pipeline.organisation_id`.
  """

  def change do
    create_if_not_exists(index(:build_history, ["start_time DESC"]))
    create_if_not_exists(index(:build_history, [:content_id]))
    create_if_not_exists(index(:trigger_history, ["inserted_at DESC"]))
    create_if_not_exists(index(:trigger_history, [:pipeline_id]))
  end
end
