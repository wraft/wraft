defmodule WraftDoc.Factory do
  use ExMachina.Ecto, repo: WraftDoc.Repo

  alias WraftDoc.{
    Account.User,
    Account.Country,
    Account.Role,
    Account.Profile,
    Account.AuthToken,
    Document.ContentType,
    Document.Block,
    Document.Instance.History,
    Document.Asset,
    Document.Layout,
    Document.Engine,
    Document.Instance,
    Document.DataTemplate,
    Document.Theme,
    Document.FieldType,
    Document.Counter,
    Document.ContentTypeField,
    Enterprise.Flow.State,
    Enterprise.Organisation,
    Enterprise.Flow,
    Authorization.Resource,
    Authorization.Permission,
    Document.BlockTemplate,
    Document.Comment,
    Document.Pipeline,
    Document.Pipeline.Stage,
    Enterprise.ApprovalSystem,
    Document.LayoutAsset,
    Document.Pipeline.TriggerHistory
  }

  def user_factory do
    %User{
      name: "wrafts user",
      email: sequence(:email, &"wraftuser-#{&1}@wmail.com"),
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
      name: "admin@wraftdocs",
      dob: Timex.shift(Timex.now(), years: -27),
      gender: "male",
      user: build(:user, name: "admin@wraftdocs")
    }
  end

  def content_type_factory do
    %ContentType{
      name: sequence(:name, &"name-#{&1}"),
      description: "A content type to create documents",
      prefix: "OFFR",
      organisation: build(:organisation),
      layout: build(:layout),
      flow: build(:flow)
    }
  end

  def block_factory do
    %Block{
      name: sequence(:name, &"name-#{&1}"),
      btype: sequence(:btype, &"btype-#{&1}"),
      api_route: "http://localhost:8080/chart",
      endpoint: "blocks_api",
      dataset: %{
        data: [
          %{
            value: 10,
            label: "January"
          },
          %{
            value: 20,
            label: "February"
          },
          %{
            value: 5,
            label: "March"
          },
          %{
            value: 60,
            label: "April"
          },
          %{
            value: 80,
            label: "May"
          },
          %{
            value: 70,
            label: "June"
          },
          %{
            value: 90,
            label: "Julay"
          }
        ],
        width: 512,
        height: 512,
        backgroundColor: "transparent",
        format: "svg",
        type: "pie"
      },
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
      unit: sequence(:name, &"layout-#{&1}"),
      organisation: build(:organisation)
    }
  end

  def layout_asset_factory do
    %LayoutAsset{
      layout: build(:layout),
      asset: build(:asset),
      creator: build(:user)
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
      instance_id: sequence(:instance_id, &"OFFLET#{&1}"),
      raw: "Content",
      serialized: %{title: "Title of the content", body: "Body of the content"},
      content_type: build(:content_type)
    }
  end

  def state_factory do
    %State{
      state: sequence(:state, &"state-#{&1}"),
      order: 1,
      organisation: build(:organisation),
      flow: build(:flow)
    }
  end

  def flow_factory do
    %Flow{
      name: sequence(:name, &"flow-#{&1}"),
      organisation: build(:organisation),
      controlled: false,
      creator: build(:user)
    }
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
      title: sequence(:title, &"title-#{&1}"),
      title_template: sequence(:title_template, &"title-[client]-#{&1}"),
      data: sequence(:data, &"data-#{&1}"),
      content_type: build(:content_type)
    }
  end

  def resource_factory do
    %Resource{
      category: sequence(:resource, &"Flow-#{&1}"),
      action: sequence(:action, &"Action-#{&1}")
    }
  end

  def permission_factory do
    %Permission{
      resource: build(:resource),
      role: build(:role)
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

  def block_template_factory do
    %BlockTemplate{
      title: sequence(:title, &"BlockTemplate title #{&1} "),
      body: sequence(:body, &"BlockTemplate body #{&1} "),
      serialised: sequence(:serialised, &"BlockTemplate serialised #{&1} "),
      organisation: build(:organisation),
      creator: build(:user)
    }
  end

  def comment_factory do
    %Comment{
      comment: sequence(:comment, &"C comment #{&1} "),
      is_parent: true,
      master: "instance",
      master_id: "sdgasdfs2262dsf32a2sd",
      user: build(:user),
      organisation: build(:organisation)
    }
  end

  def approval_system_factory do
    %ApprovalSystem{
      instance: build(:instance),
      pre_state: build(:state),
      post_state: build(:state),
      approver: build(:user),
      user: build(:user),
      organisation: build(:organisation)
    }
  end

  def field_type_factory do
    %FieldType{
      name: sequence(:name, &"String #{&1}"),
      description: "Text field",
      creator: build(:user)
    }
  end

  def content_type_field_factory do
    %ContentTypeField{
      name: sequence(:name, &"Field name #{&1}"),
      content_type: build(:content_type),
      field_type: build(:field_type)
    }
  end

  def counter_factory do
    %Counter{
      subject: sequence(:subject, &"Subject:#{&1}"),
      count: Enum.random(1..100)
    }
  end

  def auth_token_factory do
    %AuthToken{
      value: "token",
      token_type: "token",
      expiry_datetime: Timex.shift(Timex.now(), days: 1),
      user: build(:user)
    }
  end

  def pipeline_factory do
    %Pipeline{
      name: sequence(:name, &"Pipeline-#{&1}"),
      api_route: sequence(:api_route, &"clinet-#{&1}.crm-#{&1}.com"),
      creator: build(:user),
      organisation: build(:organisation)
    }
  end

  def pipe_stage_factory do
    %Stage{
      pipeline: build(:pipeline),
      content_type: build(:content_type),
      data_template: build(:data_template),
      state: build(:state),
      creator: build(:user)
    }
  end

  def trigger_history_factory do
    %TriggerHistory{
      data: %{name: sequence(:name, &"Name-#{&1}")},
      meta: %{error: sequence(:error, &"error_reason-#{&1}")},
      state: sequence(:state, &"#{&1}"),
      pipeline: build(:pipeline),
      creator: build(:user)
    }
  end
end
