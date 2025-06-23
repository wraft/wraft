defmodule WraftDoc.Models do
  @moduledoc """
  The Models context.
  """

  import Ecto.Query, warn: false

  alias WraftDoc.Models.Model
  alias WraftDoc.Models.ModelLog
  alias WraftDoc.Models.Prompt
  alias WraftDoc.Repo

  @doc """
  Returns the list of ai_models.

  ## Examples

      iex> list_ai_models(organisation_id)
      [%Model{}, ...]

  """
  @spec list_ai_models(String.t()) :: [Model.t()]
  def list_ai_models(organisation_id), do: Repo.all_by(Model, organisation_id: organisation_id)

  @doc """
  Gets the default model for a given organisation.

  ## Examples

      iex> get_default_model(org_id)
      %Model{}

      iex> get_default_model(org_id)
      nil
  """
  @spec get_default_model(Ecto.UUID.t()) :: Model.t() | nil
  def get_default_model(organisation_id) do
    query =
      from(m in Model,
        where: m.organisation_id == ^organisation_id and m.is_default == true,
        limit: 1
      )

    Repo.one(query)
  end

  @doc """
  Gets a single model.

  ## Examples

      iex> get_model(123)
      %Model{}

      iex> get_model(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_model(String.t()) :: Model.t() | nil | {:error, :invalid_id, atom()}
  def get_model(<<_::288>> = id), do: Repo.get(Model, id)
  def get_model(_), do: {:error, "Invalid model ID"}

  @doc """
  Creates a model.

  ## Examples

      iex> create_model(%{field: value})
      {:ok, %Model{}}

      iex> create_model(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_model(map()) :: {:ok, Model.t()} | {:error, Ecto.Changeset.t()}
  def create_model(attrs \\ %{}) do
    %Model{}
    |> Model.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a model.

  ## Examples

      iex> update_model(model, %{field: new_value})
      {:ok, %Model{}}

      iex> update_model(model, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_model(Model.t(), map()) :: {:ok, Model.t()} | {:error, Ecto.Changeset.t()}
  def update_model(%Model{} = model, attrs) do
    model
    |> Model.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a model.

  ## Examples

      iex> delete_model(model)
      {:ok, %Model{}}

      iex> delete_model(model)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_model(Model.t()) :: {:ok, Model.t()} | {:error, Ecto.Changeset.t()}
  def delete_model(%Model{} = model) do
    Repo.delete(model)
  end

  @doc """
  Returns the list of prompts.

  ## Examples

      iex> list_prompts(organisation_id)
      [%Prompt{}, ...]

  """
  @spec list_prompts(String.t()) :: [Prompt.t()]
  def list_prompts(organisation_id), do: Repo.all_by(Prompt, organisation_id: organisation_id)

  @doc """
  Gets a single prompts.

  ## Examples

      iex> get_prompt(123)
      %Prompt{}

      iex> get_prompt(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_prompt(String.t()) :: Prompt.t() | nil | {:error, :invalid_id, atom()}
  def get_prompt(<<_::288>> = id), do: Repo.get(Prompt, id)
  def get_prompt(_), do: {:error, "Invalid prompt ID"}

  @doc """
  Creates a prompts.

  ## Examples

      iex> create_prompts(%{field: value})
      {:ok, %Prompt{}}

      iex> create_prompts(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_prompts(map()) :: {:ok, Prompt.t()} | {:error, Ecto.Changeset.t()}
  def create_prompts(attrs \\ %{}) do
    %Prompt{}
    |> Prompt.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a prompts.

  ## Examples

      iex> update_prompts(prompts, %{field: new_value})
      {:ok, %Prompt{}}

      iex> update_prompts(prompts, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_prompts(Prompt.t(), map()) :: {:ok, Prompt.t()} | {:error, Ecto.Changeset.t()}
  def update_prompts(%Prompt{} = prompts, attrs) do
    prompts
    |> Prompt.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a prompts.

  ## Examples

      iex> delete_prompts(prompts)
      {:ok, %Prompt{}}

      iex> delete_prompts(prompts)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_prompts(Prompt.t()) :: {:ok, Prompt.t()} | {:error, Ecto.Changeset.t()}
  def delete_prompts(%Prompt{} = prompts), do: Repo.delete(prompts)

  @doc """
  Creates a model log entry.

  ## Examples

      iex> create_model_log(%{field: value})
      {:ok, %ModelLog{}}

      iex> create_model_log(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_model_log(map()) :: {:ok, ModelLog.t()} | {:error, Ecto.Changeset.t()}
  def create_model_log(attrs \\ %{}) do
    %ModelLog{}
    |> ModelLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a model log entry with execution context.

  ## Parameters

    - `context` - Map containing model, prompt, and user information
    - `status` - Status of the model execution
    - `base_url` - Base URL of the model endpoint
    - `start_time` - Start time of the execution in milliseconds

  ## Examples

      iex> create_model_log(context, "success", "https://api.example.com", 1640995200000)
      {:ok, %ModelLog{}}

  """
  @spec create_model_log(map(), String.t(), String.t(), integer()) ::
          {:ok, ModelLog.t()} | {:error, Ecto.Changeset.t()}
  def create_model_log(
        %{
          model: %{model_name: model_name, provider: provider},
          prompt: %{prompt: prompt_text},
          user: %{id: user_id, current_org_id: organisation_id}
        },
        status,
        base_url,
        start_time
      ) do
    end_time = System.monotonic_time(:millisecond)

    create_model_log(%{
      model_name: model_name,
      provider: provider,
      prompt_text: prompt_text,
      endpoint: base_url,
      status: status,
      response_time_ms: end_time - start_time,
      user_id: user_id,
      organisation_id: organisation_id
    })
  end
end
