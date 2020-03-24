defmodule WraftDoc.Factory do
  use ExMachina.Ecto, repo: WraftDoc.Repo

  alias WraftDoc.{
    Account.User,
    Enterprise.Organisation,
    Account.Role,
    Account.Profile,
    Document.ContentType,
    Document.Block,
    Document.Instance.History,
    Document.Asset,
    Document.Layout,
    Document.Engine,
    Document.Instance,
    Enterprise.Flow.State,
    Enterprise.Flow,
    Account.Country,
    Document.DataTemplate,
    Authorization.Resource,
    Document.Theme
  }

  def user_factory do
    %User{
      name: sequence(:name, &"wrafts user-#{&1}"),
      email: sequence(:email, &"wraftuser-#{&1}@gmail.com"),
      password: "encrypt",
      encrypted_password: Bcrypt.hash_pwd_salt("encrypt"),
      organisation: build(:organisation),
      role: build(:role)
    }
  end

  def organisation_factory do
    %Organisation{
      name: sequence(:name, &"organisation-#{&1}"),
      legal_name: sequence(:legal_name, &"Legal name-#{&1}"),
      address: sequence(:address, &"#{&1} th cross #{&1} th building"),
      gstin: sequence(:gstin, &"32AASDGGDGDDGDG#{&1}"),
      phone: sequence(:phone, &"985222332#{&1}"),
      email: sequence(:email, &"acborg#{&1}@gmail.com")
    }
  end

  def role_factory do
    %Role{name: "user"}
  end

  def profile_factory do
    %Profile{
      name: sequence(:name, &"name-#{&1}"),
      dob: Timex.shift(Timex.now(), years: 27),
      gender: "male",
      user: build(:user)
    }
  end

  def content_type_factory do
    %ContentType{
      name: sequence(:name, &"name-#{&1}"),
      description: "A content type to create documents",
      fields: %{name: "string", position: "string", joining_date: "date", approved_by: "string"},
      prefix: "OFFR",
      organisation: build(:organisation)
    }
  end

  def block_factory do
    %Block{
      name: sequence(:name, &"name-#{&1}"),
      btype: sequence(:btype, &"btype-#{&1}"),
      content_type: build(:content_type),
      organisation: build(:organisation)
    }
  end

  def build_history_factory do
    {:ok, start_time} = NaiveDateTime.new(2020, 03, 17, 20, 20, 20)
    {:ok, end_time} = NaiveDateTime.new(2020, 03, 17, 20, 21, 20)

    %History{
      status: sequence(:status, &"status-#{&1}"),
      exit_code: 2,
      start_time: start_time,
      end_time: end_time,
      delay: 120_000
    }
  end

  def asset_factory do
    %Asset{
      name: sequence(:name, &"asset-#{&1}"),
      creator: build(:user),
      organisation: build(:organisation)
    }
  end

  def layout_factory do
    %Layout{
      name: sequence(:name, &"layout-#{&1}"),
      description: sequence(:description, &"laout for document-#{&1}"),
      width: :rand.uniform(16),
      height: :rand.uniform(16),
      unit: sequence(:name, &"layout-#{&1}")
    }
  end

  def engine_factory do
    %Engine{
      name: sequence(:name, &"engine-#{&1}"),
      api_route: sequence(:api_route, &"localhost:4000/api/#{&1}")
    }
  end

  def instance_factory do
    %Instance{
      instance_id: "OFFL01",
      raw: "Content",
      serialized: %{title: "Title of the content", body: "Body of the content"}
    }
  end

  def state_factory do
    %State{
      state: "published",
      order: 1,
      organisation: build(:organisation)
    }
  end

  def flow_factory do
    %Flow{name: sequence(:name, &"flow-#{&1}"), organisation: build(:organisation)}
  end

  def contry_factory do
    %Country{
      country_name: sequence(:country_name, &"country-#{&1}"),
      country_code: sequence(:country_code, &"243432#{&1}"),
      calling_code: sequence(:calling_code, &"3343#{&1}")
    }
  end

  def data_template_factory do
    %DataTemplate{
      tag: sequence(:tag, &"tag-#{&1}"),
      data: sequence(:data, &"data-#{&1}")
    }
  end

  def resource_factory do
    %Resource{
      category: sequence(:resource, &"Flow-#{&1}"),
      action: sequence(:action, &"Action-#{&1}")
    }
  end

  def theme_factory do
    %Theme{
      name: sequence(:name, &"Official Letter Theme-#{&1}"),
      font: sequence(:font, &"Malery-#{&1}"),
      typescale: %{h1: "10", p: "6", h2: "8"},
      organisation: build(:organisation),
      creator: build(:user)
    }
  end
end
