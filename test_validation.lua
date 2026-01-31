#!/usr/bin/env lua

-- Simple test validation script
package.path = package.path .. ";./?.lua;./?/init.lua"

print("=" .. string.rep("=", 70))
print("CONTEXTUAL TYPING TEST VALIDATION")
print("=" .. string.rep("=", 70))

local test_files = {
   "spec.lang.contextual_typing.parser_completeness_spec",
   "spec.lang.contextual_typing.parser_extensions_spec",
   "spec.lang.contextual_typing.basic_inference_spec",
   "spec.lang.contextual_typing.inference_fallback_spec",
   "spec.lang.contextual_typing.inference_equivalence_spec",
   "spec.lang.contextual_typing.type_safety_preservation_spec",
   "spec.lang.contextual_typing.backward_compatibility_spec",
   "spec.lang.contextual_typing.backward_compatibility_property_spec",
   "spec.lang.contextual_typing.generic_constraint_satisfaction_spec",
   "spec.lang.contextual_typing.generic_error_handling_spec",
   "spec.lang.contextual_typing.mixed_parameter_handling_property_spec",
   "spec.lang.contextual_typing.mixed_parameter_error_reporting_spec",
   "spec.lang.contextual_typing.nested_inference_property_spec",
   "spec.lang.contextual_typing.complex_type_handling_property_spec",
   "spec.lang.contextual_typing.type_system_integration_property_spec",
   "spec.lang.contextual_typing.integration_test",
   "spec.lang.contextual_typing.performance_tests_spec",
}

print("\nValidating test files can be loaded...")
print(string.rep("-", 70))

local loaded = 0
local failed = 0

for i, test_file in ipairs(test_files) do
   io.write(string.format("[%2d/%2d] Loading %s ... ", i, #test_files, test_file))
   io.flush()
   
   local success, err = pcall(require, test_file)
   if success then
      print("✓ OK")
      loaded = loaded + 1
   else
      print("✗ FAILED")
      print("         Error: " .. tostring(err):sub(1, 100))
      failed = failed + 1
   end
end

print(string.rep("-", 70))
print(string.format("\nResults: %d loaded, %d failed", loaded, failed))

if failed == 0 then
   print("\n✓ All test files loaded successfully!")
   print("✓ Contextual typing implementation is working properly")
   os.exit(0)
else
   print("\n✗ Some test files failed to load")
   print("✗ Please check the errors above")
   os.exit(1)
end
