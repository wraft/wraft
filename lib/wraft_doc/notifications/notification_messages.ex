defmodule WraftDoc.Notifications.NotificationMessages do
  @moduledoc """
  Notification message
  """

  def message(:user_joins_wraft, %{user_name: user_name}) do
    "Welcome to Wraft, #{user_name}! We're excited to have you on board. Start creating, collaborating, and managing documents with ease!"
  end

  def message(:join_organisation, %{organisation_name: organisation_name}) do
    "Welcome to #{organisation_name}.!"
  end

  def message(:assign_role, %{
        role_name: role_name,
        organisation_name: organisation_name
      }) do
    "The Role of #{role_name} has been assigned to you in #{organisation_name}!"
  end

  def message(:unassign_role, %{organisation_name: organisation_name, role_name: role_name}) do
    "Your role of #{role_name} in #{organisation_name} has been revoked. Contact the #{organisation_name} administrator for further details."
  end

  def message(:state_update, %{
        document_title: document_title,
        organisation_name: organisation_name,
        state_name: state_name,
        approver_name: approver_name
      }) do
    "The Document #{document_title} in #{organisation_name} had been approved for the #{state_name} State by #{approver_name}"
  end

  def message(:pending_approvals, %{
        document_title: document_title,
        organisation_name: organisation_name,
        state_name: state_name
      }) do
    "The Document #{document_title} in #{organisation_name} has been pending for the #{state_name}"
  end

  def message(:add_comment, %{
        organisation_name: organisation_name,
        document_title: document_title
      }) do
    "New comment on #{document_title} in #{organisation_name}. Check it out!"
  end

  def message(:mention_comment, %{
        document_title: document_title,
        mentioned_by: mentioned_by
      }) do
    "You've been mentioned in a comment on #{document_title} by #{mentioned_by}. Check it out!"
  end

  def message(:form_mapping_not_complete, _) do
    "Please complete the form mapping for pipeline and try again."
  end

  def message(:pipeline_not_found, _) do
    "The pipeline you're trying to run does not exist.
    Please double-check the pipeline and try again."
  end

  def message(:pipeline_instance_failed, _) do
    "There was an error creating the document instance for pipeline, Please check the input data and try again."
  end

  def message(:pipeline_download_error, _) do
    "There was an error downloading the assets for the pipeline. Please try again."
  end

  def message(:pipeline_build_success, _) do
    "Pipeline build success"
  end

  def message(:pipeline_build_failed, _) do
    "Some builds failed for the pipeline. Please check the logs for more information."
  end

  def message(:document_reminder, %{
        document_title: document_title,
        instance_id: instance_id
      }) do
    "The Document with title: #{document_title} (Document ID: #{instance_id}) is approaching its expiry. Please take the necessary action before the deadline."
  end
end
