defmodule AshZoi.UnionTest do
  use ExUnit.Case, async: true

  describe "discriminated union regressions" do
    test "variant errors preserve the discriminator, path, and constraint details" do
      schema =
        AshZoi.to_schema(:union,
          types: [
            text: [type: :string],
            count: [type: :integer, constraints: [min: 0]]
          ]
        )

      assert {:error, [error]} =
               Zoi.parse(schema, %{"_union_type" => "count", "_union_value" => -1})

      assert error.code == :greater_than_or_equal_to
      assert error.path == ["_union_value"]
      assert {_, opts} = error.issue
      assert opts[:discriminator] == "count"
    end

    test "missing and unknown discriminators are rejected" do
      schema =
        AshZoi.to_schema(:union, types: [text: [type: :string], count: [type: :integer]])

      assert {:error, [%Zoi.Error{code: :required, path: ["_union_type"]}]} =
               Zoi.parse(schema, %{"_union_value" => "hello"})

      assert {:error, [%Zoi.Error{issue: {_, opts}}]} =
               Zoi.parse(schema, %{"_union_type" => "unknown", "_union_value" => "hello"})

      assert opts[:field] == "_union_type"
      assert opts[:value] == "unknown"
    end

    test "JSON Schema preserves variant names and nested refinements" do
      schema =
        AshZoi.to_schema(:union,
          types: [
            text: [type: :string, constraints: [match: ~r/^hello/, max_length: 20]],
            id: [type: :uuid]
          ]
        )

      json = Zoi.to_json_schema(schema)
      assert json.discriminator == %{propertyName: "_union_type"}
      assert [text, id] = json.oneOf
      assert text.properties["_union_type"] == %{const: "text"}
      assert id.properties["_union_type"] == %{const: "id"}
      assert text.properties["_union_value"].pattern == "^hello"
      assert text.properties["_union_value"].maxLength == 20

      assert id.properties["_union_value"].pattern ==
               Zoi.to_json_schema(AshZoi.to_schema(:uuid)).pattern

      for variant <- json.oneOf do
        assert Enum.sort(variant.required) == ["_union_type", "_union_value"]
      end
    end
  end
end
