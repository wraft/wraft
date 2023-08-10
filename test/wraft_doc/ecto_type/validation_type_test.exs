defmodule WraftDoc.EctoType.ValidationTypeTest do
  @moduledoc """
  Tests for ecto type specified to store validtions
  """
  use WraftDoc.ModelCase
  alias WraftDoc.EctoType.ValidationType

  @regex_binary "/([A-Z])\w+}"
  @regex_compiled ~r/\/([A-Z])w+}/

  describe "cast/1 for validation rule :required" do
    test "casts a boolean value" do
      input = %{"rule" => "required", "value" => true}
      assert {:ok, input} == ValidationType.cast(input)
    end

    test "fails to cast when value is not a boolean" do
      input = %{"rule" => "required", "value" => "invalid_value"}
      assert :error == ValidationType.cast(input)
    end
  end

  describe "cast/1 for validation rule :min_length" do
    test "casts a valid min_length value" do
      input = %{"rule" => "min_length", "value" => 5}
      assert {:ok, input} == ValidationType.cast(input)
    end

    test "fails to cast when value is not an integer" do
      input = %{"rule" => "min_length", "value" => "invalid_value"}
      assert :error == ValidationType.cast(input)
    end

    test "fails to cast when value is not greater than 0" do
      input = %{"rule" => "min_length", "value" => 0}
      assert :error == ValidationType.cast(input)
    end
  end

  describe "cast/1 for validation rule :max_length" do
    test "casts a valid max_length value" do
      input = %{"rule" => "max_length", "value" => 10}
      assert {:ok, input} == ValidationType.cast(input)
    end

    test "fails to cast when value is not an integer" do
      input = %{"rule" => "max_length", "value" => "invalid_value"}
      assert :error == ValidationType.cast(input)
    end

    test "fails to cast when value is not greater than 0" do
      input = %{"rule" => "max_length", "value" => 0}
      assert :error == ValidationType.cast(input)
    end
  end

  describe "cast/1 for validation rule :regex" do
    test "casts a valid regex value" do
      input = %{"rule" => "regex", "value" => @regex_binary}
      assert {:ok, %{"rule" => "regex", "value" => @regex_compiled}} == ValidationType.cast(input)
    end

    test "fails to cast when value is invalid regex string" do
      input = %{"rule" => "regex", "value" => "*foo"}
      assert :error == ValidationType.cast(input)
    end

    test "fails to cast when value is not a binary" do
      input = %{"rule" => "regex", "value" => 42}
      assert :error == ValidationType.cast(input)
    end
  end

  describe "cast/1 for validation rule :email" do
    test "casts successfully" do
      input = %{"rule" => "email"}
      assert {:ok, input} == ValidationType.cast(input)
    end
  end

  describe "cast/1 for validation rule :min_value" do
    test "casts a valid min_value" do
      input = %{"rule" => "min_value", "value" => 10}
      assert {:ok, input} == ValidationType.cast(input)
    end

    test "fails to cast when value is not an integer" do
      input = %{"rule" => "min_value", "value" => "invalid_value"}
      assert :error == ValidationType.cast(input)
    end
  end

  describe "cast/1 for validation rule :max_value" do
    test "casts a valid max_value" do
      input = %{"rule" => "max_value", "value" => 100}
      assert {:ok, input} == ValidationType.cast(input)
    end

    test "fails to cast when value is not an integer" do
      input = %{"rule" => "max_value", "value" => "invalid_value"}
      assert :error == ValidationType.cast(input)
    end
  end

  describe "cast/1 for validation rule :url" do
    test "casts successfully" do
      input = %{"rule" => "url"}
      assert {:ok, input} == ValidationType.cast(input)
    end
  end

  describe "cast/1 for validation rule :phone_number" do
    test "casts successfully" do
      input = %{"rule" => "phone_number"}
      assert {:ok, input} == ValidationType.cast(input)
    end
  end

  describe "cast/1 for validation rule :range" do
    test "casts a valid range" do
      input = %{"rule" => "range", "value" => [10, 20]}
      assert {:ok, input} == ValidationType.cast(input)
    end

    test "fails to cast when lower_limit is not an integer" do
      input = %{"rule" => "range", "value" => ["invalid", 20]}
      assert :error == ValidationType.cast(input)
    end

    test "fails to cast when upper_limit is not an integer" do
      input = %{"rule" => "range", "value" => [10, :invalid]}
      assert :error == ValidationType.cast(input)
    end

    test "fails to cast when lower_limit is greater than or equal to upper_limit" do
      input = %{"rule" => "range", "value" => [20, 10]}
      assert :error == ValidationType.cast(input)
    end
  end

  describe "cast/1 for validation rule :file_size" do
    test "casts a valid file size" do
      input = %{"rule" => "file_size", "value" => 20}
      assert {:ok, input} == ValidationType.cast(input)
    end

    test "fails to cast when value is less than 0" do
      input = %{"rule" => "file_size", "value" => -42}
      assert :error == ValidationType.cast(input)
    end

    test "fails to cast when value is binary" do
      input = %{"rule" => "file_size", "value" => "invalid_size"}
      assert :error == ValidationType.cast(input)
    end
  end

  describe "cast/1 for validation rule :decimal" do
    test "casts successfully" do
      input = %{"rule" => "decimal"}
      assert {:ok, input} == ValidationType.cast(input)
    end
  end

  describe "cast/1 for validation rule :options" do
    test "casts valid options" do
      input = %{"rule" => "options", "value" => ["male", "female", "other"]}
      assert {:ok, input} == ValidationType.cast(input)
    end

    test "fails to cast when value is not a list" do
      input = %{"rule" => "file_size", "value" => "male,female,other"}
      assert :error == ValidationType.cast(input)
    end
  end

  describe "cast/1 for validation rule :date" do
    test "casts successfully" do
      input = %{"rule" => "date"}
      assert {:ok, input} == ValidationType.cast(input)
    end
  end

  describe "cast/1 for validation rule :date_max" do
    test "casts successfully with valid ISO 8601 date" do
      input = %{"rule" => "date_max", "value" => "2020-01-01"}

      assert {:ok, %{"rule" => "date_max", "value" => ~D[2020-01-01]}} ==
               ValidationType.cast(input)
    end

    test "fails to cast when value is not a valid ISO 8601 date" do
      input = %{"rule" => "date_max", "value" => "2020/01/01"}

      assert :error == ValidationType.cast(input)
    end

    test "fails to cast if value is not binary" do
      input = %{"rule" => "date_max", "value" => ~D[2020-01-01]}
      assert :error == ValidationType.cast(input)
    end
  end

  describe "cast/1 for validation rule :date_min" do
    test "casts successfully with valid ISO 8601 date" do
      input = %{"rule" => "date_min", "value" => "2020-01-01"}

      assert {:ok, %{"rule" => "date_min", "value" => ~D[2020-01-01]}} ==
               ValidationType.cast(input)
    end

    test "fails to cast when value is not a valid ISO 8601 date" do
      input = %{"rule" => "date_min", "value" => "2020/01/01"}

      assert :error == ValidationType.cast(input)
    end

    test "fails to cast if value is not binary" do
      input = %{"rule" => "date_max", "value" => ~D[2020-01-01]}
      assert :error == ValidationType.cast(input)
    end
  end

  describe "cast/1 for validation rule :date_range" do
    test "casts successfully with valid ISO 8601 dates" do
      input = %{"rule" => "date_range", "value" => ["2020-01-01", "2020-01-02"]}

      assert {:ok, %{"rule" => "date_range", "value" => [~D[2020-01-01], ~D[2020-01-02]]}} ==
               ValidationType.cast(input)
    end

    test "casts successfully if both limits are same" do
      input = %{"rule" => "date_range", "value" => ["2020-01-01", "2020-01-01"]}

      assert {:ok, %{"rule" => "date_range", "value" => [~D[2020-01-01], ~D[2020-01-01]]}} ==
               ValidationType.cast(input)
    end

    test "fails to cast when either of the date is not a valid ISO 8601 date" do
      input = %{"rule" => "date_min", "value" => ["2020-01-01", "2020/01/02"]}
      assert :error == ValidationType.cast(input)

      input = %{"rule" => "date_min", "value" => ["2020/01/01", "2020-01-02"]}
      assert :error == ValidationType.cast(input)
    end

    test "fails to cast when either of the date is not binary" do
      input = %{"rule" => "date_min", "value" => ["2020-01-01", ~D[2020-01-02]]}
      assert :error == ValidationType.cast(input)

      input = %{"rule" => "date_min", "value" => [~D[2020-01-01], "2020-01-02"]}
      assert :error == ValidationType.cast(input)
    end

    test "fails to cast if lower limit is not older than upper limit" do
      input = %{"rule" => "date_range", "value" => ["2020-01-02", "2020-01-01"]}
      assert :error == ValidationType.cast(input)
    end
  end

  describe "load/1" do
    test "loads a valid map" do
      input = %{"rule" => "some_rule", "value" => "some_value"}
      assert {:ok, input} == ValidationType.load(input)
    end

    test "compiles regex" do
      input = %{"rule" => "regex", "value" => @regex_binary}
      assert {:ok, %{"rule" => "regex", "value" => @regex_compiled}} == ValidationType.load(input)
    end

    test "loads date to %Date{} struct" do
      input = %{"rule" => "date_max", "value" => "2020-01-01"}

      assert {:ok, %{"rule" => "date_max", "value" => ~D[2020-01-01]}} ==
               ValidationType.load(input)

      input = %{"rule" => "date_min", "value" => "2020-01-01"}

      assert {:ok, %{"rule" => "date_min", "value" => ~D[2020-01-01]}} ==
               ValidationType.load(input)

      input = %{"rule" => "date_range", "value" => ["2020-01-01", "2020-01-02"]}

      assert {:ok, %{"rule" => "date_range", "value" => [~D[2020-01-01], ~D[2020-01-02]]}} ==
               ValidationType.load(input)
    end

    test "fails to load when argument is not a map" do
      input = "not a map"
      assert :error == ValidationType.load(input)
    end
  end

  describe "dump/1" do
    test "dumps a valid map" do
      input = %{"rule" => "some_rule", "value" => "some_value"}
      assert {:ok, input} == ValidationType.dump(input)
    end

    test "fails to dump when argument is not a map" do
      assert :error == ValidationType.dump("not a map")
    end
  end

  test "fails to cast when rule is not valid" do
    input = %{"rule" => "invalid_rule", "value" => 3.14}
    assert :error == ValidationType.cast(input)
  end

  test "type/0" do
    assert :map == ValidationType.type()
  end
end
