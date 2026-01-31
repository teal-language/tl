-- Test runner for backward compatibility spec
package.path = package.path .. ";./?.lua;./?/init.lua"

-- Mock busted functions for basic testing
local function describe(name, func)
   print("\n" .. string.rep("=", 60))
   print("DESCRIBE: " .. name)
   print(string.rep("=", 60))
   func()
end

local function it(name, func)
   print("\n  IT: " .. name)
   local success, err = pcall(func)
   if success then
      print("    ✓ PASS")
      return true
   else
      print("    ✗ FAIL")
      print("    Error: " .. tostring(err))
      return false
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
   same = assert_same
}

-- Load and run the test
print("\n" .. string.rep("*", 60))
print("BACKWARD COMPATIBILITY TEST SUITE")
print(string.rep("*", 60))

local success, err = pcall(function()
   require("spec.lang.contextual_typing.backward_compatibility_spec")
end)

if not success then
   print("\n✗ Test suite failed with error:")
   print(err)
   os.exit(1)
else
   print("\n" .. string.rep("*", 60))
   print("TEST SUITE COMPLETED SUCCESSFULLY")
   print(string.rep("*", 60))
   os.exit(0)
end
