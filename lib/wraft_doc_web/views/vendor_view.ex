defmodule WraftDocWeb.Api.V1.VendorView do
  use WraftDocWeb, :view
  alias __MODULE__
  alias WraftDocWeb.Api.V1.InstanceView
  alias WraftDocWeb.Api.V1.OrganisationView
  alias WraftDocWeb.Api.V1.UserView

  def render("vendor.json", %{vendor: vendor}) do
    %{
      id: vendor.id,
      name: vendor.name,
      email: vendor.email,
      phone: vendor.phone,
      address: vendor.address,
      city: vendor.city,
      country: vendor.country,
      website: vendor.website,
      reg_no: vendor.reg_no,
      contact_person: vendor.contact_person,
      inserted_at: vendor.inserted_at,
      updated_at: vendor.updated_at
    }
  end

  def render("create.json", %{vendor: vendor}) do
    %{
      id: vendor.id,
      name: vendor.name,
      email: vendor.email,
      phone: vendor.phone,
      address: vendor.address,
      city: vendor.city,
      country: vendor.country,
      website: vendor.website,
      reg_no: vendor.reg_no,
      logo: vendor.logo,
      contact_person: vendor.contact_person,
      organisation:
        render_one(vendor.organisation, OrganisationView, "organisation.json", as: :organisation),
      creator: render_one(vendor.creator, UserView, "user.json", as: :user)
    }
  end

  def render("index.json", %{
        vendors: vendors,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      vendors: render_many(vendors, VendorView, "vendor.json", as: :vendor),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end

  def render("vendor_contact.json", %{vendor_contact: vendor_contact}) do
    %{
      id: vendor_contact.id,
      name: vendor_contact.name,
      email: vendor_contact.email,
      phone: vendor_contact.phone,
      job_title: vendor_contact.job_title,
      vendor_id: vendor_contact.vendor_id,
      inserted_at: vendor_contact.inserted_at,
      updated_at: vendor_contact.updated_at
    }
  end

  def render("contacts_index.json", %{
        vendor_contacts: vendor_contacts,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      contacts:
        render_many(vendor_contacts, VendorView, "vendor_contact.json", as: :vendor_contact),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end

  def render("vendor_document.json", %{vendors_content: vendors_content}) do
    %{
      vendor: render_one(vendors_content.vendor, VendorView, "vendor.json", as: :vendor),
      document: render_one(vendors_content.content, InstanceView, "instance.json", as: :instance)
    }
  end

  def render("vendor_stats.json", %{stats: stats}) do
    %{
      total_documents: stats.total_documents,
      pending_approvals: stats.pending_approvals,
      total_contract_value: Decimal.to_string(stats.total_contract_value),
      total_contacts: stats.total_contacts,
      new_this_month: stats.new_this_month
    }
  end
end
