defmodule WraftDocWeb.Plug.FeatureFlagCheck do
  @moduledoc """
  Plug to check if a feature is enabled for the current organisation.
  """
  import Plug.Conn

  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.FeatureFlags
  alias WraftDoc.Repo

  def init(opts), do: opts

  def call(conn, opts) do
    feature = Keyword.fetch!(opts, :feature)
    organisation = Repo.get(Organisation, conn.assigns[:current_user].current_org_id)

    if feature in FeatureFlags.available_features() do
      if FeatureFlags.enabled?(feature, organisation) do
        conn
      else
        conn
        |> send_resp(:forbidden, Jason.encode!(%{error: "Feature #{feature} is disabled"}))
        |> halt()
      end
    else
      raise ArgumentError, "Invalid feature name: #{feature}"
    end
  end
end
