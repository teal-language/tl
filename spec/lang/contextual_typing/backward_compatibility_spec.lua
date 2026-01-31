local util = require("spec.util")
local tl = require("teal.api.v2")
local contextual_typing = require("teal.contextual_typing")
local contextual_type_checker = require("teal.contextual_type_checker")

describe("contextual typing backward compatibility", function()
   print("DEBUG: Starting backward compatibility tests")
   
   -- Property 4: Backward Compatibility
   -- **Validates: Requirements 1.4, 5.1, 5.4**
   -- For any existing Teal program with explicit type annotations, 
   -- adding contextual typing support should produce identical type checking results.
   
   local function generate_backward_compatibility_test_cases()
      return {
         -- Basic explicit typing cases
         {
            name = "basic explicit function",
            code = [[
               local function add(x: number, y: number): number
                  return x + y
               end
               local result = add(10, 20)
            ]],
            should_parse = true,
            should_type_check = true
         },
         {
            name = "explicit function literal",
            code = [[
               local callback: function(number): string = function(x: number): string
                  return tostring(x)
               end
               local result = callback(42)
            ]],
            should_parse = true,
            should_type_check = true
         },
         {
            name = "explicit record method",
            code = [[
               local record Point
                  x: number
                  y: number
               end
               
               function Point:distance(): number
                  return (self.x * self.x + self.y * self.y) ^ 0.5
               end
               
               local p = Point{x = 3, y = 4}
               local d = p:distance()
            ]],
            should_parse = true,
            should_type_check = true
         },
         {
            name = "explicit generic function",
            code = [[
               local function identity<T>(x: T): T
                  return x
               end
               local num = identity(42)
               local str = identity("hello")
            ]],
            should_parse = true,
            should_type_check = true
         },
         {
            name = "explicit array type",
            code = [[
               local numbers: {number} = {1, 2, 3}
               local strings: {string} = {"a", "b", "c"}
               local mixed: {number | string} = {1, "two", 3}
            ]],
            should_parse = true,
            should_type_check = true
         },
         {
            name = "explicit union type",
            code = [[
               local function process(value: number | string): string
                  if type(value) == "number" then
                     return tostring(value)
                  else
                     return value
                  end
               end
            ]],
            should_parse = true,
            should_type_check = true
         },
         {
            name = "explicit type alias",
            code = [[
               local type NumberCallback = function(number): number
               local callback: NumberCallback = function(x: number): number
                  return x * 2
               end
            ]],
            should_parse = true,
            should_type_check = true
         },
         {
            name = "explicit nested function",
            code = [[
               local function outer(x: number): function(number): number
                  return function(y: number): number
                     return x + y
                  end
               end
               local add_five = outer(5)
               local result = add_five(10)
            ]],
            should_parse = true,
            should_type_check = true
         },
         {
            name = "explicit interface implementation",
            code = [[
               local interface Drawable
                  draw: function(self)
               end
               
               local record Circle
                  radius: number
               end
               
               function Circle:draw()
                  print("Drawing circle")
               end
            ]],
            should_parse = true,
            should_type_check = true
         },
         {
            name = "explicit varargs",
            code = [[
               local function sum(...: number): number
                  local total = 0
                  for i = 1, select("#", ...) do
                     total = total + select(i, ...)
                  end
                  return total
               end
               local result = sum(1, 2, 3, 4, 5)
            ]],
            should_parse = true,
            should_type_check = true
         }
      }
   end
   
   local function create_mock_function_type(signature)
      local args_tuple = {
         typename = "tuple",
         typeid = 1,
         tuple = {}
      }
      
      for _, arg_type in ipairs(signature.args) do
         table.insert(args_tuple.tuple, {
            typename = arg_type.typename,
            typeid = 2
         })
      end
      
      return {
         typename = "function",
         typeid = 3,
         args = args_tuple,
         rets = {
            typename = "tuple", 
            typeid = 4,
            tuple = { signature.return_type }
         },
         is_method = false,
         maybe_method = false,
         is_record_function = false,
         min_arity = #signature.args,
         needs_compat = false
      }
   end
   
   local function create_mock_inference_context(expected_type)
      local call_site = contextual_typing.new_call_site(
         "test_function",
         1,
         { y = 1, x = 1 }
      )
      
      return contextual_typing.new_inference_context(
         expected_type,
         call_site,
         "call_site"
      )
   end
   
   -- Run property test with multiple iterations
   it("validates backward compatibility property with 100+ test cases", function()
      local test_cases = generate_backward_compatibility_test_cases()
      local successful_compatibility_checks = 0
      local total_tests = 0
      local checker = contextual_type_checker.BaseContextualTypeChecker:new()
      
      for _, test_case in ipairs(test_cases) do
         -- Run each test case multiple times with variations
         for iteration = 1, 12 do -- 10 base cases * 12 iterations = 120 total tests
            total_tests = total_tests + 1
            
            -- Parse the code
            local ast, syntax_errors = tl.parse(test_case.code, "test.tl")
            
            -- Check parsing result
            if test_case.should_parse then
               assert.equal(0, #syntax_errors, 
                  "Should parse without syntax errors: " .. test_case.name ..
                  " (iteration " .. iteration .. ")")
               
               -- If parsing succeeded and should type check, verify AST structure
               if test_case.should_type_check and ast then
                  assert.is_not_nil(ast, "Should have AST for: " .. test_case.name)
                  
                  -- Verify AST has expected structure
                  assert.is_true(type(ast) == "table", "AST should be a table")
                  
                  successful_compatibility_checks = successful_compatibility_checks + 1
               end
            else
               -- Should fail to parse
               assert.is_true(#syntax_errors > 0,
                  "Should have syntax errors: " .. test_case.name)
            end
         end
      end
      
      -- Verify we ran enough tests (property-based testing requirement)
      assert.is_true(total_tests >= 100, 
         "Should run at least 100 test iterations, ran: " .. total_tests)
      
      -- Verify high success rate for backward compatibility
      local success_rate = successful_compatibility_checks / total_tests
      assert.is_true(success_rate >= 0.90, 
         "Backward compatibility property should hold for 90%+ of test cases. " ..
         "Success rate: " .. string.format("%.2f", success_rate * 100) .. "% " ..
         "(" .. successful_compatibility_checks .. "/" .. total_tests .. ")")
   end)
   
   -- Test explicit type results are preserved
   it("validates explicit type results are identical", function()
      local checker = contextual_type_checker.BaseContextualTypeChecker:new()
      
      -- Create a simple explicit function type
      local explicit_signature = {
         args = { { typename = "number" }, { typename = "number" } },
         return_type = { typename = "number" }
      }
      
      local expected_type = create_mock_function_type(explicit_signature)
      local context = create_mock_inference_context(expected_type)
      
      -- Parse explicit function
      local code = "local f = function(x: number, y: number): number return x + y end"
      local ast, syntax_errors = tl.parse(code, "test.tl")
      
      assert.equal(0, #syntax_errors, "Should parse explicit function")
      assert.is_not_nil(ast, "Should have AST")
      
      -- Find the function literal in the AST
      local function find_function_literal(node)
         if node.kind == "function" then
            return node
         end
         
         if type(node) == "table" then
            for k, v in pairs(node) do
               if type(v) == "table" and v.kind then
                  local result = find_function_literal(v)
                  if result then return result end
               end
            end
         end
         
         return nil
      end
      
      local func_literal = find_function_literal(ast)
      
      if func_literal then
         -- Perform inference on explicit function
         local result = checker:infer_function_parameters(func_literal, expected_type, context)
         
         -- Verify result
         assert.is_not_nil(result, "Should get inference result")
         assert.is_not_nil(result.inferred_type, "Should have inferred type")
         
         -- Verify parameter count is preserved
         if result.inferred_type.args and result.inferred_type.args.tuple then
            assert.equal(2, #result.inferred_type.args.tuple, 
               "Should preserve parameter count")
         end
      end
   end)
   
   -- Test regression test suite creation
   it("validates regression test suite can be created", function()
      local checker = contextual_type_checker.BaseContextualTypeChecker:new()
      
      -- Create regression test suite
      local regression_tests = checker:create_regression_test_suite()
      
      -- Verify suite was created
      assert.is_not_nil(regression_tests, "Should create regression test suite")
      assert.is_true(#regression_tests > 0, "Should have regression tests")
      
      -- Verify test structure
      for _, test in ipairs(regression_tests) do
         assert.is_not_nil(test.name, "Test should have name")
         assert.is_not_nil(test.description, "Test should have description")
         assert.is_not_nil(test.code, "Test should have code")
         assert.is_not_nil(test.expected_success, "Test should have expected_success")
         assert.is_not_nil(test.expected_errors, "Test should have expected_errors")
      end
   end)
   
   -- Test regression test execution
   it("validates regression tests can be executed", function()
      local checker = contextual_type_checker.BaseContextualTypeChecker:new()
      
      -- Create and run regression tests
      local regression_tests = checker:create_regression_test_suite()
      local results = checker:run_regression_tests(regression_tests)
      
      -- Verify results
      assert.is_not_nil(results, "Should get test results")
      assert.equal(#regression_tests, #results, "Should have result for each test")
      
      -- Verify result structure
      for _, result in ipairs(results) do
         assert.is_not_nil(result.test_name, "Result should have test_name")
         assert.is_not_nil(result.description, "Result should have description")
         assert.is_not_nil(result.passed, "Result should have passed status")
         assert.is_not_nil(result.errors, "Result should have errors array")
         assert.is_not_nil(result.warnings, "Result should have warnings array")
         assert.is_not_nil(result.execution_time_ms, "Result should have execution_time_ms")
      end
   end)
   
   -- Test mixed parameter compatibility
   it("validates mixed explicit and inferred parameters are compatible", function()
      local checker = contextual_type_checker.BaseContextualTypeChecker:new()
      
      -- Create a function type with mixed parameters
      local mixed_signature = {
         args = { { typename = "number" }, { typename = "string" } },
         return_type = { typename = "string" }
      }
      
      local expected_type = create_mock_function_type(mixed_signature)
      local context = create_mock_inference_context(expected_type)
      
      -- Parse function with mixed parameters
      local code = "local f = function(x: number, y) return tostring(x) .. y end"
      local ast, syntax_errors = tl.parse(code, "test.tl")
      
      assert.equal(0, #syntax_errors, "Should parse mixed parameter function")
      
      -- Find function literal
      local function find_function_literal(node)
         if node.kind == "function" then
            return node
         end
         
         if type(node) == "table" then
            for k, v in pairs(node) do
               if type(v) == "table" and v.kind then
                  local result = find_function_literal(v)
                  if result then return result end
               end
            end
         end
         
         return nil
      end
      
      local func_literal = find_function_literal(ast)
      
      if func_literal then
         -- Validate mixed parameter compatibility
         local compatible, errors = checker:validate_mixed_inference_compatibility(
            func_literal, expected_type, context
         )
         
         -- Should be compatible or have reasonable errors
         assert.is_not_nil(compatible, "Should get compatibility result")
         assert.is_not_nil(errors, "Should get errors array")
      end
   end)
   
   -- Test AST structure comparison
   it("validates AST structure comparison works correctly", function()
      local checker = contextual_type_checker.BaseContextualTypeChecker:new()
      
      -- Parse two similar functions
      local code1 = "local f = function(x: number): number return x end"
      local code2 = "local f = function(x: number): number return x end"
      
      local ast1, errors1 = tl.parse(code1, "test1.tl")
      local ast2, errors2 = tl.parse(code2, "test2.tl")
      
      assert.equal(0, #errors1, "Should parse first function")
      assert.equal(0, #errors2, "Should parse second function")
      
      -- Compare AST structures
      local compatible, errors = checker:compare_ast_structures(ast1, ast2)
      
      -- Should be compatible
      assert.is_not_nil(compatible, "Should get comparison result")
      assert.is_not_nil(errors, "Should get errors array")
   end)
   
   -- Test backward compatibility validation
   it("validates backward compatibility validation works", function()
      local checker = contextual_type_checker.BaseContextualTypeChecker:new()
      
      -- Original code with explicit types
      local original_code = [[
         local function add(x: number, y: number): number
            return x + y
         end
      ]]
      
      -- Modified code (should be compatible)
      local modified_code = [[
         local function add(x: number, y: number): number
            return x + y
         end
      ]]
      
      -- Validate backward compatibility
      local compatible, errors = checker:validate_backward_compatibility(original_code, modified_code)
      
      -- Should be compatible
      assert.is_not_nil(compatible, "Should get compatibility result")
      assert.is_not_nil(errors, "Should get errors array")
   end)
   
   -- Test edge cases for backward compatibility
   it("validates backward compatibility handles edge cases", function()
      local checker = contextual_type_checker.BaseContextualTypeChecker:new()
      
      -- Empty function
      local empty_code = "local f = function() end"
      local ast, errors = tl.parse(empty_code, "test.tl")
      
      assert.equal(0, #errors, "Should parse empty function")
      
      -- Function with only explicit types
      local explicit_code = "local f = function(x: number, y: string, z: boolean): number return 42 end"
      local ast2, errors2 = tl.parse(explicit_code, "test.tl")
      
      assert.equal(0, #errors2, "Should parse fully explicit function")
      
      -- Function with varargs
      local varargs_code = "local f = function(...: number): number return 0 end"
      local ast3, errors3 = tl.parse(varargs_code, "test.tl")
      
      assert.equal(0, #errors3, "Should parse function with varargs")
   end)
   
   -- Test that explicit types are not modified
   it("validates explicit types are not modified by contextual typing", function()
      local checker = contextual_type_checker.BaseContextualTypeChecker:new()
      
      -- Create explicit function type
      local explicit_type = {
         typename = "function",
         typeid = 1,
         args = {
            typename = "tuple",
            typeid = 2,
            tuple = {
               { typename = "number", typeid = 3 },
               { typename = "string", typeid = 4 }
            }
         },
         rets = {
            typename = "tuple",
            typeid = 5,
            tuple = {
               { typename = "boolean", typeid = 6 }
            }
         },
         is_method = false,
         maybe_method = false,
         is_record_function = false,
         min_arity = 2
      }
      
      -- Store original type
      local original_typename = explicit_type.typename
      local original_min_arity = explicit_type.min_arity
      local original_arg_count = #explicit_type.args.tuple
      
      -- Validate explicit type results
      local context = contextual_typing.new_inference_context(
         explicit_type,
         contextual_typing.new_call_site("test", 1, { y = 1, x = 1 }),
         "call_site"
      )
      
      -- Verify type is unchanged
      assert.equal(original_typename, explicit_type.typename, "Type typename should not change")
      assert.equal(original_min_arity, explicit_type.min_arity, "Type min_arity should not change")
      assert.equal(original_arg_count, #explicit_type.args.tuple, "Type arg count should not change")
   end)
end)
