defmodule WraftDoc.Documents.Signatures do
  @moduledoc """
  Context module for managing digital signatures for documents.
  """

  import Ecto.Query
  require Logger

  # Path to the pdf signer JAR file
  @pdf_signer_jar Application.compile_env!(:wraft_doc, [:signature_jar_file])
  # Digital signature keystore configuration
  @keystore_file Application.compile_env!(:wraft_doc, [:keystore_file])
  @signature_reason "I hereby certify that I have signed this document"
  @signature_location "Digital Signature"

  alias WraftDoc
  alias WraftDoc.Account.User
  alias WraftDoc.Assets
  alias WraftDoc.AuthTokens
  alias WraftDoc.AuthTokens.AuthToken
  alias WraftDoc.Client.Minio
  alias WraftDoc.CounterParties
  alias WraftDoc.CounterParties.CounterParty
  alias WraftDoc.Documents
  alias WraftDoc.Documents.ESignature
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Layouts.Layout
  alias WraftDoc.PdfAnalyzer
  alias WraftDoc.Repo
  alias WraftDoc.Workers.EmailWorker

  @doc """
  Apply digital signature to a PDF document

  ## Parameters

  - `pdf_path`: Path to the input PDF file
  - `signed_pdf_path`: Path where the signed PDF will be saved
  - `keystore_file`: Path to the keystore file (optional, defaults to `@keystore_file`)
  - `keystore_password`: Password for the keystore (optional, defaults to `@keystore_password`)
  - `key_alias`: Alias for the key in the keystore (optional, defaults to `@key_alias`)
  - `signature_reason`: Reason for the signature (optional, defaults to `@signature_reason`)
  - `signature_location`: Location of the signature (optional, defaults to `@signature_location`)
  - `certificate_path`: Path to the certificate file (optional, defaults to `@certificate_path`)


  ## Returns

  - `{:ok, output_path}`: If successful
  - `{:error, reason}`: If the operation fails
  """
  @spec apply_digital_signature(String.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def apply_digital_signature(pdf_path, signed_pdf_path, certificate_path) do
    args = [
      "-cp",
      @pdf_signer_jar,
      "com.wraft.DigitalSignerApp",
      "--input",
      pdf_path,
      "--output",
      signed_pdf_path,
      "--keystore",
      @keystore_file,
      "--keystore-password",
      to_string(get_keystore_password()),
      "--key-alias",
      to_string(get_key_alias()),
      "--reason",
      @signature_reason,
      "--location",
      @signature_location,
      "--certificate",
      certificate_path
    ]

    case System.cmd("java", args, stderr_to_stdout: true) do
      {output, 0} ->
        Logger.info("PDF signature applied successfully: #{output}")
        {:ok, signed_pdf_path}

      {error, code} ->
        Logger.error("Failed to apply PDF signature. Exit code: #{code}, Error: #{error}")
        {:error, "Failed to apply PDF signature: #{error}"}
    end
  end

  @doc """
  Apply a visual signature to a PDF document
  ## Parameters
  - `pdf_path`: Path to the input PDF file
  - `signature_image_path`: Path to the signature image file
  - `signed_pdf_path`: Path where the signed PDF will be saved
  - `coordinates`: JSON string containing list of x1, y1, x2, y2 coordinates for signature placement (origin is bottom left)
  ## Returns
  - `{:ok, output_path}`: If successful
  - `{:error, reason}`: If the operation fails
  """
  @spec apply_visual_signature(String.t(), String.t(), String.t(), String.t()) ::
          {:ok, String.t()} | {:error, String.t()}
  def apply_visual_signature(pdf_path, signature_image_path, signed_pdf_path, coordinates) do
    args = [
      "-cp",
      @pdf_signer_jar,
      "com.wraft.VisualSignerApp",
      "--input",
      pdf_path,
      "--signature",
      signature_image_path,
      "--output",
      signed_pdf_path,
      "--coordinates-json-string",
      coordinates
    ]

    Logger.info("Executing visual signer with args: #{inspect(args)}")

    case System.cmd("java", args, stderr_to_stdout: true) do
      {output, 0} ->
        Logger.info("Visual signature applied successfully: #{output}")
        {:ok, signed_pdf_path}

      {error, code} ->
        Logger.error("Failed to apply visual signature. Exit code: #{code}, Error: #{error}")
        {:error, "Failed to apply visual signature: #{error}"}
    end
  end

  @doc """
  Apply a digital signature to a document
  """
  @spec apply_digital_signature_to_document(Instance.t(), boolean()) ::
          {:ok, String.t()} | {:error, String.t()}
  def apply_digital_signature_to_document(
        %Instance{
          id: document_id,
          instance_id: instance_id,
          organisation_id: org_id
        } = instance,
        true
      ) do
    instance_dir_path = "organisations/#{org_id}/contents/#{instance_id}"
    base_local_dir_path = Path.join(File.cwd!(), instance_dir_path)

    signed_pdf_path = Path.join(instance_dir_path, "signed_#{instance_id}.pdf")
    pdf_path = get_or_download_pdf(signed_pdf_path, instance, instance_dir_path)

    # Generate certificate
    certificate_md_path = Path.join(base_local_dir_path, "certificate.md")
    certificate_pdf_path = Path.join(base_local_dir_path, "certificate.pdf")
    counterparties = CounterParties.get_document_counterparties(document_id)
    signers_content = prepare_markdown(base_local_dir_path, counterparties)
    File.write!(certificate_md_path, signers_content)

    generate_certificate(certificate_md_path, certificate_pdf_path)

    pdf_path
    |> apply_digital_signature(signed_pdf_path, certificate_pdf_path)
    |> case do
      {:ok, _signed_pdf_path} ->
        Minio.upload_file(signed_pdf_path)

        # Update the counterparty with the signed file
        Enum.each(counterparties, fn counterparty ->
          CounterParties.counter_party_sign(counterparty, %{signed_file: signed_pdf_path})
        end)

        finalize_signed_document(instance, signed_pdf_path)
        cleanup_signed_pdf(signed_pdf_path, instance_dir_path)
        {:ok, signed_pdf_path}

      {:error, reason} ->
        Logger.error("Failed to apply digital signature: #{reason}")
        cleanup_signed_pdf(signed_pdf_path, instance_dir_path)
        {:error, reason}
    end
  end

  def apply_digital_signature_to_document(_, _, false),
    do: {:ok, "Document is not completely visually signed yet"}

  @doc """
  Apply a visual signature to a document
  """
  @spec apply_visual_signature_to_document(CounterParty.t(), Instance.t(), map(), boolean()) ::
          {:ok, String.t()} | {:error, String.t()}
  def apply_visual_signature_to_document(
        %CounterParty{e_signature: []},
        _instance,
        _params,
        _signature_status
      ),
      do: {:error, "Counterparty has no signatures"}

  def apply_visual_signature_to_document(
        %CounterParty{signature_status: :signed} = _counterparty,
        _instance,
        _params,
        _signature_status
      ),
      do: {:error, "Counterparty has already signed the document"}

  def apply_visual_signature_to_document(_, %Instance{signature_status: true}, _, _),
    do: {:error, "Document is already fully signed"}

  def apply_visual_signature_to_document(
        %CounterParty{e_signature: signatures},
        %Instance{
          instance_id: instance_id,
          content_type: %{layout: %Layout{organisation_id: org_id} = _layout} = _content_type
        } = instance,
        %{"signature_image" => %Plug.Upload{path: signature_image_path}},
        signature_status
      ) do
    instance_dir_path = "organisations/#{org_id}/contents/#{instance_id}"
    base_local_dir_path = Path.join(File.cwd!(), instance_dir_path)
    File.mkdir_p!(base_local_dir_path)

    signed_pdf_path = Path.join(instance_dir_path, "signed_#{instance_id}.pdf")
    initial_pdf_path = get_or_download_pdf(signed_pdf_path, instance, instance_dir_path)

    coordinates =
      signatures
      |> Enum.map(fn %{
                       signature_data: %{
                         "page" => page,
                         "coordinates" => %{"x1" => x1, "y1" => y1, "x2" => x2, "y2" => y2}
                       }
                     } ->
        %{
          "page" => page,
          "x1" => x1,
          "y1" => y1,
          "x2" => x2,
          "y2" => y2
        }
      end)
      |> Jason.encode!()

    case apply_visual_signature(
           initial_pdf_path,
           signature_image_path,
           signed_pdf_path,
           coordinates
         ) do
      {:ok, _signed_pdf_path} ->
        append_signed_file_to_signatures(signatures, signed_pdf_path)
        Minio.upload_file(signed_pdf_path)
        handle_clean_up(signature_status, signed_pdf_path, instance_dir_path)
        {:ok, signed_pdf_path}

      {:error, reason} ->
        Logger.error("Failed to apply signature: #{inspect(reason)}")
        cleanup_signed_pdf(signed_pdf_path, instance_dir_path)
        {:error, reason}
    end
  end

  defp handle_clean_up(false, signed_pdf_path, instance_dir_path),
    do: cleanup_signed_pdf(signed_pdf_path, instance_dir_path)

  defp handle_clean_up(true, _signed_pdf_path, _instance_dir_path), do: :ok

  defp append_signed_file_to_signatures(signatures, signed_pdf_path) do
    Enum.each(signatures, fn signature ->
      update_e_signature(signature, %{signed_file: signed_pdf_path})
    end)
  end

  defp cleanup_signed_pdf(signed_pdf_path, instance_dir_path) do
    File.rm_rf(Path.join(File.cwd!(), instance_dir_path))
    File.rm_rf(signed_pdf_path)
  end

  defp get_or_download_pdf(signed_pdf_path, instance, instance_dir_path) do
    if Minio.file_exists?(signed_pdf_path) do
      download_existing_signed_pdf(signed_pdf_path)
    else
      download_original_pdf(instance, instance_dir_path)
    end
  end

  defp download_existing_signed_pdf(signed_pdf_path) do
    binary = Minio.download(signed_pdf_path)
    File.write!(signed_pdf_path, binary)
    signed_pdf_path
  end

  defp download_original_pdf(instance, instance_dir_path) do
    pdf_path =
      instance
      |> Documents.instance_updated?()
      |> then(&Assets.pdf_file_path(instance, instance_dir_path, &1))

    base_local_file_path = Path.join(File.cwd!(), pdf_path)
    binary = Minio.download(pdf_path)
    File.write!(base_local_file_path, binary)
    pdf_path
  end

  @doc """
  Generate a PDF certificate from a markdown file using Pandoc
  """
  @spec generate_certificate(String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def generate_certificate(certificate_markdown_path, certificate_pdf_path) do
    args = [
      "#{certificate_markdown_path}",
      "-o",
      "#{certificate_pdf_path}",
      "--template=#{File.cwd!() <> "/priv/signature/certificate.html"}",
      "--pdf-engine=wkhtmltopdf"
    ]

    case System.cmd("pandoc", args, stderr_to_stdout: true) do
      {output, 0} ->
        Logger.info("Certificate generated successfully: #{output}")
        {:ok, output}

      {error_output, exit_code} ->
        Logger.error("Failed to generate certificate: #{error_output}")
        {:error, exit_code}
    end
  end

  @doc """
  Prepare markdown content for certificate generation
  """
  @spec prepare_markdown(String.t(), [CounterParty.t()]) :: String.t()
  def prepare_markdown(base_local_dir_path, counterparties) do
    signers_yaml = """
    ---
    signers:
    #{format_signers(counterparties, base_local_dir_path)}
    ---
    """

    signers_yaml
  end

  defp format_signers(counterparties, base_local_dir_path) do
    counterparties
    |> Enum.with_index(1)
    |> Enum.map_join("\n", &format_signer(&1, base_local_dir_path))
  end

  defp format_signer({counterparty, index}, base_local_dir_path) do
    signature_image_path = download_signature_image(counterparty, base_local_dir_path)

    """
      - index: #{index}
        name: #{counterparty.name}
        email: #{counterparty.email}
        auth_level: Email
        counterparty_id: #{counterparty.id}
        ip_address: #{counterparty.signature_ip || "Not available"}
        device: #{counterparty.device || "Not available"}
        signed_at: "#{format_datetime(counterparty.signature_date)}"
        reason: #{@signature_reason}
        signature_image: "#{signature_image_path}"
    """
  end

  defp download_signature_image(%CounterParty{signature_image: nil}, _), do: nil

  defp download_signature_image(%CounterParty{user_id: user_id}, base_local_dir_path) do
    File.mkdir_p!(Path.join(base_local_dir_path, "signature/#{user_id}"))
    signature_local_path = Path.join(base_local_dir_path, "signature/#{user_id}/signature.png")

    "users/#{user_id}/signatures/signature.png"
    |> Minio.download()
    |> then(&File.write!(signature_local_path, &1))
    |> case do
      :ok -> signature_local_path
      _ -> nil
    end
  end

  defp format_datetime(nil), do: "Not available"

  defp format_datetime(datetime) do
    datetime
    |> DateTime.shift_zone!("Etc/UTC")
    |> Calendar.strftime("%Y-%m-%d %I:%M:%S %p (UTC)")
  end

  @doc """
  Delete all signatures associated with a counterparty
  """
  @spec delete_signatures(CounterParty.t()) :: {non_neg_integer(), nil}
  def delete_signatures(%CounterParty{id: counter_party_id}) do
    ESignature
    |> where([s], s.counter_party_id == ^counter_party_id)
    |> Repo.delete_all()
  end

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
  Check if the current signer is the last signer
  """
  @spec document_signed?(Instance.t()) :: boolean()
  def document_signed?(%Instance{id: document_id}) do
    document_id
    |> get_document_pending_signatures()
    |> Enum.count() == 1
  end

  # Finalize the document after all signatures are complete
  defp finalize_signed_document(instance, signed_pdf_path) do
    # Logic to finalize the document after all signatures
    # This could include:
    # - Generating a final signed PDF , digitally signing, Visual signing already done, wholesome digital signing.
    # - Marking the document as fully signed
    instance
    |> Instance.update_signature_status_changeset(%{signature_status: true})
    |> Repo.update()

    # - Sending notifications to all parties
    notify_document_fully_signed(instance, signed_pdf_path)

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
  Notify all parties when a document is fully signed
  """
  @spec notify_document_fully_signed(%Instance{}, String.t()) :: :ok
  def notify_document_fully_signed(
        %Instance{id: document_id, instance_id: instance_id},
        signed_pdf_path
      ) do
    counterparties = CounterParties.get_document_counterparties(document_id)

    Enum.each(counterparties, fn %CounterParty{email: email} = counterparty ->
      %{
        email: email,
        instance_id: instance_id,
        signer_name: counterparty.name,
        signed_document: signed_pdf_path,
        document_name: "signed_#{instance_id}.pdf"
      }
      |> EmailWorker.new(queue: "mailer", tags: ["document_fully_signed"])
      |> Oban.insert()
    end)
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
      set: [signature_status: :pending, signature_image: nil]
    )

    # Reset the document instance sign status to false
    instance
    |> Instance.update_signature_status_changeset(%{signature_status: false})
    |> Repo.update()

    # Delete the signed_file in minio
    instance_dir_path = "organisations/#{org_id}/contents/#{instance_id}"
    signed_pdf_path = Path.join(instance_dir_path, "signed_#{instance_id}.pdf")
    Minio.delete_file(signed_pdf_path)

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

  # Private
  defp get_keystore_password do
    System.get_env("SIGNING_LOCAL_PASSPHRASE")
  end

  defp get_key_alias do
    System.get_env("SIGNING_KEY_ALIAS") || "1"
  end
end
