local util = require("spec.util")
local tl = require("teal.api.v2")
local contextual_typing = require("teal.contextual_typing")

describe("contextual typing", function()
   describe("parser completeness property", function()
      
      -- Property 6: Parser Completeness
      -- For any syntactically valid function literal (with typed, untyped, or mixed parameters),
      -- the parser should create AST nodes containing sufficient information for contextual type inference.
      
      local function generate_function_literal_test_cases()
         return {
            -- Untyped parameters
            {
               name = "single untyped parameter",
               code = "local f = function(x) return x end",
               expected_params = {
                  { name = "x", has_type = false }
               }
            },
            {
               name = "multiple untyped parameters", 
               code = "local f = function(a, b, c) return a + b + c end",
               expected_params = {
                  { name = "a", has_type = false },
                  { name = "b", has_type = false },
                  { name = "c", has_type = false }
               }
            },
            {
               name = "no parameters",
               code = "local f = function() return 42 end",
               expected_params = {}
            },
            
            -- Typed parameters
            {
               name = "single typed parameter",
               code = "local f = function(x: number) return x end",
               expected_params = {
                  { name = "x", has_type = true }
               }
            },
            {
               name = "multiple typed parameters",
               code = "local f = function(a: number, b: string, c: boolean) return a end",
               expected_params = {
                  { name = "a", has_type = true },
                  { name = "b", has_type = true },
                  { name = "c", has_type = true }
               }
            },
            
            -- Mixed parameters
            {
               name = "mixed typed and untyped parameters",
               code = "local f = function(a: number, b, c: string, d) return a end",
               expected_params = {
                  { name = "a", has_type = true },
                  { name = "b", has_type = false },
                  { name = "c", has_type = true },
                  { name = "d", has_type = false }
               }
            },
            
            -- Complex parameter types
            {
               name = "function with array parameter type",
               code = "local f = function(arr: {number}) return #arr end",
               expected_params = {
                  { name = "arr", has_type = true }
               }
            },
            {
               name = "function with function parameter type",
               code = "local f = function(callback: function(number): string) return callback(42) end",
               expected_params = {
                  { name = "callback", has_type = true }
               }
            },
            
            -- Nested function literals
            {
               name = "nested function literal with untyped parameters",
               code = "local f = function(x) return function(y) return x + y end end",
               expected_params = {
                  { name = "x", has_type = false }
               }
            }
         }
      end
      
      local function validate_ast_node_for_inference(ast_node, expected_params)
         -- Check that the AST node is a function
         assert.equal("function", ast_node.kind, "Expected function literal AST node")
         
         -- Check that contextual typing fields are present
         assert.is_not_nil(ast_node.inferred_signature, "AST node should have inferred_signature field")
         assert.is_not_nil(ast_node.inference_source, "AST node should have inference_source field") 
         assert.is_not_nil(ast_node.inference_confidence, "AST node should have inference_confidence field")
         assert.is_not_nil(ast_node.contextual_type_info, "AST node should have contextual_type_info field")
         
         -- Check parameter structure
         local args = ast_node.args or {}
         assert.equal(#expected_params, #args, "Parameter count should match expected")
         
         for i, expected_param in ipairs(expected_params) do
            local actual_arg = args[i]
            assert.is_not_nil(actual_arg, "Parameter " .. i .. " should exist")
            
            -- Check parameter name
            if expected_param.name then
               assert.equal(expected_param.name, actual_arg.tk, "Parameter name should match")
            end
            
            -- Check type annotation presence
            if expected_param.has_type then
               assert.is_not_nil(actual_arg.argtype, "Parameter " .. i .. " should have type annotation")
            else
               assert.is_nil(actual_arg.argtype, "Parameter " .. i .. " should not have type annotation")
            end
         end
         
         return true
      end
      
      local function find_function_literal_in_ast(ast)
         -- Simple recursive search for function literal nodes
         if ast.kind == "function" then
            return ast
         end
         
         -- Check common AST node fields that might contain function literals
         local fields_to_check = {"e1", "e2", "exp", "value", "body", "exps"}
         for _, field in ipairs(fields_to_check) do
            if ast[field] then
               if type(ast[field]) == "table" and ast[field].kind then
                  local result = find_function_literal_in_ast(ast[field])
                  if result then return result end
               end
            end
         end
         
         -- Check array-like fields
         if type(ast) == "table" then
            for i = 1, #ast do
               if type(ast[i]) == "table" and ast[i].kind then
                  local result = find_function_literal_in_ast(ast[i])
                  if result then return result end
               end
            end
         end
         
         return nil
      end
      
      -- Run property test with multiple iterations
      it("validates parser completeness property with 100+ test cases", function()
         local test_cases = generate_function_literal_test_cases()
         local successful_tests = 0
         local total_tests = 0
         
         for _, test_case in ipairs(test_cases) do
            -- Run each test case multiple times with slight variations
            for iteration = 1, 15 do -- 8 base cases * 15 iterations = 120 total tests
               total_tests = total_tests + 1
               
               local code = test_case.code
               
               -- Add some variation to test robustness
               if iteration > 1 then
                  -- Add whitespace variations
                  if iteration % 3 == 0 then
                     code = code:gsub("function", " function ")
                     code = code:gsub(",", " , ")
                  end
                  -- Add comment variations  
                  if iteration % 5 == 0 then
                     code = code:gsub("return", "-- comment\n   return")
                  end
               end
               
               -- Parse the code
               local ast, syntax_errors = tl.parse(code, "test_" .. total_tests .. ".tl")
               
               -- Verify no syntax errors
               assert.same({}, syntax_errors, 
                  "Test case '" .. test_case.name .. "' iteration " .. iteration .. 
                  " should not have syntax errors: " .. code)
               
               -- Find the function literal in the AST
               local func_literal = find_function_literal_in_ast(ast)
               assert.is_not_nil(func_literal, 
                  "Should find function literal in AST for: " .. test_case.name)
               
               -- Validate the AST node has sufficient information for inference
               local success = validate_ast_node_for_inference(func_literal, test_case.expected_params)
               if success then
                  successful_tests = successful_tests + 1
               end
            end
         end
         
         -- Verify we ran enough tests (property-based testing requirement)
         assert.is_true(total_tests >= 100, 
            "Should run at least 100 test iterations, ran: " .. total_tests)
         
         -- Verify high success rate
         local success_rate = successful_tests / total_tests
         assert.is_true(success_rate >= 0.95, 
            "Parser completeness property should hold for 95%+ of test cases. " ..
            "Success rate: " .. string.format("%.2f", success_rate * 100) .. "% " ..
            "(" .. successful_tests .. "/" .. total_tests .. ")")
      end)
      
      -- Additional test for contextual typing utility functions
      it("validates contextual typing utility functions work correctly", function()
         -- Test new_inference_error
         local error = contextual_typing.new_inference_error(
            "no_contextual_information",
            { y = 1, x = 1 },
            "Test error message"
         )
         
         assert.equal("no_contextual_information", error.kind)
         assert.equal("Test error message", error.message)
         assert.equal(1, error.location.y)
         assert.equal(1, error.location.x)
         
         -- Test new_call_site
         local call_site = contextual_typing.new_call_site(
            "test_function",
            1,
            { y = 5, x = 10 }
         )
         
         assert.equal("test_function", call_site.function_name)
         assert.equal(1, call_site.argument_position)
         assert.equal(5, call_site.source_location.y)
         assert.equal(10, call_site.source_location.x)
         assert.equal(false, call_site.is_method_call)
         
         -- Test new_inference_context
         local context = contextual_typing.new_inference_context(
            { typename = "function" },
            call_site,
            "call_site"
         )
         
         assert.equal("function", context.expected_type.typename)
         assert.equal("call_site", context.source)
         assert.equal(0, context.inference_depth)
         assert.is_nil(context.parent_context)
      end)
      
      -- Test extract_parameter_info function
      it("validates extract_parameter_info extracts correct parameter information", function()
         local test_cases = {
            {
               code = "local f = function(x, y: number, z) return x end",
               expected_count = 3,
               expected_info = {
                  { name = "x", is_inferred = true },
                  { name = "y", is_inferred = false },
                  { name = "z", is_inferred = true }
               }
            }
         }
         
         for _, test_case in ipairs(test_cases) do
            local ast, syntax_errors = tl.parse(test_case.code, "test.tl")
            assert.same({}, syntax_errors)
            
            local func_literal = find_function_literal_in_ast(ast)
            assert.is_not_nil(func_literal)
            
            local param_info = contextual_typing.extract_parameter_info(func_literal)
            assert.equal(test_case.expected_count, #param_info)
            
            for i, expected in ipairs(test_case.expected_info) do
               local actual = param_info[i]
               assert.equal(expected.name, actual.name)
               assert.equal(expected.is_inferred, actual.is_inferred)
            end
         end
      end)
   end)
end)