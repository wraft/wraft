defmodule WraftDoc.Documents.SignaturesTest do
  use WraftDoc.DataCase, async: true

  alias WraftDoc.CounterParties.CounterParty
  alias WraftDoc.Documents.Signatures

  # These guard the certificate-generation injection fix: counterparty-controlled
  # fields (name/email/device/ip -- `device` is the raw User-Agent header) are
  # emitted into the Typst certificate template as `"$it.field$"` string literals.
  # Without escaping, a `"`-bearing value breaks out of the literal and, with the
  # certificate's Typst `--root`, could read arbitrary files into the PDF.
  describe "prepare_markdown/2 escapes counterparty fields for the Typst string context" do
    test "escapes double quotes so a crafted value cannot break out of the string literal" do
      counterparty = %CounterParty{
        id: "8ce37632-0000-0000-0000-000000000001",
        name: "Jane \"JD\" Doe",
        email: "jane@example.com",
        # The classic file-read injection payload.
        device: "x\" + read(\"/etc/passwd\") + \"y",
        signature_ip: "10.0.0.1",
        signature_date: nil,
        signature_image: nil
      }

      yaml = Signatures.prepare_markdown("/tmp/test-instance", [counterparty])

      # Values are YAML single-quoted scalars whose contents are Typst-escaped.
      assert yaml =~ ~S|name: 'Jane \"JD\" Doe'|
      assert yaml =~ ~S|device: 'x\" + read(\"/etc/passwd\") + \"y'|
      # The unescaped breakout form must NOT appear.
      refute yaml =~ ~S|device: 'x" + read|
    end

    test "strips control characters and newlines (prevents YAML/markup corruption)" do
      counterparty = %CounterParty{
        id: "x",
        name: "Line1\nLine2\tTab",
        email: "a@b.com",
        signature_date: nil,
        signature_image: nil
      }

      yaml = Signatures.prepare_markdown("/tmp/test-instance", [counterparty])

      refute yaml =~ "Line1\nLine2"
      assert yaml =~ "Line1 Line2 Tab"
    end

    test "emits an empty (never absolute) signature_image when none is present" do
      counterparty = %CounterParty{
        id: "x",
        name: "A",
        email: "a@b.com",
        signature_date: nil,
        signature_image: nil
      }

      yaml = Signatures.prepare_markdown("/tmp/test-instance", [counterparty])

      assert yaml =~ "signature_image: ''"
    end
  end
end
