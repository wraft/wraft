defmodule WraftDocWeb.Api.V1.VendorView do
  use WraftDocWeb, :view
  alias __MODULE__
  alias WraftDocWeb.Api.V1.{OrganisationView, UserView}

  def render("vendor.json", %{vendor: vendor}) do
    %{
      name: vendor.name,
      email: vendor.email,
      phone: vendor.phone,
      address: vendor.address,
      gstin: vendor.gstin,
      reg_no: vendor.reg_no,
      contact_person: vendor.contact_person
    }
  end

  def render("create.json", %{vendor: vendor}) do
    %{
      name: vendor.name,
      email: vendor.email,
      phone: vendor.phone,
      address: vendor.address,
      gstin: vendor.gstin,
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
end
