defmodule WraftDoc.Workflows.Adaptors.EmailAdaptor do
  @moduledoc """
  Email adaptor for sending emails with templates and attachments.

  Supports template variable interpolation in subject, body, and recipient fields.
  Can attach files from previous workflow steps.

  Configuration:
  - to: String (required) - Recipient email address (supports template variables)
  - subject: String (required) - Email subject (supports template variables)
  - body: String or Map (required) - Email body (supports template variables)
    - If string: Plain text or HTML
    - If map with "html": HTML body
    - If map with "text": Plain text body
    - If map with "template_id": Use existing email template
  - cc: String or List (optional) - CC recipients (supports template variables)
  - bcc: String or List (optional) - BCC recipients (supports template variables)
  - from: String (optional) - Sender email (default: system sender)
  - attachments: List (optional) - List of attachment specs
    - Can reference previous workflow step outputs
    - Format: [%{"source" => "{{previous.step_name}}", "filename" => "document.pdf"}]

  Example:
  config: %{
    "to" => "{{email}}",
    "subject" => "Your document is ready",
    "body" => %{"html" => "<p>Hello {{name}}, your document is ready.</p>"},
    "attachments" => [%{"source" => "{{previous.build_document}}", "filename" => "document.pdf"}]
  }
  input_data: %{"email" => "user@example.com", "name" => "John"}
  """

  @behaviour WraftDoc.Workflows.Adaptors.Adaptor

  require Logger
  alias WraftDocWeb.Mailer
  import Swoosh.Email

  @impl true
  def execute(config, input_data, _credentials) do
    with {:ok, to} <- get_recipient(config, input_data, "to"),
         {:ok, subject} <- get_subject(config, input_data),
         {:ok, body} <- get_body(config, input_data),
         {:ok, from} <- get_from(config),
         {:ok, cc} <- get_recipients(config, input_data, "cc"),
         {:ok, bcc} <- get_recipients(config, input_data, "bcc"),
         {:ok, attachments} <- get_attachments(config, input_data) do
      Logger.info("[EmailAdaptor] Sending email to #{to}")

      email =
        new()
        |> to(to)
        |> from(from)
        |> subject(subject)
        |> maybe_add_cc(cc)
        |> maybe_add_bcc(bcc)
        |> add_body(body)
        |> add_attachments(attachments)

      case Mailer.deliver(email) do
        {:ok, _result} ->
          Logger.info("[EmailAdaptor] Email sent successfully to #{to}")

          {:ok,
           %{
             to: to,
             subject: subject,
             delivered_at: DateTime.to_iso8601(DateTime.utc_now())
           }}

        {:error, reason} ->
          Logger.error("[EmailAdaptor] Failed to send email: #{inspect(reason)}")

          {:error,
           %{
             message: "Failed to send email",
             reason: inspect(reason)
           }}
      end
    end
  end

  @impl true
  def validate_config(config) do
    cond do
      !Map.has_key?(config, "to") ->
        {:error, "to is required"}

      !Map.has_key?(config, "subject") ->
        {:error, "subject is required"}

      !Map.has_key?(config, "body") && !Map.has_key?(config, "template_id") ->
        {:error, "body or template_id is required"}

      true ->
        :ok
    end
  end

  defp get_recipient(config, input_data, key) do
    case Map.get(config, key) do
      nil when key == "to" ->
        {:error, "to is required"}

      nil ->
        {:ok, nil}

      recipient when is_binary(recipient) ->
        {:ok, interpolate_template(recipient, input_data)}

      _ ->
        {:error, "#{key} must be a string"}
    end
  end

  defp get_subject(config, input_data) do
    case Map.get(config, "subject") do
      nil ->
        {:error, "subject is required"}

      subject when is_binary(subject) ->
        {:ok, interpolate_template(subject, input_data)}

      _ ->
        {:error, "subject must be a string"}
    end
  end

  defp get_body(config, input_data) do
    body_value = Map.get(config, "body")
    template_id = Map.get(config, "template_id")

    case {body_value, template_id} do
      {nil, nil} ->
        {:error, "body is required"}

      {nil, _template_id} ->
        # TODO: Load template from template_id
        {:error, "template_id not yet implemented, use body instead"}

      {body, _} when is_binary(body) ->
        process_string_body(body, input_data)

      {body, _} when is_map(body) ->
        process_map_body(body, input_data)

      _ ->
        {:error, "body must be a string or map"}
    end
  end

  defp process_string_body(body_value, input_data) do
    # Plain text or HTML (detect by checking for HTML tags)
    if String.contains?(body_value, "<") do
      {:ok, %{html: interpolate_template(body_value, input_data)}}
    else
      {:ok, %{text: interpolate_template(body_value, input_data)}}
    end
  end

  defp process_map_body(body_value, input_data) do
    # Map with html, text, or both
    processed_body =
      Enum.reduce(body_value, %{}, fn {key, value}, acc ->
        processed_value = process_body_value(value, input_data)
        Map.put(acc, key, processed_value)
      end)

    {:ok, processed_body}
  end

  defp process_body_value(value, input_data) when is_binary(value),
    do: interpolate_template(value, input_data)

  defp process_body_value(value, _input_data), do: value

  defp get_from(config) do
    case Map.get(config, "from") do
      nil -> {:ok, {sender_name(), sender_email()}}
      from when is_binary(from) -> {:ok, {sender_name(), from}}
      _ -> {:error, "from must be a string"}
    end
  end

  defp get_recipients(config, input_data, key) do
    config
    |> Map.get(key)
    |> normalize_recipients(input_data, key)
  end

  defp normalize_recipients(nil, _input_data, _key), do: {:ok, []}

  defp normalize_recipients(recipients, input_data, _key) when is_binary(recipients) do
    {:ok, [interpolate_template(recipients, input_data)]}
  end

  defp normalize_recipients(recipients, input_data, _key) when is_list(recipients) do
    processed = Enum.map(recipients, &normalize_recipient(&1, input_data))
    {:ok, processed}
  end

  defp normalize_recipients(_recipients, _input_data, key),
    do: {:error, "#{key} must be a string or list"}

  defp normalize_recipient(recipient, input_data) when is_binary(recipient),
    do: interpolate_template(recipient, input_data)

  defp normalize_recipient(recipient, _input_data), do: recipient

  defp get_attachments(config, input_data) do
    case Map.get(config, "attachments") do
      nil ->
        {:ok, []}

      attachments when is_list(attachments) ->
        # Process attachments - can reference previous workflow steps
        processed =
          Enum.map(attachments, fn attachment ->
            process_attachment(attachment, input_data)
          end)

        {:ok, Enum.filter(processed, &(&1 != nil))}

      _ ->
        {:error, "attachments must be a list"}
    end
  end

  defp process_attachment(attachment_spec, input_data) when is_map(attachment_spec) do
    source = Map.get(attachment_spec, "source")
    filename = Map.get(attachment_spec, "filename", "attachment")

    case resolve_attachment_source(source, input_data) do
      {:ok, binary_data} ->
        %Swoosh.Attachment{
          filename: interpolate_template(filename, input_data),
          content_type: get_content_type(filename),
          data: binary_data
        }

      {:error, _reason} ->
        Logger.warning("[EmailAdaptor] Could not resolve attachment source: #{inspect(source)}")
        nil
    end
  end

  defp process_attachment(_, _), do: nil

  defp resolve_attachment_source(source, input_data) when is_binary(source) do
    if previous_step_reference?(source) do
      resolve_previous_attachment(source, input_data)
    else
      decode_attachment_data(source)
    end
  end

  defp resolve_attachment_source(_, _), do: {:error, "Attachment source must be a string"}

  defp previous_step_reference?(source), do: String.contains?(source, "{{previous.")

  defp resolve_previous_attachment(source, input_data) do
    with [_, step_name] <- Regex.run(~r/\{\{previous\.(\w+)\}\}/, source),
         {:ok, step_output} <- fetch_step_output(input_data, step_name),
         {:ok, binary} <- extract_attachment_binary(step_output) do
      {:ok, binary}
    else
      nil -> {:error, "Invalid attachment source format"}
      {:error, _} = error -> error
      :error -> {:error, "Invalid attachment source format"}
    end
  end

  defp fetch_step_output(input_data, step_name) do
    output = Map.get(input_data, step_name) || Map.get(input_data, String.to_atom(step_name))
    {:ok, output}
  end

  defp extract_attachment_binary(nil), do: {:error, "Step output not found or invalid format"}

  defp extract_attachment_binary(%{"document" => data}) when is_binary(data),
    do: decode_binary_data(data)

  defp extract_attachment_binary(%{"file" => data}) when is_binary(data),
    do: decode_binary_data(data)

  defp extract_attachment_binary(binary) when is_binary(binary), do: decode_binary_data(binary)

  defp extract_attachment_binary(_),
    do: {:error, "Step output not found or invalid format"}

  defp decode_attachment_data(source) do
    case Base.decode64(source) do
      {:ok, decoded} -> {:ok, decoded}
      :error -> {:ok, source}
    end
  end

  defp decode_binary_data(data) do
    case Base.decode64(data) do
      {:ok, decoded} -> {:ok, decoded}
      :error -> {:ok, data}
    end
  end

  defp add_body(email, %{html: html}) when is_binary(html), do: html_body(email, html)

  defp add_body(email, %{text: text}) when is_binary(text), do: text_body(email, text)

  defp add_body(email, %{html: html, text: text}) when is_binary(html) and is_binary(text),
    do: email |> html_body(html) |> text_body(text)

  defp add_body(email, body) when is_map(body) do
    # Fallback - try to find html or text
    case body do
      %{"html" => html} -> html_body(email, html)
      %{"text" => text} -> text_body(email, text)
      _ -> email
    end
  end

  defp maybe_add_cc(email, []), do: email
  defp maybe_add_cc(email, [cc]), do: cc(email, cc)
  defp maybe_add_cc(email, cc_list), do: cc(email, cc_list)

  defp maybe_add_bcc(email, []), do: email
  defp maybe_add_bcc(email, [bcc]), do: bcc(email, bcc)
  defp maybe_add_bcc(email, bcc_list), do: bcc(email, bcc_list)

  defp add_attachments(email, []), do: email

  defp add_attachments(email, attachments), do: attachment(email, attachments)

  defp interpolate_template(template, data) when is_binary(template) do
    Regex.replace(~r/\{\{(\w+)\}\}/, template, fn _match, var_name ->
      value =
        Map.get(data, var_name) ||
          Map.get(data, String.to_atom(var_name)) ||
          (Map.get(data, "previous") && Map.get(Map.get(data, "previous"), var_name))

      to_string(value || "{{#{var_name}}}")
    end)
  end

  defp get_content_type(filename),
    do: Map.get(extension_to_mime_type(), Path.extname(filename), "application/octet-stream")

  defp extension_to_mime_type do
    %{
      ".pdf" => "application/pdf",
      ".doc" => "application/msword",
      ".docx" => "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
      ".xls" => "application/vnd.ms-excel",
      ".xlsx" => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      ".png" => "image/png",
      ".jpg" => "image/jpeg",
      ".jpeg" => "image/jpeg",
      ".gif" => "image/gif",
      ".txt" => "text/plain",
      ".csv" => "text/csv"
    }
  end

  defp sender_email,
    do: Application.get_env(:wraft_doc, WraftDocWeb.Mailer)[:sender_email] || "no-reply@wraft.com"

  defp sender_name, do: "Wraft"
end
