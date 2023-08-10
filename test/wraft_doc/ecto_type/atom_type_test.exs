defmodule WraftDoc.EctoType.AtomTypeTest do
  @moduledoc """
       Tests for ecto type specified to store atoms
  """
  use WraftDoc.ModelCase
  alias WraftDoc.EctoType.AtomType

  describe "cast/1" do
    test "casts a binary to an atom" do
      assert AtomType.cast("hello") == {:ok, :hello}
    end

    test "casts an atom to itself" do
      assert AtomType.cast(:hello) == {:ok, :hello}
    end

    test "fails to cast nil type" do
      assert AtomType.cast(nil) == :error
    end

    test "fails to cast other data types" do
      assert AtomType.cast(42) == :error
    end
  end

  describe "load/1" do
    test "loads a binary to an atom" do
      assert AtomType.load("greetings") == {:ok, :greetings}
    end

    test "fails to load other data types" do
      assert AtomType.load(42) == :error
      assert AtomType.load(:some_atom) == :error
      assert AtomType.load(nil) == :error
    end
  end

  describe "dump/1" do
    test "dumps an atom to a binary" do
      assert AtomType.dump(:example) == {:ok, "example"}
    end

    test "fails to dump other data types" do
      assert AtomType.dump(42) == :error
      assert AtomType.dump("some_string") == :error
      assert AtomType.dump(nil) == :error
    end
  end

  test "type/0" do
    assert AtomType.type() == :string
  end
end
