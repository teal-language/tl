#!/usr/bin/env lua

-- Set up package path
package.path = package.path .. ";./?.lua;./?/init.lua"

-- Mock busted functions for basic testing
local test_count = 0
local pass_count = 0
local fail_count = 0
local failures = {}

local function describe(name, func)
   print("\n" .. name)
   func()
end

local function it(name, func)
   test_count = test_count + 1
   local success, err = pcall(func)
   if success then
      pass_count = pass_count + 1
      print("  ✓ " .. name)
   else
      fail_count = fail_count + 1
      print("  ✗ " .. name)
      table.insert(failures, { name = name, error = tostring(err) })
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

local function assert_is_not_nil(value, message)
   if value == nil then
      error((message or "Assertion failed") .. ": expected non-nil value")
   end
end

local function assert_fail(message)
   error(message or "Assertion failed")
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
   is_not_nil = assert_is_not_nil,
   same = assert_same,
   fail = assert_fail
}

-- Load and run the test
print("Loading type safety preservation test...")
require("spec.lang.contextual_typing.type_safety_preservation_spec")

-- Print summary
print("\n" .. string.rep("=", 60))
print("Test Summary:")
print("  Total: " .. test_count)
print("  Passed: " .. pass_count)
print("  Failed: " .. fail_count)

if fail_count > 0 then
   print("\nFailures:")
   for _, failure in ipairs(failures) do
      print("  - " .. failure.name)
      print("    " .. failure.error:sub(1, 100))
   end
end

print(string.rep("=", 60))

os.exit(fail_count == 0 and 0 or 1)
