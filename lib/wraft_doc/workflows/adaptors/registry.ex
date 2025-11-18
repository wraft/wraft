defmodule WraftDoc.Workflows.Adaptors.Registry do
  @moduledoc """
  Registry for available workflow adaptors.

  Maps adaptor names to their implementation modules.
  """

  @adaptors %{
    "condition" => WraftDoc.Workflows.Adaptors.ConditionAdaptor,
    "template" => WraftDoc.Workflows.Adaptors.TemplateAdaptor,
    "http" => WraftDoc.Workflows.Adaptors.HttpAdaptor,
    "email" => WraftDoc.Workflows.Adaptors.EmailAdaptor,
    "erpnext" => WraftDoc.Workflows.Adaptors.ErpnextAdaptor,
    "form" => WraftDoc.Workflows.Adaptors.FormAdaptor,
    "webhook_processor" => WraftDoc.Workflows.Adaptors.WebhookProcessorAdaptor
  }

  @doc """
  Get an adaptor module by name.

  ## Examples

      iex> WraftDoc.Workflows.Adaptors.Registry.get_adaptor("condition")
      WraftDoc.Workflows.Adaptors.ConditionAdaptor

      iex> WraftDoc.Workflows.Adaptors.Registry.get_adaptor("unknown")
      nil
  """
  @spec get_adaptor(String.t()) :: module() | nil
  def get_adaptor(name) when is_binary(name) do
    Map.get(@adaptors, String.downcase(name))
  end

  @doc """
  List all available adaptor names.

  ## Examples

      iex> WraftDoc.Workflows.Adaptors.Registry.list_adaptors()
      ["condition", "template"]
  """
  @spec list_adaptors() :: [String.t()]
  def list_adaptors do
    Map.keys(@adaptors)
  end

  @doc """
  Check if an adaptor exists.

  ## Examples

      iex> WraftDoc.Workflows.Adaptors.Registry.adaptor_exists?("condition")
      true

      iex> WraftDoc.Workflows.Adaptors.Registry.adaptor_exists?("unknown")
      false
  """
  @spec adaptor_exists?(String.t()) :: boolean()
  def adaptor_exists?(name) when is_binary(name) do
    Map.has_key?(@adaptors, String.downcase(name))
  end
end
