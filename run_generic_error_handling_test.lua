-- Test runner for generic error handling spec
package.path = package.path .. ";./?.lua;./?/init.lua"

-- Mock busted functions for basic testing
local function describe(name, func)
   print("\n" .. name)
   func()
end

local function it(name, func)
   print("  ✓ " .. name)
   local success, err = pcall(func)
   if success then
      -- Test passed
   else
      print("    ✗ FAIL: " .. tostring(err))
      error(err)
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

local function assert_is_nil(value, message)
   if value ~= nil then
      error((message or "Assertion failed") .. ": expected nil, got " .. tostring(value))
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
   is_nil = assert_is_nil,
   same = assert_same
}

-- Load and run the test
print("=" .. string.rep("=", 78))
print("Generic Error Handling Test Suite")
print("=" .. string.rep("=", 78))

local success, err = pcall(function()
   require("spec.lang.contextual_typing.generic_error_handling_spec")
end)

if success then
   print("\n" .. "=" .. string.rep("=", 78))
   print("All tests completed successfully!")
   print("=" .. string.rep("=", 78))
else
   print("\n" .. "=" .. string.rep("=", 78))
   print("Test failed with error:")
   print(tostring(err))
   print("=" .. string.rep("=", 78))
   os.exit(1)
end
