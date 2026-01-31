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

-- Mock util module
local util = {
   contains = function(list, value)
      for _, v in ipairs(list) do
         if v == value then
            return true
         end
      end
      return false
   end
}

-- Load and run the test
local spec_util = {
   contains = util.contains
}

-- Create a mock for the spec.util module
package.loaded["spec.util"] = spec_util

-- Load the test file
local test_file = "spec/lang/contextual_typing/nested_inference_property_spec.lua"
local test_func, load_err = loadfile(test_file)

if not test_func then
   print("Error loading test file: " .. tostring(load_err))
   os.exit(1)
end

-- Set up globals for the test
_G.describe = describe
_G.it = it
_G.assert = {
   equal = assert_equal,
   is_true = assert_is_true,
   is_not_nil = assert_is_not_nil,
   fail = assert_fail
}

-- Run the test
local success, err = pcall(test_func)

if not success then
   print("\nError running tests: " .. tostring(err))
   os.exit(1)
end

-- Print summary
print("\n" .. string.rep("=", 50))
print("Test Summary")
print(string.rep("=", 50))
print("Total tests: " .. test_count)
print("Passed: " .. pass_count)
print("Failed: " .. fail_count)

if fail_count > 0 then
   print("\nFailures:")
   for _, failure in ipairs(failures) do
      print("  - " .. failure.name)
      print("    " .. failure.error)
   end
   os.exit(1)
else
   print("\nAll tests passed!")
   os.exit(0)
end
