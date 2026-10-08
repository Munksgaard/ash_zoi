defmodule AshZoi.Transforms do
  @moduledoc false

  # MFA transforms keep generated schemas usable in module attributes.
  @spec to_struct(map(), module(), keyword()) :: {:ok, struct()}
  def to_struct(value, module, _), do: {:ok, struct(module, value)}

  @spec to_union(map(), atom(), keyword()) :: {:ok, Ash.Union.t()}
  def to_union(value, name, _) do
    {:ok, %Ash.Union{type: name, value: Map.fetch!(value, "_union_value")}}
  end

  @spec to_ci_string(String.t(), Ash.CiString.casing(), keyword()) :: {:ok, Ash.CiString.t()}
  def to_ci_string(value, casing, _), do: {:ok, Ash.CiString.new(value, casing)}

  if Code.ensure_loaded?(Money) do
    @spec to_money(map(), keyword(), keyword()) :: {:ok, Money.t()} | {:error, Zoi.Error.t()}
    def to_money(%{currency: currency, amount: amount}, opts, _) do
      case Money.new(currency, amount, opts) do
        %Money{} = money ->
          {:ok, money}

        {:error, {exception, message}} ->
          field = if exception == Money.InvalidAmountError, do: :amount, else: :currency
          {:error, Zoi.Error.custom_error(issue: {message, []}, path: [field])}
      end
    end
  end
end
