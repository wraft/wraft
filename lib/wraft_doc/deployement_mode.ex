defmodule WraftDoc.DeploymentMode do
  @moduledoc false

  @deployment_mode Application.compile_env(:wraft_doc, :deployement_mode)

  def saas? do
    @deployment_mode == "saas"
  end

  def self_hosted? do
    @deployment_mode == "self-hosted"
  end
end
