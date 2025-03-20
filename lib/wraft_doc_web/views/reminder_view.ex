defmodule WraftDocWeb.Api.V1.ReminderView do
  @moduledoc """
  View module for reminder controller.
  """
  use WraftDocWeb, :view

  @doc """
  Renders a list of reminders
  """
  def render("index.json", %{reminders: reminders}) do
    render_many(reminders, __MODULE__, "reminder.json", as: :reminder)
  end

  @doc """
  Renders a single reminder
  """
  def render("show.json", %{reminder: reminder}) do
    render_one(reminder, __MODULE__, "reminder.json", as: :reminder)
  end

  def render("reminder.json", %{reminder: reminder}) do
    %{
      id: reminder.id,
      instance_id: reminder.instance_id,
      reminder_date: reminder.reminder_date,
      status: reminder.status,
      message: reminder.message,
      notification_type: reminder.notification_type,
      recipients: reminder.recipients,
      manual_date: reminder.manual_date,
      sent_at: reminder.sent_at,
      inserted_at: reminder.inserted_at,
      updated_at: reminder.updated_at
    }
  end
end
