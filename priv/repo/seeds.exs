# Script for populating the \base. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     WraftDoc.Repo.insert!(%WraftDoc.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias FunWithFlags
alias WraftDoc.Account.Country
alias WraftDoc.Document.Engine
alias WraftDoc.Enterprise.Plan
alias WraftDoc.Repo
alias WraftDoc.Seed

if !FunWithFlags.enabled?(:seeds_ran?) do
  # Seed users
  user = Seed.generate_user("wraftuser", "wraftuser@gmail.com")
  user_list = for _ <- 1..2, do: Seed.generate_user()
  user_list = [user | user_list]

  # Seed organisation and user organisation
  organisation_list = for user <- user_list, do: Seed.seed_user_organisation(user)

  country = Repo.get_by(Country, country_name: "India")

  # Delete all engines and seed engines again to avoid unique constraint error
  Repo.delete_all(Engine)
  [_pdf, _latex, pandoc] = Seed.seed_engine()

  plan = Repo.get_by(Plan, name: "Free Trial")

  for {user, organisation} <- List.zip([user_list, organisation_list]) do
    # Seed profiles with country
    Seed.seed_profile(user, country)

    # Seed Membership
    Seed.seed_membership(organisation, plan)

    # Seed Block and Block Template
    Seed.seed_block_and_block_template(user, organisation)
  end

  # Seed roles and user roles
  role_list =
    for {user, organisation} <- List.zip([user_list, organisation_list]),
        do: Seed.seed_user_roles(user, organisation)

  # Seed layout with layout asset
  layout_list =
    for {user, organisation} <- List.zip([user_list, organisation_list]),
        do: Seed.seed_layout_and_layout_asset(user, organisation, pandoc)

  # Seed theme with theme asset
  theme_list =
    for {user, organisation} <- List.zip([user_list, organisation_list]),
        do: Seed.seed_theme_and_theme_asset(user, organisation)

  # Seed Work Flow
  flow_list =
    for {user, organisation} <- List.zip([user_list, organisation_list]),
        do: Seed.seed_flow(user, organisation)

  # Seed Vendor
  vendor_list =
    for {user, organisation} <- List.zip([user_list, organisation_list]),
        do: Seed.seed_vendor(user, organisation)

  # Seed Content Type and Content Type Role
  content_type_list =
    for {user, organisation, layout, theme, flow, role} <-
          List.zip([user_list, organisation_list, layout_list, theme_list, flow_list, role_list]),
        do:
          Seed.seed_content_type_and_content_type_role(
            user,
            organisation,
            layout,
            theme,
            flow,
            role
          )

  # Seed Flow State
  state_list =
    for {user, organisation, flow} <-
          List.zip([user_list, organisation_list, flow_list]),
        do: Seed.seed_state(user, organisation, flow)

  # Seed Document Instance
  instance_list =
    for {user, content_type, states, vendor} <-
          List.zip([user_list, content_type_list, state_list, vendor_list]),
        do: Seed.seed_document_instance(user, content_type, Enum.random(states), vendor)

  # Seed Build History
  for {user, instance} <- List.zip([user_list, instance_list]),
      do: Seed.seed_build_history(user, instance)

  # Seed Approval System
  for {user, flow} <- List.zip([user_list, flow_list]),
      do: Seed.seed_approval_system(user, flow)

  # Seed Document Instance Version
  for {user, instance} <- List.zip([user_list, instance_list]),
      do: Seed.seed_document_instance_version(user, instance)

  # Seed Data Template
  for {user, content_type} <- List.zip([user_list, content_type_list]),
      do: Seed.seed_data_template(user, content_type)

  # Seed fields and content type field
  for {content_type, organisation} <- List.zip([content_type_list, organisation_list]),
      do: Seed.seed_field_and_content_type_field(content_type, organisation)

  # Enable fun with flags for ensuring that the seeds are not run more than once
  FunWithFlags.enable(:seeds_ran?)
end
