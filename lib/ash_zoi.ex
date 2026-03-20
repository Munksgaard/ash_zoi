defmodule AshZoi do
  @moduledoc """
  Bridges Ash types to Zoi validation schemas.

  `AshZoi` provides a simple way to convert Ash type definitions (with constraints)
  into Zoi validation schemas that can be used for runtime validation.

  ## Example

      # Basic type conversion
      AshZoi.to_schema(:string)
      #=> Zoi.string()

      # With constraints
      AshZoi.to_schema(:string, min_length: 3, max_length: 100)
      #=> Zoi.string(min_length: 3, max_length: 100)

      # Array types
      AshZoi.to_schema({:array, :integer}, min_length: 1, items: [min: 0, max: 100])
      #=> Zoi.array(Zoi.integer(gte: 0, lte: 100), min_length: 1)

      # Map types with fields
      AshZoi.to_schema(:map, fields: [
        name: [type: :string, constraints: [min_length: 1]],
        age: [type: :integer]
      ])
      #=> Zoi.map(%{name: Zoi.string(min_length: 1), age: Zoi.integer()})

      # Ash resources
      AshZoi.to_schema(MyApp.User)
      #=> Zoi.map(%{name: ..., email: ..., age: ...})

      # Ash TypedStructs
      AshZoi.to_schema(MyProfile)
      #=> Zoi.map(%{username: ..., age: ..., bio: ...})

  ## Type Mapping

  The following Ash types are mapped to their Zoi equivalents:

  - `Ash.Type.String` → `Zoi.string()`
  - `Ash.Type.CiString` → `Zoi.string()` (case-insensitive string, validated as string)
  - `Ash.Type.Integer` → `Zoi.integer()`
  - `Ash.Type.Float` → `Zoi.float()`
  - `Ash.Type.Boolean` → `Zoi.boolean()`
  - `Ash.Type.Atom` → `Zoi.atom()` or `Zoi.enum()` (with `one_of` constraint)
  - `Ash.Type.Decimal` → `Zoi.decimal()`
  - `Ash.Type.Date` → `Zoi.date()`
  - `Ash.Type.Time` → `Zoi.time()`
  - `Ash.Type.DateTime` → `Zoi.datetime()`
  - `Ash.Type.NaiveDatetime` → `Zoi.naive_datetime()`
  - `Ash.Type.UUID` → `Zoi.uuid()`
  - `Ash.Type.Map` → `Zoi.map()` (with optional `fields` constraint)
  - `Ash.Type.Struct` → `Zoi.struct()` (with `instance_of` and `fields`)
  - `Ash.Type.Module` → `Zoi.module()`
  - `Ash.Type.Union` → `Zoi.discriminated_union()` (using `_union_type`/`_union_value` format)
  - Ash Resources → `Zoi.map()` (introspected from resource attributes)
  - `Ash.Type.NewType` → Recursively resolved to underlying subtype
  - `Ash.TypedStruct` → `Zoi.map()` (introspected from typed struct fields)
  - Other types → `Zoi.any()`

  ## Ash Resource Support

  When you pass an Ash resource module to `to_schema/2`, it will introspect the resource's
  public attributes and generate a Zoi map schema:

      defmodule MyApp.User do
        use Ash.Resource

        attributes do
          attribute :name, :string, allow_nil?: false
          attribute :email, :string, allow_nil?: false
          attribute :age, :integer, constraints: [min: 0, max: 150]
        end
      end

      # All public attributes
      AshZoi.to_schema(MyApp.User)

      # Only specific attributes
      AshZoi.to_schema(MyApp.User, only: [:name, :email])

      # Exclude specific attributes
      AshZoi.to_schema(MyApp.User, except: [:age])

  ## TypedStruct Support

  Ash TypedStructs are fully supported and automatically converted to map schemas
  with field validation:

      defmodule MyProfile do
        use Ash.TypedStruct

        typed_struct do
          field :username, :string, allow_nil?: false
          field :age, :integer, constraints: [min: 0, max: 150]
          field :bio, :string
        end
      end

      # Converts to a map schema with field validation
      AshZoi.to_schema(MyProfile)
      #=> Zoi.map(%{username: Zoi.string(), age: Zoi.integer(gte: 0, lte: 150), bio: Zoi.nullable(Zoi.string())})

  ## NewType Support

  Custom `Ash.Type.NewType` types are supported and recursively resolved to their
  underlying subtypes with constraints merged:

      defmodule SSN do
        use Ash.Type.NewType, subtype_of: :string, constraints: [match: ~r/^\d{3}-\d{2}-\d{4}$/]
      end

      AshZoi.to_schema(SSN)
      #=> Zoi.regex(Zoi.string(), ~r/^\d{3}-\d{2}-\d{4}$/)

      # User-provided constraints override NewType defaults
      AshZoi.to_schema(SSN, max_length: 11)
      #=> Zoi.regex(Zoi.string(max_length: 11), ~r/^\d{3}-\d{2}-\d{4}$/)

  ## Constraint Mapping

  Ash constraints are mapped to Zoi options:

  - String: `min_length`, `max_length`, `match` → `regex`
  - Integer/Float: `min` → `gte`, `max` → `lte`, `greater_than` → `gt`, `less_than` → `lt`
  - Atom: `one_of` → `Zoi.enum/1`
  - Array: `min_length`, `max_length`, `items` (element constraints)
  - Struct: `instance_of` (struct module), `fields` (typed fields)

  ## Limitations

  - Array constraints `nil_items?` and `remove_nil_items?` are not supported
  - Decimal constraints `precision` and `scale` are ignored
  - DateTime constraints `precision`, `cast_dates_as`, `timezone` are ignored
  - Time constraint `precision` is ignored

  ## Behavior Notes

  - Ash resource attributes have `allow_nil?: true` by default, making them nullable in the Zoi schema.
    Set `allow_nil?: false` on your Ash attributes to make them required in the generated schema.
  - Map field definitions (`:map` type with `:fields` constraint) default `allow_nil?` to `false`,
    matching Ash's map field defaults.
  - Constraints that don't apply to a type are silently ignored
  - Map fields without a `:type` default to `:any`
  - Unknown/unsupported Ash types fall back to `Zoi.any()`
  - Only public resource attributes are included by default
  """
  @doc """
  Converts an Ash type (with optional constraints) into a Zoi validation schema.

  ## Parameters

  - `type` - An Ash type atom (`:string`, `:integer`, etc.), module (`Ash.Type.String`),
    or array tuple (`{:array, inner_type}`).
  - `constraints` - A keyword list of Ash constraints to apply. For Ash resources, you can also
    pass `:only` and `:except` options to control which attributes are included in the schema.

  ## Examples

      iex> schema = AshZoi.to_schema(:string)
      iex> is_struct(schema)
      true

      iex> schema = AshZoi.to_schema(:integer, min: 0, max: 100)
      iex> Zoi.parse(schema, 50)
      {:ok, 50}

      iex> schema = AshZoi.to_schema({:array, :string}, min_length: 1)
      iex> Zoi.parse(schema, ["hello"])
      {:ok, ["hello"]}
  """

  # Maximum depth for NewType unwrapping to prevent infinite recursion
  @max_new_type_depth 20
  @spec to_schema(type :: atom() | module() | {:array, any()}, constraints :: keyword() | nil) ::
          struct()
  def to_schema(type, constraints \\ [])

  # Normalize nil constraints to empty list
  def to_schema(type, nil), do: to_schema(type, [])

  # Handle array types
  def to_schema({:array, inner_type}, constraints) do
    # Separate array-level and element-level constraints
    {array_opts, element_constraints} = extract_array_constraints(constraints)

    # Recursively convert the inner type with element constraints
    inner_schema = to_schema(inner_type, element_constraints)

    # Create array schema with array-level constraints
    Zoi.array(inner_schema, array_opts)
  end

  # Handle all other types
  def to_schema(type, constraints) do
    to_schema_with_depth(type, constraints, 0)
  end

  # Internal helper with depth tracking for NewType unwrapping
  defp to_schema_with_depth(_type, _constraints, depth) when depth >= @max_new_type_depth do
    raise ArgumentError,
          "NewType unwrapping exceeded maximum depth of #{@max_new_type_depth}. " <>
            "This may indicate circular NewType definitions."
  end

  defp to_schema_with_depth(type, constraints, depth) do
    # Resolve the type module
    type_module = resolve_type(type)

    # Check if it's a NewType or Ash resource
    cond do
      # Check if it's a NewType (including TypedStruct) before resource check
      ash_new_type?(type_module) ->
        subtype = type_module.subtype_of()
        subtype_constraints = type_module.subtype_constraints()
        merged_constraints = Keyword.merge(subtype_constraints, constraints)
        to_schema_with_depth(subtype, merged_constraints, depth + 1)

      ash_resource?(type_module) ->
        resource_to_schema(type_module, constraints)

      true ->
        type_to_schema(type_module, constraints)
    end
  end

  ## Private Functions

  # Helper to check if a type is an Ash resource
  defp ash_resource?(type) when is_atom(type) and not is_nil(type) do
    Code.ensure_loaded?(type) and
      function_exported?(type, :spark_is, 0) and
      Ash.Resource.Info.resource?(type)
  end

  defp ash_resource?(_), do: false

  # Helper to check if a type is an Ash NewType (including TypedStruct)
  defp ash_new_type?(type) when is_atom(type) and not is_nil(type) do
    Code.ensure_loaded?(type) and
      Ash.Type.NewType.new_type?(type)
  end

  defp ash_new_type?(_), do: false

  # Resolve an Ash type to its module
  defp resolve_type(type) when is_atom(type) do
    Ash.Type.get_type(type)
  end

  defp resolve_type(type) when is_binary(type) do
    String.to_existing_atom(type)
  rescue
    _ -> type
  end

  defp resolve_type(type), do: type

  # Extract array-specific constraints from the constraint list
  defp extract_array_constraints(constraints) do
    array_keys = [:min_length, :max_length]

    array_opts = Keyword.take(constraints, array_keys)
    element_constraints = Keyword.get(constraints, :items, []) || []

    {array_opts, element_constraints}
  end

  # Map Ash type modules to Zoi schemas
  defp type_to_schema(Ash.Type.String, constraints) do
    opts = map_string_constraints(constraints)
    schema = Zoi.string(opts)

    # Apply regex constraint as a refinement if present
    case Keyword.get(constraints, :match) do
      nil ->
        schema

      regex when is_struct(regex, Regex) ->
        Zoi.regex(schema, regex)

      other ->
        raise ArgumentError, "expected :match constraint to be a Regex, got: #{inspect(other)}"
    end
  end

  defp type_to_schema(Ash.Type.Integer, constraints) do
    opts = map_numeric_constraints(constraints)
    Zoi.integer(opts)
  end

  defp type_to_schema(Ash.Type.Float, constraints) do
    opts = map_numeric_constraints(constraints)
    Zoi.float(opts)
  end

  defp type_to_schema(Ash.Type.Boolean, _constraints) do
    Zoi.boolean()
  end

  defp type_to_schema(Ash.Type.Atom, constraints) do
    case Keyword.get(constraints, :one_of) do
      nil ->
        Zoi.atom()

      values when is_list(values) ->
        Zoi.enum(values)

      other ->
        raise ArgumentError, "expected :one_of constraint to be a list, got: #{inspect(other)}"
    end
  end

  defp type_to_schema(Ash.Type.Decimal, constraints) do
    opts = map_decimal_constraints(constraints)
    Zoi.decimal(opts)
  end

  defp type_to_schema(Ash.Type.Date, _constraints) do
    Zoi.date()
  end

  defp type_to_schema(Ash.Type.Time, _constraints) do
    Zoi.time()
  end

  defp type_to_schema(Ash.Type.TimeUsec, _constraints) do
    Zoi.time()
  end

  defp type_to_schema(Ash.Type.DateTime, _constraints) do
    Zoi.datetime()
  end

  defp type_to_schema(Ash.Type.NaiveDatetime, _constraints) do
    Zoi.naive_datetime()
  end

  defp type_to_schema(Ash.Type.UtcDatetime, _constraints) do
    Zoi.datetime()
  end

  defp type_to_schema(Ash.Type.UtcDatetimeUsec, _constraints) do
    Zoi.datetime()
  end

  defp type_to_schema(Ash.Type.UUID, _constraints) do
    Zoi.uuid()
  end

  defp type_to_schema(Ash.Type.UUIDv7, _constraints) do
    Zoi.uuid()
  end

  defp type_to_schema(Ash.Type.Binary, _constraints) do
    # Binary maps to string as closest equivalent
    Zoi.string()
  end

  defp type_to_schema(Ash.Type.Map, constraints) do
    case Keyword.get(constraints, :fields) do
      nil ->
        Zoi.map()

      fields when is_list(fields) ->
        map_schema = convert_map_fields(fields)
        Zoi.map(map_schema)
    end
  end

  defp type_to_schema(Ash.Type.Module, _constraints) do
    Zoi.module()
  end

  # Handle CiString explicitly (before catch-all)
  # Handle Ash.Type.Union - convert union variants to a Zoi discriminated union.
  # Each variant becomes a map with "_union_type" (the variant name as a string)
  # and "_union_value" (the variant's schema), matching Ash's input format for unions.
  defp type_to_schema(Ash.Type.Union, constraints) do
    types = Keyword.get(constraints, :types, [])

    if types == [] do
      Zoi.any()
    else
      variant_schemas =
        Enum.map(types, fn {name, config} ->
          variant_type = config[:type]
          variant_constraints = config[:constraints] || []
          value_schema = to_schema(variant_type, variant_constraints)

          Zoi.map(%{
            "_union_type" => Zoi.literal(to_string(name)),
            "_union_value" => value_schema
          })
        end)

      Zoi.discriminated_union("_union_type", variant_schemas)
    end
  end

  defp type_to_schema(Ash.Type.CiString, constraints) do
    opts = map_string_constraints(constraints)
    schema = Zoi.string(opts)

    case Keyword.get(constraints, :match) do
      nil ->
        schema

      regex when is_struct(regex, Regex) ->
        Zoi.regex(schema, regex)

      other ->
        raise ArgumentError, "expected :match constraint to be a Regex, got: #{inspect(other)}"
    end
  end

  # Handle Ash.Type.Struct with instance_of and fields
  # TypedStructs are validated as maps because input data is typically
  # a plain map (from JSON, forms, etc.), not a struct instance.
  defp type_to_schema(Ash.Type.Struct, constraints) do
    instance_of = Keyword.get(constraints, :instance_of)
    fields = Keyword.get(constraints, :fields)

    cond do
      # If instance_of points to an Ash resource, recurse
      ash_resource?(instance_of) ->
        resource_to_schema(instance_of, [])

      # If instance_of is a NewType (TypedStruct) with fields, use the fields
      # The fields were already extracted from the NewType's subtype_constraints
      ash_new_type?(instance_of) and fields != nil ->
        Zoi.map(convert_map_fields(fields))

      # If instance_of with fields, build Zoi struct with field schemas
      instance_of != nil and fields != nil ->
        field_schemas = convert_map_fields(fields)
        Zoi.struct(instance_of, field_schemas)

      # If just instance_of, validate struct type only
      instance_of != nil ->
        Zoi.struct(instance_of)

      # If just fields, treat like a typed map
      fields != nil ->
        Zoi.map(convert_map_fields(fields))

      # No constraints at all
      true ->
        Zoi.any()
    end
  end

  # Check if unknown type is an Ash resource before falling back to any()
  defp type_to_schema(type, constraints) when is_atom(type) do
    cond do
      ash_resource?(type) ->
        resource_to_schema(type, constraints)

      true ->
        Zoi.any()
    end
  end

  # Fallback for unknown or unsupported types
  defp type_to_schema(_type, _constraints) do
    Zoi.any()
  end

  # Map string-specific constraints
  defp map_string_constraints(nil), do: []

  defp map_string_constraints(constraints) do
    Keyword.take(constraints, [:min_length, :max_length])
  end

  # Map numeric constraints (integer/float)
  defp map_numeric_constraints(nil), do: []

  defp map_numeric_constraints(constraints) do
    []
    |> maybe_add_constraint(:gte, constraints, :min)
    |> maybe_add_constraint(:lte, constraints, :max)
    |> maybe_add_constraint(:gt, constraints, :greater_than)
    |> maybe_add_constraint(:lt, constraints, :less_than)
  end

  # Map decimal constraints
  defp map_decimal_constraints(nil), do: []

  defp map_decimal_constraints(constraints) do
    []
    |> maybe_add_decimal_constraint(:gte, constraints, :min)
    |> maybe_add_decimal_constraint(:lte, constraints, :max)
    |> maybe_add_decimal_constraint(:gt, constraints, :greater_than)
    |> maybe_add_decimal_constraint(:lt, constraints, :less_than)
  end

  defp maybe_add_constraint(opts, zoi_key, constraints, ash_key) do
    case Keyword.get(constraints, ash_key) do
      nil -> opts
      value -> Keyword.put(opts, zoi_key, value)
    end
  end

  defp maybe_add_decimal_constraint(opts, zoi_key, constraints, ash_key) do
    case Keyword.get(constraints, ash_key) do
      nil ->
        opts

      value when is_number(value) ->
        Keyword.put(opts, zoi_key, Decimal.new(value))

      value ->
        Keyword.put(opts, zoi_key, value)
    end
  end

  # Convert map fields to Zoi map schema
  defp convert_map_fields(fields) do
    Enum.reduce(fields, %{}, fn {field_name, field_spec}, acc ->
      field_type = Keyword.get(field_spec, :type, :any)
      field_constraints = Keyword.get(field_spec, :constraints, [])
      allow_nil = Keyword.get(field_spec, :allow_nil?, false)

      schema = to_schema(field_type, field_constraints)

      final_schema =
        if allow_nil do
          Zoi.nullable(schema)
        else
          schema
        end

      Map.put(acc, field_name, final_schema)
    end)
  end

  # Convert an Ash resource to a Zoi map schema based on its attributes
  defp resource_to_schema(resource, constraints) do
    # Get option for which attributes to include (default: all public attributes)
    only = Keyword.get(constraints, :only, nil)
    except = Keyword.get(constraints, :except, [])

    attributes = Ash.Resource.Info.attributes(resource)

    # Filter to public attributes by default
    attributes = Enum.filter(attributes, & &1.public?)

    # Apply :only filter if provided
    attributes = if only, do: Enum.filter(attributes, &(&1.name in only)), else: attributes

    # Apply :except filter
    attributes = Enum.reject(attributes, &(&1.name in except))

    # Build the Zoi map schema from attributes
    field_schemas =
      Enum.reduce(attributes, %{}, fn attr, acc ->
        schema = to_schema(attr.type, attr.constraints)

        schema =
          if attr.allow_nil? do
            Zoi.nullable(schema)
          else
            schema
          end

        Map.put(acc, attr.name, schema)
      end)

    Zoi.map(field_schemas)
  end
end
