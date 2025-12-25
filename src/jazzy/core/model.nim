# Model Utilities
# Provides templates and helpers for defining Models/DTOs easier.

template makePrototype*(typeName: untyped) =
  ## Generates a standard constructor `new[TypeName]()`
  ## wrapper to encourage Prototype pattern usage.
  proc `new typeName`*(): typeName =
    new(result)
