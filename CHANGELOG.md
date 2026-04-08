# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.1] - 2026-04-08

### Fixed

- `Ash.Type.Enum` schemas now accept string values and coerce them to atoms.
  Previously, enums generated with `AshZoi.to_schema/2` only accepted atom
  inputs, which broke LLM tool call flows where parameters arrive as JSON strings.

## [0.2.0] - 2026-04-07

### Added

- `Ash.Type.Enum` support — enums defined with `use Ash.Type.Enum, values: [...]`
  are now converted to `Zoi.enum(values)` for proper validation

## [0.1.0] - 2026-03-23

### Added

- `AshZoi.to_schema/2` for converting Ash types to Zoi validation schemas
- Support for all built-in Ash types: String, CiString, Integer, Float, Boolean,
  Atom, Decimal, Date, Time, DateTime, NaiveDatetime, UtcDatetime,
  UtcDatetimeUsec, UUID, UUIDv7, Binary, Map, Struct, Module, and Union
- Automatic constraint mapping from Ash to Zoi (min/max → gte/lte,
  min\_length/max\_length, match → regex, one\_of → enum)
- Ash Resource introspection — pass a resource module to generate a Zoi map
  schema from its public attributes
- `:only` and `:except` options for filtering resource attributes
- Embedded resource support — nested resources are converted recursively
- `Ash.Type.Struct` support with `instance_of` and `fields` constraints
- `Ash.Type.Union` support via `Zoi.discriminated_union/3` using Ash's
  `_union_type`/`_union_value` input format
- `Ash.TypedStruct` support — typed structs are introspected and converted
  to Zoi map schemas
- `Ash.Type.NewType` support — NewTypes are automatically unwrapped to their
  underlying type with merged constraints
- Array type support (`{:array, type}`) with element-level and array-level
  constraints
- Depth-limited NewType unwrapping to prevent infinite recursion

[0.2.1]: https://github.com/Munksgaard/ash_zoi/releases/tag/v0.2.1
[0.2.0]: https://github.com/Munksgaard/ash_zoi/releases/tag/v0.2.0
[0.1.0]: https://github.com/Munksgaard/ash_zoi/releases/tag/v0.1.0
