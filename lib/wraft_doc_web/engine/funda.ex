defmodule WraftDocWeb.Funda do
  @moduledoc """
  Safe Pandoc wrapper used by the doc creation engine.

  **Important**: we always pass `"--"` before user-controlled paths to prevent
  option-injection (e.g. an input path like `"--lua-filter=..."`).
  """

  require Logger

  @default_timeout_ms 60_000
  @default_max_input_bytes 25 * 1024 * 1024
  @default_max_output_bytes 2 * 1024 * 1024

  # Optional allowlists for additional security (best used in production):
  # - `:pandoc_allowed_input_dirs` restricts which directories inputs may be read from
  # - `:pandoc_allowed_output_dirs` restricts where outputs may be written
  #
  # These can also be passed per-call via opts: `allowed_input_dirs:` / `allowed_output_dirs:`.
  @default_allowed_input_dirs Application.compile_env(:wraft_doc, :pandoc_allowed_input_dirs, [])
  @default_allowed_output_dirs Application.compile_env(
                                 :wraft_doc,
                                 :pandoc_allowed_output_dirs,
                                 []
                               )

  # 1. Check if a PANDOC_PATH environment variable is set
  # 2. Use System.find_executable to search in PATH
  # 3. Use common Docker installation paths as fallbacks
  @pandoc_executable System.get_env("PANDOC_PATH") ||
                       System.find_executable("pandoc") ||
                       "/usr/bin/pandoc"

  @allowed_output_formats ~w(
    pdf docx html markdown md txt latex tex
  )

  @doc """
  Convert a document with Pandoc.

  Returns `{:ok, output_path}` on success.

  ## Options
  - `:output_dir` - directory to write output to (default: system temp dir)
  - `:output_path` - explicit output file path (overrides `:output_dir`)
  - `:timeout_ms` - Pandoc execution timeout (default: #{@default_timeout_ms})
  - `:max_input_bytes` - max allowed input file size (default: #{@default_max_input_bytes})
  - `:max_output_bytes` - max bytes to capture from Pandoc stdout/stderr (default: #{@default_max_output_bytes})
  - `:pdf_engine` - e.g. `"xelatex"` (optional; only applied for pdf output)
  - `:template` - path to a Pandoc template file (optional)
  """
  @spec convert(String.t(), String.t() | nil, keyword()) ::
          {:ok, String.t()} | {:error, term()}
  def convert(file_path, format \\ "pdf", opts \\ [])

  def convert(file_path, format, opts) when is_nil(format), do: convert(file_path, "pdf", opts)

  def convert(file_path, format, opts) when is_binary(file_path) do
    with {:ok, pandoc_path} <- pandoc_executable(),
         {:ok, format} <- normalize_format(format),
         :ok <- validate_input_file(file_path, opts),
         {:ok, output_path} <- build_output_path(file_path, format, opts),
         {:ok, args} <- build_args(file_path, output_path, format, opts),
         {:ok, _pandoc_output} <- run_pandoc(pandoc_path, args, opts) do
      {:ok, output_path}
    end
  end

  def convert(_file_path, _format, _opts), do: {:error, :invalid_input}

  @doc """
  Deprecated demo function (kept only for backwards compatibility).
  """
  @deprecated "Use convert/3 with explicit input/output paths"
  def convert, do: {:error, :deprecated}

  def template_render do
    # Deprecated helper from early experiments. Keep the entrypoint but make it safe:
    # - no hardcoded paths
    # - prevent option injection by using `--`
    # - enforce timeouts and bounded output
    start = System.monotonic_time()

    res =
      with {:ok, pandoc_path} <- pandoc_executable(),
           {:ok, files} <- read_index_file("index.txt"),
           {:ok, output_path} <- build_output_path("cl", "pdf", []),
           {:ok, args} <-
             build_multi_input_args(files, output_path,
               from: "markdown",
               to: "latex",
               template: "template2.tex",
               pdf_engine: "xelatex"
             ),
           {:ok, _out} <- run_pandoc(pandoc_path, args, timeout_ms: @default_timeout_ms) do
        {:ok, output_path}
      end

    duration_ms =
      System.monotonic_time()
      |> Kernel.-(start)
      |> System.convert_time_unit(:native, :millisecond)

    Logger.info("pandoc template_render duration_ms=#{duration_ms}")
    res
  end

  defp pandoc_executable do
    case @pandoc_executable do
      nil -> {:error, :pandoc_not_found}
      path -> {:ok, path}
    end
  end

  defp normalize_format(format) when is_binary(format) do
    normalized = format |> String.trim() |> String.downcase()

    if normalized in @allowed_output_formats do
      {:ok, normalized}
    else
      {:error, {:invalid_format, format}}
    end
  end

  defp normalize_format(_), do: {:error, {:invalid_format, :non_string}}

  defp validate_input_file(path, opts) do
    max_input_bytes = Keyword.get(opts, :max_input_bytes, @default_max_input_bytes)
    expanded = Path.expand(path)
    allowed_input_dirs = Keyword.get(opts, :allowed_input_dirs, @default_allowed_input_dirs)

    with true <- File.exists?(expanded) or {:error, :input_not_found},
         :ok <- validate_path_allowed(expanded, allowed_input_dirs, :input),
         {:ok, %File.Stat{type: :regular, size: size}} <- File.stat(expanded),
         true <- size <= max_input_bytes or {:error, {:input_too_large, size, max_input_bytes}} do
      :ok
    else
      {:ok, %File.Stat{type: other}} -> {:error, {:invalid_input_type, other}}
      {:error, reason} -> {:error, reason}
      other -> other
    end
  end

  defp build_output_path(file_path, format, opts) do
    case Keyword.get(opts, :output_path) do
      out when is_binary(out) ->
        out_expanded = Path.expand(out)

        allowed_output_dirs =
          Keyword.get(opts, :allowed_output_dirs, @default_allowed_output_dirs)

        with :ok <- validate_path_allowed(out_expanded, allowed_output_dirs, :output),
             :ok <- File.mkdir_p(Path.dirname(out_expanded)) do
          {:ok, out_expanded}
        end

      _ ->
        output_dir =
          Keyword.get(opts, :output_dir) ||
            Application.get_env(:wraft_doc, :pandoc_output_dir) ||
            System.tmp_dir!()

        output_dir = Path.expand(output_dir)

        allowed_output_dirs =
          Keyword.get(opts, :allowed_output_dirs, @default_allowed_output_dirs)

        base =
          file_path
          |> Path.basename()
          |> Path.rootname()
          |> String.replace(~r/[^a-zA-Z0-9._-]/, "_")

        rand = Base.url_encode64(:crypto.strong_rand_bytes(6), padding: false)
        out_path = Path.join(output_dir, "#{base}-#{rand}.#{format}")

        with :ok <- validate_path_allowed(output_dir, allowed_output_dirs, :output_dir),
             :ok <- File.mkdir_p(output_dir) do
          {:ok, out_path}
        end
    end
  end

  defp build_args(input_path, output_path, format, opts) do
    template =
      case Keyword.get(opts, :template) do
        nil ->
          []

        t when is_binary(t) ->
          if File.exists?(t) do
            ["--template=#{t}"]
          else
            return_error({:template_not_found, t})
          end

        _ ->
          return_error({:invalid_template, :non_string})
      end

    pdf_engine =
      case {format, Keyword.get(opts, :pdf_engine)} do
        {"pdf", e} when is_binary(e) ->
          trimmed = String.trim(e)
          if trimmed == "", do: [], else: ["--pdf-engine=#{trimmed}"]

        _ ->
          []
      end

    args =
      []
      |> Kernel.++(template)
      |> Kernel.++(pdf_engine)
      |> Kernel.++(["--output", output_path, "--", input_path])

    {:ok, args}
  catch
    {:return_error, err} -> {:error, err}
  end

  defp build_multi_input_args(files, output_path, opts) when is_list(files) do
    from =
      case Keyword.get(opts, :from) do
        nil -> []
        v -> ["--from=#{v}"]
      end

    to =
      case Keyword.get(opts, :to) do
        nil -> []
        v -> ["--to=#{v}"]
      end

    template =
      case Keyword.get(opts, :template) do
        nil -> []
        v -> ["--template=#{v}"]
      end

    pdf_engine =
      case Keyword.get(opts, :pdf_engine) do
        nil -> []
        v -> ["--pdf-engine=#{v}"]
      end

    safe_files =
      files
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&Path.expand/1)

    with :ok <- validate_multi_input_files(safe_files) do
      {:ok,
       from ++ to ++ template ++ ["--output", output_path] ++ pdf_engine ++ ["--"] ++ safe_files}
    end
  end

  defp validate_multi_input_files(files) when is_list(files) do
    Enum.reduce_while(files, :ok, fn p, _acc ->
      cond do
        String.starts_with?(Path.basename(p), "-") ->
          {:halt, {:error, {:invalid_input_path, p}}}

        not File.exists?(p) ->
          {:halt, {:error, {:input_not_found, p}}}

        true ->
          {:cont, :ok}
      end
    end)
  end

  defp read_index_file(path) do
    expanded = Path.expand(path)

    with true <- File.exists?(expanded) or {:error, :index_not_found},
         {:ok, content} <- File.read(expanded) do
      {:ok, String.split(content, "\n", trim: true)}
    end
  end

  defp run_pandoc(pandoc_path, args, opts) do
    timeout_ms = Keyword.get(opts, :timeout_ms, @default_timeout_ms)
    max_output_bytes = Keyword.get(opts, :max_output_bytes, @default_max_output_bytes)

    port =
      Port.open({:spawn_executable, pandoc_path}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        args: args
      ])

    receive_port_output(port, [], 0, max_output_bytes, timeout_ms)
  end

  defp receive_port_output(port, chunks, bytes, max_bytes, timeout_ms) do
    receive do
      {^port, {:data, data}} ->
        new_bytes = bytes + byte_size(data)

        if new_bytes > max_bytes do
          Port.close(port)
          {:error, {:pandoc_output_too_large, new_bytes, max_bytes}}
        else
          receive_port_output(port, [data | chunks], new_bytes, max_bytes, timeout_ms)
        end

      {^port, {:exit_status, 0}} ->
        {:ok, chunks |> Enum.reverse() |> IO.iodata_to_binary()}

      {^port, {:exit_status, status}} ->
        {:error, {:pandoc_failed, status, chunks |> Enum.reverse() |> IO.iodata_to_binary()}}
    after
      timeout_ms ->
        Port.close(port)
        {:error, :pandoc_timeout}
    end
  end

  defp return_error(err), do: throw({:return_error, err})

  # If allowlist is empty => allow all (non-breaking default).
  defp validate_path_allowed(_expanded_path, allowed_dirs, _kind) when allowed_dirs in [nil, []],
    do: :ok

  defp validate_path_allowed(expanded_path, allowed_dirs, kind) when is_list(allowed_dirs) do
    expanded_allowed =
      allowed_dirs
      |> Enum.map(&Path.expand/1)
      |> Enum.map(&String.trim_trailing(&1, "/"))

    normalized = String.trim_trailing(expanded_path, "/")

    allowed? =
      Enum.any?(expanded_allowed, fn dir ->
        normalized == dir or String.starts_with?(normalized, dir <> "/")
      end)

    if allowed?, do: :ok, else: {:error, {:path_not_allowed, kind, expanded_path}}
  end

  defp validate_path_allowed(_expanded_path, other, kind),
    do: {:error, {:invalid_allowlist, kind, other}}
end
