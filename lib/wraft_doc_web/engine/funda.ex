defmodule WraftDocWeb.Funda do
  require Logger
  def convert(file_path, format \\ "pdf")

  def convert(file_path, format) when is_nil(format), do: convert(file_path)

  def convert(file_path, format) do
    System.cmd("pandoc", [file_path, "-o", "/Users/sk/offer_letter.#{format}"])
  end

  def convert() do
    bodyx1 = "--template=/Users/sk/pandoc/pandoc-letter/template-letter.tex"

    System.cmd("pandoc", [
      "/Users/sk/pandoc/pandoc-letter/example/letter.md",
      "#{bodyx1}",
      "-o",
      "/Users/sk/pandoc/coverletter.pdf"
    ])
  end

  def template_render() do
    # get page

    # generate markdown

    # pass page variables to cover.tex, used inside template.tex, which is a templte for the pandoc document

    # generate pandoc command => output.pdf

    # 
    strt_time = Timex.now()
    Logger.info(strt_time)
    files = File.read!("index.txt") |> String.split("\n")

    template = "--template=template2.tex"
    from = "--from=markdown"
    to = "--to=latex"
    out = "--out=cl.pdf"
    engine = "--pdf-engine=xelatex"

    args = [from, to, template, out, engine]
    args = files |> Enum.reduce(args, fn x, acc -> acc ++ [x] end)
    System.cmd("pandoc", args)
    end_time = Timex.now()
    Logger.info(end_time)

    duration = Timex.diff(end_time, strt_time, :seconds)
    Logger.info(duration)
  end
end
