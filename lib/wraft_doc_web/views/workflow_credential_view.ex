defmodule WraftDocWeb.Api.V1.WorkflowCredentialView do
  use WraftDocWeb, :view

  def render("index.json", %{credentials: credentials}) do
    %{
      credentials: render_many(credentials, __MODULE__, "credential.json")
    }
  end

  def render("show.json", %{credential: credential}) do
    render_one(credential, __MODULE__, "credential.json")
  end

  def render("credential.json", %{credential: credential}) do
    # Never expose decrypted credentials in API responses
    # Only show metadata
    %{
      id: credential.id,
      name: credential.name,
      adaptor_type: credential.adaptor_type,
      metadata: credential.metadata || %{},
      inserted_at: credential.inserted_at,
      updated_at: credential.updated_at
    }
  end
end
