defmodule WraftDoc.Notifications.Template do
  @moduledoc """
  Defines all notification templates and their configurations.
  """
  use WraftDoc.Notifications.Definition

  alias WraftDocWeb.MJML

  defnotification "registration.user_joins_wraft" do
    title("Welcome to Wraft")
    description("Receive a welcome message when you first join Wraft")

    message(fn %{user_name: user_name} ->
      "Welcome to Wraft, <strong>#{user_name}</strong> We're excited to have you on board."
    end)

    channels([:in_app, :email])
    email_template(MJML.Welcome)
    email_subject("Welcome to Wraft!")
  end

  defnotification "organisation.join_organisation" do
    title("Organization Welcome")
    description("Get notified when you join a new organization")

    message(fn %{organisation_name: organisation_name} ->
      "Welcome to <strong>#{organisation_name}</strong>!"
    end)

    channels([:in_app])
  end

  defnotification "organisation.join_organisation.all" do
    title("Joined in Organization")
    description("Be notified when new members join your organization")

    message(fn %{user_name: user_name} ->
      "#{user_name} joined to your organization"
    end)

    channels([:in_app])
  end

  defnotification "organisation.assign_role" do
    title("Role Assignment")
    description("Get notified when you are assigned a new role or permission")

    message(fn %{role_name: role_name, assigned_by: assigned_by} ->
      "<strong>#{assigned_by}</strong> assigned the role <strong>#{role_name}</strong> to you"
    end)

    channels([:in_app])
  end

  defnotification "organisation.unassign_role" do
    title("Role Revoked")
    description("Be informed when your role or permissions are removed")

    message(fn %{
                 assigned_by: assigned_by,
                 role_name: role_name
               } ->
      "<strong>#{assigned_by}</strong> revoked your role of <strong>#{role_name}</strong>"
    end)

    channels([:in_app])
  end

  defnotification "document.state_update" do
    title("Document State Update")
    description("Stay updated when documents progress through approval workflow states")

    message(fn %{
                 document_title: document_title,
                 state_name: state_name,
                 approver_name: approver_name
               } ->
      "<strong>#{approver_name}</strong> approved the document <strong>#{document_title}</strong> for the <strong>#{state_name}</strong> state"
    end)

    channels([:in_app, :email])
    email_template(MJML.DocumentStateUpdate)

    email_subject(fn %{document_title: title, state_name: state} ->
      "Document <strong>#{title}</strong> - <strong>#{state}</strong> State Update"
    end)
  end

  defnotification "document.pending_approvals" do
    title("Pending Approval")
    description("Get notified when documents require your approval or review")

    message(fn %{
                 document_title: document_title,
                 state_name: state_name
               } ->
      "Document <strong>#{document_title}</strong> is waiting for approvals in the <strong>#{state_name}</strong> state"
    end)

    channels([:in_app, :email])
    email_template(MJML.PendingApproval)
    email_subject("Document Pending Approval")
  end

  defnotification "document.add_comment" do
    title("New Comment")
    description("Receive notifications when someone comments on your documents or mentions you")

    message(fn %{
                 document_title: document_title,
                 commenter_name: user_name
               } ->
      "<strong>#{user_name}</strong> added a comment on <strong>#{document_title}</strong>. Check it out!"
    end)

    channels([:in_app, :email])
    email_template(MJML.CommentNotification)
    email_subject("New Comment Mention")
  end

  defnotification "document.reminder" do
    title("Document Reminder")
    description("Get reminded about documents that need your attention or action")

    message(fn %{document_title: document_title} ->
      "Reminder: Document <strong>'#{document_title}'</strong> needs your attention."
    end)

    channels([:in_app, :email])
    email_template(MJML.DocumentReminder)
    email_subject("Document Reminder")
  end

  defnotification "document.share" do
    title("Document Shared With You")
    description("Be notified when someone shares a document with you for collaboration")

    message(fn %{
                 document_title: document_title,
                 sharer_name: sharer_name
               } ->
      "<strong>#{sharer_name}</strong> has shared the document <strong>'#{document_title}'</strong> with you. You can now access, review, and collaborate on this document as part of the workflow."
    end)

    channels([:in_app, :email])
    email_template(MJML.Notification)

    email_subject(fn %{document_title: document_title} ->
      "Document Shared: <strong>#{document_title}</strong>"
    end)
  end

  defnotification "document.publish" do
    title("Document Published")
    description("Get notified when documents you're involved with are published and go live")

    message(fn %{
                 document_title: document_title,
                 publisher_name: publisher_name
               } ->
      "<strong>#{publisher_name}</strong> has published the document <strong>'#{document_title}'</strong>. The document is now live and available for viewing."
    end)

    channels([:in_app, :email])
    email_template(MJML.Notification)

    email_subject(fn %{document_title: document_title} ->
      "Document Published: <strong>#{document_title}</strong>"
    end)
  end

  defnotification "document.signature_request" do
    title("Signature Request")
    description("Receive alerts when your digital signature is requested on documents")

    message(fn %{
                 document_title: document_title,
                 requester_name: requester_name
               } ->
      "<strong>#{requester_name}</strong> has requested your signature on the document <strong>'#{document_title}'</strong>."
    end)

    channels([:in_app])
  end

  defnotification "document.fully_signed" do
    title("Document Fully Signed")
    description("Know when documents requiring signatures are completed by all parties")

    message(fn %{
                 document_title: document_title
               } ->
      "The document <strong>'#{document_title}'</strong> has been fully signed by all parties. The signed document is now available for download."
    end)

    channels([:in_app])
  end

  defnotification "pipeline.build_success" do
    title("Pipeline Build Success")
    description("Get notified when your pipeline builds complete successfully")

    message(fn _params ->
      "The pipeline build has succeeded."
    end)

    channels([:in_app])
  end

  defnotification "pipeline.build_failed" do
    title("Pipeline Build Failed")
    description("Get notified when pipeline builds fail so you can take action")

    message(fn _params ->
      "The pipeline build has failed."
    end)

    channels([:in_app])
  end

  @doc """
    List all available notification types.
  """
  @spec list_notification_types() :: [String.t()]
  def list_notification_types, do: notification_types()

  @doc """
    Get notifications with description.
  """
  @spec list_notifications() :: [%{event: String.t(), description: String.t()}]
  def list_notifications do
    Enum.map(notification_types(), fn type ->
      type
      |> get_notification()
      |> case do
        %{description: description} when not is_nil(description) ->
          %{event: type, description: description}

        _ ->
          %{event: type, description: ""}
      end
    end)
  end

  @doc """
    Render a notification message.
  """
  @spec render_message(String.t(), map()) :: String.t()
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
  @spec get_channels(String.t()) :: [atom()]
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
  @spec get_email_config(String.t()) :: {:ok, map()} | :error
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
