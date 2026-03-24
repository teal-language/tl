local util = require("spec.util")

describe("local macro code generation", function()
   it("can use $ as assignment lvalue", util.gen([[
      local record Node
         vars: Node
      end

      local record ParseState
      end

      local record Block
         is {Block}
      end

      local function parse_variable_list(_state: ParseState, _block: Block, _etc: boolean): Node
         return {}
      end

      local function fail(_state: ParseState, _block: Block, _msg: string): Node
      end

      local macro set!(lvalue: Expression, call: Expression, msg: Expression): Statement
         local state = assert(call[2][1])
         local child = assert(call[2][2])
         local block = assert(call[2][2][1])
         return ```
            if not $child then
               return fail($state, $block, $msg)
            end
            $lvalue = $call
         ```
      end

      local function my_test(): Node
         local state: ParseState = {}
         local block: Block = {}

         local node: Node = {}
         set!(node.vars, parse_variable_list(state, block[5], false), "expected a variable list")
         return node
      end

      my_test()
   ]], [[











      local function parse_variable_list(_state, _block, _etc)
         return {}
      end

      local function fail(_state, _block, _msg)
      end













      local function my_test()
         local state = {}
         local block = {}

         local node = {}
         if not block[5] then return fail(state, block, "expected a variable list") end; node.vars = parse_variable_list(state, block[5], false)
         return node
      end

      my_test()
   ]]))
end)

