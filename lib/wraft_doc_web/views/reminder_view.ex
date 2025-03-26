defmodule WraftDocWeb.Api.V1.ReminderView do
  @moduledoc """
  View module for reminder controller.
  """
  use WraftDocWeb, :view

  alias WraftDocWeb.Api.V1.InstanceView

  @doc """
  Renders a list of reminders
  """

  def render("index.json", %{
        reminders: reminders,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      reminders: render_many(reminders, __MODULE__, "create.json", as: :reminder),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end

  @doc """
  Renders a single reminder
  """
  def render("create.json", %{reminder: reminder}) do
    %{
      reminder: render_one(reminder, __MODULE__, "reminder.json", as: :reminder),
      content: render_one(reminder.content, InstanceView, "instance.json", as: :instance)
    }
  end

  def render("reminder.json", %{reminder: reminder}) do
    %{
      id: reminder.id,
      reminder_date: reminder.reminder_date,
      status: reminder.status,
      message: reminder.message,
      notification_type: reminder.notification_type,
      recipients: reminder.recipients,
      manual_date: reminder.manual_date,
      sent_at: reminder.sent_at,
      creator_id: reminder.creator_id,
      inserted_at: reminder.inserted_at,
      updated_at: reminder.updated_at
    }
  end
end
