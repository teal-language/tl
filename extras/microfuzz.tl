#!/usr/bin/env -S tl run

math.randomseed(os.time())

print("micro fuzz!")

--local parser = require("tl")
local parser = require("teal.parser")

local tokens = {
   -- cat docs/src/grammar.md | sed 's,’,’\n,g;s,‘,\n‘,g' | grep '^‘' | sort -u | tr -d '‘’' | sed 's/\(.*\)/"\1",/g'
   "#",
   "%",
   "&",
   "(",
   ")",
   "*",
   "+",
   ",",
   "-",
   "...",
   "..",
   ".",
   "//",
   "/",
   "::",
   ":",
   ";",
   "<<",
   "<=",
   "<",
   "==",
   "=",
   ">=",
   ">>",
   ">",
   "?",
   "[",
   "]",
   "^",
   "{",
   "|",
   "}",
   "~=",
   "~",
   "and",
   "as",
   "boolean",
   "break",
   "do",
   "else",
   "elseif",
   "end",
   "enum",
   "false",
   "for",
   "function",
   "global",
   "goto",
   "if",
   "in",
   "interface",
   "is",
   "local",
   "macroexp",
   "metamethod",
   "nil",
   "not",
   "number",
   "or",
   "record",
   "repeat",
   "require",
   "return",
   "string",
   "then",
   "true",
   "type",
   "until",
   "userdata",
   "where",
   "while",
   -- other tokens
   "\"a string\"",
   "'a string'",
   "[==[a string]==]",
   "--#pragma arity on\n",
   "0",
   "123.456",
   "-2",
   "-234.56",
   -- macros
   "$",
   "`",
   "```",
   -- snippets
   "local record Foo",
   "local record Foo x: ",
   "interface Bla is Foo where",
   "if x < 2 then",
   "while true do",
   "elseif x > 3 then",
   "else",
   "local function hello()",
   "for _, x in ipairs(foo) do",
   "local xyz = ",
   "global xyz = ",
   "local xyz: ",
   "global xyz: ",
   "; local record Foo",
   "; local record Foo x: ",
   "; interface Bla is Foo where",
   "; if x < 2 then",
   "; while true do",
   "; elseif x > 3 then",
   "; else ",
   "; local function hello()",
   "; local function hello(",
   "; global function hello(",
   "; function foo:",
   "; for _, x in ipairs(foo) do",
   "; local xyz = ",
   "; global xyz = ",
   "; local xyz: ",
   "; global xyz: ",
   "end",
   "end",
   "end",
   "end",

}

local program_tokens = {}
for _ = 1, 10 do
   table.insert(program_tokens, tokens[math.random(#tokens)])
end

while true do
   local program = table.concat(program_tokens, " ")

   local _, errs = parser.parse(program, "foo.tl")

   if #errs > 0 then

      if errs[1].x > 50 then
         print(#program_tokens, errs[1].x, program)
      end

      local first_error = errs[1].x
      local good_tokens = 0
      local len = 0
      for i = 1, #program_tokens do
         if len < first_error then
            len = len + #program_tokens[i] + 1
            good_tokens = good_tokens + 1
         end
      end
      while #program_tokens > good_tokens do
         table.remove(program_tokens)
      end
      for _ = 1, math.random(3) - 1 do
         table.remove(program_tokens)
      end
   end

   for _ = 1, math.random(4) - 1 do
      table.insert(program_tokens, tokens[math.random(#tokens)])
   end
end
