defmodule WraftDoc.Notifications.Template do
  @moduledoc """
  Defines all notification templates and their configurations.
  """

  use WraftDoc.Notifications.Definition

  defnotification :user_joins_wraft do
    title("Welcome to Wraft")

    message(fn %{user_name: user_name} ->
      "Welcome to Wraft, #{user_name}! We're excited to have you on board."
    end)

    channels([:in_app, :email])
    email_template(:welcome_email)
    email_subject("Welcome to Wraft!")
  end

  defnotification :join_organisation do
    title("Organization Welcome")

    message(fn %{organisation_name: organisation_name} ->
      "Welcome to #{organisation_name}!"
    end)

    channels([:in_app])
  end

  defnotification :assign_role do
    title("Role Assignment")

    message(fn %{role_name: role_name, organisation_name: organisation_name} ->
      "The Role of #{role_name} has been assigned to you in #{organisation_name}!"
    end)

    channels([:in_app])
  end

  defnotification :unassign_role do
    title("Role Revoked")

    message(fn %{organisation_name: organisation_name, role_name: role_name} ->
      "Your role of #{role_name} in #{organisation_name} has been revoked. Contact the #{organisation_name} administrator for further details."
    end)

    channels([:in_app])
  end

  # Document notifications
  defnotification :state_update do
    title("Document State Update")

    message(fn %{
                 document_title: document_title,
                 organisation_name: organisation_name,
                 state_name: state_name,
                 approver_name: approver_name
               } ->
      "The Document #{document_title} in #{organisation_name} had been approved for the #{state_name} State by #{approver_name}"
    end)

    channels([:in_app, :email])
    email_template(:document_state_update)

    email_subject(fn %{document_title: title, state_name: state} ->
      "Document '#{title}' - #{state} State Update"
    end)
  end

  defnotification :pending_approvals do
    title("Pending Approval")

    message(fn %{
                 document_title: document_title,
                 organisation_name: organisation_name,
                 state_name: state_name
               } ->
      "The Document #{document_title} in #{organisation_name} has been pending for the #{state_name}"
    end)

    channels([:in_app, :email])
    email_template(:pending_approval)
    email_subject("Document Pending Approval")
  end

  defnotification :add_comment do
    title("New Comment")

    message(fn %{
                 organisation_name: organisation_name,
                 document_title: document_title
               } ->
      "You've been mentioned in a comment on #{document_title} in #{organisation_name}. Check it out!"
    end)

    channels([:in_app, :email])
    email_template(:comment_notification)
    email_subject("New Comment Mention")
  end

  defnotification :document_reminder do
    title("Document Reminder")

    message(fn %{document_title: document_title} ->
      "Reminder: Document '#{document_title}' needs your attention."
    end)

    channels([:in_app, :email])
    email_template(:document_reminder)
    email_subject("Document Reminder")
  end

  # Pipeline notifications
  defnotification :form_mapping_not_complete do
    title("Form Mapping Incomplete")

    message(fn _params ->
      "Please complete the form mapping for pipeline and try again."
    end)

    channels([:in_app])
  end

  @doc """
    List all available notification types.
  """
  def list_notification_types, do: notification_types()

  @doc """
    Render a notification message.
  """
  def render_message(type, params) do
    type
    |> get_notification()
    |> case do
      %{message: message_fn} when is_function(message_fn) ->
        message_fn.(params)

      _ ->
        raise "Notification type #{type} not found"
    end
  end

  @doc """
    Get notification channels.
  """
  def get_channels(type) do
    type
    |> get_notification()
    |> case do
      %{channels: channels} -> channels
      _ -> [:in_app]
    end
  end

  @doc """
    Get email configuration.
  """
  def get_email_config(type) do
    type
    |> get_notification()
    |> case do
      %{email_template: template, email_subject: subject}
      when not is_nil(template) ->
        {:ok, %{template: template, subject: normalize_subject(subject)}}

      _ ->
        :error
    end
  end

  defp normalize_subject(subject) when is_function(subject), do: subject
  defp normalize_subject(subject), do: fn _ -> subject end
end
