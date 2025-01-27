defmodule WraftDoc.Notifications.NotificationMessages do
  @moduledoc """
  Notification message
  """

  def message(:user_joins_wraft, %{user_name: user_name}) do
    "Welcome to Wraft, #{user_name}! We're excited to have you on board. Start creating, collaborating, and managing documents with ease!"
  end

  def message(:joins_organisation, %{organisation_name: organisation_name}) do
    "Welcome to #{organisation_name}...!!"
  end

  def message(:assigned_role, %{
        role_name: role_name,
        organisation_name: organisation_name
      }) do
    "The Role of #{role_name} has been assigned to you in #{organisation_name}!"
  end

  def message(:unassign_role, %{organisation_name: organisation_name, role_name: role_name}) do
    "Your role of #{role_name} in #{organisation_name} has been revoked. Contact the #{organisation_name} administrator for further details."
  end

  def message(:pending_approvals, %{
        organisation_name: organisation_name,
        document_name: document_name,
        state_name: state_name
      }) do
    "Action Required: The #{state_name} for #{document_name} in #{organisation_name} is pending."
  end

  def message(:add_comment, %{
        organisation_name: organisation_name,
        document_title: document_title,
        user_name: user_name
      }) do
    "#{user_name}You've been mentioned in a comment on #{document_title} in #{organisation_name}. Check it out!"
  end
end
