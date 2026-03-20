defmodule AshZoiTest.SimpleStruct do
  defstruct [:name, :value]
end

defmodule AshZoiTest do
  use ExUnit.Case
  doctest AshZoi

  # Test Ash resources for testing resource conversion
  defmodule TestAddress do
    @moduledoc false
    use Ash.Resource, data_layer: :embedded

    attributes do
      attribute(:street, :string, public?: true, allow_nil?: false)
      attribute(:city, :string, public?: true, allow_nil?: false)
      attribute(:zip, :string, public?: true, constraints: [max_length: 10])
    end
  end

  defmodule TestUser do
    @moduledoc false
    use Ash.Resource, data_layer: :embedded

    attributes do
      uuid_v7_primary_key(:id, public?: false)
      attribute(:name, :string, public?: true, allow_nil?: false, constraints: [min_length: 1])
      attribute(:email, :string, public?: true, allow_nil?: false)
      attribute(:age, :integer, public?: true, constraints: [min: 0, max: 150])
      attribute(:bio, :string, public?: true)
      attribute(:role, :atom, public?: true, constraints: [one_of: [:admin, :user, :moderator]])
      attribute(:address, TestAddress, public?: true)
      attribute(:tags, {:array, :string}, public?: true)
      attribute(:internal_field, :string, public?: false)
    end
  end

  # Test TypedStruct for NewType testing
  defmodule TestProfile do
    @moduledoc false
    use Ash.TypedStruct

    typed_struct do
      field(:username, :string, allow_nil?: false)
      field(:age, :integer, constraints: [min: 0, max: 150])
      field(:bio, :string)
    end
  end

  # Test NewType: String with regex constraint
  defmodule TestSSN do
    @moduledoc false
    use Ash.Type.NewType,
      subtype_of: :string,
      constraints: [match: ~r/^\d{3}-\d{2}-\d{4}$/]
  end

  # Test NewType: Integer with min constraint
  defmodule TestPositiveInteger do
    @moduledoc false
    use Ash.Type.NewType, subtype_of: :integer, constraints: [min: 0]
  end

  # Test NewType wrapping a union (the typical Ash pattern)
  defmodule TestContent do
    @moduledoc false
    use Ash.Type.NewType,
      subtype_of: :union,
      constraints: [
        types: [
          text: [type: :string, constraints: [max_length: 1000]],
          number: [type: :integer, constraints: [min: 0]]
        ]
      ]
  end

  # Test resource using a union NewType as an attribute
  defmodule TestPost do
    @moduledoc false
    use Ash.Resource, data_layer: :embedded

    attributes do
      attribute(:title, :string, public?: true, allow_nil?: false)
      attribute(:content, AshZoiTest.TestContent, public?: true, allow_nil?: false)
    end
  end

  describe "basic type conversion (no constraints)" do
    test "converts :string to Zoi string schema" do
      schema = AshZoi.to_schema(:string)

      assert {:ok, "hello"} = Zoi.parse(schema, "hello")
      assert {:error, errors} = Zoi.parse(schema, 123)
      assert [%Zoi.Error{code: :invalid_type}] = errors
    end

    test "converts :integer to Zoi integer schema" do
      schema = AshZoi.to_schema(:integer)

      assert {:ok, 42} = Zoi.parse(schema, 42)
      assert {:error, errors} = Zoi.parse(schema, "42")
      assert [%Zoi.Error{code: :invalid_type}] = errors
    end

    test "converts :float to Zoi float schema" do
      schema = AshZoi.to_schema(:float)

      assert {:ok, 3.14} = Zoi.parse(schema, 3.14)
      assert {:error, errors} = Zoi.parse(schema, "3.14")
      assert [%Zoi.Error{code: :invalid_type}] = errors
    end

    test "converts :boolean to Zoi boolean schema" do
      schema = AshZoi.to_schema(:boolean)

      assert {:ok, true} = Zoi.parse(schema, true)
      assert {:ok, false} = Zoi.parse(schema, false)
      assert {:error, errors} = Zoi.parse(schema, "true")
      assert [%Zoi.Error{code: :invalid_type}] = errors
    end

    test "converts :atom to Zoi atom schema" do
      schema = AshZoi.to_schema(:atom)

      assert {:ok, :hello} = Zoi.parse(schema, :hello)
      assert {:ok, :world} = Zoi.parse(schema, :world)
    end

    test "converts :date to Zoi date schema" do
      schema = AshZoi.to_schema(:date)
      date = ~D[2024-01-01]

      assert {:ok, ^date} = Zoi.parse(schema, date)
      assert {:error, _} = Zoi.parse(schema, "2024-01-01")
    end

    test "converts :time to Zoi time schema" do
      schema = AshZoi.to_schema(:time)
      time = ~T[12:30:45]

      assert {:ok, ^time} = Zoi.parse(schema, time)
      assert {:error, _} = Zoi.parse(schema, "12:30:45")
    end

    test "converts :datetime to Zoi datetime schema" do
      schema = AshZoi.to_schema(:datetime)
      datetime = DateTime.utc_now()

      assert {:ok, ^datetime} = Zoi.parse(schema, datetime)
      assert {:error, _} = Zoi.parse(schema, "2024-01-01T12:00:00Z")
    end

    test "converts :naive_datetime to Zoi naive_datetime schema" do
      schema = AshZoi.to_schema(:naive_datetime)
      naive_datetime = ~N[2024-01-01 12:30:45]

      assert {:ok, ^naive_datetime} = Zoi.parse(schema, naive_datetime)
      assert {:error, _} = Zoi.parse(schema, "2024-01-01 12:30:45")
    end

    test "converts :uuid to Zoi uuid schema" do
      schema = AshZoi.to_schema(:uuid)
      uuid = "550e8400-e29b-41d4-a716-446655440000"

      assert {:ok, ^uuid} = Zoi.parse(schema, uuid)
      assert {:error, _} = Zoi.parse(schema, "not-a-uuid")
    end

    test "converts :map to Zoi map schema" do
      schema = AshZoi.to_schema(:map)
      map = %{key: "value"}

      assert {:ok, ^map} = Zoi.parse(schema, map)
      assert {:error, _} = Zoi.parse(schema, "not a map")
    end

    test "converts :module to Zoi module schema" do
      schema = AshZoi.to_schema(:module)

      assert {:ok, String} = Zoi.parse(schema, String)
      assert {:error, _} = Zoi.parse(schema, "String")
    end

    test "converts unknown type to Zoi any schema" do
      schema = AshZoi.to_schema(:term)

      assert {:ok, "anything"} = Zoi.parse(schema, "anything")
      assert {:ok, 123} = Zoi.parse(schema, 123)
      assert {:ok, :atom} = Zoi.parse(schema, :atom)
    end
  end

  describe "constraint mapping" do
    test "maps string min_length constraint" do
      schema = AshZoi.to_schema(:string, min_length: 3)

      assert {:ok, "hello"} = Zoi.parse(schema, "hello")
      assert {:error, errors} = Zoi.parse(schema, "hi")
      assert [%Zoi.Error{code: :greater_than_or_equal_to}] = errors
    end

    test "maps string max_length constraint" do
      schema = AshZoi.to_schema(:string, max_length: 5)

      assert {:ok, "hello"} = Zoi.parse(schema, "hello")
      assert {:error, errors} = Zoi.parse(schema, "hello world")
      assert [%Zoi.Error{code: :less_than_or_equal_to}] = errors
    end

    test "maps string min_length and max_length constraints together" do
      schema = AshZoi.to_schema(:string, min_length: 3, max_length: 10)

      assert {:ok, "hello"} = Zoi.parse(schema, "hello")
      assert {:error, _} = Zoi.parse(schema, "hi")
      assert {:error, _} = Zoi.parse(schema, "hello world!")
    end

    test "maps string match constraint to regex" do
      schema = AshZoi.to_schema(:string, match: ~r/^[a-z]+$/)

      assert {:ok, "hello"} = Zoi.parse(schema, "hello")
      assert {:error, errors} = Zoi.parse(schema, "Hello123")
      assert [%Zoi.Error{code: :invalid_format}] = errors
    end

    test "maps integer min constraint to gte" do
      schema = AshZoi.to_schema(:integer, min: 0)

      assert {:ok, 0} = Zoi.parse(schema, 0)
      assert {:ok, 10} = Zoi.parse(schema, 10)
      assert {:error, errors} = Zoi.parse(schema, -1)
      assert [%Zoi.Error{code: :greater_than_or_equal_to}] = errors
    end

    test "maps integer max constraint to lte" do
      schema = AshZoi.to_schema(:integer, max: 100)

      assert {:ok, 100} = Zoi.parse(schema, 100)
      assert {:ok, 50} = Zoi.parse(schema, 50)
      assert {:error, errors} = Zoi.parse(schema, 101)
      assert [%Zoi.Error{code: :less_than_or_equal_to}] = errors
    end

    test "maps integer min and max constraints together" do
      schema = AshZoi.to_schema(:integer, min: 0, max: 100)

      assert {:ok, 50} = Zoi.parse(schema, 50)
      assert {:error, _} = Zoi.parse(schema, -1)
      assert {:error, _} = Zoi.parse(schema, 101)
    end

    test "maps float min and max constraints" do
      schema = AshZoi.to_schema(:float, min: 0.0, max: 1.0)

      assert {:ok, 0.5} = Zoi.parse(schema, 0.5)
      assert {:ok, result} = Zoi.parse(schema, 0.0)
      assert result == 0.0
      assert {:ok, 1.0} = Zoi.parse(schema, 1.0)
      assert {:error, _} = Zoi.parse(schema, -0.1)
      assert {:error, _} = Zoi.parse(schema, 1.1)
    end

    test "maps float greater_than constraint to gt" do
      schema = AshZoi.to_schema(:float, greater_than: 0.0)

      assert {:ok, 0.1} = Zoi.parse(schema, 0.1)
      assert {:error, errors} = Zoi.parse(schema, 0.0)
      assert [%Zoi.Error{code: :greater_than}] = errors
    end

    test "maps float less_than constraint to lt" do
      schema = AshZoi.to_schema(:float, less_than: 1.0)

      assert {:ok, 0.9} = Zoi.parse(schema, 0.9)
      assert {:error, errors} = Zoi.parse(schema, 1.0)
      assert [%Zoi.Error{code: :less_than}] = errors
    end

    test "maps float greater_than and less_than constraints (exclusive bounds)" do
      schema = AshZoi.to_schema(:float, greater_than: 0.0, less_than: 1.0)

      assert {:ok, 0.5} = Zoi.parse(schema, 0.5)
      assert {:error, _} = Zoi.parse(schema, 0.0)
      assert {:error, _} = Zoi.parse(schema, 1.0)
    end

    test "maps atom one_of constraint to enum" do
      schema = AshZoi.to_schema(:atom, one_of: [:red, :green, :blue])

      assert {:ok, :red} = Zoi.parse(schema, :red)
      assert {:ok, :green} = Zoi.parse(schema, :green)
      assert {:ok, :blue} = Zoi.parse(schema, :blue)
      assert {:error, errors} = Zoi.parse(schema, :yellow)
      assert [%Zoi.Error{code: :invalid_enum_value}] = errors
    end

    test "maps decimal min and max constraints" do
      schema = AshZoi.to_schema(:decimal, min: 0, max: 100)

      assert {:ok, result} = Zoi.parse(schema, Decimal.new("50"))
      assert Decimal.equal?(result, Decimal.new("50"))

      assert {:error, _} = Zoi.parse(schema, Decimal.new("-1"))
      assert {:error, _} = Zoi.parse(schema, Decimal.new("101"))
    end

    test "maps decimal greater_than and less_than constraints" do
      schema = AshZoi.to_schema(:decimal, greater_than: 0, less_than: 100)

      assert {:ok, result} = Zoi.parse(schema, Decimal.new("50"))
      assert Decimal.equal?(result, Decimal.new("50"))

      assert {:error, errors} = Zoi.parse(schema, Decimal.new("0"))
      assert [%Zoi.Error{code: :greater_than}] = errors

      assert {:error, errors} = Zoi.parse(schema, Decimal.new("100"))
      assert [%Zoi.Error{code: :less_than}] = errors
    end
  end

  describe "array types" do
    test "converts array of strings" do
      schema = AshZoi.to_schema({:array, :string})

      assert {:ok, ["hello", "world"]} = Zoi.parse(schema, ["hello", "world"])
      assert {:error, errors} = Zoi.parse(schema, ["hello", 123])
      assert [%Zoi.Error{code: :invalid_type, path: [1]}] = errors
    end

    test "converts array of integers" do
      schema = AshZoi.to_schema({:array, :integer})

      assert {:ok, [1, 2, 3]} = Zoi.parse(schema, [1, 2, 3])
      assert {:error, errors} = Zoi.parse(schema, [1, "2", 3])
      assert [%Zoi.Error{code: :invalid_type, path: [1]}] = errors
    end

    test "applies element constraints via items" do
      schema = AshZoi.to_schema({:array, :integer}, items: [min: 0, max: 100])

      assert {:ok, [0, 50, 100]} = Zoi.parse(schema, [0, 50, 100])
      assert {:error, errors} = Zoi.parse(schema, [0, 50, 101])
      assert [%Zoi.Error{code: :less_than_or_equal_to, path: [2]}] = errors
    end

    test "applies array-level min_length constraint" do
      schema = AshZoi.to_schema({:array, :string}, min_length: 1)

      assert {:ok, ["hello"]} = Zoi.parse(schema, ["hello"])
      assert {:error, errors} = Zoi.parse(schema, [])
      assert [%Zoi.Error{code: :greater_than_or_equal_to}] = errors
    end

    test "applies array-level max_length constraint" do
      schema = AshZoi.to_schema({:array, :string}, max_length: 2)

      assert {:ok, ["a", "b"]} = Zoi.parse(schema, ["a", "b"])
      assert {:error, errors} = Zoi.parse(schema, ["a", "b", "c"])
      assert [%Zoi.Error{code: :less_than_or_equal_to}] = errors
    end

    test "combines array-level and element-level constraints" do
      schema =
        AshZoi.to_schema({:array, :integer},
          min_length: 1,
          max_length: 5,
          items: [min: 0, max: 100]
        )

      assert {:ok, [0, 50, 100]} = Zoi.parse(schema, [0, 50, 100])
      assert {:error, _} = Zoi.parse(schema, [])
      assert {:error, _} = Zoi.parse(schema, [1, 2, 3, 4, 5, 6])
      assert {:error, _} = Zoi.parse(schema, [101])
    end

    test "handles nested arrays" do
      schema = AshZoi.to_schema({:array, {:array, :integer}})

      assert {:ok, [[1, 2], [3, 4]]} = Zoi.parse(schema, [[1, 2], [3, 4]])
      assert {:error, _} = Zoi.parse(schema, [[1, 2], ["3", 4]])
    end
  end

  describe "module name resolution" do
    test "resolves Ash.Type.String module name" do
      schema = AshZoi.to_schema(Ash.Type.String)

      assert {:ok, "hello"} = Zoi.parse(schema, "hello")
      assert {:error, _} = Zoi.parse(schema, 123)
    end

    test "resolves Ash.Type.Integer module name" do
      schema = AshZoi.to_schema(Ash.Type.Integer)

      assert {:ok, 42} = Zoi.parse(schema, 42)
      assert {:error, _} = Zoi.parse(schema, "42")
    end

    test "resolves Ash.Type.Boolean module name" do
      schema = AshZoi.to_schema(Ash.Type.Boolean)

      assert {:ok, true} = Zoi.parse(schema, true)
      assert {:error, _} = Zoi.parse(schema, "true")
    end

    test "applies constraints with module name" do
      schema = AshZoi.to_schema(Ash.Type.String, min_length: 3)

      assert {:ok, "hello"} = Zoi.parse(schema, "hello")
      assert {:error, _} = Zoi.parse(schema, "hi")
    end
  end

  describe "fallback types" do
    test "converts :term to Zoi any schema" do
      schema = AshZoi.to_schema(:term)

      assert {:ok, "string"} = Zoi.parse(schema, "string")
      assert {:ok, 123} = Zoi.parse(schema, 123)
      assert {:ok, :atom} = Zoi.parse(schema, :atom)
      assert {:ok, [1, 2, 3]} = Zoi.parse(schema, [1, 2, 3])
      assert {:ok, %{key: "value"}} = Zoi.parse(schema, %{key: "value"})
    end

    test "converts unknown custom type to Zoi any schema" do
      schema = AshZoi.to_schema(:unknown_custom_type)

      assert {:ok, "anything"} = Zoi.parse(schema, "anything")
    end
  end

  describe "map fields" do
    test "converts map with typed fields" do
      schema =
        AshZoi.to_schema(:map,
          fields: [
            name: [type: :string],
            age: [type: :integer]
          ]
        )

      valid_data = %{name: "Alice", age: 30}
      assert {:ok, ^valid_data} = Zoi.parse(schema, valid_data)

      invalid_data = %{name: "Alice", age: "thirty"}
      assert {:error, errors} = Zoi.parse(schema, invalid_data)
      assert [%Zoi.Error{code: :invalid_type, path: [:age]}] = errors
    end

    test "converts map with field constraints" do
      schema =
        AshZoi.to_schema(:map,
          fields: [
            name: [type: :string, constraints: [min_length: 2, max_length: 50]],
            age: [type: :integer, constraints: [min: 0, max: 150]]
          ]
        )

      valid_data = %{name: "Alice", age: 30}
      assert {:ok, ^valid_data} = Zoi.parse(schema, valid_data)

      assert {:error, _} = Zoi.parse(schema, %{name: "A", age: 30})
      assert {:error, _} = Zoi.parse(schema, %{name: "Alice", age: -1})
    end

    test "converts map with nullable fields" do
      schema =
        AshZoi.to_schema(:map,
          fields: [
            name: [type: :string],
            middle_name: [type: :string, allow_nil?: true],
            age: [type: :integer]
          ]
        )

      valid_data = %{name: "Alice", middle_name: nil, age: 30}
      assert {:ok, ^valid_data} = Zoi.parse(schema, valid_data)

      valid_data2 = %{name: "Alice", middle_name: "Marie", age: 30}
      assert {:ok, ^valid_data2} = Zoi.parse(schema, valid_data2)
    end

    test "converts map with nested types" do
      schema =
        AshZoi.to_schema(:map,
          fields: [
            name: [type: :string],
            tags: [type: {:array, :string}]
          ]
        )

      valid_data = %{name: "Alice", tags: ["admin", "user"]}
      assert {:ok, ^valid_data} = Zoi.parse(schema, valid_data)

      assert {:error, _} = Zoi.parse(schema, %{name: "Alice", tags: ["admin", 123]})
    end
  end

  describe "special Ash types" do
    test "converts Ash.Type.Binary to string" do
      schema = AshZoi.to_schema(Ash.Type.Binary)

      assert {:ok, "hello"} = Zoi.parse(schema, "hello")
      assert {:error, _} = Zoi.parse(schema, 123)
    end

    test "converts Ash.Type.TimeUsec to time" do
      schema = AshZoi.to_schema(Ash.Type.TimeUsec)
      time = ~T[12:30:45.123456]

      assert {:ok, ^time} = Zoi.parse(schema, time)
    end

    test "converts Ash.Type.UtcDatetime to datetime" do
      schema = AshZoi.to_schema(Ash.Type.UtcDatetime)
      datetime = DateTime.utc_now()

      assert {:ok, ^datetime} = Zoi.parse(schema, datetime)
    end

    test "converts Ash.Type.UtcDatetimeUsec to datetime" do
      schema = AshZoi.to_schema(Ash.Type.UtcDatetimeUsec)
      datetime = DateTime.utc_now()

      assert {:ok, ^datetime} = Zoi.parse(schema, datetime)
    end

    test "converts Ash.Type.UUIDv7 to uuid" do
      schema = AshZoi.to_schema(Ash.Type.UUIDv7)
      uuid = "550e8400-e29b-41d4-a716-446655440000"

      assert {:ok, ^uuid} = Zoi.parse(schema, uuid)
    end
  end

  describe "edge cases" do
    test "handles nil constraints gracefully" do
      schema = AshZoi.to_schema(:string, nil)
      assert {:ok, "hello"} = Zoi.parse(schema, "hello")
    end

    test "handles nil constraints for integer" do
      schema = AshZoi.to_schema(:integer, nil)
      assert {:ok, 42} = Zoi.parse(schema, 42)
    end

    test "handles nil constraints for float" do
      schema = AshZoi.to_schema(:float, nil)
      assert {:ok, 1.5} = Zoi.parse(schema, 1.5)
    end

    test "handles array with items: nil" do
      schema = AshZoi.to_schema({:array, :integer}, items: nil)
      assert {:ok, [1, 2, 3]} = Zoi.parse(schema, [1, 2, 3])
    end

    test "raises for invalid match constraint" do
      assert_raise ArgumentError, ~r/expected :match constraint to be a Regex/, fn ->
        AshZoi.to_schema(:string, match: "not a regex")
      end
    end

    test "raises for invalid one_of constraint" do
      assert_raise ArgumentError, ~r/expected :one_of constraint to be a list/, fn ->
        AshZoi.to_schema(:atom, one_of: :not_a_list)
      end
    end

    test "inapplicable constraints are silently ignored" do
      # min_length doesn't apply to integer, should not crash
      schema = AshZoi.to_schema(:integer, min_length: 3)
      assert {:ok, 42} = Zoi.parse(schema, 42)
    end

    test "handles empty constraints list" do
      schema = AshZoi.to_schema(:string, [])
      assert {:ok, "hello"} = Zoi.parse(schema, "hello")
    end
  end

  describe "Ash resource to schema" do
    test "converts a simple resource to a map schema" do
      schema = AshZoi.to_schema(TestAddress)

      assert {:ok, %{street: "123 Main St", city: "Springfield", zip: "12345"}} =
               Zoi.parse(schema, %{street: "123 Main St", city: "Springfield", zip: "12345"})
    end

    test "rejects invalid data for resource attributes" do
      schema = AshZoi.to_schema(TestAddress)
      # zip exceeds max_length of 10
      assert {:error, _} =
               Zoi.parse(schema, %{street: "123 Main", city: "Springfield", zip: "12345678901"})
    end

    test "handles allow_nil? correctly" do
      schema = AshZoi.to_schema(TestAddress)
      # street is allow_nil?: false, so nil should fail
      assert {:error, _} = Zoi.parse(schema, %{street: nil, city: "Springfield", zip: "12345"})
    end

    test "respects :only option for resource schemas" do
      schema = AshZoi.to_schema(TestUser, only: [:name, :email])

      assert {:ok, %{name: "Alice", email: "alice@example.com"}} =
               Zoi.parse(schema, %{name: "Alice", email: "alice@example.com"})
    end

    test "respects :except option for resource schemas" do
      schema = AshZoi.to_schema(TestUser, except: [:bio, :role, :address, :tags, :age])

      assert {:ok, %{name: "Alice", email: "alice@example.com"}} =
               Zoi.parse(schema, %{name: "Alice", email: "alice@example.com"})
    end

    test "excludes non-public attributes" do
      schema = AshZoi.to_schema(TestUser)
      # internal_field should not be in the schema since it's not public
      # The schema should work without it
      result =
        Zoi.parse(schema, %{
          name: "Alice",
          email: "alice@example.com",
          age: 30,
          bio: "Hello",
          role: :admin,
          address: %{street: "123 Main", city: "Springfield", zip: "12345"},
          tags: ["elixir", "ash"]
        })

      assert {:ok, _} = result
    end

    test "handles nested embedded resources" do
      schema = AshZoi.to_schema(TestUser)
      # Address validation should be applied to nested data
      result =
        Zoi.parse(schema, %{
          name: "Alice",
          email: "alice@example.com",
          age: 30,
          bio: nil,
          role: :user,
          address: %{street: "123 Main", city: "Springfield", zip: "12345"},
          tags: ["elixir"]
        })

      assert {:ok, _} = result
    end

    test "validates constraints from resource attributes" do
      schema = AshZoi.to_schema(TestUser)
      # age has min: 0, max: 150
      assert {:error, _} =
               Zoi.parse(schema, %{
                 name: "Alice",
                 email: "alice@example.com",
                 age: -1,
                 bio: nil,
                 role: :user,
                 address: %{street: "123 Main", city: "Springfield", zip: "12345"},
                 tags: []
               })
    end
  end

  describe "CiString type" do
    test "converts ci_string to string schema" do
      schema = AshZoi.to_schema(:ci_string)
      assert {:ok, "hello"} = Zoi.parse(schema, "hello")
      assert {:error, _} = Zoi.parse(schema, 42)
    end

    test "ci_string with constraints" do
      schema = AshZoi.to_schema(:ci_string, min_length: 3)
      assert {:ok, "hello"} = Zoi.parse(schema, "hello")
      assert {:error, _} = Zoi.parse(schema, "hi")
    end
  end

  describe "Ash.Type.Struct" do
    test "converts struct type with instance_of only" do
      schema = AshZoi.to_schema(:struct, instance_of: AshZoiTest.SimpleStruct)

      assert {:ok, %AshZoiTest.SimpleStruct{}} =
               Zoi.parse(schema, %AshZoiTest.SimpleStruct{name: "test", value: 42})

      assert {:error, _} = Zoi.parse(schema, %{name: "test", value: 42})
    end

    test "converts struct type with instance_of and fields" do
      schema =
        AshZoi.to_schema(:struct,
          instance_of: AshZoiTest.SimpleStruct,
          fields: [
            name: [type: :string, constraints: [min_length: 1]],
            value: [type: :integer, constraints: [min: 0]]
          ]
        )

      assert {:ok, _} = Zoi.parse(schema, %AshZoiTest.SimpleStruct{name: "test", value: 42})
      assert {:error, _} = Zoi.parse(schema, %AshZoiTest.SimpleStruct{name: "", value: 42})
    end

    test "converts struct type with instance_of pointing to Ash resource" do
      schema = AshZoi.to_schema(:struct, instance_of: AshZoiTest.TestAddress)
      assert {:ok, _} = Zoi.parse(schema, %{street: "123 Main", city: "Test", zip: "12345"})
    end

    test "converts struct type with fields only (no instance_of)" do
      schema =
        AshZoi.to_schema(:struct,
          fields: [
            name: [type: :string],
            count: [type: :integer]
          ]
        )

      assert {:ok, _} = Zoi.parse(schema, %{name: "test", count: 5})
      assert {:error, _} = Zoi.parse(schema, %{name: 42, count: 5})
    end

    test "converts struct type with no constraints" do
      schema = AshZoi.to_schema(:struct)
      # Should accept anything
      assert {:ok, _} = Zoi.parse(schema, "anything")
    end
  end

  describe "resource edge cases" do
    test "handles non-existent module gracefully" do
      # A random atom that's not a module should fall back to Zoi.any()
      schema = AshZoi.to_schema(:not_a_real_type_at_all)
      assert {:ok, _} = Zoi.parse(schema, "anything")
    end
  end

  describe "Ash TypedStruct" do
    test "converts typed struct to map schema with field validation" do
      schema = AshZoi.to_schema(AshZoiTest.TestProfile)
      # Should validate a map with the correct field types
      assert {:ok, _} = Zoi.parse(schema, %{username: "alice", age: 25, bio: "hello"})
    end

    test "enforces field constraints from typed struct" do
      schema = AshZoi.to_schema(AshZoiTest.TestProfile)
      # age has min: 0, max: 150
      assert {:error, _} = Zoi.parse(schema, %{username: "alice", age: -1, bio: "hello"})
      assert {:error, _} = Zoi.parse(schema, %{username: "alice", age: 151, bio: "hello"})
    end

    test "enforces allow_nil? from typed struct fields" do
      schema = AshZoi.to_schema(AshZoiTest.TestProfile)
      # username is allow_nil?: false
      assert {:error, _} = Zoi.parse(schema, %{username: nil, age: 25, bio: "hello"})
    end

    test "nullable fields accept nil" do
      schema = AshZoi.to_schema(AshZoiTest.TestProfile)
      # bio is allow_nil?: true (default)
      assert {:ok, _} = Zoi.parse(schema, %{username: "alice", age: 25, bio: nil})
    end

    test "validates correct values" do
      schema = AshZoi.to_schema(AshZoiTest.TestProfile)

      assert {:ok, %{username: "alice", age: 25, bio: "hello"}} =
               Zoi.parse(schema, %{username: "alice", age: 25, bio: "hello"})
    end
  end

  describe "Ash NewType" do
    test "converts NewType subtype_of string with constraints" do
      schema = AshZoi.to_schema(AshZoiTest.TestSSN)
      assert {:ok, "123-45-6789"} = Zoi.parse(schema, "123-45-6789")
      assert {:error, _} = Zoi.parse(schema, "not-an-ssn")
    end

    test "converts NewType subtype_of integer with constraints" do
      schema = AshZoi.to_schema(AshZoiTest.TestPositiveInteger)
      assert {:ok, 42} = Zoi.parse(schema, 42)
      assert {:error, _} = Zoi.parse(schema, -1)
    end

    test "user constraints can override NewType constraints" do
      # TestPositiveInteger has min: 0, but we can further restrict
      schema = AshZoi.to_schema(AshZoiTest.TestPositiveInteger, max: 100)
      assert {:ok, 50} = Zoi.parse(schema, 50)
      assert {:error, _} = Zoi.parse(schema, 150)
      # min: 0 should still be enforced from NewType
      assert {:error, _} = Zoi.parse(schema, -1)
    end

    test "NewType validates non-negative integers" do
      schema = AshZoi.to_schema(AshZoiTest.TestPositiveInteger)
      assert {:ok, 0} = Zoi.parse(schema, 0)
      assert {:ok, 1} = Zoi.parse(schema, 1)
      assert {:ok, 100} = Zoi.parse(schema, 100)
      assert {:error, errors} = Zoi.parse(schema, -1)
      assert [%Zoi.Error{code: :greater_than_or_equal_to}] = errors
    end

    test "NewType validates SSN format" do
      schema = AshZoi.to_schema(AshZoiTest.TestSSN)
      assert {:ok, "123-45-6789"} = Zoi.parse(schema, "123-45-6789")
      assert {:ok, "000-00-0000"} = Zoi.parse(schema, "000-00-0000")
      assert {:error, errors} = Zoi.parse(schema, "12345678")
      assert [%Zoi.Error{code: :invalid_format}] = errors
      assert {:error, errors} = Zoi.parse(schema, "123-45-678")
      assert [%Zoi.Error{code: :invalid_format}] = errors
    end

    test "handles NewType with no additional user constraints" do
      # TestPositiveInteger already has constraints, just verify it works
      schema = AshZoi.to_schema(AshZoiTest.TestPositiveInteger)
      assert {:ok, 0} = Zoi.parse(schema, 0)
      assert {:error, _} = Zoi.parse(schema, -1)
    end

    test "handles array of NewType" do
      schema = AshZoi.to_schema({:array, AshZoiTest.TestSSN})

      assert {:ok, ["123-45-6789", "987-65-4321"]} =
               Zoi.parse(schema, ["123-45-6789", "987-65-4321"])

      assert {:error, _} = Zoi.parse(schema, ["not-an-ssn"])
    end

    test "handles array of TypedStruct" do
      schema = AshZoi.to_schema({:array, AshZoiTest.TestProfile})

      assert {:ok, [%{username: "alice", age: 25, bio: nil}]} =
               Zoi.parse(schema, [%{username: "alice", age: 25, bio: nil}])

      assert {:error, _} = Zoi.parse(schema, [%{username: nil, age: 25, bio: nil}])
    end
  end

  describe "README examples" do
    test "basic type conversion" do
      schema = AshZoi.to_schema(:string)
      assert {:ok, "hello"} = Zoi.parse(schema, "hello")

      schema = AshZoi.to_schema(:integer)
      assert {:ok, 42} = Zoi.parse(schema, 42)

      schema = AshZoi.to_schema(:boolean)
      assert {:ok, true} = Zoi.parse(schema, true)
    end

    test "string constraints" do
      schema = AshZoi.to_schema(:string, min_length: 3, max_length: 100)
      assert {:ok, "hello"} = Zoi.parse(schema, "hello")
      assert {:error, _} = Zoi.parse(schema, "hi")
    end

    test "regex matching" do
      schema = AshZoi.to_schema(:string, match: ~r/^[a-z]+$/)
      assert {:ok, "hello"} = Zoi.parse(schema, "hello")
      assert {:error, _} = Zoi.parse(schema, "Hello123")
    end

    test "integer constraints" do
      schema = AshZoi.to_schema(:integer, min: 0, max: 100)
      assert {:ok, 50} = Zoi.parse(schema, 50)
      assert {:error, _} = Zoi.parse(schema, -1)
      assert {:error, _} = Zoi.parse(schema, 101)
    end

    test "float exclusive bounds" do
      schema = AshZoi.to_schema(:float, greater_than: 0.0, less_than: 1.0)
      assert {:ok, 0.5} = Zoi.parse(schema, 0.5)
      assert {:error, _} = Zoi.parse(schema, 0.0)
      assert {:error, _} = Zoi.parse(schema, 1.0)
    end

    test "atom enum" do
      schema = AshZoi.to_schema(:atom, one_of: [:red, :green, :blue])
      assert {:ok, :red} = Zoi.parse(schema, :red)
      assert {:error, _} = Zoi.parse(schema, :yellow)
    end

    test "array of strings" do
      schema = AshZoi.to_schema({:array, :string})
      assert {:ok, ["hello", "world"]} = Zoi.parse(schema, ["hello", "world"])
      assert {:error, _} = Zoi.parse(schema, ["hello", 123])
    end

    test "array with element constraints" do
      schema = AshZoi.to_schema({:array, :integer}, items: [min: 0, max: 100])
      assert {:ok, [0, 50, 100]} = Zoi.parse(schema, [0, 50, 100])
      assert {:error, _} = Zoi.parse(schema, [0, 50, 101])
    end

    test "array with length constraints" do
      schema = AshZoi.to_schema({:array, :string}, min_length: 1, max_length: 5)
      assert {:ok, ["hello"]} = Zoi.parse(schema, ["hello"])
      assert {:error, _} = Zoi.parse(schema, [])
    end

    test "map with typed fields and regex constraint" do
      schema =
        AshZoi.to_schema(:map,
          fields: [
            name: [type: :string, constraints: [min_length: 2, max_length: 50]],
            age: [type: :integer, constraints: [min: 0, max: 150]],
            email: [type: :string, constraints: [match: ~r/@/]]
          ]
        )

      assert {:ok, _} = Zoi.parse(schema, %{name: "Alice", age: 30, email: "alice@example.com"})
      assert {:error, _} = Zoi.parse(schema, %{name: "A", age: 30, email: "alice@example.com"})

      assert {:error, _} =
               Zoi.parse(schema, %{name: "Alice", age: -1, email: "alice@example.com"})

      assert {:error, _} = Zoi.parse(schema, %{name: "Alice", age: 30, email: "invalid"})
    end

    test "map with nullable fields" do
      schema =
        AshZoi.to_schema(:map,
          fields: [
            name: [type: :string],
            middle_name: [type: :string, allow_nil?: true]
          ]
        )

      assert {:ok, %{name: "Alice", middle_name: nil}} =
               Zoi.parse(schema, %{name: "Alice", middle_name: nil})
    end

    test "map with atom one_of in fields" do
      schema =
        AshZoi.to_schema(:map,
          fields: [
            page: [type: :integer, constraints: [min: 1]],
            per_page: [type: :integer, constraints: [min: 1, max: 100]],
            sort_by: [type: :atom, constraints: [one_of: [:name, :date, :popularity]]],
            order: [type: :atom, constraints: [one_of: [:asc, :desc]]]
          ]
        )

      assert {:ok, _} = Zoi.parse(schema, %{page: 1, per_page: 10, sort_by: :name, order: :asc})

      assert {:error, _} =
               Zoi.parse(schema, %{page: 0, per_page: 10, sort_by: :name, order: :asc})

      assert {:error, _} =
               Zoi.parse(schema, %{page: 1, per_page: 10, sort_by: :invalid, order: :asc})
    end

    test "map with nested array field and constraints" do
      schema =
        AshZoi.to_schema(:map,
          fields: [
            username: [
              type: :string,
              constraints: [min_length: 3, max_length: 20, match: ~r/^[a-zA-Z0-9_]+$/]
            ],
            email: [type: :string, constraints: [match: ~r/@/]],
            age: [type: :integer, constraints: [min: 13, max: 120]],
            bio: [type: :string, constraints: [max_length: 500], allow_nil?: true],
            tags: [type: {:array, :string}, constraints: [max_length: 5, items: [max_length: 20]]]
          ]
        )

      valid = %{
        username: "john_doe",
        email: "john@example.com",
        age: 25,
        bio: nil,
        tags: ["elixir", "phoenix"]
      }

      assert {:ok, _} = Zoi.parse(schema, valid)

      # username too short
      assert {:error, _} = Zoi.parse(schema, %{valid | username: "jd"})
      # invalid email
      assert {:error, _} = Zoi.parse(schema, %{valid | email: "invalid"})
      # age too young
      assert {:error, _} = Zoi.parse(schema, %{valid | age: 12})
    end

    test "module name resolution" do
      schema1 = AshZoi.to_schema(:string)
      schema2 = AshZoi.to_schema(Ash.Type.String)

      assert {:ok, "hello"} = Zoi.parse(schema1, "hello")
      assert {:ok, "hello"} = Zoi.parse(schema2, "hello")
      assert {:error, _} = Zoi.parse(schema1, 42)
      assert {:error, _} = Zoi.parse(schema2, 42)
    end
  end

  describe "union types" do
    test "converts union to discriminated union with _union_type/_union_value" do
      schema =
        AshZoi.to_schema(:union,
          types: [
            str: [type: :string],
            int: [type: :integer]
          ]
        )

      assert {:ok, %{"_union_type" => "str", "_union_value" => "hello"}} =
               Zoi.parse(schema, %{"_union_type" => "str", "_union_value" => "hello"})

      assert {:ok, %{"_union_type" => "int", "_union_value" => 42}} =
               Zoi.parse(schema, %{"_union_type" => "int", "_union_value" => 42})

      # Wrong type for variant
      assert {:error, _} =
               Zoi.parse(schema, %{"_union_type" => "str", "_union_value" => 42})

      # Unknown variant name
      assert {:error, _} =
               Zoi.parse(schema, %{"_union_type" => "unknown", "_union_value" => "hello"})
    end

    test "distinguishes same-type variants by name" do
      schema =
        AshZoi.to_schema(:union,
          types: [
            foo: [type: :string],
            bar: [type: :string]
          ]
        )

      assert {:ok, %{"_union_type" => "foo", "_union_value" => "hello"}} =
               Zoi.parse(schema, %{"_union_type" => "foo", "_union_value" => "hello"})

      assert {:ok, %{"_union_type" => "bar", "_union_value" => "world"}} =
               Zoi.parse(schema, %{"_union_type" => "bar", "_union_value" => "world"})
    end

    test "enforces per-variant constraints" do
      schema =
        AshZoi.to_schema(:union,
          types: [
            small_int: [type: :integer, constraints: [min: 0, max: 100]],
            text: [type: :string, constraints: [max_length: 50]]
          ]
        )

      assert {:ok, _} =
               Zoi.parse(schema, %{"_union_type" => "small_int", "_union_value" => 50})

      assert {:error, _} =
               Zoi.parse(schema, %{"_union_type" => "small_int", "_union_value" => 101})

      assert {:ok, _} =
               Zoi.parse(schema, %{"_union_type" => "text", "_union_value" => "hello"})

      long_string = String.duplicate("a", 51)

      assert {:error, _} =
               Zoi.parse(schema, %{"_union_type" => "text", "_union_value" => long_string})
    end

    test "converts union with no types to any" do
      schema = AshZoi.to_schema(:union, types: [])
      assert {:ok, "anything"} = Zoi.parse(schema, "anything")
    end

    test "converts union without types constraint to any" do
      schema = AshZoi.to_schema(:union)
      assert {:ok, "anything"} = Zoi.parse(schema, "anything")
    end

    test "converts NewType wrapping a union" do
      schema = AshZoi.to_schema(AshZoiTest.TestContent)

      assert {:ok, %{"_union_type" => "text", "_union_value" => "hello"}} =
               Zoi.parse(schema, %{"_union_type" => "text", "_union_value" => "hello"})

      assert {:ok, %{"_union_type" => "number", "_union_value" => 42}} =
               Zoi.parse(schema, %{"_union_type" => "number", "_union_value" => 42})
    end

    test "NewType union enforces variant constraints" do
      schema = AshZoi.to_schema(AshZoiTest.TestContent)

      # text variant: max_length: 1000
      assert {:ok, _} =
               Zoi.parse(schema, %{
                 "_union_type" => "text",
                 "_union_value" => String.duplicate("a", 1000)
               })

      assert {:error, _} =
               Zoi.parse(schema, %{
                 "_union_type" => "text",
                 "_union_value" => String.duplicate("a", 1001)
               })

      # number variant: min: 0
      assert {:ok, _} =
               Zoi.parse(schema, %{"_union_type" => "number", "_union_value" => 0})

      assert {:error, _} =
               Zoi.parse(schema, %{"_union_type" => "number", "_union_value" => -1})
    end

    test "resource with NewType union attribute" do
      schema = AshZoi.to_schema(AshZoiTest.TestPost)

      assert {:ok, _} =
               Zoi.parse(schema, %{
                 title: "Hello",
                 content: %{"_union_type" => "text", "_union_value" => "some text"}
               })

      assert {:ok, _} =
               Zoi.parse(schema, %{
                 title: "Hello",
                 content: %{"_union_type" => "number", "_union_value" => 42}
               })

      # Invalid variant value
      assert {:error, _} =
               Zoi.parse(schema, %{
                 title: "Hello",
                 content: %{"_union_type" => "number", "_union_value" => -1}
               })
    end
  end
end
