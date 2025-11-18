defmodule WraftDoc.Workflows.Actions.Registry do
  @moduledoc """
  Registry for workflow actions.

  Actions are pre-configured templates that map to adapters.
  Each action provides default configuration for creating workflow jobs.
  """

  @actions %{
    "build_document" => %{
      adapter: "template",
      name: "Build Document",
      description: "Build a document from a template using a document ID",
      icon: "document-text",
      category: "documents",
      default_config: %{
        template_id: nil,
        document_id: "{{input.document_id}}",
        output_field: "document"
      },
      required_fields: [:template_id],
      input_fields: [
        %{name: "document_id", label: "Document ID", type: "string", required: true}
      ]
    },
    "send_email" => %{
      adapter: "email",
      name: "Send Email",
      description: "Send email with template and attachments",
      icon: "envelope",
      category: "communication",
      default_config: %{
        template_id: nil,
        to: "{{input.email}}",
        subject: "{{input.subject}}",
        attachments: []
      },
      required_fields: [:to, :template_id],
      input_fields: [
        %{name: "to", label: "Recipient Email", type: "string", required: true},
        %{name: "template_id", label: "Email Template", type: "select", required: true}
      ]
    },
    "send_to_erpnext" => %{
      adapter: "erpnext",
      name: "Send to ERPNext",
      description: "Send document to ERPNext system",
      icon: "server",
      category: "integrations",
      default_config: %{
        endpoint: nil,
        doctype: "Document",
        document_field: "{{previous.document}}",
        credentials_id: nil
      },
      required_fields: [:endpoint, :doctype],
      input_fields: [
        %{name: "endpoint", label: "ERPNext Endpoint", type: "string", required: true},
        %{name: "doctype", label: "Document Type", type: "string", required: true}
      ]
    },
    "form_submit_trigger" => %{
      adapter: "form",
      name: "Form Submit Trigger",
      description: "Trigger workflow when form is submitted",
      icon: "form",
      category: "triggers",
      default_config: %{
        form_id: nil,
        service_mapping: %{}
      },
      required_fields: [:form_id],
      input_fields: [
        %{name: "form_id", label: "Form ID", type: "select", required: true}
      ]
    },
    "invoice_webhook_processor" => %{
      adapter: "webhook_processor",
      name: "Invoice Webhook Processor",
      description: "Process invoice webhook from ERPNext, build document, send back",
      icon: "webhook",
      category: "integrations",
      default_config: %{
        webhook_secret: nil,
        document_template_id: nil,
        erpnext_response_endpoint: nil,
        doctype_mapping: %{}
      },
      required_fields: [:document_template_id, :erpnext_response_endpoint],
      input_fields: [
        %{
          name: "document_template_id",
          label: "Document Template",
          type: "select",
          required: true
        },
        %{
          name: "erpnext_response_endpoint",
          label: "ERPNext Response Endpoint",
          type: "string",
          required: true
        }
      ]
    },
    "condition_check" => %{
      adapter: "condition",
      name: "Condition Check",
      description: "Evaluate data and branch workflow based on condition",
      icon: "git-branch",
      category: "logic",
      default_config: %{
        field: "status",
        operator: "==",
        value: "active"
      },
      required_fields: [:field, :operator],
      input_fields: [
        %{name: "field", label: "Field Name", type: "string", required: true},
        %{
          name: "operator",
          label: "Operator",
          type: "select",
          required: true,
          options: ["==", "!=", ">", "<", ">=", "<="]
        },
        %{name: "value", label: "Value", type: "string", required: false}
      ]
    },
    "http_request" => %{
      adapter: "http",
      name: "HTTP Request",
      description: "Make HTTP API call",
      icon: "globe",
      category: "integrations",
      default_config: %{
        url: "https://api.example.com",
        method: "GET",
        headers: %{},
        body: nil
      },
      required_fields: [:url, :method],
      input_fields: [
        %{name: "url", label: "URL", type: "string", required: true},
        %{
          name: "method",
          label: "Method",
          type: "select",
          required: true,
          options: ["GET", "POST", "PUT", "PATCH", "DELETE"]
        },
        %{name: "headers", label: "Headers", type: "json", required: false},
        %{name: "body", label: "Body", type: "json", required: false}
      ]
    }
  }

  @doc """
  List all available actions.
  """
  @spec list_actions() :: [map()]
  def list_actions do
    Map.values(@actions)
  end

  @doc """
  Get an action by ID.
  """
  @spec get_action(String.t()) :: map() | nil
  def get_action(action_id) do
    Map.get(@actions, action_id)
  end

  @doc """
  List actions by category.
  """
  @spec list_actions_by_category(String.t()) :: [map()]
  def list_actions_by_category(category) do
    @actions
    |> Map.values()
    |> Enum.filter(&(&1.category == category))
  end

  @doc """
  List actions filtered by enabled adapters.
  """
  @spec list_available_actions([String.t()]) :: [map()]
  def list_available_actions(enabled_adapters) do
    @actions
    |> Map.values()
    |> Enum.filter(fn action ->
      Enum.member?(enabled_adapters, action.adapter)
    end)
  end

  @doc """
  Get all unique categories.
  """
  @spec list_categories() :: [String.t()]
  def list_categories do
    @actions
    |> Map.values()
    |> Enum.map(& &1.category)
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc """
  Get action ID for a given action map (for serialization).
  """
  @spec get_action_id(map()) :: String.t() | nil
  def get_action_id(action_map) do
    @actions
    |> Enum.find(fn {_id, action} -> action == action_map end)
    |> case do
      {id, _} -> id
      _ -> nil
    end
  end
end
