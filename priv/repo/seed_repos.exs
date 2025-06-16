alias WraftDoc.Repo
alias WraftDoc.Seed

alias WraftDoc.Storage.Repository

# Create a single repository
repository =
  case Repo.get_by(WraftDoc.Storage.Repository, name: "Main Repository") do
    nil ->
      Repo.insert!(%WraftDoc.Storage.Repository{
        name: "Main Repository",
        description: "A test repository for development",
        status: "active",
        item_count: 0,
        # 100MB in bytes
        storage_limit: 100_000_000,
        current_storage_used: 0
      })

    existing_repo ->
      existing_repo
  end

# Load first user
user = Repo.get_by(WraftDoc.Account.User, email: "wraftuser@gmail.com")

# Update repository with user info
repository =
  repository
  |> Ecto.Changeset.change()
  |> Ecto.Changeset.put_change(:creator_id, Ecto.UUID.cast!(user.id))
  |> Ecto.Changeset.put_change(:organisation_id, Ecto.UUID.cast!(user.last_signed_in_org))
  |> Repo.update!()

# dummyrepos = [
#   "Contracts/",
#   "Contracts/Client_Agreements/",
#   "Contracts/Client_Agreements/acme_corp_service_agreement.pdf",
#   "Contracts/Client_Agreements/global_tech_master_agreement.pdf",
#   "Contracts/Client_Agreements/innovate_solutions_contract.pdf",
#   "Contracts/Client_Agreements/enterprise_systems_sla.pdf",
#   "Contracts/Client_Agreements/digital_dynamics_partnership.pdf",
#   "Contracts/Vendor_Contracts/",
#   "Contracts/Vendor_Contracts/office_supplies_contract.pdf",
#   "Contracts/Vendor_Contracts/it_services_agreement.pdf",
#   "Contracts/Vendor_Contracts/cleaning_services_contract.pdf",
#   "Contracts/Vendor_Contracts/security_services_agreement.pdf",
#   "Contracts/Vendor_Contracts/catering_services_contract.pdf",
#   "Contracts/Employment/",
#   "Contracts/Employment/executive_employment_agreement.pdf",
#   "Contracts/Employment/senior_developer_contract.pdf",
#   "Contracts/Employment/marketing_manager_agreement.pdf",
#   "Contracts/Employment/sales_director_contract.pdf",
#   "Contracts/Employment/hr_specialist_agreement.pdf",
#   "Proposals/",
#   "Proposals/2024/",
#   "Proposals/2024/Q1/",
#   "Proposals/2024/Q1/enterprise_software_proposal.pdf",
#   "Proposals/2024/Q1/cloud_migration_proposal.pdf",
#   "Proposals/2024/Q1/digital_transformation_proposal.pdf",
#   "Proposals/2024/Q2/",
#   "Proposals/2024/Q2/ai_implementation_proposal.pdf",
#   "Proposals/2024/Q2/cybersecurity_upgrade_proposal.pdf",
#   "Proposals/2024/Q2/mobile_app_development_proposal.pdf",
#   "Proposals/2024/Q3/",
#   "Proposals/2024/Q3/data_analytics_platform_proposal.pdf",
#   "Proposals/2024/Q3/infrastructure_modernization_proposal.pdf",
#   "Proposals/2024/Q3/business_intelligence_proposal.pdf",
#   "Proposals/2024/Q4/",
#   "Proposals/2024/Q4/automation_suite_proposal.pdf",
#   "Proposals/2024/Q4/integration_services_proposal.pdf",
#   "Agreements/",
#   "Agreements/Partnership/",
#   "Agreements/Partnership/strategic_alliance_agreement.pdf",
#   "Agreements/Partnership/joint_venture_agreement.pdf",
#   "Agreements/Partnership/technology_partnership_agreement.pdf",
#   "Agreements/Partnership/distribution_partnership_agreement.pdf",
#   "Agreements/Partnership/reseller_agreement.pdf",
#   "Agreements/Licensing/",
#   "Agreements/Licensing/software_license_agreement.pdf",
#   "Agreements/Licensing/trademark_license_agreement.pdf",
#   "Agreements/Licensing/patent_license_agreement.pdf",
#   "Agreements/Licensing/content_license_agreement.pdf",
#   "Agreements/NDA/",
#   "Agreements/NDA/mutual_nda_template.pdf",
#   "Agreements/NDA/client_confidentiality_agreement.pdf",
#   "Agreements/NDA/vendor_nda_agreement.pdf",
#   "Agreements/NDA/employee_confidentiality_agreement.pdf",
#   "SLA/",
#   "SLA/Service_Level_Agreements/",
#   "SLA/Service_Level_Agreements/cloud_hosting_sla.pdf",
#   "SLA/Service_Level_Agreements/application_support_sla.pdf",
#   "SLA/Service_Level_Agreements/network_services_sla.pdf",
#   "SLA/Service_Level_Agreements/database_management_sla.pdf",
#   "SLA/Service_Level_Agreements/backup_recovery_sla.pdf",
#   "SLA/Maintenance_Agreements/",
#   "SLA/Maintenance_Agreements/software_maintenance_agreement.pdf",
#   "SLA/Maintenance_Agreements/hardware_maintenance_agreement.pdf",
#   "SLA/Maintenance_Agreements/system_maintenance_sla.pdf",
#   "Legal/",
#   "Legal/Compliance/",
#   "Legal/Compliance/gdpr_compliance_document.pdf",
#   "Legal/Compliance/sox_compliance_report.pdf",
#   "Legal/Compliance/iso_certification_agreement.pdf",
#   "Legal/Compliance/hipaa_compliance_agreement.pdf",
#   "Legal/Compliance/pci_dss_compliance_document.pdf",
#   "Legal/Policies/",
#   "Legal/Policies/privacy_policy.pdf",
#   "Legal/Policies/terms_of_service.pdf",
#   "Legal/Policies/acceptable_use_policy.pdf",
#   "Legal/Policies/data_retention_policy.pdf",
#   "Legal/Policies/security_policy.pdf",
#   "Financial/",
#   "Financial/Invoices/",
#   "Financial/Invoices/2024_q1_invoices.pdf",
#   "Financial/Invoices/2024_q2_invoices.pdf",
#   "Financial/Invoices/2024_q3_invoices.pdf",
#   "Financial/Purchase_Orders/",
#   "Financial/Purchase_Orders/po_2024_001_office_equipment.pdf",
#   "Financial/Purchase_Orders/po_2024_002_software_licenses.pdf",
#   "Financial/Purchase_Orders/po_2024_003_consulting_services.pdf",
#   "Financial/Purchase_Orders/po_2024_004_hardware_procurement.pdf",
#   "HR/",
#   "HR/Policies/",
#   "HR/Policies/employee_handbook.pdf",
#   "HR/Policies/remote_work_policy.pdf",
#   "HR/Policies/code_of_conduct.pdf",
#   "HR/Policies/harassment_prevention_policy.pdf",
#   "HR/Policies/performance_review_policy.pdf",
#   "HR/Benefits/",
#   "HR/Benefits/health_insurance_agreement.pdf",
#   "HR/Benefits/retirement_plan_agreement.pdf",
#   "HR/Benefits/employee_stock_option_plan.pdf",
#   "HR/Benefits/flexible_spending_account_agreement.pdf",
#   "Operations/",
#   "Operations/Procedures/",
#   "Operations/Procedures/incident_response_procedure.pdf",
#   "Operations/Procedures/change_management_procedure.pdf",
#   "Operations/Procedures/backup_procedure.pdf",
#   "Operations/Procedures/disaster_recovery_procedure.pdf",
#   "Operations/Procedures/security_incident_procedure.pdf",
#   "Operations/Manuals/",
#   "Operations/Manuals/system_administration_manual.pdf",
#   "Operations/Manuals/user_training_manual.pdf",
#   "Operations/Manuals/troubleshooting_guide.pdf",
#   "Operations/Manuals/deployment_manual.pdf",
#   "Archived/",
#   "Archived/2023/",
#   "Archived/2023/expired_contracts.pdf",
#   "Archived/2023/completed_projects.pdf",
#   "Archived/2023/old_vendor_agreements.pdf",
#   "Archived/2022/",
#   "Archived/2022/legacy_system_documentation.pdf",
#   "Archived/2022/discontinued_service_agreements.pdf"
# ]

# # Sort paths by depth to ensure parents are created before children
# sorted_paths = Enum.sort_by(dummyrepos, fn path ->
#   path |> String.split("/") |> length()
# end)

# # Create storage items for the dummy repository structure
# Enum.each(sorted_paths, fn path ->
#   # Skip if already exists
#   unless Repo.get_by(WraftDoc.Storage.StorageItem, path: path) do
#     # Determine if it's a file or folder
#     is_file = String.contains?(path, ".")
#     item_type = if is_file, do: "file", else: "folder"

#     # Calculate depth level based on path separators
#     depth_level = path |> String.split("/") |> length()

#     # Create materialized path
#     materialized_path = "/" <> String.trim_trailing(path, "/")

#     # Extract name from path
#     name = path |> String.split("/") |> List.last() |> String.trim_trailing("/")

#     # Calculate parent_id by finding the parent path
#     parent_id = if depth_level > 1 do
#       # Get parent path by removing the last segment
#       path_segments = String.split(path, "/")
#       parent_path = path_segments |> Enum.drop(-1) |> Enum.join("/")

#       # Handle case where parent path might end with "/" for directories
#       parent_path = if String.ends_with?(parent_path, "/"), do: parent_path, else: parent_path <> "/"

#       # Try to find parent with or without trailing slash
#       parent_item = Repo.get_by(WraftDoc.Storage.StorageItem, path: parent_path) ||
#                    Repo.get_by(WraftDoc.Storage.StorageItem, path: String.trim_trailing(parent_path, "/"))

#       if parent_item, do: parent_item.id, else: nil
#     else
#       nil
#     end

#     # Set file-specific attributes
#     {mime_type, file_extension, size} = if is_file do
#       ext = Path.extname(name)
#       mime = case ext do
#         ".pdf" -> "application/pdf"
#         _ -> "application/octet-stream"
#       end
#       {mime, ext, 1024}  # Default size for demo
#     else
#       {"inode/directory", nil, 0}
#     end

#     Repo.insert!(%WraftDoc.Storage.StorageItem{
#       name: name,
#       display_name: name,
#       item_type: item_type,
#       path: path,
#       path_hash: :crypto.hash(:sha256, path) |> Base.encode16(case: :lower),
#       depth_level: depth_level,
#       materialized_path: materialized_path,
#       mime_type: mime_type,
#       file_extension: file_extension,
#       size: size,
#       checksum_sha256: :crypto.hash(:sha256, path <> name) |> Base.encode16(case: :lower),
#       version_number: "1.0",
#       is_current_version: true,
#       classification_level: "public",
#       is_deleted: false,
#       parent_id: parent_id,
#       deleted_at: nil,
#       sync_source: "manual",
#       external_id: nil,
#       external_metadata: %{},
#       last_synced_at: DateTime.utc_now() |> DateTime.truncate(:second),
#       content_extracted: false,
#       thumbnail_generated: false,
#       download_count: 0,
#       last_accessed_at: DateTime.utc_now() |> DateTime.truncate(:second),
#       metadata: %{},
#       repository_id: repository.id,
#       creator_id: user.id,
#       organisation_id: user.last_signed_in_org
#     })
#   end
# end)

# IO.inspect(repository)

# Create root folder
# root_folder = Repo.insert!(%Folder{
#   name: "Root",
#   repository_id: Ecto.UUID.cast!(repository.id),
#   parent_id: nil,
#   materialized_path: "/",
#   depth_level: 1,
#   folder_order: 1,
#   is_deleted: false,
#   child_folder_count: 0,
#   child_file_count: 0,
#   total_size: 0,
#   creator_id: Ecto.UUID.cast!(user.id),
#   organisation_id: Ecto.UUID.cast!(user.last_signed_in_org),
# })

# # Create Documents folder
# documents_folder = Repo.insert!(%Folder{
#   name: "Documents",
#   repository_id: Ecto.UUID.cast!(repository.id),
#   parent_id: root_folder.id,
#   materialized_path: "/Documents",
#   depth_level: 2,
#   folder_order: 1,
#   is_deleted: false,
#   child_folder_count: 0,
#   child_file_count: 0,
#   total_size: 0,
#   creator_id: Ecto.UUID.cast!(user.id),
#   organisation_id: Ecto.UUID.cast!(user.last_signed_in_org),
# })

# # Create Images folder
# images_folder = Repo.insert!(%Folder{
#   name: "Images",
#   repository_id: Ecto.UUID.cast!(repository.id),
#   parent_id: root_folder.id,
#   materialized_path: "/Images",
#   depth_level: 2,
#   folder_order: 2,
#   is_deleted: false,
#   child_folder_count: 0,
#   child_file_count: 0,
#   total_size: 0,
#   creator_id: Ecto.UUID.cast!(user.id),
#   organisation_id: Ecto.UUID.cast!(user.last_signed_in_org),
# })

# # Create Templates folder
# templates_folder = Repo.insert!(%Folder{
#   name: "Templates",
#   repository_id: Ecto.UUID.cast!(repository.id),
#   parent_id: root_folder.id,
#   materialized_path: "/Templates",
#   depth_level: 2,
#   folder_order: 3,
#   is_deleted: false,
#   child_folder_count: 0,
#   child_file_count: 0,
#   total_size: 0,
#   creator_id: Ecto.UUID.cast!(user.id),
#   organisation_id: Ecto.UUID.cast!(user.last_signed_in_org),
# })

# # Create Reports folder under Documents
# reports_folder = Repo.insert!(%Folder{
#   name: "Reports",
#   repository_id: Ecto.UUID.cast!(repository.id),
#   parent_id: documents_folder.id,
#   materialized_path: "/Documents/Reports",
#   depth_level: 3,
#   folder_order: 1,
#   is_deleted: false,
#   child_folder_count: 0,
#   child_file_count: 0,
#   total_size: 0,
#   creator_id: Ecto.UUID.cast!(user.id),
#   organisation_id: Ecto.UUID.cast!(user.last_signed_in_org),
# })

# # Create Q1 and Q2 folders under Reports
# q1_folder = Repo.insert!(%Folder{
#   name: "Q1",
#   repository_id: Ecto.UUID.cast!(repository.id),
#   parent_id: reports_folder.id,
#   materialized_path: "/Documents/Reports/Q1",
#   depth_level: 4,
#   folder_order: 1,
#   is_deleted: false,
#   child_folder_count: 0,
#   child_file_count: 0,
#   total_size: 0,
#   creator_id: Ecto.UUID.cast!(user.id),
#   organisation_id: Ecto.UUID.cast!(user.last_signed_in_org),
# })

# q2_folder = Repo.insert!(%Folder{
#   name: "Q2",
#   repository_id: Ecto.UUID.cast!(repository.id),
#   parent_id: reports_folder.id,
#   materialized_path: "/Documents/Reports/Q2",
#   depth_level: 4,
#   folder_order: 2,
#   is_deleted: false,
#   child_folder_count: 0,
#   child_file_count: 0,
#   total_size: 0,
#   creator_id: Ecto.UUID.cast!(user.id),
#   organisation_id: Ecto.UUID.cast!(user.last_signed_in_org),
# })

# # Create Presentations folder under Documents
# presentations_folder = Repo.insert!(%Folder{
#   name: "Presentations",
#   repository_id: Ecto.UUID.cast!(repository.id),
#   parent_id: documents_folder.id,
#   materialized_path: "/Documents/Presentations",
#   depth_level: 3,
#   folder_order: 2,
#   is_deleted: false,
#   child_folder_count: 0,
#   child_file_count: 0,
#   total_size: 0,
#   creator_id: Ecto.UUID.cast!(user.id),
#   organisation_id: Ecto.UUID.cast!(user.last_signed_in_org),
# })

# # Create Screenshots and Icons folders under Images
# screenshots_folder = Repo.insert!(%Folder{
#   name: "Screenshots",
#   repository_id: Ecto.UUID.cast!(repository.id),
#   parent_id: images_folder.id,
#   materialized_path: "/Images/Screenshots",
#   depth_level: 3,
#   folder_order: 1,
#   is_deleted: false,
#   child_folder_count: 0,
#   child_file_count: 0,
#   total_size: 0,
#   creator_id: Ecto.UUID.cast!(user.id),
#   organisation_id: Ecto.UUID.cast!(user.last_signed_in_org),
# })

# icons_folder = Repo.insert!(%Folder{
#   name: "Icons",
#   repository_id: Ecto.UUID.cast!(repository.id),
#   parent_id: images_folder.id,
#   materialized_path: "/Images/Icons",
#   depth_level: 3,
#   folder_order: 2,
#   is_deleted: false,
#   child_folder_count: 0,
#   child_file_count: 0,
#   total_size: 0,
#   creator_id: Ecto.UUID.cast!(user.id),
#   organisation_id: Ecto.UUID.cast!(user.last_signed_in_org),
# })

# # Create Email, Reports, and Presentations folders under Templates
# email_templates_folder = Repo.insert!(%Folder{
#   name: "Email",
#   repository_id: Ecto.UUID.cast!(repository.id),
#   parent_id: templates_folder.id,
#   materialized_path: "/Templates/Email",
#   depth_level: 3,
#   folder_order: 1,
#   is_deleted: false,
#   child_folder_count: 0,
#   child_file_count: 0,
#   total_size: 0,
#   creator_id: Ecto.UUID.cast!(user.id),
#   organisation_id: Ecto.UUID.cast!(user.last_signed_in_org),
# })

# report_templates_folder = Repo.insert!(%Folder{
#   name: "Reports",
#   repository_id: Ecto.UUID.cast!(repository.id),
#   parent_id: templates_folder.id,
#   materialized_path: "/Templates/Reports",
#   depth_level: 3,
#   folder_order: 2,
#   is_deleted: false,
#   child_folder_count: 0,
#   child_file_count: 0,
#   total_size: 0,
#   creator_id: Ecto.UUID.cast!(user.id),
#   organisation_id: Ecto.UUID.cast!(user.last_signed_in_org),
# })

# presentation_templates_folder = Repo.insert!(%Folder{
#   name: "Presentations",
#   repository_id: Ecto.UUID.cast!(repository.id),
#   parent_id: templates_folder.id,
#   materialized_path: "/Templates/Presentations",
#   depth_level: 3,
#   folder_order: 3,
#   is_deleted: false,
#   child_folder_count: 0,
#   child_file_count: 0,
#   total_size: 0,
#   creator_id: Ecto.UUID.cast!(user.id),
#   organisation_id: Ecto.UUID.cast!(user.last_signed_in_org),
# })

# # Update parent folder counts
# Repo.update!(Ecto.Changeset.change(documents_folder, child_folder_count: 2))
# Repo.update!(Ecto.Changeset.change(reports_folder, child_folder_count: 2))
# Repo.update!(Ecto.Changeset.change(images_folder, child_folder_count: 2))
# Repo.update!(Ecto.Changeset.change(templates_folder, child_folder_count: 3))

# # Add files to Q1 folder
# Repo.insert!(%WraftDoc.Storage.File{
#   name: "Q1_Report.pdf",
#   display_name: "Q1 Report",
#   file_extension: "pdf",
#   mime_type: "application/pdf",
#   file_size: 1024 * 1024, # 1MB
#   storage_key: "reports/q1/Q1_Report.pdf",
#   checksum_sha256: "dummy_checksum_1",
#   is_deleted: false,
#   download_count: 0,
#   content_extracted: false,
#   thumbnail_generated: false,
#   repository_id: Ecto.UUID.cast!(repository.id),
#   folder_id: q1_folder.id,
#   creator_id: Ecto.UUID.cast!(user.id),
#   organisation_id: Ecto.UUID.cast!(user.last_signed_in_org),
#   version: 1
# })

# Repo.insert!(%WraftDoc.Storage.File{
#   name: "Q1_Summary.docx",
#   display_name: "Q1 Summary",
#   file_extension: "docx",
#   mime_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
#   file_size: 512 * 1024, # 512KB
#   storage_key: "reports/q1/Q1_Summary.docx",
#   checksum_sha256: "dummy_checksum_2",
#   is_deleted: false,
#   download_count: 0,
#   content_extracted: false,
#   thumbnail_generated: false,
#   repository_id: Ecto.UUID.cast!(repository.id),
#   folder_id: q1_folder.id,
#   creator_id: Ecto.UUID.cast!(user.id),
#   organisation_id: Ecto.UUID.cast!(user.last_signed_in_org),
#   version: 1
# })

# # Add files to Q2 folder
# Repo.insert!(%WraftDoc.Storage.File{
#   name: "Q2_Report.pdf",
#   display_name: "Q2 Report",
#   file_extension: "pdf",
#   mime_type: "application/pdf",
#   file_size: 1024 * 1024, # 1MB
#   storage_key: "reports/q2/Q2_Report.pdf",
#   checksum_sha256: "dummy_checksum_3",
#   is_deleted: false,
#   download_count: 0,
#   content_extracted: false,
#   thumbnail_generated: false,
#   repository_id: Ecto.UUID.cast!(repository.id),
#   folder_id: q2_folder.id,
#   creator_id: Ecto.UUID.cast!(user.id),
#   organisation_id: Ecto.UUID.cast!(user.last_signed_in_org),
#   version: 1
# })

# # Add files to Presentations folder
# Repo.insert!(%WraftDoc.Storage.File{
#   name: "Company_Overview.pptx",
#   display_name: "Company Overview",
#   file_extension: "pptx",
#   mime_type: "application/vnd.openxmlformats-officedocument.presentationml.presentation",
#   file_size: 2 * 1024 * 1024, # 2MB
#   storage_key: "presentations/Company_Overview.pptx",
#   checksum_sha256: "dummy_checksum_4",
#   is_deleted: false,
#   download_count: 0,
#   content_extracted: false,
#   thumbnail_generated: false,
#   repository_id: Ecto.UUID.cast!(repository.id),
#   folder_id: presentations_folder.id,
#   creator_id: Ecto.UUID.cast!(user.id),
#   organisation_id: Ecto.UUID.cast!(user.last_signed_in_org),
#   version: 1
# })

# # Add files to Screenshots folder
# Repo.insert!(%WraftDoc.Storage.File{
#   name: "Dashboard.png",
#   display_name: "Dashboard Screenshot",
#   file_extension: "png",
#   mime_type: "image/png",
#   file_size: 256 * 1024, # 256KB
#   storage_key: "screenshots/Dashboard.png",
#   checksum_sha256: "dummy_checksum_5",
#   is_deleted: false,
#   download_count: 0,
#   content_extracted: false,
#   thumbnail_generated: true,
#   repository_id: Ecto.UUID.cast!(repository.id),
#   folder_id: screenshots_folder.id,
#   creator_id: Ecto.UUID.cast!(user.id),
#   organisation_id: Ecto.UUID.cast!(user.last_signed_in_org),
#   version: 1
# })

# # Add files to Icons folder
# Repo.insert!(%WraftDoc.Storage.File{
#   name: "logo.svg",
#   display_name: "Company Logo",
#   file_extension: "svg",
#   mime_type: "image/svg+xml",
#   file_size: 64 * 1024, # 64KB
#   storage_key: "icons/logo.svg",
#   checksum_sha256: "dummy_checksum_6",
#   is_deleted: false,
#   download_count: 0,
#   content_extracted: false,
#   thumbnail_generated: false,
#   repository_id: Ecto.UUID.cast!(repository.id),
#   folder_id: icons_folder.id,
#   creator_id: Ecto.UUID.cast!(user.id),
#   organisation_id: Ecto.UUID.cast!(user.last_signed_in_org),
#   version: 1
# })

# # Add files to Email Templates folder
# Repo.insert!(%WraftDoc.Storage.File{
#   name: "Welcome_Email.html",
#   display_name: "Welcome Email Template",
#   file_extension: "html",
#   mime_type: "text/html",
#   file_size: 32 * 1024, # 32KB
#   storage_key: "templates/email/Welcome_Email.html",
#   checksum_sha256: "dummy_checksum_7",
#   is_deleted: false,
#   download_count: 0,
#   content_extracted: true,
#   thumbnail_generated: false,
#   repository_id: Ecto.UUID.cast!(repository.id),
#   folder_id: email_templates_folder.id,
#   creator_id: Ecto.UUID.cast!(user.id),
#   organisation_id: Ecto.UUID.cast!(user.last_signed_in_org),
#   version: 1
# })

# # Add files to Report Templates folder
# Repo.insert!(%WraftDoc.Storage.File{
#   name: "Monthly_Report.docx",
#   display_name: "Monthly Report Template",
#   file_extension: "docx",
#   mime_type: "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
#   file_size: 128 * 1024, # 128KB
#   storage_key: "templates/reports/Monthly_Report.docx",
#   checksum_sha256: "dummy_checksum_8",
#   is_deleted: false,
#   download_count: 0,
#   content_extracted: false,
#   thumbnail_generated: false,
#   repository_id: Ecto.UUID.cast!(repository.id),
#   folder_id: report_templates_folder.id,
#   creator_id: Ecto.UUID.cast!(user.id),
#   organisation_id: Ecto.UUID.cast!(user.last_signed_in_org),
#   version: 1
# })

# # Add files to Presentation Templates folder
# Repo.insert!(%WraftDoc.Storage.File{
#   name: "Project_Update.pptx",
#   display_name: "Project Update Template",
#   file_extension: "pptx",
#   mime_type: "application/vnd.openxmlformats-officedocument.presentationml.presentation",
#   file_size: 512 * 1024, # 512KB
#   storage_key: "templates/presentations/Project_Update.pptx",
#   checksum_sha256: "dummy_checksum_9",
#   is_deleted: false,
#   download_count: 0,
#   content_extracted: false,
#   thumbnail_generated: false,
#   repository_id: Ecto.UUID.cast!(repository.id),
#   folder_id: presentation_templates_folder.id,
#   creator_id: Ecto.UUID.cast!(user.id),
#   organisation_id: Ecto.UUID.cast!(user.last_signed_in_org),
#   version: 1
# })

# # Update file counts for all folders
# Repo.update!(Ecto.Changeset.change(q1_folder, child_file_count: 2))
# Repo.update!(Ecto.Changeset.change(q2_folder, child_file_count: 1))
# Repo.update!(Ecto.Changeset.change(presentations_folder, child_file_count: 1))
# Repo.update!(Ecto.Changeset.change(screenshots_folder, child_file_count: 1))
# Repo.update!(Ecto.Changeset.change(icons_folder, child_file_count: 1))
# Repo.update!(Ecto.Changeset.change(email_templates_folder, child_file_count: 1))
# Repo.update!(Ecto.Changeset.change(report_templates_folder, child_file_count: 1))
# Repo.update!(Ecto.Changeset.change(presentation_templates_folder, child_file_count: 1))

# # Create repository asset from local PDF file
# # pdf_path = "temp/contract-signed.pdf"

# # with {:ok, file_stats} <- File.stat(pdf_path),
# #      {:ok, file_content} <- File.read(pdf_path),
# #      checksum = :crypto.hash(:sha256, file_content) |> Base.encode16(case: :lower) do
# #   Repo.insert!(%WraftDoc.Storage.RepositoryAsset{
# #     filename: %{file_name: "sample.pdf", binary: file_content},
# #     title: "Sample PDF Document",
# #     description: "A sample PDF document for testing",
# #     file_size: file_stats.size,
# #     mime_type: "application/pdf",
# #     status: "completed",
# #     processed: true,
# #     metadata: %{
# #       "pages" => 1,
# #       "author" => "WraftDoc",
# #       "created_at" => DateTime.utc_now()
# #     },
# #     version: 1,
# #     version_name: "1.0",
# #     storage_key: "samples/sample.pdf",
# #     checksum_sha256: checksum,
# #     content_extracted: true,
# #     thumbnail_generated: true,
# #     download_count: 0,
# #     repository_id: Ecto.UUID.cast!(repository.id),
# #     creator_id: Ecto.UUID.cast!(user.id),
# #     organisation_id: Ecto.UUID.cast!(user.last_signed_in_org)
# #   })
# # end
