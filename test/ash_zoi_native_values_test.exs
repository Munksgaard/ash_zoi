defmodule AshZoi.NativeValuesTest do
  use ExUnit.Case, async: true

  defmodule Label do
    use Ash.Type.NewType,
      subtype_of: :ci_string,
      constraints: [min_length: 2, match: ~r/^[A-Za-z]+$/, casing: :lower]
  end

  defmodule Price do
    use Ash.Type.NewType,
      subtype_of: AshMoney.Types.Money,
      constraints: [min: 0, ex_money_opts: [fractional_digits: 4]]
  end

  defmodule Profile do
    use Ash.TypedStruct

    typed_struct do
      field(:label, Label, allow_nil?: false)
      field(:price, Price, allow_nil?: false)
    end
  end

  defmodule Choice do
    use Ash.Type.NewType,
      subtype_of: :union,
      constraints: [types: [price: [type: Price], profile: [type: Profile]]]
  end

  defmodule Address do
    use Ash.Resource, data_layer: :embedded

    resource do
      description("A native address.")
    end

    attributes do
      attribute(:city, Label, public?: true, allow_nil?: false)
    end
  end

  defmodule Order do
    use Ash.Resource, data_layer: :embedded

    attributes do
      uuid_primary_key(:id, public?: false)
      attribute(:private, :string)
      attribute(:address, Address, public?: true, allow_nil?: false)
      attribute(:choices, {:array, Choice}, public?: true, allow_nil?: false)
      attribute(:price, Price, public?: true)
    end
  end

  # Also exercise schemas embedded in compiled module attributes.
  @price_schema AshZoi.to_schema(Price, coerce: true)
  @choice_schema AshZoi.to_schema(Choice, coerce: true)
  @profile_schema AshZoi.to_schema(Profile, coerce: true)
  @label_schema AshZoi.to_schema(Label)
  @order_schema AshZoi.to_schema(Order, coerce: true)

  test "money returns Money with normalized currency and format options" do
    assert {:ok, %Money{currency: :USD} = money} =
             Zoi.parse(@price_schema, %{"currency" => "usd", "amount" => "12.50"})

    assert money == Money.new(:USD, Decimal.new("12.50"), fractional_digits: 4)
    assert {:error, _} = Zoi.parse(@price_schema, %{"currency" => "USD", "amount" => -1})
  end

  test "invalid currency and non-finite amounts return validation errors, not exceptions" do
    assert {:error, [%Zoi.Error{path: [:currency]}]} =
             Zoi.parse(@price_schema, %{"currency" => "NOT_A_CURRENCY", "amount" => 1})

    schema = AshZoi.to_schema(AshMoney.Types.Money)

    for amount <- [Decimal.new("NaN"), Decimal.new("Infinity")] do
      assert {:error, [%Zoi.Error{path: [:amount]}]} =
               Zoi.parse(schema, %{currency: "USD", amount: amount})
    end
  end

  test "CiString returns its native type after validating the input" do
    assert {:ok, %Ash.CiString{} = label} = Zoi.parse(@label_schema, "Hello")
    assert Ash.CiString.value(label) == "hello"
    assert {:error, _} = Zoi.parse(@label_schema, "H")
    assert {:error, _} = Zoi.parse(@label_schema, "123")

    schema = AshZoi.to_schema(:ci_string, casing: :upper)
    assert {:ok, %Ash.CiString{string: "HELLO"}} = Zoi.parse(schema, "Hello")
  end

  test "TypedStruct values contain recursively parsed native fields" do
    assert {:ok, %Profile{label: %Ash.CiString{}, price: %Money{currency: :USD}}} =
             Zoi.parse(@profile_schema, profile_input())

    assert {:error, _} = Zoi.parse(@profile_schema, put_in(profile_input(), ["label"], "!"))
  end

  test "union wrappers return Ash.Union containing native payloads" do
    assert {:ok, %Ash.Union{type: :profile, value: %Profile{price: %Money{}}}} =
             Zoi.parse(@choice_schema, wrapper("profile", profile_input()))

    assert {:ok, %Ash.Union{type: :price, value: %Money{currency: :USD}}} =
             Zoi.parse(@choice_schema, wrapper("price", %{"currency" => "USD", "amount" => 2}))

    assert {:error, _} = Zoi.parse(@choice_schema, wrapper("unknown", profile_input()))
  end

  test "resources, arrays, NewTypes, and nullable fields compose" do
    input = %{
      "address" => %{"city" => "London"},
      "choices" => [wrapper("profile", profile_input())],
      "price" => nil
    }

    assert {:ok,
            %Order{
              address: %Address{city: %Ash.CiString{string: "london"}},
              choices: [%Ash.Union{type: :profile, value: %Profile{price: %Money{}}}],
              price: nil
            }} = Zoi.parse(@order_schema, input)

    array_schema = AshZoi.to_schema({:array, Profile}, coerce: true)
    assert {:ok, [%Profile{price: %Money{}}]} = Zoi.parse(array_schema, [profile_input()])
  end

  test "only and except filter inputs, not the shape of the resulting resource struct" do
    for opts <- [[only: [:address]], [except: [:choices, :price]]] do
      schema = AshZoi.to_schema(Order, [coerce: true] ++ opts)

      assert {:ok, %Order{} = order} =
               Zoi.parse(schema, %{
                 "address" => %{"city" => "London"},
                 "id" => "injected",
                 "private" => "injected",
                 "choices" => "ignored"
               })

      assert order.id == struct(Order).id
      assert order.private == struct(Order).private
      assert order.choices == struct(Order).choices
      assert %Address{} = order.address
    end
  end

  test "plain maps remain maps but their typed fields become native" do
    schema =
      AshZoi.to_schema(:map,
        coerce: true,
        fields: [
          profile: [type: Profile],
          price: [type: Price, allow_nil?: true],
          choice: [type: Choice, allow_nil?: true]
        ]
      )

    assert {:ok, %{profile: %Profile{}, price: nil, choice: nil} = result} =
             Zoi.parse(schema, %{"profile" => profile_input(), "price" => nil, "choice" => nil})

    refute is_struct(result)
  end

  test "constructor failures preserve nested error paths and variant information" do
    input = %{
      "address" => %{"city" => "London"},
      "choices" => [wrapper("price", %{"currency" => "NOT_A_CURRENCY", "amount" => 2})],
      "price" => nil
    }

    assert {:error, [error]} = Zoi.parse(@order_schema, input)
    assert error.path == [:choices, 0, "_union_value", :currency]
    assert {_, opts} = error.issue
    assert opts[:discriminator] == "price"
  end

  test "JSON Schema still describes map/string inputs with nested constraints" do
    for schema <- [@price_schema, @choice_schema, @profile_schema, @label_schema, @order_schema] do
      assert schema |> Zoi.to_json_schema() |> Jason.encode!() |> is_binary()
    end

    money = Zoi.to_json_schema(@price_schema)
    assert money.type == :object
    assert money.properties.currency.type == :string
    assert Decimal.equal?(money.properties.amount.minimum, 0)

    label = Zoi.to_json_schema(@label_schema)
    assert label.type == :string
    assert label.pattern == "^[A-Za-z]+$"
    assert label.minLength == 2

    assert %{discriminator: %{propertyName: "_union_type"}, oneOf: [_, _]} =
             Zoi.to_json_schema(@choice_schema)

    assert Zoi.to_json_schema(AshZoi.to_schema(Address)).description == "A native address."
  end

  test "output typespecs describe native values, including nullable map fields" do
    assert type_spec(@price_schema) == "Money.t()"
    assert type_spec(@label_schema) == "Ash.CiString.t()"
    assert type_spec(@profile_schema) == "%AshZoi.NativeValuesTest.Profile{}"
    assert type_spec(@order_schema) == "%AshZoi.NativeValuesTest.Order{}"
    assert type_spec(@choice_schema) =~ "%Ash.Union{type: :price, value: Money.t()}"

    schema = AshZoi.to_schema(:map, fields: [price: [type: Price, allow_nil?: true]])
    assert type_spec(schema) =~ "nil | Money.t()"
  end

  defp profile_input,
    do: %{"label" => "Hello", "price" => %{"currency" => "USD", "amount" => 1.25}}

  defp wrapper(type, value), do: %{"_union_type" => type, "_union_value" => value}
  defp type_spec(schema), do: schema |> Zoi.type_spec() |> Macro.to_string()
end
