defmodule WraftDoc.Notifications.Template do
  @moduledoc """
  Defines all notification templates and their configurations.
  """
  use WraftDoc.Notifications.Definition

  alias WraftDocWeb.MJML

  defnotification "registration.user_joins_wraft" do
    title("Welcome to Wraft")

    message(fn %{user_name: user_name} ->
      "Welcome to Wraft, #{user_name}! We're excited to have you on board."
    end)

    channels([:in_app, :email])
    email_template(MJML.Welcome)
    email_subject("Welcome to Wraft!")
  end

  defnotification "organisation.join_organisation" do
    title("Organization Welcome")

    message(fn %{organisation_name: organisation_name} ->
      "Welcome to #{organisation_name}!"
    end)

    channels([:in_app])
  end

  defnotification "organisation.assign_role" do
    title("Role Assignment")

    message(fn %{role_name: role_name, organisation_name: organisation_name} ->
      "The Role of #{role_name} has been assigned to you in #{organisation_name}!"
    end)

    channels([:in_app])
  end

  defnotification "organisation.unassign_role" do
    title("Role Revoked")

    message(fn %{organisation_name: organisation_name, role_name: role_name} ->
      "Your role of #{role_name} in #{organisation_name} has been revoked. Contact the #{organisation_name} administrator for further details."
    end)

    channels([:in_app])
  end

  defnotification "document.state_update" do
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
    email_template(MJML.DocumentStateUpdate)

    email_subject(fn %{document_title: title, state_name: state} ->
      "Document '#{title}' - #{state} State Update"
    end)
  end

  defnotification "document.pending_approvals" do
    title("Pending Approval")

    message(fn %{
                 document_title: document_title,
                 organisation_name: organisation_name,
                 state_name: state_name
               } ->
      "The Document #{document_title} in #{organisation_name} has been pending for the #{state_name}"
    end)

    channels([:in_app, :email])
    email_template(MJML.PendingApproval)
    email_subject("Document Pending Approval")
  end

  defnotification "document.add_comment" do
    title("New Comment")

    message(fn %{
                 document_title: document_title,
                 commenter_name: user_name
               } ->
      "You've been mentioned in a comment on #{document_title} by #{user_name}. Check it out!"
    end)

    channels([:in_app, :email])
    email_template(MJML.CommentNotification)
    email_subject("New Comment Mention")
  end

  defnotification "document.reminder" do
    title("Document Reminder")

    message(fn %{document_title: document_title} ->
      "Reminder: Document '#{document_title}' needs your attention."
    end)

    channels([:in_app, :email])
    email_template(MJML.DocumentReminder)
    email_subject("Document Reminder")
  end

  defnotification "document.share" do
    title("Document Shared With You")

    message(fn %{
                 document_title: document_title,
                 sharer_name: sharer_name,
                 organisation_name: organisation_name
               } ->
      "#{sharer_name} has shared the document '#{document_title}' with you in #{organisation_name}. You can now access, review, and collaborate on this document as part of the workflow."
    end)

    channels([:in_app, :email])
    email_template(MJML.Notification)

    email_subject(fn %{document_title: document_title} ->
      "Document Shared: #{document_title}"
    end)
  end

  defnotification "document.publish" do
    title("Document Published")

    message(fn %{
                 document_title: document_title,
                 publisher_name: publisher_name
               } ->
      "The document '#{document_title}' has been published by #{publisher_name}. The document is now live and available for viewing."
    end)

    channels([:in_app, :email])
    email_template(MJML.Notification)

    email_subject(fn %{document_title: document_title} ->
      "Document Published: #{document_title}"
    end)
  end

  defnotification "document.signature_request" do
    title("Signature Request")

    message(fn %{
                 document_title: document_title,
                 requester_name: requester_name
               } ->
      "#{requester_name} has requested your signature on the document '#{document_title}'. Please review and sign the document at your earliest convenience."
    end)

    channels([:in_app])
  end

  defnotification "document.fully_signed" do
    title("Document Fully Signed")

    message(fn %{
                 document_title: document_title
               } ->
      "The document '#{document_title}' has been fully signed by all parties. The signed document is now available for download."
    end)

    channels([:in_app])
  end

  defnotification "pipeline.form_mapping_not_complete" do
    title("Form Mapping Incomplete")

    message(fn _params ->
      "Please complete the form mapping for pipeline and try again."
    end)

    channels([:in_app])
  end

  defnotification "pipeline.not_found" do
    title("Pipeline Not Found")

    message(fn _params ->
      "The pipeline you are trying to access does not exist."
    end)

    channels([:in_app])
  end

  defnotification "pipeline.instance_failed" do
    title("Pipeline Instance Failed")

    message(fn _params ->
      "The pipeline instance has failed."
    end)

    channels([:in_app])
  end

  defnotification "pipeline.download_error" do
    title("Pipeline Download Error")

    message(fn _params ->
      "There was an error downloading the pipeline."
    end)

    channels([:in_app])
  end

  defnotification "pipeline.build_success" do
    title("Pipeline Build Success")

    message(fn _params ->
      "The pipeline build has succeeded."
    end)

    channels([:in_app])
  end

  defnotification "pipeline.build_failed" do
    title("Pipeline Build Failed")

    message(fn _params ->
      "The pipeline build has failed."
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

      %{message: message} when is_binary(message) ->
        message

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
      %{email_template: template, email_subject: subject, title: title}
      when not is_nil(template) ->
        {:ok, %{template: template, subject: normalize_subject(subject), title: title}}

      _ ->
        :error
    end
  end

  defp normalize_subject(subject) when is_function(subject), do: subject
  defp normalize_subject(subject), do: fn _ -> subject end
end
