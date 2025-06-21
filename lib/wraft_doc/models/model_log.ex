defmodule WraftDoc.Models.ModelLog do
  @moduledoc """
    ModelLog model for storing and managing model logs.
  """

  use WraftDoc.Schema
  import Ecto.Changeset

  alias __MODULE__
  alias WraftDoc.Account.User
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Models.Model
  alias WraftDoc.Models.Prompt

  schema "ai_model_log" do
    field(:prompt_text, :string)
    field(:model_name, :string)
    field(:endpoint, :string)
    field(:provider, :string)
    field(:status, :string)
    field(:response, :string)
    field(:response_time_ms, :integer)

    belongs_to(:prompt, Prompt)
    belongs_to(:model, Model)
    belongs_to(:user, User)
    belongs_to(:organisation, Organisation)

    timestamps()
  end

  @doc false
  def changeset(%ModelLog{} = model_log, attrs) do
    model_log
    |> cast(attrs, [
      :model_name,
      :prompt_text,
      :endpoint,
      :status,
      :response,
      :response_time_ms,
      :model_id,
      :prompt_id,
      :user_id,
      :organisation_id
    ])
    |> validate_required([
      :model_name,
      :prompt_text,
      :status,
      :response_time_ms,
      :model_id,
      :prompt_id,
      :user_id,
      :organisation_id
    ])
  end
end
