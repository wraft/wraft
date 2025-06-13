defmodule WraftDoc.FeatureFlags.OrganizationActor do
  @moduledoc """
  Actor implementation for FunWithFlags to support organization-based feature flags.
  """

  alias WraftDoc.Enterprise.Organisation

  @behaviour FunWithFlags.Actor

  def id(%Organisation{id: org_id}), do: "org:#{org_id}"
  def id(%{id: org_id}), do: "org:#{org_id}"
end
