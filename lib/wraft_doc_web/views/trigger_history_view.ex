defmodule WraftDocWeb.Api.V1.TriggerHistoryView do
  use WraftDocWeb, :view
  alias __MODULE__
  alias WraftDoc.Document.Pipeline.TriggerHistory
  alias WraftDocWeb.Api.V1.UserView

  def render("create.json", %{}) do
    %{
      info:
        "Trigger accepted. All the required documents in the pipeline will be created soon and will be available for you to download.!"
    }
  end

  def render("trigger.json", %{trigger: trigger}) do
    %{
      id: trigger.uuid,
      data: trigger.data,
      error: trigger.error,
      state: TriggerHistory.get_state(trigger),
      start_time: trigger.start_time,
      end_time: trigger.end_time,
      duration: trigger.duration,
      zip_file: generate_url(trigger),
      updated_at: trigger.updated_at,
      inserted_at: trigger.inserted_at,
      creator: render_one(trigger.creator, UserView, "user.json", as: :user)
    }
  end

  def render("index.json", %{
        triggers: triggers,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      triggers: render_many(triggers, TriggerHistoryView, "trigger.json", as: :trigger),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end

  defp generate_url(%{zip_file: zip_file}) when is_nil(zip_file) == false do
    "temp/pipe_builds/#{zip_file}"
  end

  defp generate_url(%{zip_file: zip_file}) when is_nil(zip_file) do
    nil
  end
end
