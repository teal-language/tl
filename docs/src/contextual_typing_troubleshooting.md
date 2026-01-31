# Contextual Typing Troubleshooting Guide

## Common Issues and Solutions

### 1. "Cannot infer parameter types: no contextual type information available"

**Error Message:**
```
Error: Cannot infer parameter types: no contextual type information available
Suggestion: Provide explicit type annotations or use the function in a context that provides type information
```

**Cause:** The function literal is not used in a context where the expected type is known.

**Examples:**

```teal
-- ❌ This fails - no context
local f = function(x) return x + 1 end

-- ✅ This works - explicit type annotation
local f: function(number): number = function(x) return x + 1 end

-- ✅ This works - context from function parameter
local function apply(f: function(number): number): number
   return f(42)
end
apply(function(x) return x + 1 end)

-- ✅ This works - context from assignment
local f: function(number): number = function(x) return x + 1 end
```

**Solutions:**
1. Add explicit type annotations to the function literal
2. Use the function in a context that provides type information (function call, assignment, etc.)
3. Assign the function to a variable with an explicit type annotation

---

### 2. "Parameter count mismatch: function has X parameters, expected Y"

**Error Message:**
```
Error: Parameter count mismatch: function has 1 parameters, expected 2
```

**Cause:** The function literal has a different number of parameters than the expected function type.

**Examples:**

```teal
-- ❌ This fails - wrong parameter count
local f: function(number, string): string = function(x) 
   return "result"
end

-- ✅ This works - correct parameter count
local f: function(number, string): string = function(x, y) 
   return y
end

-- ✅ This works - explicit types match
local f: function(number, string): string = function(x: number, y: string) 
   return y
end
```

**Solutions:**
1. Ensure the function has the correct number of parameters
2. Check the expected function type signature
3. Add or remove parameters as needed

---

### 3. "Type mismatch: declared X, expected Y"

**Error Message:**
```
Error: Parameter 1 type mismatch: declared string, expected number
```

**Cause:** An explicitly typed parameter doesn't match the expected type from the context.

**Examples:**

```teal
-- ❌ This fails - explicit type doesn't match expected
local f: function(number): number = function(x: string) 
   return 0
end

-- ✅ This works - explicit type matches expected
local f: function(number): number = function(x: number) 
   return x + 1
end

-- ✅ This works - let inference handle it
local f: function(number): number = function(x) 
   return x + 1
end
```

**Solutions:**
1. Change the explicit type to match the expected type
2. Remove the explicit type and let contextual typing infer it
3. Check the expected function type signature

---

### 4. "Type mismatch in function body: expected X, got Y"

**Error Message:**
```
Error: Type mismatch: expected number, got string
```

**Cause:** The function body returns or uses a value of the wrong type.

**Examples:**

```teal
-- ❌ This fails - wrong return type
local f: function(number): number = function(x) 
   return "string"
end

-- ❌ This fails - wrong operation on parameter
local f: function(number): number = function(x) 
   return x:upper()  -- number has no method 'upper'
end

-- ✅ This works - correct return type
local f: function(number): number = function(x) 
   return x + 1
end

-- ✅ This works - correct operation on parameter
local f: function(string): string = function(x) 
   return x:upper()
end
```

**Solutions:**
1. Ensure the function body returns the correct type
2. Use operations appropriate for the parameter type
3. Check the inferred parameter types

---

### 5. "Ambiguous inference: multiple possible types"

**Error Message:**
```
Error: Ambiguous inference: multiple possible types
Suggestion: Specify explicit types to resolve ambiguity or provide more context
```

**Cause:** The context doesn't provide enough information to uniquely determine the type.

**Examples:**

```teal
-- ❌ This might be ambiguous in complex scenarios
local f = function(x) return x end

-- ✅ This works - explicit type annotation
local f: function(number): number = function(x) return x end

-- ✅ This works - clear context
local function apply(f: function(number): number): number
   return f(42)
end
apply(function(x) return x end)
```

**Solutions:**
1. Add explicit type annotations
2. Provide more context (use in a function call, assignment, etc.)
3. Use generic type parameters to clarify the type

---

### 6. "Generic constraint not satisfied"

**Error Message:**
```
Error: Generic constraint not satisfied: inferred X, expected Y
```

**Cause:** The inferred type doesn't satisfy the generic type constraints.

**Examples:**

```teal
-- ❌ This fails - type doesn't satisfy constraint
local function process<T: number>(f: function(x: T): T): T
   return f(42)
end
process(function(x: string) return x end)

-- ✅ This works - type satisfies constraint
local function process<T: number>(f: function(x: T): T): T
   return f(42)
end
process(function(x: number) return x end)

-- ✅ This works - inference satisfies constraint
local function process<T: number>(f: function(x: T): T): T
   return f(42)
end
process(function(x) return x end)  -- x is inferred as number
```

**Solutions:**
1. Ensure the inferred type satisfies the generic constraints
2. Add explicit type annotations if needed
3. Check the generic type bounds

---

### 7. "Recursive type depth exceeded"

**Error Message:**
```
Error: Inference depth limit exceeded (10)
```

**Cause:** The inference process encountered deeply nested types that exceeded the recursion limit.

**Examples:**

```teal
-- ❌ This might exceed depth limit with very deep nesting
local function level1(f: function(g: function(h: function(...): ...): ...): ...): ...
   -- Very deeply nested
end

-- ✅ This works - reasonable nesting depth
local function level1(f: function(g: function(x: number): number): number): number
   return f(function(x) return x * 2 end)
end
```

**Solutions:**
1. Reduce the nesting depth of function types
2. Break complex nested functions into simpler components
3. Use type aliases to simplify complex types

---

### 8. "Mixed parameter conflict"

**Error Message:**
```
Error: Mixed parameter conflict: explicit type conflicts with inferred type
```

**Cause:** An explicitly typed parameter conflicts with the expected type from context.

**Examples:**

```teal
-- ❌ This fails - explicit type conflicts with expected
local f: function(number, string): string = function(x: string, y) 
   return y
end

-- ✅ This works - explicit type matches expected
local f: function(number, string): string = function(x: number, y) 
   return y
end

-- ✅ This works - let inference handle it
local f: function(number, string): string = function(x, y) 
   return y
end
```

**Solutions:**
1. Ensure explicit types match the expected types
2. Remove explicit types and let inference handle it
3. Check the expected function type signature

---

## Performance Issues

### Issue: Slow Type Checking

**Cause:** Contextual typing inference is taking too long.

**Solutions:**
1. Check for deeply nested function types
2. Simplify complex generic type scenarios
3. Use type aliases to reduce complexity
4. Consider breaking large functions into smaller ones

### Issue: High Memory Usage

**Cause:** Inference metadata is consuming too much memory.

**Solutions:**
1. Reduce the number of function literals with contextual typing
2. Use explicit type annotations for frequently used functions
3. Break large files into smaller modules

---

## Debugging Tips

### 1. Enable Verbose Error Messages

Use the `--verbose` flag when running the type checker:

```bash
tl check --verbose myfile.tl
```

### 2. Check Inferred Types

Hover over parameters in your IDE to see the inferred types.

### 3. Add Explicit Types for Debugging

Temporarily add explicit type annotations to see what types are being inferred:

```teal
-- Add explicit types to debug
local f: function(number): number = function(x: number) 
   return x + 1
end
```

### 4. Simplify Complex Code

Break down complex nested functions into simpler components:

```teal
-- Instead of:
local result = outer(function(g) return g(function(x) return x * 2 end) end)

-- Try:
local inner = function(x) return x * 2 end
local middle = function(g) return g(inner) end
local result = outer(middle)
```

### 5. Check Type Aliases

Ensure type aliases are correctly defined:

```teal
local type NumberTransform = function(x: number): number

-- Verify the type alias is used correctly
local f: NumberTransform = function(x) return x + 1 end
```

---

## Best Practices

### 1. Use Contextual Typing for Callbacks

```teal
-- ✅ Good - use contextual typing for callbacks
local function filter(items: {number}, predicate: function(x: number): boolean): {number}
   local result: {number} = {}
   for i, item in ipairs(items) do
      if predicate(item) then
         table.insert(result, item)
      end
   end
   return result
end

local evens = filter(numbers, function(x) return x % 2 == 0 end)
```

### 2. Use Explicit Types for Complex Functions

```teal
-- ✅ Good - use explicit types for complex functions
local f: function(number, string, boolean): string = function(x: number, y: string, z: boolean): string
   return y .. tostring(x) .. tostring(z)
end
```

### 3. Use Type Aliases for Repeated Function Types

```teal
-- ✅ Good - use type aliases
local type Predicate<T> = function(x: T): boolean

local function filter<T>(items: {T}, predicate: Predicate<T>): {T}
   -- Implementation
end
```

### 4. Mix Explicit and Inferred Types Carefully

```teal
-- ✅ Good - mix when it makes sense
local f: function(number, string): string = function(x: number, y) 
   return y .. tostring(x)
end
```

### 5. Document Complex Type Inference

```teal
-- ✅ Good - document complex inference
-- The callback parameter type is inferred from the expected function signature
local function apply(f: function(x: number): number): number
   return f(42)
end
```

---

## Getting Help

If you encounter issues not covered here:

1. Check the [Contextual Typing Documentation](contextual_typing.md)
2. Review the [Functions Documentation](functions.md)
3. Check the [Generics Documentation](generics.md)
4. Report issues on the [Teal GitHub Repository](https://github.com/teal-language/teal)
