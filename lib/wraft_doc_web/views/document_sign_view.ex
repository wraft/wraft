defmodule WraftDocWeb.Api.V1.DocumentSignView do
  use WraftDocWeb, :view

  def render("show.json", %{integration: integration}) do
    %{
      "envelopeId" => integration["envelopeId"],
      "status" => integration["status"],
      "statusDateTime" => integration["statusDateTime"],
      "uri" => integration["uri"]
    }
  end

  def render("error.json", %{error: error}) do
    %{
      error: error
    }
  end
end
