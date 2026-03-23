# AshZoi

A library that bridges [Ash](https://hexdocs.pm/ash) types to [Zoi](https://hexdocs.pm/zoi) validation schemas.

`AshZoi` provides a simple way to convert Ash type definitions (with constraints) into Zoi validation schemas that can be used for runtime validation.

## Installation

Add `ash_zoi` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ash, "~> 3.0"},
    {:zoi, "~> 0.17.3"},
    {:ash_zoi, "~> 0.1.0"}
  ]
end
```

## Usage

### Basic Type Conversion

Convert Ash type atoms to Zoi schemas:

```elixir
# Simple types
AshZoi.to_schema(:string)
#=> Zoi.string()

AshZoi.to_schema(:integer)
#=> Zoi.integer()

AshZoi.to_schema(:boolean)
#=> Zoi.boolean()
```

### With Constraints

Apply Ash constraints that are automatically mapped to Zoi validations:

```elixir
# String constraints
schema = AshZoi.to_schema(:string, min_length: 3, max_length: 100)
Zoi.parse(schema, "hello")
#=> {:ok, "hello"}

Zoi.parse(schema, "hi")
#=> {:error, [%Zoi.Error{code: :greater_than_or_equal_to, ...}]}

# Regex matching
schema = AshZoi.to_schema(:string, match: ~r/^[a-z]+$/)
Zoi.parse(schema, "hello")
#=> {:ok, "hello"}

# Integer constraints
schema = AshZoi.to_schema(:integer, min: 0, max: 100)
Zoi.parse(schema, 50)
#=> {:ok, 50}

# Float constraints
schema = AshZoi.to_schema(:float, greater_than: 0.0, less_than: 1.0)
Zoi.parse(schema, 0.5)
#=> {:ok, 0.5}

# Atom enum
schema = AshZoi.to_schema(:atom, one_of: [:red, :green, :blue])
Zoi.parse(schema, :red)
#=> {:ok, :red}
```

### Array Types

Convert array types with element-level and array-level constraints:

```elixir
# Array of strings
schema = AshZoi.to_schema({:array, :string})
Zoi.parse(schema, ["hello", "world"])
#=> {:ok, ["hello", "world"]}

# Array with element constraints
schema = AshZoi.to_schema({:array, :integer}, items: [min: 0, max: 100])
Zoi.parse(schema, [0, 50, 100])
#=> {:ok, [0, 50, 100]}

# Array with length constraints
schema = AshZoi.to_schema({:array, :string}, min_length: 1, max_length: 5)
Zoi.parse(schema, ["hello"])
#=> {:ok, ["hello"]}

# Combined constraints
schema = AshZoi.to_schema(
  {:array, :integer}, 
  min_length: 1,
  max_length: 10,
  items: [min: 0, max: 100]
)
```

### Map Types with Fields

Convert map types with typed fields:

```elixir
schema = AshZoi.to_schema(:map, 
  fields: [
    name: [type: :string, constraints: [min_length: 2, max_length: 50]],
    age: [type: :integer, constraints: [min: 0, max: 150]],
    email: [type: :string, constraints: [match: ~r/@/]]
  ]
)

Zoi.parse(schema, %{name: "Alice", age: 30, email: "alice@example.com"})
#=> {:ok, %{name: "Alice", age: 30, email: "alice@example.com"}}

# Nullable fields
schema = AshZoi.to_schema(:map, 
  fields: [
    name: [type: :string],
    middle_name: [type: :string, allow_nil?: true]
  ]
)

Zoi.parse(schema, %{name: "Alice", middle_name: nil})
#=> {:ok, %{name: "Alice", middle_name: nil}}
```

### Ash Resources

Convert Ash resources to map schemas based on their attributes:

```elixir
defmodule MyApp.Address do
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :street, :string, public?: true, allow_nil?: false
    attribute :city, :string, public?: true, allow_nil?: false
    attribute :zip, :string, public?: true, constraints: [max_length: 10]
  end
end

defmodule MyApp.User do
  use Ash.Resource

  attributes do
    uuid_primary_key :id
    attribute :name, :string, public?: true, allow_nil?: false, constraints: [min_length: 1]
    attribute :email, :string, public?: true, allow_nil?: false
    attribute :age, :integer, public?: true, constraints: [min: 0, max: 150]
    attribute :address, MyApp.Address, public?: true  # Embedded resource
    attribute :internal_field, :string  # private by default
  end
end

# Convert entire resource (only public attributes)
schema = AshZoi.to_schema(MyApp.User)
Zoi.parse(schema, %{
  name: "Alice",
  email: "alice@example.com",
  age: 30,
  address: %{street: "123 Main", city: "Springfield", zip: "12345"}
})
#=> {:ok, %{name: "Alice", email: "alice@example.com", ...}}

# Only specific attributes
schema = AshZoi.to_schema(MyApp.User, only: [:name, :email])
Zoi.parse(schema, %{name: "Alice", email: "alice@example.com"})
#=> {:ok, %{name: "Alice", email: "alice@example.com"}}

# Exclude specific attributes
schema = AshZoi.to_schema(MyApp.User, except: [:age])
```

**Notes:**

- Only public attributes (`:public?`) are included
- Non-public attributes are automatically excluded
- Embedded resources used as attribute types are automatically introspected
- The `:only` and `:except` options allow fine-grained control over included attributes
- Ash resource attributes have `allow_nil?: true` by default, making them nullable in the Zoi schema.
  Set `allow_nil?: false` on your Ash attributes to make them required in the generated schema.
- Map field definitions (`:map` type with `:fields` constraint) default `allow_nil?` to `false`,
  matching Ash's map field defaults.

### Ash TypedStructs

Convert Ash TypedStructs to map schemas with field validation:

```elixir
defmodule MyApp.Profile do
  use Ash.TypedStruct

  typed_struct do
    field :username, :string, allow_nil?: false
    field :age, :integer, constraints: [min: 0, max: 150]
    field :bio, :string
    field :website, :string, constraints: [match: ~r/^https?:\/\//]
  end
end

# Convert TypedStruct to schema
schema = AshZoi.to_schema(MyApp.Profile)
Zoi.parse(schema, %{username: "alice", age: 25, bio: "Hello", website: "https://example.com"})
#=> {:ok, %{username: "alice", age: 25, bio: "Hello", website: "https://example.com"}}

# Field constraints are enforced
Zoi.parse(schema, %{username: "alice", age: -1, bio: "Hello", website: "https://example.com"})
#=> {:error, [%Zoi.Error{code: :greater_than_or_equal_to, path: [:age], ...}]}

# allow_nil?: false is enforced
Zoi.parse(schema, %{username: nil, age: 25, bio: "Hello", website: "https://example.com"})
#=> {:error, [%Zoi.Error{code: :invalid_type, path: [:username], ...}]}

# Nullable fields accept nil (default: allow_nil?: true)
Zoi.parse(schema, %{username: "alice", age: 25, bio: nil, website: "https://example.com"})
#=> {:ok, %{username: "alice", age: 25, bio: nil, website: "https://example.com"}}
```

**Notes:**

- TypedStructs are automatically detected and converted to map schemas
- Field types and constraints are preserved from the TypedStruct definition
- `allow_nil?` is respected (defaults to `true` for fields, `false` when explicitly set)
- All Ash type features (constraints, validations) work with TypedStruct fields

### Ash NewTypes

Convert custom `Ash.Type.NewType` types with their baked-in constraints:

```elixir
defmodule MyApp.SSN do
  use Ash.Type.NewType,
    subtype_of: :string,
    constraints: [match: ~r/^\d{3}-\d{2}-\d{4}$/]
end

defmodule MyApp.PositiveInteger do
  use Ash.Type.NewType,
    subtype_of: :integer,
    constraints: [min: 0]
end

# NewTypes are automatically resolved to their underlying type with constraints
schema = AshZoi.to_schema(MyApp.SSN)
Zoi.parse(schema, "123-45-6789")
#=> {:ok, "123-45-6789"}

Zoi.parse(schema, "invalid-ssn")
#=> {:error, [%Zoi.Error{code: :invalid_format, ...}]}

# User-provided constraints override NewType defaults
schema = AshZoi.to_schema(MyApp.PositiveInteger, max: 100)
Zoi.parse(schema, 50)
#=> {:ok, 50}

Zoi.parse(schema, 150)  # Exceeds user-provided max
#=> {:error, [%Zoi.Error{code: :less_than_or_equal_to, ...}]}

Zoi.parse(schema, -1)   # Violates NewType's min: 0 constraint
#=> {:error, [%Zoi.Error{code: :greater_than_or_equal_to, ...}]}
```

**Notes:**

- NewTypes are automatically detected using `Ash.Type.NewType.new_type?/1`
- The underlying `subtype_of` type is resolved recursively
- NewType constraints are merged with user-provided constraints
- User-provided constraints take precedence (override NewType defaults)
- Supports all Ash types as subtypes (primitives, composites, other NewTypes)

### Union Types

Ash union types are typically defined as NewTypes wrapping `:union`
(see [Ash.Type.Union NewType integration](https://hexdocs.pm/ash/Ash.Type.Union.html#module-newtype-integration)):

```elixir
defmodule MyApp.Content do
  use Ash.Type.NewType,
    subtype_of: :union,
    constraints: [
      types: [
        text: [type: :string, constraints: [max_length: 1000]],
        number: [type: :integer, constraints: [min: 0]]
      ]
    ]
end

# The NewType is automatically unwrapped and the union variants are converted
# to a Zoi discriminated union using Ash's _union_type/_union_value format
schema = AshZoi.to_schema(MyApp.Content)

Zoi.parse(schema, %{"_union_type" => "text", "_union_value" => "hello"})
#=> {:ok, %{"_union_type" => "text", "_union_value" => "hello"}}

Zoi.parse(schema, %{"_union_type" => "number", "_union_value" => 42})
#=> {:ok, %{"_union_type" => "number", "_union_value" => 42}}

# Unknown variant name
Zoi.parse(schema, %{"_union_type" => "unknown", "_union_value" => "hello"})
#=> {:error, [...]}

# Wrong type for variant
Zoi.parse(schema, %{"_union_type" => "number", "_union_value" => "not a number"})
#=> {:error, [...]}
```

Union NewTypes work seamlessly as resource attribute types:

```elixir
defmodule MyApp.Post do
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :title, :string, public?: true, allow_nil?: false
    attribute :content, MyApp.Content, public?: true, allow_nil?: false
  end
end

schema = AshZoi.to_schema(MyApp.Post)
Zoi.parse(schema, %{title: "Hello", content: %{"_union_type" => "text", "_union_value" => "some text"}})
#=> {:ok, %{title: "Hello", content: %{"_union_type" => "text", ...}}}
```

You can also pass union types directly:

```elixir
schema = AshZoi.to_schema(:union, types: [
  foo: [type: :string],
  bar: [type: :string]
])

# Same-type variants are distinguished by name
Zoi.parse(schema, %{"_union_type" => "foo", "_union_value" => "hello"})
#=> {:ok, %{"_union_type" => "foo", "_union_value" => "hello"}}
```

**Notes:**

- Unions use Ash's `_union_type`/`_union_value` input format with string keys
- Each variant is identified by name via `Zoi.discriminated_union/3`
- Same-type variants (e.g., two `:string` variants) are properly distinguished
- Per-variant constraints are enforced
- NewType unions are automatically unwrapped and resolved

### Module Name Resolution

You can use either Ash type atoms or module names:

```elixir
AshZoi.to_schema(:string)
# Same as:
AshZoi.to_schema(Ash.Type.String)
```

## Type Mapping

The following Ash types are mapped to their Zoi equivalents:

| Ash Type | Zoi Schema | Notes |
|----------|------------|-------|
| `Ash.Type.String` | `Zoi.string()` | Supports `min_length`, `max_length`, `match` (regex) |
| `Ash.Type.CiString` | `Zoi.string()` | Case-insensitive string, validated as string |
| `Ash.Type.Integer` | `Zoi.integer()` | Supports `min`, `max`, `greater_than`, `less_than` |
| `Ash.Type.Float` | `Zoi.float()` | Supports `min`, `max`, `greater_than`, `less_than` |
| `Ash.Type.Boolean` | `Zoi.boolean()` | |
| `Ash.Type.Atom` | `Zoi.atom()` or `Zoi.enum()` | With `one_of` constraint → `Zoi.enum()` |
| `Ash.Type.Decimal` | `Zoi.decimal()` | Supports `min`, `max`, `greater_than`, `less_than` |
| `Ash.Type.Date` | `Zoi.date()` | |
| `Ash.Type.Time` | `Zoi.time()` | `TimeUsec` also maps to `time()` |
| `Ash.Type.DateTime` | `Zoi.datetime()` | All datetime variants map to `datetime()` |
| `Ash.Type.NaiveDatetime` | `Zoi.naive_datetime()` | |
| `Ash.Type.UUID` | `Zoi.uuid()` | `UUIDv7` also maps to `uuid()` |
| `Ash.Type.Map` | `Zoi.map()` | With `fields` constraint → `Zoi.map(fields_map)` |
| `Ash.Type.Struct` | `Zoi.struct()` | With `instance_of` and optional `fields` constraints |
| `Ash.Type.Module` | `Zoi.module()` | |
| `Ash.Type.Union` | `Zoi.discriminated_union()` | Uses `_union_type`/`_union_value` format, distinguishes same-type variants |
| `Ash.Type.Binary` | `Zoi.string()` | Closest equivalent |
| `Ash.Type.NewType` | (varies) | Recursively resolved to underlying subtype with constraints |
| `Ash.TypedStruct` | `Zoi.map()` | Introspected from typed struct fields (treated as map) |
| Ash Resources | `Zoi.map()` | Introspected from resource public attributes |
| Other types | `Zoi.any()` | Fallback for unknown/custom types |

## Constraint Mapping

Ash constraints are automatically mapped to Zoi validations:

### String Constraints

- `min_length` → `min_length` (Zoi constructor option)
- `max_length` → `max_length` (Zoi constructor option)
- `match` → Applied as `Zoi.regex()` refinement

### Numeric Constraints (Integer/Float/Decimal)

- `min` → `gte` (greater than or equal to)
- `max` → `lte` (less than or equal to)
- `greater_than` → `gt` (exclusive lower bound)
- `less_than` → `lt` (exclusive upper bound)

### Atom Constraints

- `one_of` → `Zoi.enum(values)`

### Array Constraints

- `min_length` → `min_length` (array-level)
- `max_length` → `max_length` (array-level)
- `items` → Applied to element schema (element-level constraints)

### Map Constraints

- `fields` → Converted to `Zoi.map(fields_map)` with typed fields
- `allow_nil?` → Wraps field schema with `Zoi.nullable()`

### Struct Constraints

- `instance_of` → Validates struct type with `Zoi.struct(module)`
- `fields` → Typed field schemas when combined with `instance_of`
- If `instance_of` points to an Ash resource, the resource's attributes are introspected
## Limitations

The following Ash constraints are not supported or ignored:

- **Array constraints:**
  - `nil_items?` - Not supported in Zoi
  - `remove_nil_items?` - Not supported in Zoi
  
- **Decimal constraints:**
  - `precision` - No Zoi equivalent
  - `scale` - No Zoi equivalent
  
- **DateTime constraints:**
  - `precision` - Ignored
  - `cast_dates_as` - Ignored
  - `timezone` - Ignored
  
- **Time constraints:**
  - `precision` - Ignored

- **Struct constraints:**
  - When `instance_of` is an Ash resource, `fields` constraints are ignored (resource attributes are used instead)

Custom Ash types not listed in the type mapping table will fall back to `Zoi.any()`, which accepts any value.

## Examples

### Validate User Input

```elixir
defmodule MyApp.UserSchema do
  def user_schema do
    AshZoi.to_schema(:map,
      fields: [
        username: [
          type: :string,
          constraints: [min_length: 3, max_length: 20, match: ~r/^[a-zA-Z0-9_]+$/]
        ],
        email: [
          type: :string,
          constraints: [match: ~r/@/]
        ],
        age: [
          type: :integer,
          constraints: [min: 13, max: 120]
        ],
        bio: [
          type: :string,
          constraints: [max_length: 500],
          allow_nil?: true
        ],
        tags: [
          type: {:array, :string},
          constraints: [max_length: 5, items: [max_length: 20]]
        ]
      ]
    )
  end
  
  def validate_user(data) do
    user_schema() |> Zoi.parse(data)
  end
end

# Usage
MyApp.UserSchema.validate_user(%{
  username: "john_doe",
  email: "john@example.com",
  age: 25,
  bio: nil,
  tags: ["elixir", "phoenix"]
})
#=> {:ok, %{username: "john_doe", email: "john@example.com", ...}}
```

### Validate API Parameters

```elixir
defmodule MyApp.API.Params do
  def pagination_schema do
    AshZoi.to_schema(:map,
      fields: [
        page: [type: :integer, constraints: [min: 1]],
        per_page: [type: :integer, constraints: [min: 1, max: 100]],
        sort_by: [type: :atom, constraints: [one_of: [:name, :date, :popularity]]],
        order: [type: :atom, constraints: [one_of: [:asc, :desc]]]
      ]
    )
  end
end

# In your controller:
def index(conn, params) do
  case MyApp.API.Params.pagination_schema() |> Zoi.parse(params) do
    {:ok, validated_params} ->
      # Use validated_params
      json(conn, %{data: fetch_data(validated_params)})
      
    {:error, errors} ->
      conn
      |> put_status(400)
      |> json(%{errors: format_errors(errors)})
  end
end
```

### Validate Ash Resource Data

```elixir
defmodule MyApp.BlogPost do
  use Ash.Resource

  attributes do
    uuid_primary_key :id
    attribute :title, :string, public?: true, allow_nil?: false, constraints: [min_length: 5, max_length: 200]
    attribute :body, :string, public?: true, allow_nil?: false, constraints: [min_length: 10]
    attribute :published, :boolean, public?: true, default: false
    attribute :tags, {:array, :string}, public?: true, constraints: [max_length: 10]
    attribute :author_email, :string, public?: true, constraints: [match: ~r/@/]
  end
end

# Validate input data before creating a resource
def create_post(input_data) do
  schema = AshZoi.to_schema(MyApp.BlogPost, except: [:id])
  
  case Zoi.parse(schema, input_data) do
    {:ok, validated_data} ->
      MyApp.BlogPost
      |> Ash.Changeset.for_create(:create, validated_data)
      |> MyApp.Api.create()
    
    {:error, errors} ->
      {:error, format_validation_errors(errors)}
  end
end
```

## Documentation

Full documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/ash_zoi>.

## License

MIT License - see LICENSE file for details.
