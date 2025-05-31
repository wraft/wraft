defmodule WraftDoc.Documents.Signatures do
  @moduledoc """
  Context module for managing digital signatures for documents.
  """

  import Ecto.Query
  require Logger

  # Path to the pdf signer JAR file
  @visual_signer_jar Application.compile_env!(:wraft_doc, [:signature_jar_file])
  # Digital signature keystore configuration
  @keystore_file Application.compile_env!(:wraft_doc, [:keystore_file])
  @keystore_password System.get_env("SIGNING_LOCAL_PASSPHRASE")
  @key_alias System.get_env("SIGNING_KEY_ALIAS") || "1"
  @signature_reason "I hereby certify that I have signed this document"
  @signature_location "Digital Signature"

  alias WraftDoc
  alias WraftDoc.Account.User
  alias WraftDoc.Assets
  alias WraftDoc.AuthTokens
  alias WraftDoc.AuthTokens.AuthToken
  alias WraftDoc.Client.Minio
  alias WraftDoc.CounterParties.CounterParty
  alias WraftDoc.Documents
  alias WraftDoc.Documents.ESignature
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Layouts.Layout
  alias WraftDoc.PdfAnalyzer
  alias WraftDoc.Repo
  alias WraftDoc.Workers.EmailWorker

  @doc """
  Apply a visual signature to a PDF document

  ## Parameters

  - `pdf_path`: Path to the input PDF file
  - `signature_image_path`: Path to the signature image file
  - `output_pdf_path`: Path where the signed PDF will be saved
  - `page`: Page number where the signature should be applied (0-based)
  - `coordinates`: Map containing x1, y1, x2, y2 coordinates for signature placement
  - `keystore_file`: Path to the keystore file (optional, defaults to `@keystore_file`)
  - `keystore_password`: Password for the keystore (optional, defaults to `@keystore_password`)
  - `key_alias`: Alias for the key in the keystore (optional, defaults to `@key_alias`)
  - `signature_reason`: Reason for the signature (optional, defaults to `@signature_reason`)
  - `signature_location`: Location of the signature (optional, defaults to `@signature_location`)


  ## Returns

  - `{:ok, output_path}`: If successful
  - `{:error, reason}`: If the operation fails
  """
  @spec apply_visual_signature(String.t(), String.t(), String.t(), integer(), map()) ::
          {:ok, String.t()} | {:error, String.t()}
  def apply_visual_signature(
        pdf_path,
        signature_image_path,
        output_pdf_path,
        page,
        %{"x1" => x1, "y1" => y1, "x2" => x2, "y2" => y2} = _coordinates
      ) do
    args = [
      "-cp",
      @visual_signer_jar,
      "com.wraft.VisualSignerApp",
      "--input",
      pdf_path,
      "--signature",
      signature_image_path,
      "--output",
      output_pdf_path,
      "--page",
      "#{page}",
      "--x1",
      "#{x1}",
      "--y1",
      "#{y1}",
      "--x2",
      "#{x2}",
      "--y2",
      "#{y2}",
      "--keystore",
      @keystore_file,
      "--keystore-password",
      @keystore_password,
      "--key-alias",
      @key_alias,
      "--reason",
      @signature_reason,
      "--location",
      @signature_location
    ]

    case System.cmd("java", args, stderr_to_stdout: true) do
      {output, 0} ->
        Logger.info("Visual signature applied successfully: #{output}")
        {:ok, output_pdf_path}

      {error, code} ->
        Logger.error("Failed to apply visual signature. Exit code: #{code}, Error: #{error}")
        {:error, "Failed to apply visual signature: #{error}"}
    end
  end

  @doc """
  Apply a signature to a document using the visual signer
  """
  @spec apply_signature_to_document(ESignature.t(), Instance.t(), map()) ::
          {:ok, ESignature.t()} | {:error, String.t()}
  def apply_signature_to_document(
        %CounterParty{e_signature: []},
        _instance,
        _params
      ),
      do: {:error, "Counterparty has no signatures"}

  def apply_signature_to_document(
        %CounterParty{signature_status: :signed} = _counterparty,
        _instance,
        _params
      ),
      do: {:error, "Counterparty has already signed the document"}

  def apply_signature_to_document(
        %CounterParty{e_signature: signatures} = counterparty,
        %Instance{
          instance_id: instance_id,
          content_type: %{layout: %Layout{organisation_id: org_id} = _layout} = _content_type
        } = instance,
        %{"signature_image" => %Plug.Upload{path: signature_image_path}}
      ) do
    instance_dir_path = "organisations/#{org_id}/contents/#{instance_id}"
    base_local_dir_path = Path.join(File.cwd!(), instance_dir_path)
    File.mkdir_p!(base_local_dir_path)

    pdf_path =
      instance
      |> Documents.instance_updated?()
      |> then(&Assets.pdf_file_path(instance, instance_dir_path, &1))

    base_local_file_path = Path.join(File.cwd!(), pdf_path)
    binary = Minio.download(pdf_path)
    File.write!(base_local_file_path, binary)

    output_pdf_path = Path.join(instance_dir_path, "signed_#{instance_id}.pdf")

    {updated_signatures, _} =
      Enum.map_reduce(signatures, pdf_path, fn %ESignature{
                                                 signature_data: %{
                                                   "page" => page,
                                                   "coordinates" => coordinates
                                                 }
                                               } = signature,
                                               current_pdf ->
        case apply_visual_signature(
               current_pdf,
               signature_image_path,
               output_pdf_path,
               page,
               coordinates
             ) do
          {:ok, _output_path} ->
            {:ok, updated_signature} =
              update_e_signature(signature, %{signed_file: output_pdf_path})

            {updated_signature, output_pdf_path}

          {:error, reason} ->
            Logger.error("Failed to apply signature: #{inspect(reason)}")
            {signature, current_pdf}
        end
      end)

    Minio.upload_file(output_pdf_path)

    # Clean up
    File.rm_rf(Path.join(File.cwd!(), instance_dir_path))
    File.rm_rf(output_pdf_path)

    {:ok,
     %{
       counterparty: %{counterparty | e_signature: updated_signatures},
       signed_pdf_path: output_pdf_path
     }}
  end

  @doc """
  Get a signature by counterparty ID
  """
  @spec get_signature_by_counterparty(CounterParty.t()) :: ESignature.t() | nil
  def get_signature_by_counterparty(%CounterParty{id: counter_party_id}) do
    ESignature
    |> where([s], s.counter_party_id == ^counter_party_id)
    |> preload([:user, :counter_party, content: [:creator]])
    |> Repo.one()
  end

  def get_signature_by_counterparty(_), do: nil

  @doc """
  Get a signature by Signature ID & Document ID
  """
  @spec get_signature(ESignature.t()) :: ESignature.t() | nil
  def get_signature(<<_::288>> = signature_id, <<_::288>> = document_id) do
    ESignature
    |> where([s], s.id == ^signature_id and s.content_id == ^document_id)
    |> preload([:counter_party])
    |> Repo.one()
  end

  def get_signature(_), do: nil

  @doc """
  Create a new signature request for a document
  """
  @spec create_signature(Instance.t(), User.t(), CounterParty.t() | [CounterParty.t()]) ::
          {:ok, ESignature.t()} | {:error, Ecto.Changeset.t()}
  def create_signature(
        %Instance{id: document_id} = _instance,
        %User{id: user_id, current_org_id: org_id} = _user
      ) do
    signature_params = %{
      content_id: document_id,
      user_id: user_id,
      organisation_id: org_id
    }

    %ESignature{}
    |> ESignature.changeset(signature_params)
    |> Repo.insert()
    |> case do
      {:ok, signature} ->
        Repo.preload(signature, [:counter_party])

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def create_signature(instance, user, counterparty_list),
    do: Enum.each(counterparty_list, &create_signature(instance, user, &1))

  @doc """
  Get pending signatures for a document
  """
  def get_document_pending_signatures(<<_::288>> = document_id) do
    CounterParty
    |> where([cp], cp.content_id == ^document_id and cp.signature_status == :pending)
    |> preload([:content, :user])
    |> Repo.all()
  end

  @doc """
  Get all signatures for a document
  """
  def get_document_signatures(document_id) do
    ESignature
    |> where([s], s.content_id == ^document_id)
    |> preload([:content, :user, :organisation, :counter_party])
    |> Repo.all()
  end

  @doc """
  Delete a signature by ID
  """
  @spec delete_signature(ESignature.t()) :: {:ok, ESignature.t()} | {:error, Ecto.Changeset.t()}
  def delete_signature(%ESignature{} = signature), do: Repo.delete(signature)

  # TODO need to implement this function
  @doc """
  Check if all signatures for a document are complete
  """
  @spec check_document_signature_status(Instance.t()) ::
          {:ok, Instance.t()} | {:error, :not_signed}
  def check_document_signature_status(%Instance{id: document_id}) do
    document_id
    |> get_document_pending_signatures()
    |> Enum.empty?()
    |> case do
      true ->
        # All signatures are complete
        finalize_signed_document(document_id)

      false ->
        # There are still pending signatures
        {:error, :not_signed}
    end
  end

  # Finalize the document after all signatures are complete
  defp finalize_signed_document(instance) do
    # Logic to finalize the document after all signatures
    # This could include:
    # - Marking the document as fully signed
    # - Generating a final signed PDF
    # - Updating the document status
    # - Sending notifications to all parties

    # Future implementation details would go here
    {:ok, instance}
  end

  @doc """
  Update a signature
  """
  @spec update_e_signature(ESignature.t(), map()) ::
          {:ok, ESignature.t()} | {:error, Ecto.Changeset.t()}
  def update_e_signature(%ESignature{} = signature, params) do
    # Make sure to include signed_file in the allowed params
    signature
    |> ESignature.changeset(params)
    |> Repo.update()
    |> case do
      {:ok, updated_signature} ->
        Repo.preload(updated_signature, [:counter_party])
        {:ok, updated_signature}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
   Send a signature request email to the counterparty
  """
  @spec signature_request_email(%Instance{}, %CounterParty{}, String.t()) ::
          {:ok, Oban.Job.t()} | {:error, Oban.Job.changeset() | term()}
  def signature_request_email(
        %Instance{instance_id: instance_id, id: document_id},
        %CounterParty{name: name, email: email},
        token
      ) do
    %{
      email: email,
      name: name,
      token: token,
      document_id: document_id,
      instance_id: instance_id
    }
    |> EmailWorker.new(queue: "mailer", tags: ["document_signature_request"])
    |> Oban.insert()
  end

  @doc """
  Send signature request emails to all counterparties for a document
  """
  @spec signature_request_email(%Instance{}, [CounterParty.t()]) :: :ok
  def signature_request_email(instance, counterparties) do
    Enum.each(counterparties, fn %CounterParty{email: email} = counterparty ->
      {:ok, %AuthToken{value: token}} = AuthTokens.create_signer_invite_token(instance, email)
      signature_request_email(instance, counterparty, token)
    end)
  end

  # TODO : Function need to be implemented
  @doc """
  Notify the document owner when a signature is completed
  """
  def notify_document_owner_email(
        %ESignature{
          content: %Instance{creator: owner, instance_id: instance_id},
          counter_party: counterparty
        } =
          _signature
      ) do
    %{
      email: owner.email,
      instance_id: instance_id,
      signer_name: counterparty.name
    }
    |> EmailWorker.new(queue: "mailer", tags: ["notify_document_owner_signature_complete"])
    |> Oban.insert()
  end

  @doc """
  Generate a PDF with the signature
  """
  def generate_signature(
        %Instance{
          instance_id: instance_id,
          id: document_id,
          content_type: %{layout: %Layout{organisation_id: org_id} = layout} = _content_type
        } = instance,
        current_user
      ) do
    # Preload the layout with its engine association
    layout = Assets.preload_asset(layout)

    # Delete existing signatures for the instance
    Repo.delete_all(
      from(
        s in ESignature,
        where: s.content_id == ^document_id and s.organisation_id == ^org_id
      )
    )

    # When ESignature are removed. Also put the associated counterparty to pending
    Repo.update_all(
      from(
        cp in CounterParty,
        where: cp.content_id == ^document_id
      ),
      set: [signature_status: :pending]
    )

    case Documents.build_doc(instance, layout, sign: true) do
      {_, 0} ->
        instance_dir_path = "organisations/#{org_id}/contents/#{instance_id}"
        instance_updated? = Documents.instance_updated?(instance)
        pdf_path = Assets.pdf_file_path(instance, instance_dir_path, instance_updated?)

        # Determine the engine type based on the layout's engine
        engine_type = determine_engine_type(layout.engine)

        # Pass the engine type from the layout to the PDF analyzer
        case PdfAnalyzer.analyze_pdf(pdf_path, engine_type) do
          {:ok, json_result} ->
            # Parse the JSON result to extract rectangle coordinates
            analysis_result = PdfAnalyzer.parse_result(json_result)

            # Process the rectangles to find signature fields
            signature_fields = extract_signature_fields(analysis_result["rectangles"])

            # Clean up
            File.rm_rf(Path.join(File.cwd!(), instance_dir_path))
            File.rm_rf(Path.join(File.cwd!(), "/organisations/images/"))

            # Create new e_signature entries with the signature fields
            create_signature_entries(signature_fields, instance.id, current_user.id, org_id)

          {:error, reason} ->
            Logger.error("Failed to analyze PDF for signatures: #{reason}")
            {:error, "Failed to analyze PDF for signatures"}
        end

      _ ->
        Logger.error("Failed to generate PDF for instance #{instance_id}")
        {:error, "Failed to generate PDF"}
    end
  end

  # Helper function to check for engine type
  defp determine_engine_type(%{name: "Pandoc + Typst"}), do: "typst"
  defp determine_engine_type(%{name: "Pandoc"}), do: "latex"

  # Helper function to create signature entries
  defp create_signature_entries(signature_fields, content_id, user_id, org_id) do
    Enum.map(signature_fields, fn field ->
      changeset =
        ESignature.changeset(%ESignature{}, %{
          content_id: content_id,
          signature_data: field,
          signature_position: field.coordinates,
          signature_type: :electronic,
          user_id: user_id,
          organisation_id: org_id,
          counter_party_id: nil
        })

      changeset
      |> Repo.insert()
      |> case do
        {:ok, signature} ->
          Repo.preload(signature, [:counter_party])

        {:error, changeset} ->
          Logger.error("Failed to create signature entry: #{inspect(changeset)}")
          {:error, changeset}
      end
    end)
  end

  # Helper function to extract signature fields from rectangle data
  # This reduces nesting depth in the main function
  defp extract_signature_fields(rectangles) do
    Enum.map(rectangles, fn rect ->
      %{
        page: rect["page"],
        dimensions: %{
          width: rect["dimensions"]["width"],
          height: rect["dimensions"]["height"]
        },
        coordinates: %{
          x1: rect["corners"]["x1"],
          y1: rect["corners"]["y1"],
          x2: rect["corners"]["x2"],
          y2: rect["corners"]["y2"]
        }
      }
    end)
  end

  @doc """
  Assign a counter party to a signature
  """
  @spec assign_counter_party(ESignature.t(), CounterParty.t()) ::
          {:ok, ESignature.t()} | {:error, Ecto.Changeset.t()}
  def assign_counter_party(
        %ESignature{} = signature,
        %CounterParty{id: counter_party_id} = counter_party
      ) do
    signature
    |> ESignature.changeset(%{counter_party_id: counter_party_id})
    |> Repo.update()
    |> case do
      {:ok, updated_signature} ->
        {:ok, %{updated_signature | counter_party: counter_party}}

      error ->
        error
    end
  end
end
