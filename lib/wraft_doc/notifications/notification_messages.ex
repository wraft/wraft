defmodule WraftDoc.Notifications.NotificationMessages do
  @moduledoc """
  Notification message
  """
  alias WraftDoc.Account
  alias WraftDoc.Document
  alias WraftDoc.Enterprise
  alias WraftDoc.Repo

  def message(:user_joins_wraft, %{user_id: user_id}) do
    user = Account.get_user(user_id)

    "Welcome to Wraft, #{user.name}! We're excited to have you on board. Start creating, collaborating, and managing documents with ease!"
  end

  def message(:user_joins_new_organisation, %{organisation_id: organisation_id}) do
    organisation = Enterprise.get_organisation(organisation_id)
    "Welcome to #{organisation.name}! You've successfully joined the organisation_id!"
  end

  def message(:user_assigned_role_or_update, %{
        organisation_id: organisation_id,
        role_id: role_id,
        user_id: user_id
      }) do
    role_name =
      Repo.preload(
        Account.get_user_role(%{current_org_id: organisation_id}, user_id, role_id),
        :role
      )

    "The Role of #{role_name.role.name} has been assigned to you!"
  end

  def message(:role_revoked_or_removed, %{organisation_id: organisation_id, role_id: role_id}) do
    "Your role_id of #{role_id} in #{organisation_id} has been revoked. Contact the #{organisation_id} administrator for further details."
  end

  def message(:organisation_document_flow_pending, %{
        organisation_id: organisation_id,
        document_id: document_id,
        state_id: state_id,
        user: user
      }) do
    state_flow = Enterprise.get_state(user, state_id)
    organisation = Enterprise.get_organisation(organisation_id)
    document = Document.get_instance(document_id, %{current_org_id: organisation_id})

    "Action Required: The #{state_flow.state} for #{document.serialized["title"]} in #{organisation.name} is pending."
  end

  def message(:organisation_pipeline_update, _args) do
    "The organisation pipeline has been updated."
  end

  def message(:comments_or_mentions_made, %{
        organisation_id: organisation_id,
        document_id: document_id,
        creator_id: user_id
      }) do
    document = Document.get_instance(document_id, %{current_org_id: organisation_id})
    organisation = Enterprise.get_organisation(organisation_id)
    user = Account.get_user(user_id)

    "#{user.name}You've been mentioned in a comment on #{document.serialized["title"]} in #{organisation.name}. Check it out!"
  end
end
