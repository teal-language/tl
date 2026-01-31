# Contextual Typing in Teal

## Overview

Contextual typing (also known as target type inference) is a feature that enables automatic type inference for callback function parameters based on the expected function type at the call site. This eliminates the need for explicit type annotations while maintaining full type safety.

## Motivation

When working with callbacks and higher-order functions, developers often need to write verbose type annotations:

```teal
local function filter(items: {number}, predicate: function(x: number): boolean): {number}
   local result: {number} = {}
   for i, item in ipairs(items) do
      if predicate(item) then
         table.insert(result, item)
      end
   end
   return result
end

-- Without contextual typing, you need explicit types:
local numbers = {1, 2, 3, 4, 5}
local evens = filter(numbers, function(x: number) return x % 2 == 0 end)
```

With contextual typing, the parameter type can be inferred from the expected function signature:

```teal
-- With contextual typing, types are inferred:
local evens = filter(numbers, function(x) return x % 2 == 0 end)
```

## Common Use Cases

### 1. Array Methods

```teal
local function map<T, U>(f: function(x: T): U, items: {T}): {U}
   local result: {U} = {}
   for i, item in ipairs(items) do
      result[i] = f(item)
   end
   return result
end

local numbers = {1, 2, 3}
-- Parameter type 'x' is inferred as 'number'
local strings = map(function(x) return tostring(x) end, numbers)
```

### 2. Event Handlers

```teal
local record EventEmitter
   on: function(self: EventEmitter, event: string, handler: function(data: string): void): void
end

local emitter: EventEmitter = {}

function emitter:on(event: string, handler: function(data: string): void)
   -- Implementation
end

-- Parameter type 'data' is inferred as 'string'
emitter:on("message", function(data) print(data) end)
```

### 3. Higher-Order Functions

```teal
local function compose(f: function(x: number): number, g: function(x: number): number): function(x: number): number
   -- Parameter types are inferred from the expected function signatures
   return function(x) return f(g(x)) end
end

local add_one = function(x) return x + 1 end
local double = function(x) return x * 2 end
local composed = compose(add_one, double)
```

### 4. Table Constructors

```teal
local record Callbacks
   on_success: function(result: string): void
   on_error: function(error: string): void
end

local callbacks: Callbacks = {
   -- Parameter types are inferred from the record field types
   on_success = function(result) print(result) end,
   on_error = function(error) print(error) end,
}
```

### 5. Generic Functions

```teal
local function apply<T, U>(f: function(x: T): U, x: T): U
   return f(x)
end

-- Parameter type is inferred as 'number' from generic context
local result = apply(function(x) return x + 1 end, 42)
```

## Mixed Explicit and Inferred Parameters

You can mix explicit and inferred parameter types:

```teal
local function process(f: function(x: number, y: string): string): string
   return f(42, "test")
end

-- First parameter type is explicit, second is inferred
local result = process(function(x: number, y) return y .. tostring(x) end)
```

## Type Safety

Contextual typing maintains full type safety. Type mismatches are still caught:

```teal
local f: function(x: number): number = function(x) 
   return "string"  -- Error: expected number, got string
end
```

Parameter types are enforced in the function body:

```teal
local f: function(x: number): number = function(x) 
   return x:upper()  -- Error: number has no method 'upper'
end
```

## Backward Compatibility

Contextual typing is fully backward compatible. Existing code with explicit type annotations continues to work unchanged:

```teal
-- This still works exactly as before
local f: function(x: number): number = function(x: number): number 
   return x + 1 
end
```

## Error Messages

When contextual typing fails or produces type errors, clear error messages are provided:

### No Contextual Information

```teal
local f = function(x) return x + 1 end  -- Error: cannot infer parameter types without context
```

**Suggestion:** Provide explicit type annotations or use the function in a context that provides type information.

### Type Mismatch

```teal
local f: function(x: number): number = function(x) 
   return "string"  -- Error: expected number, got string
end
```

**Suggestion:** Check the inferred type and ensure the function body returns the correct type.

### Incompatible Signature

```teal
local f: function(x: number, y: string): string = function(x) 
   return "result"  -- Error: parameter count mismatch
end
```

**Suggestion:** Ensure the function has the correct number of parameters.

## Performance Characteristics

Contextual typing is designed to have minimal performance impact:

- **Inference Time:** Typically < 1ms per function literal
- **Memory Overhead:** Minimal, only storing inference metadata
- **Caching:** Repeated inferences are cached for performance
- **Recursion Limits:** Prevents infinite loops with depth limits

## Advanced Patterns

### Nested Callbacks

```teal
local function outer(f: function(g: function(x: number): number): number): number
   return f(function(x) return x * 2 end)
end

-- Both function literals have their types inferred
local result = outer(function(g) return g(5) end)
```

### Union Types

```teal
local function process(f: function(x: number | string): boolean): boolean
   return f(42) and f("test")
end

-- Parameter type is inferred as 'number | string'
local result = process(function(x) return true end)
```

### Type Aliases

```teal
local type NumberTransform = function(x: number): number

local function apply(f: NumberTransform): number
   return f(42)
end

-- Parameter type is inferred from the type alias
local result = apply(function(x) return x + 1 end)
```

## Troubleshooting

### Issue: "Cannot infer parameter types"

**Cause:** The function literal is not used in a context that provides type information.

**Solution:** Either provide explicit type annotations or use the function in a context with a known function type.

```teal
-- This fails:
local f = function(x) return x + 1 end

-- This works:
local f: function(number): number = function(x) return x + 1 end

-- This also works:
local function apply(f: function(number): number): number
   return f(42)
end
apply(function(x) return x + 1 end)
```

### Issue: Type mismatch in function body

**Cause:** The inferred parameter type doesn't match how it's used in the function body.

**Solution:** Check the expected function type and ensure your function body uses the parameters correctly.

```teal
-- This fails:
local f: function(number): number = function(x) 
   return x:upper()  -- Error: number has no method 'upper'
end

-- This works:
local f: function(number): number = function(x) 
   return x + 1
end
```

### Issue: Parameter count mismatch

**Cause:** The function literal has a different number of parameters than expected.

**Solution:** Ensure the function has the correct number of parameters.

```teal
-- This fails:
local f: function(number, string): string = function(x) 
   return "result"
end

-- This works:
local f: function(number, string): string = function(x, y) 
   return y
end
```

## Integration with IDE

Most IDEs with Teal support will show inferred parameter types in:

- **Hover Information:** Hover over a parameter to see its inferred type
- **Autocomplete:** Suggestions based on inferred parameter types
- **Error Diagnostics:** Clear error messages with inferred types highlighted

## See Also

- [Functions](functions.md) - Function types and declarations
- [Generics](generics.md) - Generic type parameters
- [Type System](types_in_teal.md) - Teal's type system overview
