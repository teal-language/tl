-- Test runner for generic constraint satisfaction spec
package.path = package.path .. ";./?.lua;./?/init.lua"

-- Mock busted functions for basic testing
local function describe(name, func)
   print("Running: " .. name)
   func()
end

local function it(name, func)
   print("  Test: " .. name)
   local success, err = pcall(func)
   if success then
      print("    PASS")
   else
      print("    FAIL: " .. tostring(err))
      print("    Stack: " .. debug.traceback())
   end
end

local function assert_equal(expected, actual, message)
   if expected ~= actual then
      error((message or "Assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
   end
end

local function assert_is_true(value, message)
   if not value then
      error((message or "Assertion failed") .. ": expected true, got " .. tostring(value))
   end
end

local function assert_is_false(value, message)
   if value then
      error((message or "Assertion failed") .. ": expected false, got " .. tostring(value))
   end
end

local function assert_is_not_nil(value, message)
   if value == nil then
      error((message or "Assertion failed") .. ": expected non-nil value")
   end
end

local function assert_same(expected, actual, message)
   -- Simple equality check for tables
   if type(expected) == "table" and type(actual) == "table" then
      if #expected ~= #actual then
         error((message or "Assertion failed") .. ": table lengths differ")
      end
      for i, v in ipairs(expected) do
         if v ~= actual[i] then
            error((message or "Assertion failed") .. ": table elements differ at index " .. i)
         end
      end
   else
      assert_equal(expected, actual, message)
   end
end

-- Set up global assert functions
_G.describe = describe
_G.it = it
_G.assert = {
   equal = assert_equal,
   is_true = assert_is_true,
   is_false = assert_is_false,
   is_not_nil = assert_is_not_nil,
   same = assert_same
}

-- Load and run the test
print("Loading generic constraint satisfaction test...")
require("spec.lang.contextual_typing.generic_constraint_satisfaction_spec")
print("Test completed.")
