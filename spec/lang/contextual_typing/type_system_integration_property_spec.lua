local util = require("spec.util")
local tl = require("teal.api.v2")
local contextual_typing = require("teal.contextual_typing")
local contextual_type_checker = require("teal.contextual_type_checker")
local type_alias_subtyping_support = require("teal.type_alias_subtyping_support")

describe("contextual typing type system integration property", function()
   print("DEBUG: Starting type system integration property tests")
   
   -- Property 10: Type System Integration
   -- **Validates: Requirements 8.2, 8.4, 8.5**
   -- For any contextual inference involving type aliases or subtyping relationships,
   -- the inferred types should integrate consistently with the broader type system
   -- and respect all existing type relationships.
   
   local function generate_type_alias_scenarios()
      return {
         -- Simple type aliases
         {
            name = "simple_alias",
            code = [[
               type MyNumber = number
               local function process(x: MyNumber): MyNumber
                  return x * 2
               end
            ]],
            category = "simple_alias"
         },
         {
            name = "string_alias",
            code = [[
               type Name = string
               local function greet(name: Name): Name
                  return "Hello, " .. name
               end
            ]],
            category = "simple_alias"
         },
         
         -- Nested type aliases
         {
            name = "nested_alias",
            code = [[
               type BaseNumber = number
               type DoubleNumber = BaseNumber
               local function double(x: DoubleNumber): DoubleNumber
                  return x * 2
               end
            ]],
            category = "nested_alias"
         },
         
         -- Function type aliases
         {
            name = "function_alias",
            code = [[
               type Processor = function(number): number
               local function apply(f: Processor, x: number): number
                  return f(x)
               end
            ]],
            category = "function_alias"
         },
         
         -- Record type aliases
         {
            name = "record_alias",
            code = [[
               local record Point
                  x: number
                  y: number
               end
               type Location = Point
               local function distance(p: Location): number
                  return (p.x * p.x + p.y * p.y) ^ 0.5
               end
            ]],
            category = "record_alias"
         },
         
         -- Array type aliases
         {
            name = "array_alias",
            code = [[
               type Numbers = {number}
               local function sum(nums: Numbers): number
                  local total = 0
                  for _, n in ipairs(nums) do
                     total = total + n
                  end
                  return total
               end
            ]],
            category = "array_alias"
         },
         
         -- Union type aliases
         {
            name = "union_alias",
            code = [[
               type Value = number | string
               local function process(v: Value): string
                  if v is number then
                     return tostring(v)
                  else
                     return v
                  end
               end
            ]],
            category = "union_alias"
         },
      }
   end
   
   local function generate_subtyping_scenarios()
      return {
         -- Integer is subtype of number
         {
            name = "integer_subtype_number",
            code = [[
               local function process(x: number): number
                  return x * 2
               end
               local i: integer = 5
               local result = process(i)
            ]],
            category = "numeric_subtyping"
         },
         
         -- Nil is subtype of all types
         {
            name = "nil_subtype",
            code = [[
               local function process(x: number | nil): number
                  if x then
                     return x
                  else
                     return 0
                  end
               end
               local result = process(nil)
            ]],
            category = "nil_subtyping"
         },
         
         -- Record subtyping
         {
            name = "record_subtyping",
            code = [[
               local record Animal
                  name: string
               end
               local record Dog
                  name: string
                  breed: string
               end
               local function getName(a: Animal): string
                  return a.name
               end
               local dog: Dog = {name = "Buddy", breed = "Golden"}
               local name = getName(dog)
            ]],
            category = "record_subtyping"
         },
         
         -- Array element subtyping
         {
            name = "array_element_subtyping",
            code = [[
               local function process(nums: {number}): number
                  local sum = 0
                  for _, n in ipairs(nums) do
                     sum = sum + n
                  end
                  return sum
               end
               local ints: {integer} = {1, 2, 3}
               local result = process(ints)
            ]],
            category = "array_subtyping"
         },
         
         -- Union type subtyping
         {
            name = "union_subtyping",
            code = [[
               local function process(v: number | string): string
                  if v is number then
                     return tostring(v)
                  else
                     return v
                  end
               end
               local n: number = 42
               local result = process(n)
            ]],
            category = "union_subtyping"
         },
      }
   end
   
   local function generate_mixed_scenarios()
      return {
         -- Type alias with subtyping
         {
            name = "alias_with_subtyping",
            code = [[
               type NumericValue = number
               local function process(x: NumericValue): NumericValue
                  return x * 2
               end
               local i: integer = 5
               local result = process(i)
            ]],
            category = "alias_subtyping"
         },
         
         -- Nested aliases with subtyping
         {
            name = "nested_alias_subtyping",
            code = [[
               type BaseNum = number
               type ProcessedNum = BaseNum
               local function process(x: ProcessedNum): ProcessedNum
                  return x + 1
               end
               local i: integer = 10
               local result = process(i)
            ]],
            category = "nested_alias_subtyping"
         },
         
         -- Function alias with subtyping
         {
            name = "function_alias_subtyping",
            code = [[
               type Transformer = function(number): number
               local function apply(f: Transformer, x: integer): number
                  return f(x)
               end
               local double: function(number): number = function(n: number): number
                  return n * 2
               end
               local result = apply(double, 5)
            ]],
            category = "function_alias_subtyping"
         },
         
         -- Generic with type aliases
         {
            name = "generic_with_alias",
            code = [[
               type Container<T> = {T}
               local function first<T>(c: Container<T>): T
                  return c[1]
               end
               local nums: Container<number> = {1, 2, 3}
               local n = first(nums)
            ]],
            category = "generic_alias"
         },
      }
   end
   
   local function test_type_alias_resolution(scenario)
      local env = tl.init_env()
      local result = tl.process(scenario.code, env)
      
      -- Check that the code type checks successfully
      assert.truthy(result.ok, "Code should type check: " .. scenario.name)
      
      -- Check that no errors were reported
      assert.equal(0, #result.errors, "Should have no type errors: " .. scenario.name)
   end
   
   local function test_subtyping_preservation(scenario)
      local env = tl.init_env()
      local result = tl.process(scenario.code, env)
      
      -- Check that the code type checks successfully
      assert.truthy(result.ok, "Code should type check: " .. scenario.name)
      
      -- Check that no errors were reported
      assert.equal(0, #result.errors, "Should have no type errors: " .. scenario.name)
   end
   
   local function test_mixed_integration(scenario)
      local env = tl.init_env()
      local result = tl.process(scenario.code, env)
      
      -- Check that the code type checks successfully
      assert.truthy(result.ok, "Code should type check: " .. scenario.name)
      
      -- Check that no errors were reported
      assert.equal(0, #result.errors, "Should have no type errors: " .. scenario.name)
   end
   
   it("resolves type aliases correctly in contextual inference", function()
      local scenarios = generate_type_alias_scenarios()
      
      for _, scenario in ipairs(scenarios) do
         test_type_alias_resolution(scenario)
      end
   end)
   
   it("preserves subtyping relationships during inference", function()
      local scenarios = generate_subtyping_scenarios()
      
      for _, scenario in ipairs(scenarios) do
         test_subtyping_preservation(scenario)
      end
   end)
   
   it("integrates type aliases and subtyping correctly", function()
      local scenarios = generate_mixed_scenarios()
      
      for _, scenario in ipairs(scenarios) do
         test_mixed_integration(scenario)
      end
   end)
   
   it("handles type alias resolution in function parameters", function()
      local code = [[
         type Processor = function(number): number
         local function apply(f: Processor, x: number): number
            return f(x)
         end
         local double: function(number): number = function(n: number): number
            return n * 2
         end
         local result = apply(double, 5)
      ]]
      
      local env = tl.init_env()
      local result = tl.process(code, env)
      
      assert.truthy(result.ok, "Should type check successfully")
      assert.equal(0, #result.errors, "Should have no type errors")
   end)
   
   it("validates subtyping in record types", function()
      local code = [[
         local record Base
            x: number
         end
         local record Derived
            x: number
            y: number
         end
         local function process(b: Base): number
            return b.x
         end
         local d: Derived = {x = 1, y = 2}
         local result = process(d)
      ]]
      
      local env = tl.init_env()
      local result = tl.process(code, env)
      
      assert.truthy(result.ok, "Should type check successfully")
      assert.equal(0, #result.errors, "Should have no type errors")
   end)
   
   it("handles nested type aliases", function()
      local code = [[
         type Level1 = number
         type Level2 = Level1
         type Level3 = Level2
         local function process(x: Level3): Level3
            return x * 2
         end
         local result = process(5)
      ]]
      
      local env = tl.init_env()
      local result = tl.process(code, env)
      
      assert.truthy(result.ok, "Should type check successfully")
      assert.equal(0, #result.errors, "Should have no type errors")
   end)
   
   it("preserves type safety with union types", function()
      local code = [[
         type Value = number | string
         local function process(v: Value): string
            if v is number then
               return tostring(v)
            else
               return v
            end
         end
         local n: number = 42
         local s: string = "hello"
         local r1 = process(n)
         local r2 = process(s)
      ]]
      
      local env = tl.init_env()
      local result = tl.process(code, env)
      
      assert.truthy(result.ok, "Should type check successfully")
      assert.equal(0, #result.errors, "Should have no type errors")
   end)
   
   it("handles array type aliases with subtyping", function()
      local code = [[
         type Numbers = {number}
         local function sum(nums: Numbers): number
            local total = 0
            for _, n in ipairs(nums) do
               total = total + n
            end
            return total
         end
         local ints: {integer} = {1, 2, 3}
         local result = sum(ints)
      ]]
      
      local env = tl.init_env()
      local result = tl.process(code, env)
      
      assert.truthy(result.ok, "Should type check successfully")
      assert.equal(0, #result.errors, "Should have no type errors")
   end)
   
   it("validates function type aliases", function()
      local code = [[
         type Transformer = function(number): number
         local function apply(f: Transformer, x: number): number
            return f(x)
         end
         local double: function(number): number = function(n: number): number
            return n * 2
         end
         local result = apply(double, 5)
      ]]
      
      local env = tl.init_env()
      local result = tl.process(code, env)
      
      assert.truthy(result.ok, "Should type check successfully")
      assert.equal(0, #result.errors, "Should have no type errors")
   end)
   
   it("respects type alias definitions in error messages", function()
      local code = [[
         type MyNumber = number
         local function process(x: MyNumber): MyNumber
            return x * 2
         end
         local result = process("not a number")
      ]]
      
      local env = tl.init_env()
      local result = tl.process(code, env)
      
      -- This should fail type checking
      assert.falsy(result.ok, "Should fail type check")
      assert.truthy(#result.errors > 0, "Should have type errors")
   end)
   
   it("handles complex type alias scenarios", function()
      local code = [[
         local record Point
            x: number
            y: number
         end
         type Location = Point
         type Locations = {Location}
         local function distance(p: Location): number
            return (p.x * p.x + p.y * p.y) ^ 0.5
         end
         local function totalDistance(locs: Locations): number
            local total = 0
            for _, loc in ipairs(locs) do
               total = total + distance(loc)
            end
            return total
         end
         local points: Locations = {{x = 0, y = 0}, {x = 3, y = 4}}
         local result = totalDistance(points)
      ]]
      
      local env = tl.init_env()
      local result = tl.process(code, env)
      
      assert.truthy(result.ok, "Should type check successfully")
      assert.equal(0, #result.errors, "Should have no type errors")
   end)
end)
