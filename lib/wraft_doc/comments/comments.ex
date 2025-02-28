defmodule WraftDoc.Comments do
  @moduledoc """
  Module for handling comment-related operations, including creation and retrieval.
  """
  import Ecto
  import Ecto.Query

  alias WraftDoc.Comment
  alias WraftDoc.Repo
  alias WraftDoc.User

  @doc """
  Create a comment
  """
  # TODO - improve tests
  def create_comment(%{current_org_id: <<_::288>> = org_id} = current_user, params) do
    params = Map.put(params, "organisation_id", org_id)
    insert_comment(current_user, params)
  end

  def create_comment(%{current_org_id: nil} = current_user, params),
    do: insert_comment(current_user, params)

  def create_comment(_, _), do: {:error, :fake}

  @doc """
  Updates a comment
  """
  @spec update_comment(Comment.t(), map) :: Comment.t()
  def update_comment(comment, params) do
    comment
    |> Comment.changeset(params)
    |> Repo.update()
    |> case do
      {:error, _} = changeset ->
        changeset

      {:ok, comment} ->
        Repo.preload(comment, [{:user, :profile}])
    end
  end

  @doc """
  Deletes a coment
  """
  def delete_comment(%Comment{} = comment) do
    Repo.delete(comment)
  end

  @doc """
  Get a comment by uuid.
  """
  # TODO - improve tests
  @spec get_comment(Ecto.UUID.t(), User.t()) :: Comment.t() | nil
  def get_comment(<<_::288>> = id, %{current_org_id: org_id}) do
    case Repo.get_by(Comment, id: id, organisation_id: org_id) do
      %Comment{} = comment -> comment
      _ -> {:error, :invalid_id, "Comment"}
    end
  end

  def get_comment(<<_::288>>, _), do: {:error, :fake}
  def get_comment(_, %{current_org_id: _}), do: {:error, :invalid_id, "Comment"}
  def get_comment(_, _), do: {:error, :invalid_id, "Comment"}

  @doc """
  Fetch a comment and all its details.
  """
  # TODO - improve tests
  @spec show_comment(Ecto.UUID.t(), User.t()) :: Comment.t() | nil
  def show_comment(id, user) do
    with %Comment{} = comment <- get_comment(id, user) do
      Repo.preload(comment, [{:user, :profile}])
    end
  end

  @doc """
  Comments under a master
  """
  # TODO - improve tests
  def comment_index(%{current_org_id: org_id}, %{"master_id" => master_id} = params) do
    query =
      from(c in Comment,
        where: c.organisation_id == ^org_id,
        where: c.master_id == ^master_id,
        where: c.is_parent == true,
        order_by: [desc: c.inserted_at],
        preload: [{:user, :profile}]
      )

    Repo.paginate(query, params)
  end

  def comment_index(%{current_org_id: _}, _), do: {:error, :invalid_data}
  def comment_index(_, %{"master_id" => _}), do: {:error, :fake}
  def comment_index(_, _), do: {:error, :invalid_data}

  @doc """
   Replies under a comment
  """
  # TODO - improve tests
  @spec comment_replies(%{current_org_id: any}, map) :: Scrivener.Page.t()
  def comment_replies(
        %{current_org_id: org_id} = user,
        %{"master_id" => master_id, "comment_id" => comment_id} = params
      ) do
    with %Comment{id: parent_id} <- get_comment(comment_id, user) do
      query =
        from(c in Comment,
          where: c.organisation_id == ^org_id,
          where: c.master_id == ^master_id,
          where: c.is_parent == false,
          where: c.parent_id == ^parent_id,
          order_by: [desc: c.inserted_at],
          preload: [{:user, :profile}]
        )

      Repo.paginate(query, params)
    end
  end

  def comment_replies(_, %{"master_id" => _, "comment_id" => _}), do: {:error, :fake}
  def comment_replies(%{current_org_id: _}, _), do: {:error, :invalid_data}
  def comment_replies(_, _), do: {:error, :invalid_data}

  # Private
  defp insert_comment(current_user, params) do
    current_user
    |> build_assoc(:comments)
    |> Comment.changeset(params)
    |> Repo.insert()
    |> case do
      {:ok, comment} ->
        Repo.preload(comment, [{:user, :profile}])

      {:error, _} = changeset ->
        changeset
    end
  end
end
