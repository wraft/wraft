defmodule WraftDocWeb.Api.V1.TriggerHistoryView do
  use WraftDocWeb, :view

  def render("create.json", %{}) do
    %{
      info:
        "Trigger accepted. All the required documents in the pipeline will be created soon and will be available for you to download.!"
    }
  end
end
