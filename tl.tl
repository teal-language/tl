
local VERSION = "0.15.3+dev"

local stdlib = [=====[

do
   global type any
   global type thread
   global type userdata

   local enum FileStringMode
      "a" "l" "L" "*a" "*l" "*L"
   end

   local enum FileNumberMode
      "n" "*n"
   end

   local enum FileMode
      "a" "l" "L" "*a" "*l" "*L" "n" "*n"
   end

   global record FILE
      userdata

      enum SeekWhence
         "set" "cur" "end"
      end

      enum SetVBufMode
         "no" "full" "line"
      end

      close: function(FILE): boolean, string, number
      flush: function(FILE)

      lines: function(FILE): (function(): (string))
      lines: function(FILE, FileNumberMode...): (function(): (number...))
      lines: function(FILE, (number | FileStringMode)...): (function(): (string...))
      lines: function(FILE, (number | FileMode)...): (function(): ((string | number)...))
      lines: function(FILE, (number | string)...): (function(): (string...))

      read: function(FILE): string
      read: function(FILE, FileNumberMode...): number...
      read: function(FILE, (number | FileStringMode)...): string...
      read: function(FILE, (number | FileMode)...): ((string | number)...)
      read: function(FILE, (number | string)...): (string...)

      seek: function(FILE, ? SeekWhence, ? integer): integer, string
      setvbuf: function(FILE, SetVBufMode, ? integer)

      write: function(FILE, (string | number)...): FILE, string

      metamethod __close: function(FILE)
   end

   global record coroutine
      type Function = function(any...): any...

      close: function(thread): boolean, string
      create: function(Function): thread
      isyieldable: function(): boolean
      resume: function(thread, any...): boolean, any...
      running: function(): thread, boolean
      status: function(thread): string
      wrap: function<F>(F): F
      yield: function(any...): any...
   end

   global record debug
      record GetInfoTable
         name: string
         namewhat: string
         source: string
         short_src: string
         linedefined: integer
         lastlinedefined: integer
         what: string
         currentline: integer
         istailcall: boolean
         nups: integer
         nparams: integer
         isvararg: boolean
         func: any
         activelines: {integer:boolean}
      end

      enum HookEvent
         "call" "tail call" "return" "line" "count"
      end

      type HookFunction = function(HookEvent, integer)

      type AnyFunction = function(any...):any...

      debug: function()
      gethook: function(? thread): HookFunction, integer

      getinfo: function(AnyFunction | integer): GetInfoTable
      getinfo: function(AnyFunction | integer, string): GetInfoTable
      getinfo: function(thread, AnyFunction | integer, string): GetInfoTable

      getlocal: function(thread, AnyFunction, integer): string
      getlocal: function(thread, integer, integer): string, any
      getlocal: function(AnyFunction, integer): string
      getlocal: function(integer, integer): string, any

      getmetatable: function<T>(T): metatable<T>
      getregistry: function(): {any:any}
      getupvalue: function(AnyFunction, integer): any
      getuservalue: function(userdata, integer): any

      sethook: function(thread, HookFunction, string, ? integer)
      sethook: function(HookFunction, string, ? integer)

      setlocal: function(thread, integer, integer, any): string
      setlocal: function(integer, integer, any): string

      setmetatable: function<T>(T, metatable<T>): T
      setupvalue: function(AnyFunction, integer, any): string
      setuservalue: function<U>(U, any, integer): U --[[U is userdata]]

      traceback: function(thread, ? string, ? integer): string
      traceback: function(? string, ? integer): string

      upvalueid: function(AnyFunction, integer): userdata
      upvaluejoin: function(AnyFunction, integer, AnyFunction, integer)
   end

   global record io
      enum OpenMode
         "r" "w" "a" "r+" "w+" "a+"
         "rb" "wb" "ab" "r+b" "w+b" "a+b"
         "*r" "*w" "*a" "*r+" "*w+" "*a+"
         "*rb" "*wb" "*ab" "*r+b" "*w+b" "*a+b"
      end

      close: function(? FILE)
      input: function(? FILE): FILE
      flush: function()

      lines: function(? string): (function(): (string))
      lines: function(? string, FileNumberMode...): (function(): (number...))
      lines: function(? string, (number | FileStringMode)...): (function(): (string...))
      lines: function(? string, (number | FileMode)...): (function(): ((string | number)...))
      lines: function(? string, (number | string)...): (function(): (string...))

      open: function(string, ? OpenMode): FILE, string
      output: function(? FILE): FILE
      popen: function(string, ? OpenMode): FILE, string

      read: function(): string
      read: function(FileNumberMode...): number...
      read: function((number | FileStringMode)...): string...
      read: function((number | FileMode)...): ((string | number)...)
      read: function((number | string)...): (string...)

      stderr: FILE
      stdin: FILE
      stdout: FILE
      tmpfile: function(): FILE
      type: function(any): string
      write: function((string | number)...): FILE, string
   end

   global record math
      type Numeric = number | integer

      abs: function<N is Numeric>(N): N
      acos: function(number): number
      asin: function(number): number
      atan: function(number, ? number): number
      atan2: function(number, number): number
      ceil: function(number): integer
      cos: function(number): number
      cosh: function(number): number
      deg: function(number): number
      exp: function(number): number
      floor: function(number): integer

      fmod: function(integer, integer): integer
      fmod: function(number, number): number

      frexp: function(number): number, number
      huge: number
      ldexp: function(number, number): number
      log: function(number, ? number): number
      log10: function(number): number

      max: function(integer...): integer
      max: function((number | integer)...): number
      max: function<T>(T...): T
      max: function(any...): any

      maxinteger: integer --[[needs_compat]]

      min: function(integer...): integer
      min: function((number | integer)...): number
      min: function<T>(T...): T
      min: function(any...): any

      mininteger: integer --[[needs_compat]]

      modf: function(number): integer, number
      pi: number
      pow: function(number, number): number
      rad: function(number): number

      random: function(integer, ? integer): integer
      random: function(): number

      randomseed: function(? integer, ? integer): integer, integer
      sin: function(number): number
      sinh: function(number): number
      sqrt: function(number): number
      tan: function(number): number
      tanh: function(number): number
      tointeger: function(any): integer
      type: function(any): string
      ult: function(number, number): boolean
   end

   global record metatable<T>
      enum Mode
         "k" "v" "kv"
      end

      __call: function(T, any...): any...
      __mode: Mode
      __name: string
      __tostring: function(T): string
      __pairs: function<K, V>(T): (function(): (K, V))

      __index: any --[[FIXME: function | table | anything with an __index metamethod]]
      __newindex: any --[[FIXME: function | table | anything with an __index metamethod]]

      __gc: function(T)
      __close: function(T)

      __add: function(any, any): any
      __sub: function(any, any): any
      __mul: function(any, any): any
      __div: function(any, any): any
      __idiv: function(any, any): any
      __mod: function(any, any): any
      __pow: function(any, any): any
      __band: function(any, any): any
      __bor: function(any, any): any
      __bxor: function(any, any): any
      __shl: function(any, any): any
      __shr: function(any, any): any
      __concat: function(any, any): any

      __len: function(T): any
      __unm: function(T): any
      __bnot: function(T): any

      __eq: function(any, any): boolean
      __lt: function(any, any): boolean
      __le: function(any, any): boolean
   end

   global record os
      record DateTable
         year: integer
         month: integer
         day: integer
         hour: integer
         min: integer
         sec: integer
         wday: integer
         yday: integer
         isdst: boolean
      end

      enum DateMode
         "!*t" "*t"
      end

      clock: function(): number

      date: function(DateMode, ? number): DateTable
      date: function(? string, ? number): string

      difftime: function(integer, integer): number
      execute: function(string): boolean, string, integer
      exit: function(? (integer | boolean), ? boolean)
      getenv: function(string): string
      remove: function(string): boolean, string
      rename: function(string, string): boolean, string
      setlocale: function(string, ? string): string
      time: function(? DateTable): integer
      tmpname: function(): string
   end

   global record package
      config: string
      cpath: string
      loaded: {string:any}
      loadlib: function(string, string): (function)
      loaders: { function(string): any, any }
      path: string
      preload: {any:any}
      searchers: { function(string): any }
      searchpath: function(string, string, ? string, ? string): string, string
   end

   global record string
      byte: function(string, ? integer): integer
      byte: function(string, integer, ? integer): integer...

      char: function(integer...): string
      dump: function(function(any...): (any), ? boolean): string
      find: function(string, string, ? integer, ? boolean): integer, integer, string
      format: function(string, any...): string
      gmatch: function(string, string, ? integer): (function(): string...)

      gsub: function(string, string, string, ? integer): string, integer
      gsub: function(string, string, {string:string}, ? integer): string, integer
      gsub: function(string, string, function(string...): (string | integer | boolean), ? integer): string, integer

      len: function(string): integer
      lower: function(string): string
      match: function(string, string, ? integer): string...
      pack: function(string, any...): string
      packsize: function(string): integer
      rep: function(string, integer, ? string): string
      reverse: function(string): string
      sub: function(string, integer, ? integer): string
      unpack: function(string, string, ? integer): any...
      upper: function(string): string
   end

   global record table
      type SortFunction = function<A>(A, A): boolean

      record PackTable<A>
         is {A}

         n: integer
      end

      concat: function({(string | number)}, ? string, ? integer, ? integer): string

      insert: function<A>({A}, integer, A)
      insert: function<A>({A}, A)

      move: function<A>({A}, integer, integer, integer, ? {A}): {A}

      pack: function<T>(T...): PackTable<T>
      pack: function(any...): {any:any}

      remove: function<A>({A}, ? integer): A
      sort: function<A>({A}, ? SortFunction<A>)

      unpack: function<A>({A}, ? number, ? number): A... --[[needs_compat]]
   end

   global record utf8
      char: function(integer...): string
      charpattern: string
      codepoint: function(string, ? integer, ? integer, ? boolean): integer...
      codes: function(string, ? boolean): (function(string, ? integer): (integer, integer))
      len: function(string, ? integer, ? integer, ? boolean): integer
      offset: function(string, integer, ? integer): integer
   end

   local record StandardLibrary
      enum CollectGarbageCommand
         "collect"
         "count"
         "stop"
         "restart"
      end

      enum CollectGarbageSetValue
         "step"
         "setpause"
         "setstepmul"
      end

      enum CollectGarbageIsRunning
         "isrunning"
      end

      type LoadFunction = function(): string

      enum LoadMode
         "b" "t" "bt"
      end

      type XpcallMsghFunction = function(...: any): ()

      arg: {string}
      assert: function<A, B>(A, ? B): A

      collectgarbage: function(? CollectGarbageCommand): number
      collectgarbage: function(CollectGarbageSetValue, integer): number
      collectgarbage: function(CollectGarbageIsRunning): boolean
      collectgarbage: function(string, ? number): (boolean | number)

      dofile: function(? string): any...

      error: function(? any, ? integer)
      getmetatable: function<T>(T): metatable<T>
      ipairs: function<A>({A}): (function():(integer, A))

      load: function((string | LoadFunction), ? string, ? LoadMode, ? table): (function, string)
      load: function((string | LoadFunction), ? string, ? string, ? table): (function, string)

      loadfile: function(? string, ? string, ? {any:any}): (function, string)

      next: function<K, V>({K:V}, ? K): (K, V)
      next: function<A>({A}, ? integer): (integer, A)

      pairs: function<K, V>({K:V}): (function():(K, V))
      pcall: function(function(any...):(any...), any...): boolean, any...
      print: function(any...)
      rawequal: function(any, any): boolean

      rawget: function<K, V>({K:V}, K): V
      rawget: function({any:any}, any): any
      rawget: function(any, any): any

      rawlen: function<A>({A}): integer

      rawset: function<K, V>({K:V}, K, V): {K:V}
      rawset: function({any:any}, any, any): {any:any}
      rawset: function(any, any, any): any

      require: function(string): any

      select: function<T>(integer, T...): T...
      select: function(integer, any...): any...
      select: function(string, any...): integer

      setmetatable: function<T>(T, metatable<T>): T

      tonumber: function(any): number
      tonumber: function(any, integer): integer

      tostring: function(any): string
      type: function(any): string
      warn: function(string, string...)
      xpcall: function(function(any...):(any...), XpcallMsghFunction, any...): boolean, any...
      _VERSION: string
   end

   global arg <const> = StandardLibrary.arg
   global assert <const> = StandardLibrary.assert
   global collectgarbage <const> = StandardLibrary.collectgarbage
   global dofile <const> = StandardLibrary.dofile
   global error <const> = StandardLibrary.error
   global getmetatable <const> = StandardLibrary.getmetatable
   global load <const> = StandardLibrary.load
   global loadfile <const> = StandardLibrary.loadfile
   global next <const> = StandardLibrary.next
   global pairs <const> = StandardLibrary.pairs
   global pcall <const> = StandardLibrary.pcall
   global print <const> = StandardLibrary.print
   global rawequal <const> = StandardLibrary.rawequal
   global rawget <const> = StandardLibrary.rawget
   global rawlen <const> = StandardLibrary.rawlen
   global rawset <const> = StandardLibrary.rawset
   global require <const> = StandardLibrary.require
   global select <const> = StandardLibrary.select
   global setmetatable <const> = StandardLibrary.setmetatable
   global tostring <const> = StandardLibrary.tostring
   global tonumber <const> = StandardLibrary.tonumber
   global ipairs <const> = StandardLibrary.ipairs
   global type <const> = StandardLibrary.type
   global xpcall <const> = StandardLibrary.xpcall
   global _VERSION <const> = StandardLibrary._VERSION
end

]=====]

local interface Where
   f: string
   y: integer
   x: integer
end

local record Errors
   filename: string
   errors: {Error}
   warnings: {Error}
   unknown_dots: {string:boolean}
end

local record tl
   enum LoadMode
      "b"
      "t"
      "bt"
      "cb"
      "ct"
      "cbt"
   end
   type LoadFunction = function(...:any): any...

   enum GenCompat
      "off"
      "optional"
      "required"
   end

   enum GenTarget
      "5.1"
      "5.3"
      "5.4"
   end

   enum Feat
      "on"
      "off"
   end

   record PrettyPrintOptions
      preserve_indent: boolean
      preserve_newlines: boolean
      preserve_hashbang: boolean
   end

   record TypeCheckOptions
      feat_lax: Feat
      feat_arity: Feat
      gen_compat: GenCompat
      gen_target: GenTarget
      run_internal_compiler_checks: boolean
   end

   record Env
      globals: {string:Variable}
      modules: {string:Type}
      module_filenames: {string:string}
      loaded: {string:Result}
      loaded_order: {string}
      reporter: TypeReporter
      keep_going: boolean
      report_types: boolean
      defaults: TypeCheckOptions
   end

   record Result
      filename: string
      ast: Node
      type: Type
      syntax_errors: {Error}
      type_errors: {Error}
      gen_error: string
      warnings: {Error}
      env: Env
      dependencies: {string:string} -- module name, file found
   end

   enum WarningKind
      "unknown"
      "unused"
      "redeclaration"
      "branch"
      "hint"
      "debug"
   end
   warning_kinds: {WarningKind:boolean}

   record Error
      y: integer
      x: integer
      msg: string
      filename: string

      tag: WarningKind

      -- used temporarily for stable-sorting
      i: integer
   end

   type errors = Errors

   typecodes: {string:integer}

   record TypeInfo
      t: integer

      str: string
      file: string
      x: integer
      y: integer
      ref: integer -- NOMINAL
      fields: {string: integer} -- RECORD
      enums: {string} -- ENUM
      args: {{integer, string}} -- FUNCTION
      rets: {{integer, string}} -- FUNCTION
      vararg: boolean -- FUNCTION
      varret: boolean -- FUNCTION
      types: {integer} -- UNION, POLY, TUPLE
      keys: integer -- MAP
      values: integer -- MAP
      elements: integer -- ARRAY
   end

   record TypeReport
      by_pos: {string: {integer: {integer: integer}}}
      types: {integer: TypeInfo}
      symbols: {{integer, integer, string, integer}}
      globals: {string: integer}
   end

   record EnvOptions
      defaults: TypeCheckOptions
      predefined_modules: {string}
   end

   load: function(string, string, LoadMode, {any:any}): LoadFunction, string
   process: function(string, Env, ? FILE): (Result, string)
   process_string: function(string, Env, ? string): Result
   gen: function(string, Env, PrettyPrintOptions): string, Result
   type_check: function(Node, string, TypeCheckOptions, ? Env): Result, string
   new_env: function(? EnvOptions): Env, string
   version: function(): string

   -- Backwards compatibility
   init_env: function(? boolean, ? boolean | GenCompat, ? GenTarget, ? {string}): Env, string

   package_loader_env: Env
   load_envs: { {any:any} : Env }
end

local record TypeReporter
   typeid_to_num: {integer: integer}
   typename_to_num: {TypeName: integer}
   next_num: integer
   tr: TypeReport

   get_typenum: function(TypeReporter, Type): integer
end

tl.version = function(): string
   return VERSION
end

local wk <total>: {tl.WarningKind:boolean} = {
   ["unknown"] = true,
   ["unused"] = true,
   ["redeclaration"] = true,
   ["branch"] = true,
   ["hint"] = true,
   ["debug"] = true,
}
tl.warning_kinds = wk

-- Implementation rationale:
-- * bit 31: (MSB) special ("any", "unknown", "invalid")
--   * "any" satisfies all Lua masks
-- * bits 30-27: if valid: other Teal types ("nominal", "poly", "union", "typevar")
-- * bits 24-26: reserved
-- * bits 20-23: abstract types ("interface")
-- * bits 16-19: if valid: Teal types ("array", "record", "map", "tuple", "enum") that map to a Lua type ("table", "string")
-- * bit 15: if not valid: value is unknown
-- * bits 8-14: reserved
-- * bits 0-7: (LSB) Lua types, one bit for each ("nil", "number", "boolean", "string", table, "function", "userdata", "thread")
--   * every valid value has a Lua type bit set
tl.typecodes = {
   -- Lua types
   NIL                    = 0x00000001,
   NUMBER                 = 0x00000002,
   BOOLEAN                = 0x00000004,
   STRING                 = 0x00000008,
   TABLE                  = 0x00000010,
   FUNCTION               = 0x00000020,
   USERDATA               = 0x00000040,
   THREAD                 = 0x00000080,
   -- Teal types
   INTEGER                = 0x00010002,
   ENUM                   = 0x00010004,
   EMPTY_TABLE            = 0x00000008,
   ARRAY                  = 0x00010008,
   RECORD                 = 0x00020008,
   MAP                    = 0x00040008,
   TUPLE                  = 0x00080008,
   INTERFACE              = 0x00100008,
   POLY                   = 0x20000020,
   UNION                  = 0x40000000,
   -- Indirect types
   NOMINAL                = 0x10000000,
   TYPE_VARIABLE          = 0x08000000,
   -- Special types
   ANY                    = 0xffffffff,
   UNKNOWN                = 0x80008000,
   INVALID                = 0x80000000,
}

local type Env = tl.Env
local type EnvOptions = tl.EnvOptions
local type Error = tl.Error
local type Feat = tl.Feat
local type GenCompat = tl.GenCompat
local type GenTarget = tl.GenTarget
local type LoadFunction = tl.LoadFunction
local type LoadMode = tl.LoadMode
local type PrettyPrintOptions = tl.PrettyPrintOptions
local type Result = tl.Result
local type TypeCheckOptions = tl.TypeCheckOptions
local type TypeInfo = tl.TypeInfo
local type TypeReport = tl.TypeReport
local type WarningKind = tl.WarningKind

local DEFAULT_GEN_COMPAT <const>: GenCompat = "optional"
local DEFAULT_GEN_TARGET <const>: GenTarget = "5.3"

local enum Narrow
   "narrow"
   "narrowed_declaration"
   "declaration"
end

local record Variable
   t: Type
   attribute: Attribute
   needs_compat: boolean
   narrowed_from: Type
   is_narrowed: Narrow
   declared_at: Node
   is_func_arg: boolean
   used: boolean
   used_as_type: boolean
   aliasing: Variable
   implemented: {string:boolean}
end

--------------------------------------------------------------------------------
-- Compiler debugging
--------------------------------------------------------------------------------

local TL_DEBUG = os.getenv("TL_DEBUG")
local TL_DEBUG_MAXLINE = math.maxinteger

if TL_DEBUG then
   local max <const> = assert(tonumber(TL_DEBUG), "TL_DEBUG was defined, but not a number")
   if max < 0 then
      TL_DEBUG_MAXLINE = math.tointeger(-max)
   elseif max > 1 then
      local count = 0
      local skip: string = nil
      debug.sethook(function(event: debug.HookEvent)
         if event == "call" or event == "tail call" or event == "return" then
            local info <const> = debug.getinfo(2)

            if skip then
               if info.name == skip and event == "return" then
                  skip = nil
               end
               return
            elseif (info.name or "?"):match("^tl_debug_") and event == "call" then
               skip = info.name
               return
            end

            local name = info.name or "<anon>", info.currentline > 0 and "@" .. info.currentline or ""
            io.stderr:write(name, " :: ", event as string, "\n")
            io.stderr:flush()
         else
            count = count + 100
            if count > max then
               error("Too many instructions")
            end
         end
      end, "cr", 100)
   end
end

--------------------------------------------------------------------------------
-- Lexer
--------------------------------------------------------------------------------

local enum TokenKind
   "hashbang"
   "keyword"
   "op"
   "string"
   "[" "]" "(" ")" "{" "}" "," ":" "#" "." ";" "?"
   "::"
   "..."
   "identifier"
   "number"
   "integer"
   "$ERR unfinished_comment$"
   "$ERR invalid_string$"
   "$ERR invalid_number$"
   "$ERR invalid$"
   "$EOF$"
end

local record Token
   x: integer
   y: integer
   tk: string
   kind: TokenKind
end

do
   local enum LexState
      "start"
      "any"
      "identifier"
      "got -"
      "got --"
      "got ."
      "got .."
      "got ="
      "got ~"
      "got ["
      "got 0"
      "got <"
      "got >"
      "got /"
      "got :"
      "got --["
      "string single"
      "string single got \\"
      "string double"
      "string double got \\"
      "string long"
      "string long got ]"
      "comment short"
      "comment long"
      "comment long got ]"
      "number dec"
      "number decfloat"
      "number hex"
      "number hexfloat"
      "number power"
      "number powersign"
   end

   local last_token_kind <total>: {LexState:TokenKind} = {
      ["start"] = nil, -- never in a token
      ["any"] = nil, -- never in a token
      ["identifier"] = "identifier",
      ["got -"] = "op",
      ["got --"] = nil, -- drop comment
      ["got ."] = ".",
      ["got .."] = "op",
      ["got ="] = "op",
      ["got ~"] = "op",
      ["got ["] = "[",
      ["got 0"] = "number",
      ["got <"] = "op",
      ["got >"] = "op",
      ["got /"] = "op",
      ["got :"] = "op",
      ["got --["] = nil, -- drop comment
      ["string single"] = "$ERR invalid_string$",
      ["string single got \\"] = "$ERR invalid_string$",
      ["string double"] = "$ERR invalid_string$",
      ["string double got \\"] = "$ERR invalid_string$",
      ["string long"] = "$ERR invalid_string$",
      ["string long got ]"] = "$ERR invalid_string$",
      ["comment short"] = nil, -- drop comment
      ["comment long"] = "$ERR unfinished_comment$",
      ["comment long got ]"] = "$ERR unfinished_comment$",
      ["number dec"] = "integer",
      ["number decfloat"] = "number",
      ["number hex"] = "integer",
      ["number hexfloat"] = "number",
      ["number power"] = "number",
      ["number powersign"] = "$ERR invalid_number$",
   }

   local keywords: {string:boolean} = {
      ["and"] = true,
      ["break"] = true,
      ["do"] = true,
      ["else"] = true,
      ["elseif"] = true,
      ["end"] = true,
      ["false"] = true,
      ["for"] = true,
      ["function"] = true,
      ["goto"] = true,
      ["if"] = true,
      ["in"] = true,
      ["local"] = true,
      ["nil"] = true,
      ["not"] = true,
      ["or"] = true,
      ["repeat"] = true,
      ["return"] = true,
      ["then"] = true,
      ["true"] = true,
      ["until"] = true,
      ["while"] = true,
   }

   local lex_any_char_states: {string:LexState} = {
      ["\""] = "string double",
      ["'"] = "string single",
      ["-"] = "got -",
      ["."] = "got .",
      ["0"] = "got 0",
      ["<"] = "got <",
      [">"] = "got >",
      ["/"] = "got /",
      [":"] = "got :",
      ["="] = "got =",
      ["~"] = "got ~",
      ["["] = "got [",
   }

   for c = string.byte("a"), string.byte("z") do
      lex_any_char_states[string.char(c)] = "identifier"
   end
   for c = string.byte("A"), string.byte("Z") do
      lex_any_char_states[string.char(c)] = "identifier"
   end
   lex_any_char_states["_"] = "identifier"

   for c = string.byte("1"), string.byte("9") do
      lex_any_char_states[string.char(c)] = "number dec"
   end

   local lex_word: {string:boolean} = {}
   for c = string.byte("a"), string.byte("z") do
      lex_word[string.char(c)] = true
   end
   for c = string.byte("A"), string.byte("Z") do
      lex_word[string.char(c)] = true
   end
   for c = string.byte("0"), string.byte("9") do
      lex_word[string.char(c)] = true
   end
   lex_word["_"] = true

   local lex_decimals: {string:boolean} = {}
   for c = string.byte("0"), string.byte("9") do
      lex_decimals[string.char(c)] = true
   end

   local lex_hexadecimals: {string:boolean} = {}
   for c = string.byte("0"), string.byte("9") do
      lex_hexadecimals[string.char(c)] = true
   end
   for c = string.byte("a"), string.byte("f") do
      lex_hexadecimals[string.char(c)] = true
   end
   for c = string.byte("A"), string.byte("F") do
      lex_hexadecimals[string.char(c)] = true
   end

   local lex_any_char_kinds: {string:TokenKind} = {}
   local single_char_kinds: {TokenKind} = {"[", "]", "(", ")", "{", "}", ",", "#", ";", "?"}
   for _, c in ipairs(single_char_kinds) do
      lex_any_char_kinds[c] = c
   end
   for _, c in ipairs({"+", "*", "|", "&", "%", "^"}) do
      lex_any_char_kinds[c] = "op"
   end

   local lex_space: {string:boolean} = {}
   for _, c in ipairs({" ", "\t", "\v", "\n", "\r"}) do
      lex_space[c] = true
   end

   local escapable_characters: {string:boolean} = {
      a = true,
      b = true,
      f = true,
      n = true,
      r = true,
      t = true,
      v = true,
      z = true,
      ["\\"] = true,
      ["\'"] = true,
      ["\""] = true,
      ["\r"] = true,
      ["\n"] = true,
   }

   local function lex_string_escape(input: string, i: integer, c: string): integer, boolean
      if escapable_characters[c] then
         return 0, true
      elseif c == "x" then
         return 2, (
            lex_hexadecimals[input:sub(i+1, i+1)] and
            lex_hexadecimals[input:sub(i+2, i+2)]
         )
      elseif c == "u" then
         if input:sub(i+1, i+1) == "{" then
            local p = i + 2
            if not lex_hexadecimals[input:sub(p, p)] then
               return 2, false
            end
            while true do
               p = p + 1
               c = input:sub(p, p)
               if not lex_hexadecimals[c] then
                  return p - i, c == "}"
               end
            end
         end
      elseif lex_decimals[c] then
         local len = lex_decimals[input:sub(i+1, i+1)]
                     and (lex_decimals[input:sub(i+2, i+2)] and 2 or 1)
                     or  0
         return len, tonumber(input:sub(i, i + len)) < 256
      else
         return 0, false
      end
   end

   function tl.lex(input: string, filename: string): {Token}, {Error}
      local tokens: {Token} = {}

      local state: LexState = "any"
      local fwd = true
      local y = 1
      local x = 0
      local i = 0
      local lc_open_lvl = 0
      local lc_close_lvl = 0
      local ls_open_lvl = 0
      local ls_close_lvl = 0
      local errs: {Error} = {}
      local nt = 0

      local tx: integer
      local ty: integer
      local ti: integer
      local in_token = false

      local function begin_token()
         tx = x
         ty = y
         ti = i
         in_token = true
      end

      local function end_token(kind: TokenKind, tk: string)
         nt = nt + 1
         tokens[nt] = {
            x = tx,
            y = ty,
            tk = tk,
            kind = kind,
         }
         in_token = false
      end

      local function end_token_identifier()
         local tk = input:sub(ti, i - 1)
         nt = nt + 1
         tokens[nt] = {
            x = tx,
            y = ty,
            tk = tk,
            kind = keywords[tk] and "keyword" or "identifier"
         }
         in_token = false
      end

      local function end_token_prev(kind: TokenKind)
         local tk = input:sub(ti, i - 1)
         nt = nt + 1
         tokens[nt] = {
            x = tx,
            y = ty,
            tk = tk,
            kind = kind
         }
         in_token = false
      end

      local function end_token_here(kind: TokenKind)
         local tk = input:sub(ti, i)
         nt = nt + 1
         tokens[nt] = {
            x = tx,
            y = ty,
            tk = tk,
            kind = kind
         }
         in_token = false
      end

      local function drop_token()
         in_token = false
      end

      local function add_syntax_error()
         local t = tokens[nt]
         local msg: string
         if t.kind == "$ERR invalid_string$" then
            msg = "malformed string"
         elseif t.kind == "$ERR invalid_number$" then
            msg = "malformed number"
         elseif t.kind == "$ERR unfinished_comment$" then
            msg = "unfinished long comment"
         else
            msg = "invalid token '" .. t.tk .. "'"
         end
         table.insert(errs, {
            filename = filename,
            y = t.y,
            x = t.x,
            msg = msg,
         })
      end

      local len = #input
      if input:sub(1,2) == "#!" then
         begin_token()
         i = input:find("\n")
         if not i then
            i = len + 1
         end
         end_token_prev("hashbang")
         y = 2
         x = 0
      end
      state = "any"

      while i <= len do
         if fwd then
            i = i + 1
            if i > len then
               break
            end
         end

         local c: string = input:sub(i, i)

         if fwd then
            if c == "\n" then
               y = y + 1
               x = 0
            else
               x = x + 1
            end
         else
            fwd = true
         end

         if state == "any" then
            local st = lex_any_char_states[c]
            if st then
               state = st
               begin_token()
            else
               local k = lex_any_char_kinds[c]
               if k then
                  begin_token()
                  end_token(k, c)
               elseif not lex_space[c] then
                  begin_token()
                  end_token_here("$ERR invalid$")
                  add_syntax_error()
               end
            end
         elseif state == "identifier" then
            if not lex_word[c] then
               end_token_identifier()
               fwd = false
               state = "any"
            end
         elseif state == "string double" then
            if c == "\\" then
               state = "string double got \\"
            elseif c == "\"" then
               end_token_here("string")
               state = "any"
            end
         elseif state == "comment short" then
            if c == "\n" then
               state = "any"
            end
         elseif state == "got =" then
            local t: string
            if c == "=" then
               t = "=="
            else
               t = "="
               fwd = false
            end
            end_token("op", t)
            state = "any"
         elseif state == "got ." then
            if c == "." then
               state = "got .."
            elseif lex_decimals[c] then
               state = "number decfloat"
            else
               end_token(".", ".")
               fwd = false
               state = "any"
            end
         elseif state == "got :" then
            local t: TokenKind
            if c == ":" then
               t = "::"
            else
               t = ":"
               fwd = false
            end
            end_token(t, t)
            state = "any"
         elseif state == "got [" then
            if c == "[" then
               state = "string long"
            elseif c == "=" then
               ls_open_lvl = ls_open_lvl + 1
            else
               end_token("[", "[")
               fwd = false
               state = "any"
               ls_open_lvl = 0
            end
         elseif state == "number dec" then
            if lex_decimals[c] then
               -- proceed
            elseif c == "." then
               state = "number decfloat"
            elseif c == "e" or c == "E" then
               state = "number powersign"
            else
               end_token_prev("integer")
               fwd = false
               state = "any"
            end
         elseif state == "got -" then
            if c == "-" then
               state = "got --"
            else
               end_token("op", "-")
               fwd = false
               state = "any"
            end
         elseif state == "got .." then
            if c == "." then
               end_token("...", "...")
            else
               end_token("op", "..")
               fwd = false
            end
            state = "any"
         elseif state == "number hex" then
            if lex_hexadecimals[c] then
               -- proceed
            elseif c == "." then
               state = "number hexfloat"
            elseif c == "p" or c == "P" then
               state = "number powersign"
            else
               end_token_prev("integer")
               fwd = false
               state = "any"
            end
         elseif state == "got --" then
            if c == "[" then
               state = "got --["
            else
               fwd = false
               state = "comment short"
               drop_token()
            end
         elseif state == "got 0" then
            if c == "x" or c == "X" then
               state = "number hex"
            elseif c == "e" or c == "E" then
               state = "number powersign"
            elseif lex_decimals[c] then
               state = "number dec"
            elseif c == "." then
               state = "number decfloat"
            else
               end_token_prev("integer")
               fwd = false
               state = "any"
            end
         elseif state == "got --[" then
            if c == "[" then
               state = "comment long"
            elseif c == "=" then
               lc_open_lvl = lc_open_lvl + 1
            else
               fwd = false
               state = "comment short"
               drop_token()
               lc_open_lvl = 0
            end
         elseif state == "comment long" then
            if c == "]" then
               state = "comment long got ]"
            end
         elseif state == "comment long got ]" then
            if c == "]" and lc_close_lvl == lc_open_lvl then
               drop_token()
               state = "any"
               lc_open_lvl = 0
               lc_close_lvl = 0
            elseif c == "=" then
               lc_close_lvl = lc_close_lvl + 1
            else
               state = "comment long"
               lc_close_lvl = 0
            end
         elseif state == "string double got \\" then
            local skip, valid = lex_string_escape(input, i, c)
            i = i + skip
            if not valid then
               end_token_here("$ERR invalid_string$")
               add_syntax_error()
            end
            x = x + skip
            state = "string double"
         elseif state == "string single" then
            if c == "\\" then
               state = "string single got \\"
            elseif c == "'" then
               end_token_here("string")
               state = "any"
            end
         elseif state == "string single got \\" then
            local skip, valid = lex_string_escape(input, i, c)
            i = i + skip
            if not valid then
               end_token_here("$ERR invalid_string$")
               add_syntax_error()
            end
            x = x + skip
            state = "string single"
         elseif state == "got ~" then
            local t: string
            if c == "=" then
               t = "~="
            else
               t = "~"
               fwd = false
            end
            end_token("op", t)
            state = "any"
         elseif state == "got <" then
            local t: string
            if c == "=" then
               t = "<="
            elseif c == "<" then
               t = "<<"
            else
               t = "<"
               fwd = false
            end
            end_token("op", t)
            state = "any"
         elseif state == "got >" then
            local t: string
            if c == "=" then
               t = ">="
            elseif c == ">" then
               t = ">>"
            else
               t = ">"
               fwd = false
            end
            end_token("op", t)
            state = "any"
         elseif state == "got /" then
            local t: string
            if c == "/" then
               t = "//"
            else
               t = "/"
               fwd = false
            end
            end_token("op", t)
            state = "any"
         elseif state == "string long" then
            if c == "]" then
               state = "string long got ]"
            end
         elseif state == "string long got ]" then
            if c == "]" then
               if ls_close_lvl == ls_open_lvl then
                  end_token_here("string")
                  state = "any"
                  ls_open_lvl = 0
                  ls_close_lvl = 0
               end
            elseif c == "=" then
               ls_close_lvl = ls_close_lvl + 1
            else
               state = "string long"
               ls_close_lvl = 0
            end
         elseif state == "number hexfloat" then
            if c == "p" or c == "P" then
               state = "number powersign"
            elseif not lex_hexadecimals[c] then
               end_token_prev("number")
               fwd = false
               state = "any"
            end
         elseif state == "number decfloat" then
            if c == "e" or c == "E" then
               state = "number powersign"
            elseif not lex_decimals[c] then
               end_token_prev("number")
               fwd = false
               state = "any"
            end
         elseif state == "number powersign" then
            if c == "-" or c == "+" then
               state = "number power"
            elseif lex_decimals[c] then
               state = "number power"
            else
               end_token_here("$ERR invalid_number$")
               add_syntax_error()
               state = "any"
            end
         elseif state == "number power" then
            if not lex_decimals[c] then
               end_token_prev("number")
               fwd = false
               state = "any"
            end
         end
      end

      if in_token then
         if last_token_kind[state] then
            end_token_prev(last_token_kind[state])
            if last_token_kind[state]:sub(1, 4) == "$ERR" then
               add_syntax_error()
            elseif keywords[tokens[nt].tk] then
               tokens[nt].kind = "keyword"
            end
         else
            drop_token()
         end
      end

      table.insert(tokens, { x = x + 1, y = y, i = i, tk = "$EOF$", kind = "$EOF$" })

      return tokens, errs
   end
end

local function binary_search<T, U>(list: {T}, item: U, cmp: function(T, U): boolean): integer, T
   local len <const> = #list
   local mid: integer
   local s, e = 1, len
   while s <= e do
      mid = math.floor((s + e) / 2)
      local val <const> = list[mid]
      local res <const> = cmp(val, item)
      if res then
         if mid == len then
            return mid, val
         else
            if not cmp(list[mid + 1], item) then
               return mid, val
            end
         end
         s = mid + 1
      else
         e = mid - 1
      end
   end
end

function tl.get_token_at(tks: {Token}, y: integer, x: integer): string
   local _, found <const> = binary_search(
      tks, nil,
      function(tk: Token): boolean
         return tk.y < y
            or (tk.y == y and tk.x <= x)
      end
   )

   if found
      and found.y == y
      and found.x <= x and x < found.x + #found.tk
   then
      return found.tk
   end
end

--------------------------------------------------------------------------------
-- Recursive descent parser
--------------------------------------------------------------------------------

local last_typeid = 0

local function new_typeid(): integer
   last_typeid = last_typeid + 1
   return last_typeid
end

local enum TypeName
   "typedecl"
   "typealias"
   "typevar"
   "typearg"
   "function"
   "array"
   "map"
   "tupletable"
   "record"
   "interface"
   "enum"
   "boolean"
   "string"
   "nil"
   "thread"
   "number"
   "integer"
   "union"
   "nominal"
   "emptytable"
   "literal_table_item"
   "unresolved_emptytable_value"
   "unresolved_typearg"
   "unresolvable_typearg"
   "circular_require"
   "tuple"
   "poly" -- intersection types, currently restricted to polymorphic functions defined inside records
   "any"
   "unknown" -- to be used in lax mode only
   "invalid" -- producing a new value of this type (not propagating) must always produce a type error
   "none"
   "*"
end

local table_types <total>: {TypeName:boolean} = {
   ["array"] = true,
   ["map"] = true,
   ["record"] = true,
   ["interface"] = true,
   ["emptytable"] = true,
   ["tupletable"] = true,

   ["typedecl"] = false,
   ["typealias"] = false,
   ["typevar"] = false,
   ["typearg"] = false,
   ["function"] = false,
   ["enum"] = false,
   ["boolean"] = false,
   ["string"] = false,
   ["nil"] = false,
   ["thread"] = false,
   ["number"] = false,
   ["integer"] = false,
   ["union"] = false,
   ["nominal"] = false,
   ["literal_table_item"] = false,
   ["unresolved_emptytable_value"] = false,
   ["unresolved_typearg"] = false,
   ["unresolvable_typearg"] = false,
   ["circular_require"] = false,
   ["tuple"] = false,
   ["poly"] = false,
   ["any"] = false,
   ["unknown"] = false,
   ["invalid"] = false,
   ["none"] = false,
   ["*"] = false,
}

local interface Type
   is Where
   where self.typename

   y: integer
   x: integer

   typename: TypeName    -- discriminator
   typeid: integer       -- unique identifier
   inferred_at: Where    -- for error messages
   needs_compat: boolean -- for Lua compatibilty
end

local record StringType
   is Type
   where self.typename == "string"

   literal: string
end

local function is_numeric_type(t:Type): boolean
   return t.typename == "number" or t.typename == "integer"
end

local interface NumericType
   is Type
   where is_numeric_type(self)
end

local record IntegerType
   is NumericType
   where self.typename == "integer"
end

local record BooleanType
   is Type
   where self.typename == "boolean"
end

local interface HasTypeArgs
   is Type
   where self.typeargs

   typeargs: {TypeArgType}
end

local record TypeDeclType
   is Type, HasTypeArgs
   where self.typename == "typedecl"

   def: Type
   closed: boolean
end

local record TypeAliasType
   is Type, HasTypeArgs
   where self.typename == "typealias"

   alias_to: NominalType
   is_nested_alias: boolean
end

local type TypeType = TypeDeclType | TypeAliasType

local record LiteralTableItemType
   is Type
   where self.typename == "literal_table_item"

   -- table items
   kname: string
   ktype: Type
   vtype: Type
end

local record Scope
   vars: {string:Variable}
   labels: {string:Node}
   pending_labels: {string:{Node}}
   pending_nominals: {string:{NominalType}}
   pending_global_types: {string:boolean}
   narrows: {string:boolean}
end

local interface HasDeclName
   declname: string
end

local record NominalType
   is Type
   where self.typename == "nominal"

   names: {string}
   typevals: {Type}
   found: TypeType      -- type is found but typeargs are not resolved
   resolved: Type       -- type is found and typeargs are resolved
end

local interface ArrayLikeType
   is Type
   where self.elements

   elements: Type
   consttypes: {Type}
   inferred_len: integer
end

local interface RecordLikeType
   is Type, HasTypeArgs, HasDeclName, ArrayLikeType
   where self.fields

   interface_list: {ArrayType | NominalType}
   interfaces_expanded: boolean
   fields: {string: Type}
   field_order: {string}
   meta_fields: {string: Type}
   meta_field_order: {string}
   is_userdata: boolean
end

local record ArrayType
   is ArrayLikeType
   where self.typename == "array"
end

local record RecordType
   is RecordLikeType
   where self.typename == "record"
end

local record InterfaceType
   is RecordLikeType
   where self.typename == "interface"
end

local record InvalidType
   is Type
   where self.typename == "invalid"
end

local record UnknownType
   is Type
   where self.typename == "unknown"
end

local record TupleType
   is Type
   where self.typename == "tuple"

   is_va: boolean
   tuple: {Type}
end

local record TypeArgType
   is Type
   where self.typename == "typearg"

   typearg: string
   constraint: Type
end

local record UnresolvedTypeArgType
   is Type
   where self.typename == "unresolved_typearg"

   typearg: string
   constraint: Type
end

local record UnresolvableTypeArgType
   is Type
   where self.typename == "unresolvable_typearg"

   typearg: string
end

local record TypeVarType
   is Type
   where self.typename == "typevar"

   typevar: string
   constraint: Type
end

local record MapType
   is Type
   where self.typename == "map"

   keys: Type
   values: Type
end

local record EmptyTableType
   is Type
   where self.typename == "emptytable"

   declared_at: Node
   assigned_to: string
   keys: Type
end

local record UnresolvedEmptyTableValueType
   is Type
   where self.typename == "unresolved_emptytable_value"

   emptytable_type: EmptyTableType
end

local record FunctionType
   is Type, HasTypeArgs
   where self.typename == "function"

   is_method: boolean
   is_record_function: boolean
   min_arity: integer
   args: TupleType
   rets: TupleType
   macroexp: Node
end

local interface AggregateType
   is Type
   where self.types

   types: {Type}
end

local record UnionType
   is AggregateType
   where self.typename == "union"
end

local record TupleTableType
   is AggregateType
   where self.typename == "tupletable"
end

local record PolyType
   is AggregateType
   where self.typename == "poly"

   types: {FunctionType}
end

local record EnumType
   is Type, HasDeclName
   where self.typename == "enum"

   enumset: {string:boolean}
end

local record Operator
   y: integer
   x: integer
   arity: integer
   op: string
   prec: integer
end

local enum NodeKind
   "op"
   "nil"
   "string"
   "number"
   "integer"
   "boolean"
   "literal_table"
   "literal_table_item"
   "function"
   "expression_list"
   "enum_item"
   "if"
   "if_block"
   "while"
   "fornum"
   "forin"
   "goto"
   "label"
   "repeat"
   "do"
   "break"
   "return"
   "newtype"
   "argument"
   "type_identifier"
   "variable"
   "variable_list"
   "statements"
   "assignment"
   "argument_list"
   "local_function"
   "global_function"
   "local_type"
   "global_type"
   "record_function"
   "local_declaration"
   "global_declaration"
   "identifier"
   "cast"
   "..."
   "paren"
   "macroexp"
   "local_macroexp"
   "interface"
   "error_node"
end

local enum FactType
   "is"     -- type-based type judgement (its negation implies the subtracted type)
   "=="     -- value-based type judgement (its negation does not imply a subtracted type negated)
   "not"    -- negation: type-based judgements subtract, value-based judgements prove nothing
   "and"    -- conjunction: type-based judgements intersect, any value-based judgement downgrades all
   "or"     -- disjunction: type-based judgements unite, any value-based judgement downgrades all
   "truthy" -- expression that is either truthy or a runtime error
end

local interface Fact
   where self.fact

   fact: FactType
   w: Where
   no_infer: boolean
end

local record TruthyFact
   is Fact
   where self.fact == "truthy"

   metamethod __call: function(Fact, Fact): TruthyFact
end

local record NotFact
   is Fact
   where self.fact == "not"

   f1: Fact

   metamethod __call: function(Fact, Fact): NotFact
end

local record AndFact
   is Fact
   where self.fact == "and"

   f1: Fact
   f2: Fact

   metamethod __call: function(Fact, Fact): AndFact
end

local record OrFact
   is Fact
   where self.fact == "or"

   f1: Fact
   f2: Fact

   metamethod __call: function(Fact, Fact): OrFact
end

local record EqFact
   is Fact
   where self.fact == "=="

   var: string
   typ: Type

   metamethod __call: function(Fact, Fact): EqFact
end

local record IsFact
   is Fact
   where self.fact == "is"

   var: string
   typ: Type

   metamethod __call: function(Fact, Fact): IsFact
end

local enum KeyParsed
   "short"
   "long"
   "implicit"
end

local enum Attribute
   "const"
   "close"
   "total"
end

local attributes <total>: {Attribute: boolean} = {
   ["const"] = true,
   ["close"] = true,
   ["total"] = true,
}
local is_attribute <const>: {string:boolean} = attributes as {string:boolean}

local record Node
   is {Node}, Where
   where self.kind ~= nil

   record ExpectedContext
      kind: NodeKind
      name: string
   end

   tk: string
   kind: NodeKind
   symbol_list_slot: integer
   semicolon: boolean
   hashbang: string

   is_longstring: boolean

   yend: integer
   xend: integer

   known: Fact

   -- bidirectional inference
   expected: Type
   expected_context: Node.ExpectedContext

   key: Node
   value: Node
   key_parsed: KeyParsed

   typeargs: {TypeArgType}
   min_arity: integer
   args: Node
   rets: TupleType
   body: Node
   implicit_global_function: boolean
   is_predeclared_local_function: boolean

   name: Node

   -- statements list in a `repeat`, delay closing scope
   is_repeat: boolean

   -- var declaration
   attribute: Attribute

   fn_owner: Node
   is_method: boolean

   exp: Node
   if_parent: Node
   if_block_n: integer
   if_blocks: {Node}
   block_returns: boolean

   -- fornum
   var: Node
   from: Node
   to: Node
   step: Node

   -- forin
   vars: Node
   exps: Node

   -- newtype
   newtype: TypeType
   elide_type: boolean

   -- expressions
   op: Operator
   e1: Node
   e2: Node
   constnum: number
   conststr: string
   failstore: boolean
   discarded_tuple: boolean
   receiver: Type

   -- table literal
   array_len: integer
   is_total: boolean
   missing: {string}

   -- goto
   label: string

   -- label
   used_label: boolean

   casttype: Type

   -- variable
   is_lvalue: boolean

   -- macroexp
   macrodef: Node
   expanded: Node

   argtype: Type
   itemtype: Type
   decltuple: TupleType

   opt: boolean

   debug_type: Type
end

local function a_type<T is Type>(w: Where, typename: TypeName, t: T): T
   t.typeid = new_typeid()
   t.f = w.f
   t.x = w.x
   t.y = w.y
   t.typename = typename
   return t
end

local function edit_type(w: Where, t: Type, typename: TypeName): Type
   t.typeid = new_typeid()
   t.f = w.f
   t.x = w.x
   t.y = w.y
   t.typename = typename
   return t
end

local macroexp a_typedecl(w: Where, def: Type): TypeDeclType
   return a_type(w, "typedecl", { def = def } as TypeDeclType)
end

local macroexp a_tuple(w: Where, t: {Type}): TupleType
   return a_type(w, "tuple", { tuple = t } as TupleType)
end

local macroexp a_union(w: Where, t: {Type}): UnionType
   return a_type(w, "union", { types = t } as UnionType)
end

local function a_function(w: Where, t: FunctionType): FunctionType
   assert(t.min_arity)
   return a_type(w, "function", t)
end

local function a_vararg(w: Where, t: {Type}): TupleType
   local typ = a_tuple(w, t)
   typ.is_va = true
   return typ
end

local macroexp an_array(w: Where, t: Type): ArrayType
   return a_type(w, "array", { elements = t } as ArrayType)
end

local macroexp a_map(w: Where, k: Type, v: Type): MapType
   return a_type(w, "map", { keys = k, values = v } as MapType)
end

local function a_nominal(n: Node, names: {string}): NominalType
   return a_type(n, "nominal", { names = names } as NominalType)
end

local macroexp an_invalid(w: Where): InvalidType
   return a_type(w, "invalid", {} as InvalidType)
end

local macroexp an_unknown(w: Where): UnknownType
   return a_type(w, "unknown", {} as UnknownType)
end

local an_operator: function(Node, integer, string): Operator

local function shallow_copy_new_type<T is Type>(t: T): T
   local copy: {any:any} = {}
   for k, v in pairs(t as {any:any}) do
      copy[k] = v
   end
   copy.typeid = new_typeid()
   return copy as T
end

local function shallow_copy_table<T>(t: T): T
   local copy: {any:any} = {}
   for k, v in pairs(t as {any:any}) do
      copy[k] = v
   end
   return copy as T
end

-- TODO move to Errors module
local function clear_redundant_errors(errors: {Error})
   local redundant: {integer} = {}
   local lastx, lasty = 0, 0
   for i, err in ipairs(errors) do
      err.i = i
   end
   table.sort(errors, function(a: Error, b: Error): boolean
      local af = assert(a.filename)
      local bf = assert(b.filename)
      return af < bf
             or (af == bf   and (a.y < b.y
             or (a.y == b.y and (a.x < b.x
             or (a.x == b.x and (a.i < b.i))))))
   end)
   for i, err in ipairs(errors) do
      err.i = nil
      if err.x == lastx and err.y == lasty then
         table.insert(redundant, i)
      end
      lastx, lasty = err.x, err.y
   end
   for i = #redundant, 1, -1 do
      table.remove(errors, redundant[i])
   end
end

local simple_types: {TypeName:boolean} = {
   ["nil"] = true,
   ["any"] = true,
   ["number"] = true,
   ["string"] = true,
   ["thread"] = true,
   ["boolean"] = true,
   ["integer"] = true,
}

do -----------------------------------------------------------------------------

local record ParseState
   tokens: {Token}
   errs: {Error}
   filename: string
   end_alignment_hint: Error

   required_modules: {string}
end

local enum ParseTypeListMode
   "rets"
   "decltuple"
   "casttype"
end

local parse_type_list: function(ParseState, integer, ParseTypeListMode): integer, TupleType
local parse_expression: function(ParseState, integer): integer, Node, integer
local parse_expression_and_tk: function(ps: ParseState, i: integer, tk: string): integer, Node
local parse_statements: function(ParseState, integer, ? boolean): integer, Node
local parse_argument_list: function(ParseState, integer): integer, Node, integer
local parse_argument_type_list: function(ParseState, integer): integer, TupleType, boolean, integer
local parse_type: function(ParseState, integer): integer, Type, integer
local parse_type_declaration: function(ps: ParseState, i: integer, node_name: NodeKind): integer, Node
local parse_newtype: function(ps: ParseState, i: integer): integer, Node
local parse_interface_name: function(ps: ParseState, i: integer): integer, Type, integer

local type ParseBody = function(ps: ParseState, i: integer, def: Type, node: Node): integer, Node
local parse_enum_body: function(ps: ParseState, i: integer, def: EnumType, node: Node): integer, Node
local parse_record_body: function(ps: ParseState, i: integer, def: Type, node: Node): integer, Node
local parse_type_body_fns: {TypeName:ParseBody}

local function fail(ps: ParseState, i: integer, msg: string): integer
   if not ps.tokens[i] then
      local eof = ps.tokens[#ps.tokens]
      table.insert(ps.errs, { filename = ps.filename, y = eof.y, x = eof.x, msg = msg or "unexpected end of file" })
      return #ps.tokens
   end
   table.insert(ps.errs, { filename = ps.filename, y = ps.tokens[i].y, x = ps.tokens[i].x, msg = assert(msg, "syntax error, but no error message provided") })
   return math.min(#ps.tokens, i + 1)
end

local function end_at(node: Node, tk: Token)
   node.yend = tk.y
   node.xend = tk.x + #tk.tk - 1
end

local function verify_tk(ps: ParseState, i: integer, tk: string): integer
   if ps.tokens[i].tk == tk then
      return i + 1
   end
   return fail(ps, i, "syntax error, expected '" .. tk .. "'")
end

local function verify_end(ps: ParseState, i: integer, istart: integer, node: Node): integer
   if ps.tokens[i].tk == "end" then
      local endy, endx = ps.tokens[i].y, ps.tokens[i].x
      node.yend = endy
      node.xend = endx + 2
      if node.kind ~= "function" and endy ~= node.y and endx ~= node.x then
         if not ps.end_alignment_hint then
            ps.end_alignment_hint = { filename = ps.filename, y = node.y, x = node.x, msg = "syntax error hint: construct starting here is not aligned with its 'end' at " .. ps.filename .. ":" .. endy .. ":" .. endx .. ":" }
         end
      end
      return i + 1
   end
   end_at(node, ps.tokens[i])
   if ps.end_alignment_hint then
      table.insert(ps.errs, ps.end_alignment_hint)
      ps.end_alignment_hint = nil
   end
   return fail(ps, i, "syntax error, expected 'end' to close construct started at " .. ps.filename .. ":" .. ps.tokens[istart].y .. ":" .. ps.tokens[istart].x .. ":")
end

local function new_node(ps: ParseState, i: integer, kind?: NodeKind): Node
   local t = ps.tokens[i]
   return { f = ps.filename, y = t.y, x = t.x, tk = t.tk, kind = kind or (t.kind as NodeKind) }
end

local function new_type(ps: ParseState, i: integer, typename: TypeName): Type
   local token = ps.tokens[i]
   local t: Type = {}
   t.typeid = new_typeid()
   t.f = ps.filename
   t.x = token.x
   t.y = token.y
   t.typename = typename
   return t
end

local function new_typedecl(ps: ParseState, i: integer, def: Type): TypeDeclType
   local t = new_type(ps, i, "typedecl") as TypeDeclType
   t.def = def
   return t
end

local function new_tuple(ps: ParseState, i: integer, types?: {Type}, is_va?: boolean): TupleType, {Type}
   local t = new_type(ps, i, "tuple") as TupleType
   t.is_va = is_va
   t.tuple = types or {}
   return t, t.tuple
end

local function new_typealias(ps: ParseState, i: integer, alias_to: NominalType): TypeAliasType
   local t = new_type(ps, i, "typealias") as TypeAliasType
   t.alias_to = alias_to
   return t
end

local function new_nominal(ps: ParseState, i: integer, name?: string): NominalType
   local t = new_type(ps, i, "nominal") as NominalType
   if name then
      t.names = { name }
   end
   return t
end

local function verify_kind(ps: ParseState, i: integer, kind: TokenKind, node_kind?: NodeKind): integer, Node
   if ps.tokens[i].kind == kind then
      return i + 1, new_node(ps, i, node_kind)
   end
   return fail(ps, i, "syntax error, expected " .. kind)
end

local type SkipFunction = function(ParseState, integer): integer, Node

local function skip(ps: ParseState, i: integer, skip_fn: SkipFunction): integer, Node
   local err_ps: ParseState = {
      filename = ps.filename,
      tokens = ps.tokens,
      errs = {},
      required_modules = {},
   }
   return skip_fn(err_ps, i)
end

local function failskip(ps: ParseState, i: integer, msg: string, skip_fn: SkipFunction, starti?: integer): integer
   local skip_i = skip(ps, starti or i, skip_fn)
   fail(ps, i, msg)
   return skip_i
end

local function skip_type_body(ps: ParseState, i: integer): integer, Node
   local tn = ps.tokens[i].tk as TypeName
   i = i + 1
   assert(parse_type_body_fns[tn], tn .. " has no parse body function")
   return parse_type_body_fns[tn](ps, i, {}, { kind = "function" --[[ skip end_alignment_hint ]] })
end

local function parse_table_value(ps: ParseState, i: integer): integer, Node, integer
   local next_word = ps.tokens[i].tk
   if next_word == "record" or next_word == "interface" then
      local skip_i, e = skip(ps, i, skip_type_body)
      if e then
         fail(ps, i, next_word == "record"
                     and "syntax error: this syntax is no longer valid; declare nested record inside a record"
                     or  "syntax error: cannot declare interface inside a table; use a statement")
         return skip_i, new_node(ps, i, "error_node")
      end
   elseif next_word == "enum" and ps.tokens[i + 1].kind == "string" then
      i = failskip(ps, i, "syntax error: this syntax is no longer valid; declare nested enum inside a record", skip_type_body)
      return i, new_node(ps, i - 1, "error_node")
   end

   local e: Node
   i, e = parse_expression(ps, i)
   if not e then
      e = new_node(ps, i - 1, "error_node")
   end
   return i, e
end

local function parse_table_item(ps: ParseState, i: integer, n?: integer): integer, Node, integer
   local node = new_node(ps, i, "literal_table_item")
   if ps.tokens[i].kind == "$EOF$" then
      return fail(ps, i, "unexpected eof")
   end

   if ps.tokens[i].tk == "[" then
      node.key_parsed = "long"
      i = i + 1
      i, node.key = parse_expression_and_tk(ps, i, "]")
      i = verify_tk(ps, i, "=")
      i, node.value = parse_table_value(ps, i)
      return i, node, n
   elseif ps.tokens[i].kind == "identifier" then
      if ps.tokens[i+1].tk == "=" then
         node.key_parsed = "short"
         i, node.key = verify_kind(ps, i, "identifier", "string")
         node.key.conststr = node.key.tk
         node.key.tk = '"' .. node.key.tk .. '"'
         i = verify_tk(ps, i, "=")
         i, node.value = parse_table_value(ps, i)
         return i, node, n
      elseif ps.tokens[i+1].tk == ":" then
         node.key_parsed = "short"
         local orig_i = i
         local try_ps: ParseState = {
            filename = ps.filename,
            tokens = ps.tokens,
            errs = {},
            required_modules = ps.required_modules,
         }
         i, node.key = verify_kind(try_ps, i, "identifier", "string")
         node.key.conststr = node.key.tk
         node.key.tk = '"' .. node.key.tk .. '"'
         i = verify_tk(try_ps, i, ":")
         i, node.itemtype = parse_type(try_ps, i)
         if node.itemtype and ps.tokens[i].tk == "=" then
            i = verify_tk(try_ps, i, "=")
            i, node.value = parse_table_value(try_ps, i)
            if node.value then
               for _, e in ipairs(try_ps.errs) do
                  table.insert(ps.errs, e)
               end
               return i, node, n
            end
         end
         -- backtrack:
         node.itemtype = nil
         i = orig_i
      end
   end

   node.key = new_node(ps, i, "integer")
   node.key_parsed = "implicit"
   node.key.constnum = n
   node.key.tk = tostring(n)
   i, node.value = parse_expression(ps, i)
   if not node.value then
      return fail(ps, i, "expected an expression")
   end
   return i, node, n + 1
end

local type ParseItem = function<T>(ParseState, integer, ? integer): integer, T, integer

local enum SeparatorMode
   "sep"
   "term"
end

local function parse_list<T>(ps: ParseState, i: integer, list: {T}, close: {string:boolean}, sep: SeparatorMode, parse_item: ParseItem<T>): integer, {T}
   local n = 1
   while ps.tokens[i].kind ~= "$EOF$" do
      if close[ps.tokens[i].tk] then
         end_at(list as Node, ps.tokens[i])
         break
      end
      local item: T
      local oldn = n
      i, item, n = parse_item(ps, i, n)
      n = n or oldn
      table.insert(list, item)
      if ps.tokens[i].tk == "," then
         i = i + 1
         if sep == "sep" and close[ps.tokens[i].tk] then
            fail(ps, i, "unexpected '" .. ps.tokens[i].tk .. "'")
            return i, list
         end
      elseif sep == "term" and ps.tokens[i].tk == ";" then
         i = i + 1
      elseif not close[ps.tokens[i].tk] then
         local options = {}
         for k, _ in pairs(close) do
            table.insert(options, "'" .. k .. "'")
         end
         table.sort(options)
         local first = options[1]:sub(2, -2)
         local msg: string
         -- heuristic for parenthesized lists
         if first == ")" and ps.tokens[i].tk == "=" then
            msg = "syntax error, cannot perform an assignment here (did you mean '=='?)"
            i = failskip(ps, i, msg, parse_expression, i + 1)
         else
            table.insert(options, "','")
            msg = "syntax error, expected one of: " .. table.concat(options, ", ")
            fail(ps, i, msg)
         end
         -- heuristic for error recovery to avoid a cascade of errors:
         -- * if we're parsing a bracketed list, assume the missing token is a separator;
         -- * otherwise, if we have a line break, insert expected terminator token.
         if first ~= "}" and ps.tokens[i].y ~= ps.tokens[i-1].y then
            -- FIXME closing token may not be a keyword (but non-keywords are checked with verify_tk, so it should work)
            table.insert(ps.tokens, i, { tk = first, y = ps.tokens[i-1].y, x = ps.tokens[i-1].x + 1, kind = "keyword" })
            return i, list
         end
      end
   end
   return i, list
end

local function parse_bracket_list<T>(ps: ParseState, i: integer, list: {T}, open: string, close: string, sep: SeparatorMode, parse_item: ParseItem<T>): integer, {T}
   i = verify_tk(ps, i, open)
   i = parse_list(ps, i, list, { [close] = true }, sep, parse_item)
   i = verify_tk(ps, i, close)
   return i, list
end

local function parse_table_literal(ps: ParseState, i: integer): integer, Node
   local node = new_node(ps, i, "literal_table")
   return parse_bracket_list(ps, i, node, "{", "}", "term", parse_table_item)
end

local function parse_trying_list<T>(ps: ParseState, i: integer, list: {T}, parse_item: ParseItem<T>): integer, {T}
   local try_ps: ParseState = {
      filename = ps.filename,
      tokens = ps.tokens,
      errs = {},
      required_modules = ps.required_modules,
   }
   local tryi, item: integer, T = parse_item(try_ps, i)
   if not item then
      return i, list
   end
   for _, e in ipairs(try_ps.errs) do
      table.insert(ps.errs, e)
   end
   i = tryi
   table.insert(list, item)
   if ps.tokens[i].tk == "," then
      while ps.tokens[i].tk == "," do
         i = i + 1
         i, item = parse_item(ps, i)
         table.insert(list, item)
      end
   end
   return i, list
end

local function parse_anglebracket_list<T is Type>(ps: ParseState, i: integer, parse_item: ParseItem<T>): integer, {T}
   if ps.tokens[i+1].tk == ">" then
      return fail(ps, i+1, "type argument list cannot be empty")
   end
   local types: {T} = {}
   i = verify_tk(ps, i, "<")
   i = parse_list(ps, i, types, { [">"] = true, [">>"] = true, }, "sep", parse_item)
   if ps.tokens[i].tk == ">" then
      i = i + 1
   elseif ps.tokens[i].tk == ">>" then
      -- tokenizer hack: consume one bracket from '>>', don't increment i
      ps.tokens[i].tk = ">"
   else
      return fail(ps, i, "syntax error, expected '>'")
   end
   return i, types
end

local function parse_typearg(ps: ParseState, i: integer): integer, TypeArgType, integer
   local name = ps.tokens[i].tk
   local constraint: Type
   i = verify_kind(ps, i, "identifier")
   if ps.tokens[i].tk == "is" then
      i = i + 1
      i, constraint = parse_interface_name(ps, i) -- FIXME what about generic interfaces
   end
   local t = new_type(ps, i, "typearg") as TypeArgType
   t.typearg = name
   t.constraint = constraint
   return i, t
end

local function parse_return_types(ps: ParseState, i: integer): integer, TupleType
   local iprev = i - 1
   local t: TupleType
   i, t = parse_type_list(ps, i, "rets")
   if #t.tuple == 0 then
      t.x = ps.tokens[iprev].x
      t.y = ps.tokens[iprev].y
   end
   return i, t
end

local function parse_function_type(ps: ParseState, i: integer): integer, FunctionType
   local typ = new_type(ps, i, "function") as FunctionType
   i = i + 1
   if ps.tokens[i].tk == "<" then
      i, typ.typeargs = parse_anglebracket_list(ps, i, parse_typearg)
   end
   if ps.tokens[i].tk == "(" then
      i, typ.args, typ.is_method, typ.min_arity = parse_argument_type_list(ps, i)
      i, typ.rets = parse_return_types(ps, i)
   else
      typ.args = new_tuple(ps, i, { new_type(ps, i, "any") }, true)
      typ.rets = new_tuple(ps, i, { new_type(ps, i, "any") }, true)
      typ.is_method = false
      typ.min_arity = 0
   end
   return i, typ
end

local function parse_simple_type_or_nominal(ps: ParseState, i: integer): integer, Type
   local tk = ps.tokens[i].tk
   local st = simple_types[tk as TypeName]
   if st then
      return i + 1, new_type(ps, i, tk as TypeName)
   elseif tk == "table" and ps.tokens[i + 1].tk ~= "."  then
      local typ = new_type(ps, i, "map") as MapType
      typ.keys = new_type(ps, i, "any")
      typ.values = new_type(ps, i, "any")
      return i + 1, typ
   end

   local typ = new_nominal(ps, i, tk)
   i = i + 1
   while ps.tokens[i].tk == "." do
      i = i + 1
      if ps.tokens[i].kind == "identifier" then
         table.insert(typ.names, ps.tokens[i].tk)
         i = i + 1
      else
         return fail(ps, i, "syntax error, expected identifier")
      end
   end

   if ps.tokens[i].tk == "<" then
      i, typ.typevals = parse_anglebracket_list(ps, i, parse_type)
   end
   return i, typ
end

local function parse_base_type(ps: ParseState, i: integer): integer, Type, integer
   local tk = ps.tokens[i].tk
   if ps.tokens[i].kind == "identifier" then
      return parse_simple_type_or_nominal(ps, i)
   elseif tk == "{" then
      local istart = i
      i = i + 1
      local t: Type
      i, t = parse_type(ps, i)
      if not t then
         return i
      end
      if ps.tokens[i].tk == "}" then
         local decl = new_type(ps, istart, "array") as ArrayType
         decl.elements = t
         end_at(decl as Node, ps.tokens[i])
         i = verify_tk(ps, i, "}")
         return i, decl
      elseif ps.tokens[i].tk == "," then
         local decl = new_type(ps, istart, "tupletable") as TupleTableType
         decl.types = { t }
         local n = 2
         repeat
            i = i + 1
            i, decl.types[n] = parse_type(ps, i)
            if not decl.types[n] then
               break
            end
            n = n + 1
         until ps.tokens[i].tk ~= ","
         end_at(decl as Node, ps.tokens[i])
         i = verify_tk(ps, i, "}")
         return i, decl
      elseif ps.tokens[i].tk == ":" then
         local decl = new_type(ps, istart, "map") as MapType
         i = i + 1
         decl.keys = t
         i, decl.values = parse_type(ps, i)
         if not decl.values then
            return i
         end
         end_at(decl as Node, ps.tokens[i])
         i = verify_tk(ps, i, "}")
         return i, decl
      end
      return fail(ps, i, "syntax error; did you forget a '}'?")
   elseif tk == "function" then
      return parse_function_type(ps, i)
   elseif tk == "nil" then
      return i + 1, new_type(ps, i, "nil")
   end
   return fail(ps, i, "expected a type")
end

parse_type = function(ps: ParseState, i: integer): integer, Type, integer
   if ps.tokens[i].tk == "(" then
      i = i + 1
      local t: Type
      i, t = parse_type(ps, i)
      i = verify_tk(ps, i, ")")
      return i, t
   end

   local bt: Type
   local istart = i
   i, bt = parse_base_type(ps, i)
   if not bt then
      return i
   end
   if ps.tokens[i].tk == "|" then
      local u = new_type(ps, istart, "union") as UnionType
      u.types = { bt }
      while ps.tokens[i].tk == "|" do
         i = i + 1
         i, bt = parse_base_type(ps, i)
         if not bt then
            return i
         end
         table.insert(u.types, bt)
      end
      bt = u
   end
   return i, bt
end

parse_type_list = function(ps: ParseState, i: integer, mode: ParseTypeListMode): integer, TupleType
   local t, list = new_tuple(ps, i)

   local first_token = ps.tokens[i].tk
   if mode == "rets" or mode == "decltuple" then
      if first_token == ":" then
         i = i + 1
      else
         return i, t
      end
   end

   local optional_paren = false
   if ps.tokens[i].tk == "(" then
      optional_paren = true
      i = i + 1
   end

   local prev_i = i
   i = parse_trying_list(ps, i, list, parse_type)
   if i == prev_i and ps.tokens[i].tk ~= ")" then
      fail(ps, i - 1, "expected a type list")
   end

   if mode == "rets" and ps.tokens[i].tk == "..." then
      i = i + 1
      local nrets = #list
      if nrets > 0 then
         t.is_va = true
      else
         fail(ps, i, "unexpected '...'")
      end
   end

   if optional_paren then
      i = verify_tk(ps, i, ")")
   end

   return i, t
end

local function parse_function_args_rets_body(ps: ParseState, i: integer, node: Node): integer, Node
   local istart = i - 1
   if ps.tokens[i].tk == "<" then
      i, node.typeargs = parse_anglebracket_list(ps, i, parse_typearg)
   end
   i, node.args, node.min_arity = parse_argument_list(ps, i)
   i, node.rets = parse_return_types(ps, i)
   i, node.body = parse_statements(ps, i)
   end_at(node, ps.tokens[i])
   i = verify_end(ps, i, istart, node)
   return i, node
end

local function parse_function_value(ps: ParseState, i: integer): integer, Node
   local node = new_node(ps, i, "function")
   i = verify_tk(ps, i, "function")
   return parse_function_args_rets_body(ps, i, node)
end

local function unquote(str: string): string, boolean
   local f = str:sub(1, 1)
   if f == '"' or f == "'" then
      return str:sub(2, -2), false
   end
   f = str:match("^%[=*%[")
   local l = #f + 1
   return str:sub(l, -l), true
end

local function parse_literal(ps: ParseState, i: integer): integer, Node
   local tk = ps.tokens[i].tk
   local kind = ps.tokens[i].kind
   if kind == "identifier" then
      return verify_kind(ps, i, "identifier", "variable")
   elseif kind == "string" then
      local node = new_node(ps, i, "string")
      node.conststr, node.is_longstring = unquote(tk)
      return i + 1, node
   elseif kind == "number" or kind == "integer" then
      local n = tonumber(tk)
      local node: Node
      i, node = verify_kind(ps, i, kind)
      node.constnum = n
      return i, node
   elseif tk == "true" then
      return verify_kind(ps, i, "keyword", "boolean")
   elseif tk == "false" then
      return verify_kind(ps, i, "keyword", "boolean")
   elseif tk == "nil" then
      return verify_kind(ps, i, "keyword", "nil")
   elseif tk == "function" then
      return parse_function_value(ps, i)
   elseif tk == "{" then
      return parse_table_literal(ps, i)
   elseif kind == "..." then
      return verify_kind(ps, i, "...")
   elseif kind == "$ERR invalid_string$" then
      return fail(ps, i, "malformed string")
   elseif kind == "$ERR invalid_number$" then
      return fail(ps, i, "malformed number")
   end
   return fail(ps, i, "syntax error")
end

local function node_is_require_call(n: Node): string
   if n.e1 and n.e2 -- literal require call
      and n.e1.kind == "variable" and n.e1.tk == "require"
      and n.e2.kind == "expression_list" and #n.e2 == 1
      and n.e2[1].kind == "string"
   then
      return n.e2[1].conststr
   elseif n.op and n.op.op == "@funcall" -- pcall(require, "str")
      and n.e1 and n.e1.tk == "pcall"
      and n.e2 and #n.e2 == 2
      and n.e2[1].kind == "variable" and n.e2[1].tk == "require"
      and n.e2[2].kind == "string" and n.e2[2].conststr
   then
      return n.e2[2].conststr
   else
      return nil -- table.insert cares about arity
   end
end

do
   local precedences: {integer:{string:integer}} = {
      [1] = {
         ["not"] = 11,
         ["#"] = 11,
         ["-"] = 11,
         ["~"] = 11,
      },
      [2] = {
         ["or"] = 1,
         ["and"] = 2,
         ["is"] = 3,
         ["<"] = 3,
         [">"] = 3,
         ["<="] = 3,
         [">="] = 3,
         ["~="] = 3,
         ["=="] = 3,
         ["|"] = 4,
         ["~"] = 5,
         ["&"] = 6,
         ["<<"] = 7,
         [">>"] = 7,
         [".."] = 8,
         ["+"] = 9,
         ["-"] = 9,
         ["*"] = 10,
         ["/"] = 10,
         ["//"] = 10,
         ["%"] = 10,
         ["^"] = 12,
         ["as"] = 50,
         ["@funcall"] = 100,
         ["@index"] = 100,
         ["."] = 100,
         [":"] = 100,
      },
   }

   local is_right_assoc: {string:boolean} = {
      ["^"] = true,
      [".."] = true,
   }

   local function new_operator(tk: Token, arity: integer, op: string): Operator
      return { y = tk.y, x = tk.x, arity = arity, op = op, prec = precedences[arity][op] }
   end

   an_operator = function(node: Node, arity: integer, op: string): Operator
      return { y = node.y, x = node.x, arity = arity, op = op, prec = precedences[arity][op] }
   end

   local args_starters: {TokenKind:boolean} = {
      ["("] = true,
      ["{"] = true,
      ["string"] = true,
   }

   local E: function(ParseState, integer, Node, integer): integer, Node

   local function after_valid_prefixexp(ps: ParseState, prevnode: Node, i: integer): boolean
      return ps.tokens[i - 1].kind == ")" -- '(' exp ')'
         or (prevnode.kind == "op"
             and (prevnode.op.op == "@funcall"
                  or prevnode.op.op == "@index"
                  or prevnode.op.op == "."
                  or prevnode.op.op == ":")
             )
         or prevnode.kind == "identifier"
         or prevnode.kind == "variable"
   end

   -- small hack: for the sake of `tl types`, parse an invalid binary exp
   -- as a paren to produce a unary indirection on e1 and save its location.
   local function failstore(ps: ParseState, tkop: Token, e1: Node): Node
      return { f = ps.filename, y = tkop.y, x = tkop.x, kind = "paren", e1 = e1, failstore = true }
   end

   local function P(ps: ParseState, i: integer): integer, Node
      if ps.tokens[i].kind == "$EOF$" then
         return i
      end
      local e1: Node
      local t1 = ps.tokens[i]
      if precedences[1][t1.tk] ~= nil then
         local op: Operator = new_operator(t1, 1, t1.tk)
         i = i + 1
         local prev_i = i
         i, e1 = P(ps, i)
         if not e1 then
            fail(ps, prev_i, "expected an expression")
            return i
         end
         e1 = { f = ps.filename, y = t1.y, x = t1.x, kind = "op", op = op, e1 = e1 }
      elseif ps.tokens[i].tk == "(" then
         i = i + 1
         local prev_i = i
         i, e1 = parse_expression_and_tk(ps, i, ")")
         if not e1 then
            fail(ps, prev_i, "expected an expression")
            return i
         end
         e1 = { f = ps.filename, y = t1.y, x = t1.x, kind = "paren", e1 = e1 }
      else
         i, e1 = parse_literal(ps, i)
      end

      if not e1 then
         return i
      end

      while true do
         local tkop = ps.tokens[i]
         if tkop.kind == "," or tkop.kind == ")" then -- check most common terminators first
            break
         end
         if tkop.tk == "." or tkop.tk == ":" then
            local op: Operator = new_operator(tkop, 2, tkop.tk)

            local prev_i = i

            local key: Node
            i = i + 1
            if ps.tokens[i].kind ~= "identifier" then
               local skipped = skip(ps, i, parse_type as SkipFunction)
               if skipped > i + 1 then
                  fail(ps, i, "syntax error, cannot declare a type here (missing 'local' or 'global'?)")
                  return skipped, failstore(ps, tkop, e1)
               end
            end
            i, key = verify_kind(ps, i, "identifier")
            if not key then
               return i, failstore(ps, tkop, e1)
            end

            if op.op == ":" then
               if not args_starters[ps.tokens[i].kind] then
                  if ps.tokens[i].tk == "=" then
                     fail(ps, i, "syntax error, cannot perform an assignment here (missing 'local' or 'global'?)")
                  else
                     fail(ps, i, "expected a function call for a method")
                  end
                  return i, failstore(ps, tkop, e1)
               end

               if not after_valid_prefixexp(ps, e1, prev_i) then
                  fail(ps, prev_i, "cannot call a method on this expression")
                  return i, failstore(ps, tkop, e1)
               end
            end

            e1 = { f = ps.filename, y = tkop.y, x = tkop.x, kind = "op", op = op, e1 = e1, e2 = key }
         elseif tkop.tk == "(" then
            local prev_tk = ps.tokens[i - 1]
            if tkop.y > prev_tk.y then
               table.insert(ps.tokens, i, { y = prev_tk.y, x = prev_tk.x + #prev_tk.tk, tk = ";", kind = ";" })
               break
            end

            local op: Operator = new_operator(tkop, 2, "@funcall")

            local prev_i = i

            local args = new_node(ps, i, "expression_list")
            i, args = parse_bracket_list(ps, i, args, "(", ")", "sep", parse_expression)

            if not after_valid_prefixexp(ps, e1, prev_i) then
               fail(ps, prev_i, "cannot call this expression")
               return i, failstore(ps, tkop, e1)
            end

            e1 = { f = ps.filename, y = args.y, x = args.x, kind = "op", op = op, e1 = e1, e2 = args }

            table.insert(ps.required_modules, node_is_require_call(e1))
         elseif tkop.tk == "[" then
            local op: Operator = new_operator(tkop, 2, "@index")

            local prev_i = i

            local idx: Node
            i = i + 1
            i, idx = parse_expression_and_tk(ps, i, "]")

            if not after_valid_prefixexp(ps, e1, prev_i) then
               fail(ps, prev_i, "cannot index this expression")
               return i, failstore(ps, tkop, e1)
            end

            e1 = { f = ps.filename, y = tkop.y, x = tkop.x, kind = "op", op = op, e1 = e1, e2 = idx }
         elseif tkop.kind == "string" or tkop.kind == "{" then
            local op: Operator = new_operator(tkop, 2, "@funcall")

            local prev_i = i

            local args = new_node(ps, i, "expression_list")
            local argument: Node
            if tkop.kind == "string" then
               argument = new_node(ps, i)
               argument.conststr = unquote(tkop.tk)
               i = i + 1
            else
               i, argument = parse_table_literal(ps, i)
            end

            if not after_valid_prefixexp(ps, e1, prev_i) then
               if tkop.kind == "string" then
                  fail(ps, prev_i, "cannot use a string here; if you're trying to call the previous expression, wrap it in parentheses")
               else
                  fail(ps, prev_i, "cannot use a table here; if you're trying to call the previous expression, wrap it in parentheses")
               end
               return i, failstore(ps, tkop, e1)
            end

            table.insert(args, argument)
            e1 = { f = ps.filename, y = args.y, x = args.x, kind = "op", op = op, e1 = e1, e2 = args }

            table.insert(ps.required_modules, node_is_require_call(e1))
         elseif tkop.tk == "as" or tkop.tk == "is" then
            local op: Operator = new_operator(tkop, 2, tkop.tk)

            i = i + 1
            local cast = new_node(ps, i, "cast")
            if ps.tokens[i].tk == "(" then
               i, cast.casttype = parse_type_list(ps, i, "casttype")
            else
               i, cast.casttype = parse_type(ps, i)
            end
            if not cast.casttype then
               return i, failstore(ps, tkop, e1)
            end
            e1 = { f = ps.filename, y = tkop.y, x = tkop.x, kind = "op", op = op, e1 = e1, e2 = cast, conststr = e1.conststr }
         else
            break
         end
      end

      return i, e1
   end

   E = function(ps: ParseState, i: integer, lhs: Node, min_precedence: integer): integer, Node
      local lookahead = ps.tokens[i].tk
      while precedences[2][lookahead] and precedences[2][lookahead] >= min_precedence do
         local t1 = ps.tokens[i]
         local op: Operator = new_operator(t1, 2, t1.tk)
         i = i + 1
         local rhs: Node
         i, rhs = P(ps, i)
         if not rhs then
            fail(ps, i, "expected an expression")
            return i
         end
         lookahead = ps.tokens[i].tk
         while precedences[2][lookahead] and ((precedences[2][lookahead] > (precedences[2][op.op]))
            or (is_right_assoc[lookahead] and (precedences[2][lookahead] == precedences[2][op.op]))) do
            i, rhs = E(ps, i, rhs, precedences[2][lookahead])
            if not rhs then
               fail(ps, i, "expected an expression")
               return i
            end
            lookahead = ps.tokens[i].tk
         end
         lhs = { f = ps.filename, y = t1.y, x = t1.x, kind = "op", op = op, e1 = lhs, e2 = rhs, }
      end
      return i, lhs
   end

   parse_expression = function(ps: ParseState, i: integer): integer, Node, integer
      local lhs: Node
      local istart = i
      i, lhs = P(ps, i)
      if lhs then
         i, lhs = E(ps, i, lhs, 0)
      end
      if lhs then
         return i, lhs, 0
      end
      -- if cursor moved, a more specific error was already thrown
      if i == istart then
         i = fail(ps, i, "expected an expression")
      end
      return i
   end
end

parse_expression_and_tk = function(ps: ParseState, i: integer, tk: string): integer, Node
   local e: Node
   i, e = parse_expression(ps, i)
   if not e then
      e = new_node(ps, i - 1, "error_node")
   end
   if ps.tokens[i].tk == tk then
      i = i + 1
   else
      local msg = "syntax error, expected '" .. tk .. "'"
      if ps.tokens[i].tk == "=" then
         msg = "syntax error, cannot perform an assignment here (did you mean '=='?)"
      end

      -- try to resync the parser for a bit
      for n = 0, 19 do
         local t = ps.tokens[i + n]
         if t.kind == "$EOF$" then
            break
         end
         if t.tk == tk then
            fail(ps, i, msg)
            return i + n + 1, e
         end
      end
      i = fail(ps, i, msg)
   end
   return i, e
end

local function parse_variable_name(ps: ParseState, i: integer): integer, Node, integer
   local node: Node
   i, node = verify_kind(ps, i, "identifier")
   if not node then
      return i
   end
   if ps.tokens[i].tk == "<" then
      i = i + 1
      local annotation: Node
      i, annotation = verify_kind(ps, i, "identifier")
      if annotation then
         if not is_attribute[annotation.tk] then
            fail(ps, i, "unknown variable annotation: " .. annotation.tk)
         end
         node.attribute = annotation.tk as Attribute
      else
         fail(ps, i, "expected a variable annotation")
      end
      i = verify_tk(ps, i, ">")
   end
   return i, node
end

local function parse_argument(ps: ParseState, i: integer): integer, Node, integer
   local node: Node
   if ps.tokens[i].tk == "..." then
      i, node = verify_kind(ps, i, "...", "argument")
      node.opt = true
   else
      i, node = verify_kind(ps, i, "identifier", "argument")
   end
   if ps.tokens[i].tk == "..." then
      fail(ps, i, "'...' needs to be declared as a typed argument")
   end
   if ps.tokens[i].tk == "?" then
      i = i + 1
      node.opt = true
   end
   if ps.tokens[i].tk == ":" then
      i = i + 1
      local argtype: Type

      i, argtype = parse_type(ps, i)

      if node then
         node.argtype = argtype
      end
   end
   return i, node, 0
end

parse_argument_list = function(ps: ParseState, i: integer): integer, Node, integer
   local node = new_node(ps, i, "argument_list")
   i, node = parse_bracket_list(ps, i, node, "(", ")", "sep", parse_argument)
   local opts = false
   local min_arity = 0
   for a, fnarg in ipairs(node) do
      if fnarg.tk == "..." then
         if a ~= #node then
            fail(ps, i, "'...' can only be last argument")
            break
         end
      elseif fnarg.opt then
         opts = true
      elseif opts then
         return fail(ps, i, "non-optional arguments cannot follow optional arguments")
      else
         min_arity = min_arity + 1
      end
   end
   return i, node, min_arity
end

local record ArgumentInfo
   i: integer
   type: Type
   is_va: boolean
   is_self: boolean
   opt: boolean
end

local function parse_argument_type(ps: ParseState, i: integer): integer, ArgumentInfo, integer
   local opt = false
   local is_va = false
   local is_self = false
   local argument_name: string = nil

   if ps.tokens[i].kind == "identifier" then
      argument_name = ps.tokens[i].tk
      if ps.tokens[i + 1].tk == "?" then
         opt = true
         if ps.tokens[i + 2].tk == ":" then
            i = i + 3
         end
      elseif ps.tokens[i + 1].tk == ":" then
         i = i + 2
      end
   elseif ps.tokens[i].kind == "?" then
      opt = true
      i = i + 1
   elseif ps.tokens[i].tk == "..." then
      if ps.tokens[i + 1].tk == ":" then
         i = i + 2
         is_va = true
      else
         return fail(ps, i, "cannot have untyped '...' when declaring the type of an argument")
      end
   end

   local typ: Type; i, typ = parse_type(ps, i)
   if typ then
      if not is_va and ps.tokens[i].tk == "..." then
         i = i + 1
         is_va = true
      end

      if argument_name == "self" then
         is_self = true
      end
   end

   return i, { i = i, type = typ, is_va = is_va, is_self = is_self, opt = opt or is_va }, 0
end

parse_argument_type_list = function(ps: ParseState, i: integer): integer, Type, boolean, integer
   local ars: {ArgumentInfo} = {}
   i = parse_bracket_list(ps, i, ars, "(", ")", "sep", parse_argument_type)
   local t, list = new_tuple(ps, i)
   local n = #ars
   local min_arity = 0
   for l, ar in ipairs(ars) do
      list[l] = ar.type
      if ar.is_va and l < n then
         fail(ps, ar.i, "'...' can only be last argument")
      end
      if not ar.opt then
         min_arity = min_arity + 1
      end
   end
   if n > 0 and ars[n].is_va then
      t.is_va = true
   end
   return i, t, (n > 0 and ars[1].is_self), min_arity
end

local function parse_identifier(ps: ParseState, i: integer): integer, Node, integer
   if ps.tokens[i].kind == "identifier" then
      return i + 1, new_node(ps, i, "identifier")
   end
   i = fail(ps, i, "syntax error, expected identifier")
   return i, new_node(ps, i, "error_node")
end

local function parse_local_function(ps: ParseState, i: integer): integer, Node
   i = verify_tk(ps, i, "local")
   i = verify_tk(ps, i, "function")
   local node = new_node(ps, i - 2, "local_function")
   i, node.name = parse_identifier(ps, i)
   return parse_function_args_rets_body(ps, i, node)
end

local enum FunctionKind
   "global"
   "record"
end

local function parse_function(ps: ParseState, i: integer, fk: FunctionKind): integer, Node
   local orig_i = i
   i = verify_tk(ps, i, "function")
   local fn = new_node(ps, i - 1, "global_function")
   local names: {Node} = {}
   i, names[1] = parse_identifier(ps, i)
   while ps.tokens[i].tk == "." do
      i = i + 1
      i, names[#names + 1] = parse_identifier(ps, i)
   end
   if ps.tokens[i].tk == ":" then
      i = i + 1
      i, names[#names + 1] = parse_identifier(ps, i)
      fn.is_method = true
   end

   if #names > 1 then
      fn.kind = "record_function"
      local owner = names[1]
      owner.kind = "type_identifier"
      for i2 = 2, #names - 1 do
         local dot = an_operator(names[i2], 2, ".")
         names[i2].kind = "identifier"
         owner = { f = ps.filename, y = names[i2].y, x = names[i2].x, kind = "op", op = dot, e1 = owner, e2 = names[i2] }
      end
      fn.fn_owner = owner
   end
   fn.name = names[#names]

   local selfx, selfy = ps.tokens[i].x, ps.tokens[i].y
   i = parse_function_args_rets_body(ps, i, fn)
   if fn.is_method and fn.args then
      table.insert(fn.args, 1, { f = ps.filename, x = selfx, y = selfy, tk = "self", kind = "identifier", is_self = true })
      fn.min_arity = fn.min_arity + 1
   end

   if not fn.name then
      return orig_i + 1
   end

   if fn.kind == "record_function" and fk == "global" then
      fail(ps, orig_i, "record functions cannot be annotated as 'global'")
   elseif fn.kind == "global_function" and fk == "record" then
      fn.implicit_global_function = true
   end

   return i, fn
end

local function parse_if_block(ps: ParseState, i: integer, n: integer, node: Node, is_else?: boolean): integer, Node
   local block = new_node(ps, i, "if_block")
   i = i + 1
   block.if_parent = node
   block.if_block_n = n
   if not is_else then
      i, block.exp = parse_expression_and_tk(ps, i, "then")
      if not block.exp then
         return i
      end
   end
   i, block.body = parse_statements(ps, i)
   if not block.body then
      return i
   end
   end_at(block.body, ps.tokens[i - 1])
   block.yend, block.xend = block.body.yend, block.body.xend
   table.insert(node.if_blocks, block)
   return i, node
end

local function parse_if(ps: ParseState, i: integer): integer, Node
   local istart = i
   local node = new_node(ps, i, "if")
   node.if_blocks = {}
   i, node = parse_if_block(ps, i, 1, node)
   if not node then
      return i
   end
   local n = 2
   while ps.tokens[i].tk == "elseif" do
      i, node = parse_if_block(ps, i, n, node)
      if not node then
         return i
      end
      n = n + 1
   end
   if ps.tokens[i].tk == "else" then
      i, node = parse_if_block(ps, i, n, node, true)
      if not node then
         return i
      end
   end
   i = verify_end(ps, i, istart, node)
   return i, node
end

local function parse_while(ps: ParseState, i: integer): integer, Node
   local istart = i
   local node = new_node(ps, i, "while")
   i = verify_tk(ps, i, "while")
   i, node.exp = parse_expression_and_tk(ps, i, "do")
   i, node.body = parse_statements(ps, i)
   i = verify_end(ps, i, istart, node)
   return i, node
end

local function parse_fornum(ps: ParseState, i: integer): integer, Node
   local istart = i
   local node = new_node(ps, i, "fornum")
   i = i + 1
   i, node.var = parse_identifier(ps, i)
   i = verify_tk(ps, i, "=")
   i, node.from = parse_expression_and_tk(ps, i, ",")
   i, node.to = parse_expression(ps, i)
   if ps.tokens[i].tk == "," then
      i = i + 1
      i, node.step = parse_expression_and_tk(ps, i, "do")
   else
      i = verify_tk(ps, i, "do")
   end
   i, node.body = parse_statements(ps, i)
   i = verify_end(ps, i, istart, node)
   return i, node
end

local function parse_forin(ps: ParseState, i: integer): integer, Node
   local istart = i
   local node = new_node(ps, i, "forin")
   i = i + 1
   node.vars = new_node(ps, i, "variable_list")
   i, node.vars = parse_list(ps, i, node.vars, { ["in"] = true }, "sep", parse_identifier)
   i = verify_tk(ps, i, "in")
   node.exps = new_node(ps, i, "expression_list")
   i = parse_list(ps, i, node.exps, { ["do"] = true }, "sep", parse_expression)
   if #node.exps < 1 then
      return fail(ps, i, "missing iterator expression in generic for")
   elseif #node.exps > 3 then
      return fail(ps, i, "too many expressions in generic for")
   end
   i = verify_tk(ps, i, "do")
   i, node.body = parse_statements(ps, i)
   i = verify_end(ps, i, istart, node)
   return i, node
end

local function parse_for(ps: ParseState, i: integer): integer, Node
   if ps.tokens[i+1].kind == "identifier" and ps.tokens[i+2].tk == "=" then
      return parse_fornum(ps, i)
   else
      return parse_forin(ps, i)
   end
end

local function parse_repeat(ps: ParseState, i: integer): integer, Node
   local node = new_node(ps, i, "repeat")
   i = verify_tk(ps, i, "repeat")
   i, node.body = parse_statements(ps, i)
   node.body.is_repeat = true
   i = verify_tk(ps, i, "until")
   i, node.exp = parse_expression(ps, i)
   end_at(node, ps.tokens[i - 1])
   return i, node
end

local function parse_do(ps: ParseState, i: integer): integer, Node
   local istart = i
   local node = new_node(ps, i, "do")
   i = verify_tk(ps, i, "do")
   i, node.body = parse_statements(ps, i)
   i = verify_end(ps, i, istart, node)
   return i, node
end

local function parse_break(ps: ParseState, i: integer): integer, Node
   local node = new_node(ps, i, "break")
   i = verify_tk(ps, i, "break")
   return i, node
end

local function parse_goto(ps: ParseState, i: integer): integer, Node
   local node = new_node(ps, i, "goto")
   i = verify_tk(ps, i, "goto")
   node.label = ps.tokens[i].tk
   i = verify_kind(ps, i, "identifier")
   return i, node
end

local function parse_label(ps: ParseState, i: integer): integer, Node
   local node = new_node(ps, i, "label")
   i = verify_tk(ps, i, "::")
   node.label = ps.tokens[i].tk
   i = verify_kind(ps, i, "identifier")
   i = verify_tk(ps, i, "::")
   return i, node
end

local stop_statement_list: {string:boolean} = {
   ["end"] = true,
   ["else"] = true,
   ["elseif"] = true,
   ["until"] = true,
}

local stop_return_list: {string:boolean} = {
   [";"] = true,
   ["$EOF$"] = true,
}

for k, v in pairs(stop_statement_list) do
   stop_return_list[k] = v
end

local function parse_return(ps: ParseState, i: integer): integer, Node
   local node = new_node(ps, i, "return")
   i = verify_tk(ps, i, "return")
   node.exps = new_node(ps, i, "expression_list")
   i = parse_list(ps, i, node.exps, stop_return_list, "sep", parse_expression)
   if ps.tokens[i].kind == ";" then
      i = i + 1
   end
   return i, node
end

local function store_field_in_record(ps: ParseState, i: integer, field_name: string, t: Type, fields: {string: Type}, field_order: {string}): boolean
   if not fields[field_name] then
      fields[field_name] = t
      table.insert(field_order, field_name)
   else
      local prev_t = fields[field_name]
      if t is FunctionType and prev_t is FunctionType then
         local p = new_type(ps, i, "poly") as PolyType
         p.types = { prev_t, t }
         fields[field_name] = p
      elseif t is FunctionType and prev_t is PolyType then
         table.insert(prev_t.types, t)
      else
         fail(ps, i, "attempt to redeclare field '" .. field_name .. "' (only functions can be overloaded)")
         return false
      end
   end
   return true
end

local function parse_nested_type(ps: ParseState, i: integer, def: RecordLikeType, typename: TypeName, parse_body: ParseBody): integer, boolean
   i = i + 1 -- skip 'record' or 'enum'
   local iv = i

   local v: Node
   i, v = verify_kind(ps, i, "identifier", "type_identifier")
   if not v then
      return fail(ps, i, "expected a variable name")
   end

   local nt: Node = new_node(ps, i - 2, "newtype")
   local ndef = new_type(ps, i, typename)
   local itype = i
   local iok = parse_body(ps, i, ndef, nt)
   if iok then
      i = iok
      nt.newtype = new_typedecl(ps, itype, ndef)
   end

   store_field_in_record(ps, iv, v.tk, nt.newtype, def.fields, def.field_order)
   return i
end

parse_enum_body = function(ps: ParseState, i: integer, def: EnumType, node: Node): integer, Node
   local istart = i - 1
   def.enumset = {}
   while ps.tokens[i].tk ~= "$EOF$" and ps.tokens[i].tk ~= "end" do
      local item: Node
      i, item = verify_kind(ps, i, "string", "enum_item")
      if item then
         table.insert(node, item)
         def.enumset[unquote(item.tk)] = true
      end
   end
   i = verify_end(ps, i, istart, node)
   return i, node
end

local metamethod_names: {string:boolean} = {
   ["__add"] = true,
   ["__sub"] = true,
   ["__mul"] = true,
   ["__div"] = true,
   ["__mod"] = true,
   ["__pow"] = true,
   ["__unm"] = true,
   ["__idiv"] = true,
   ["__band"] = true,
   ["__bor"] = true,
   ["__bxor"] = true,
   ["__bnot"] = true,
   ["__shl"] = true,
   ["__shr"] = true,
   ["__concat"] = true,
   ["__len"] = true,
   ["__eq"] = true,
   ["__lt"] = true,
   ["__le"] = true,
   ["__index"] = true,
   ["__newindex"] = true,
   ["__call"] = true,
   ["__tostring"] = true,
   ["__pairs"] = true,
   ["__gc"] = true,
   ["__close"] = true,
   ["__is"] = true,
}

local function parse_macroexp(ps: ParseState, istart: integer, iargs: integer): integer, Node
   local node = new_node(ps, istart, "macroexp")

   local i: integer
   if ps.tokens[istart + 1].tk == "<" then
      i, node.typeargs = parse_anglebracket_list(ps, istart + 1, parse_typearg)
   else
      i = iargs
   end

   i, node.args, node.min_arity = parse_argument_list(ps, i)
   i, node.rets = parse_return_types(ps, i)
   i = verify_tk(ps, i, "return")
   i, node.exp = parse_expression(ps, i)
   end_at(node, ps.tokens[i])
   i = verify_end(ps, i, istart, node)
   return i, node
end

local function parse_where_clause(ps: ParseState, i: integer, typeargs: {TypeArgType}): integer, Node
   local node = new_node(ps, i, "macroexp")

   local selftype = new_nominal(ps, i, "@self")
   if typeargs then
      selftype.typevals = {}
      for a, t in ipairs(typeargs) do
         selftype.typevals[a] = a_nominal(node, { t.typearg })
      end
   end

   node.is_method = true
   node.args = new_node(ps, i, "argument_list")
   node.args[1] = new_node(ps, i, "argument")
   node.args[1].tk = "self"
   node.args[1].argtype = selftype
   node.min_arity = 1
   node.rets = new_tuple(ps, i)
   node.rets.tuple[1] = new_type(ps, i, "boolean")
   i, node.exp = parse_expression(ps, i)
   end_at(node, ps.tokens[i - 1])
   return i, node
end

parse_interface_name = function(ps: ParseState, i: integer): integer, Type, integer
   local istart = i
   local typ: Type
   i, typ = parse_simple_type_or_nominal(ps, i)
   if not typ is NominalType then
      return fail(ps, istart, "expected an interface")
   end
   return i, typ
end

local function parse_array_interface_type(ps: ParseState, i: integer, def: RecordLikeType): integer, Type
   if def.interface_list then
      local first = def.interface_list[1]
      if first is ArrayType then
         return failskip(ps, i, "duplicated declaration of array element type", parse_type as SkipFunction)
      end
   end
   local t: Type
   i, t = parse_base_type(ps, i)
   if not t then
      return i
   end
   if not t is ArrayType then
      fail(ps, i, "expected an array declaration")
      return i
   end
   def.elements = t.elements
   return i, t
end

local function clone_typeargs(ps: ParseState, i: integer, typeargs: {TypeArgType}): {TypeArgType}
   local copy = {}
   for a, ta in ipairs(typeargs) do
      local cta = new_type(ps, i, "typearg") as TypeArgType
      cta.typearg = ta.typearg
      copy[a] = cta
   end
   return copy
end


parse_record_body = function(ps: ParseState, i: integer, def: RecordLikeType, node: Node): integer, Node
   local istart = i - 1
   def.fields = {}
   def.field_order = {}

   if ps.tokens[i].tk == "<" then
      i, def.typeargs = parse_anglebracket_list(ps, i, parse_typearg)
   end

   if ps.tokens[i].tk == "{" then
      local atype: Type
      i, atype = parse_array_interface_type(ps, i, def)
      if atype then
         def.interface_list = { atype }
      end
   end

   if ps.tokens[i].tk == "is" then
      i = i + 1

      if ps.tokens[i].tk == "{" then
         local atype: Type
         i, atype = parse_array_interface_type(ps, i, def)
         if ps.tokens[i].tk == "," then
            i = i + 1
            i, def.interface_list = parse_trying_list(ps, i, {}, parse_interface_name)
         else
            def.interface_list = {}
         end
         if atype then
            table.insert(def.interface_list, 1, atype)
         end
      else
         i, def.interface_list = parse_trying_list(ps, i, {}, parse_interface_name)
      end
   end

   if ps.tokens[i].tk == "where" then
      local wstart = i
      i = i + 1
      local where_macroexp: Node
      i, where_macroexp = parse_where_clause(ps, i, def.typeargs)

      local typ = new_type(ps, wstart, "function") as FunctionType
      if def.typeargs then
         typ.typeargs = clone_typeargs(ps, i, def.typeargs)
      end
      typ.is_method = true
      typ.min_arity = 1
      typ.args = new_tuple(ps, wstart, {
         a_nominal(where_macroexp, { "@self" })
      })
      typ.rets = new_tuple(ps, wstart, { new_type(ps, wstart, "boolean") })
      typ.macroexp = where_macroexp

      def.meta_fields = {}
      def.meta_field_order = {}
      store_field_in_record(ps, i, "__is", typ, def.meta_fields, def.meta_field_order)
   end

   while not (ps.tokens[i].kind == "$EOF$" or ps.tokens[i].tk == "end") do
      local tn = ps.tokens[i].tk as TypeName
      if ps.tokens[i].tk == "userdata" and ps.tokens[i+1].tk ~= ":" then
         if def.is_userdata then
            fail(ps, i, "duplicated 'userdata' declaration")
         else
            def.is_userdata = true
         end
         i = i + 1
      elseif ps.tokens[i].tk == "{" then
         return fail(ps, i, "syntax error: this syntax is no longer valid; declare array interface at the top with 'is {...}'")
      elseif ps.tokens[i].tk == "type" and ps.tokens[i + 1].tk ~= ":" then
         i = i + 1
         local iv = i

         local lt: Node
         i, lt = parse_type_declaration(ps, i, "local_type") -- local_type Node will be discarded
         if not lt then
            return fail(ps, i, "expected a type definition")
         end

         local v = lt.var
         if not v then
            return fail(ps, i, "expected a variable name")
         end

         local nt = lt.value
         if not nt or not nt.newtype then
            return fail(ps, i, "expected a type definition")
         end

         local ntt = nt.newtype
         if ntt is TypeAliasType then
            ntt.is_nested_alias = true
         end

         store_field_in_record(ps, iv, v.tk, nt.newtype, def.fields, def.field_order)
      elseif parse_type_body_fns[tn] and ps.tokens[i+1].tk ~= ":" then
         i = parse_nested_type(ps, i, def, tn, parse_type_body_fns[tn])
      else
         local is_metamethod = false
         if ps.tokens[i].tk == "metamethod" and ps.tokens[i+1].tk ~= ":" then
            is_metamethod = true
            i = i + 1
         end

         local v: Node
         if ps.tokens[i].tk == "[" then
            i, v = parse_literal(ps, i+1)
            if v and not v.conststr then
               return fail(ps, i, "expected a string literal")
            end
            i = verify_tk(ps, i, "]")
         else
            i, v = verify_kind(ps, i, "identifier", "variable")
         end
         local iv = i
         if not v then
            return fail(ps, i, "expected a variable name")
         end

         if ps.tokens[i].tk == ":" then
            i = i + 1
            local t: Type
            i, t = parse_type(ps, i)
            if not t then
               return fail(ps, i, "expected a type")
            end

            local field_name = v.conststr or v.tk
            local fields = def.fields
            local field_order = def.field_order
            if is_metamethod then
               if not def.meta_fields then
                  def.meta_fields = {}
                  def.meta_field_order = {}
               end
               fields = def.meta_fields
               field_order = def.meta_field_order
               if not metamethod_names[field_name] then
                  fail(ps, i - 1, "not a valid metamethod: " .. field_name)
               end
            end

            if ps.tokens[i].tk == "=" and ps.tokens[i + 1].tk == "macroexp" then
               if not t is FunctionType then
                  fail(ps, i + 1, "macroexp must have a function type")
               else
                  i, t.macroexp = parse_macroexp(ps, i + 1, i + 2)
               end
            end

            store_field_in_record(ps, iv, field_name, t, fields, field_order)
         elseif ps.tokens[i].tk == "=" then
            local next_word = ps.tokens[i + 1].tk
            if next_word == "record" or next_word == "enum" then
               return fail(ps, i, "syntax error: this syntax is no longer valid; use '" .. next_word .. " " .. v.tk .. "'")
            elseif next_word == "functiontype" then
               return fail(ps, i, "syntax error: this syntax is no longer valid; use 'type " .. v.tk .. " = function('...")
            else
               return fail(ps, i, "syntax error: this syntax is no longer valid; use 'type " .. v.tk .. " = '...")
            end
         else
            fail(ps, i, "syntax error: expected ':' for an attribute or '=' for a nested type")
         end
      end
   end
   i = verify_end(ps, i, istart, node)
   return i, node
end

parse_type_body_fns = {
   ["interface"] = parse_record_body,
   ["record"] = parse_record_body,
   ["enum"] = parse_enum_body,
}

parse_newtype = function(ps: ParseState, i: integer): integer, Node
   local node: Node = new_node(ps, i, "newtype")
   local def: Type
   local tn = ps.tokens[i].tk as TypeName
   local itype = i
   if parse_type_body_fns[tn] then
      def = new_type(ps, i, tn)
      i = i + 1
      i = parse_type_body_fns[tn](ps, i, def, node)
      if not def then
         return fail(ps, i, "expected a type")
      end

      node.newtype = new_typedecl(ps, itype, def)
      return i, node
   else
      i, def = parse_type(ps, i)
      if not def then
         return fail(ps, i, "expected a type")
      end

      if def is NominalType then
         node.newtype = new_typealias(ps, itype, def)
      else
         node.newtype = new_typedecl(ps, itype, def)
      end

      return i, node
   end
end

local function parse_assignment_expression_list(ps: ParseState, i: integer, asgn: Node): integer, Node
   asgn.exps = new_node(ps, i, "expression_list")
   repeat
      i = i + 1
      local val: Node
      i, val = parse_expression(ps, i)
      if not val then
         if #asgn.exps == 0 then
            asgn.exps = nil
         end
         return i
      end
      table.insert(asgn.exps, val)
   until ps.tokens[i].tk ~= ","
   return i, asgn
end

local parse_call_or_assignment: function(ps: ParseState, i: integer): integer, Node
do
   local function is_lvalue(node: Node): boolean
      node.is_lvalue = node.kind == "variable"
                       or (node.kind == "op"
                           and (node.op.op == "@index" or node.op.op == "."))
      return node.is_lvalue
   end

   local function parse_variable(ps: ParseState, i: integer): integer, Node, integer
      local node: Node
      i, node = parse_expression(ps, i)
      if not (node and is_lvalue(node)) then
         return fail(ps, i, "expected a variable")
      end
      return i, node
   end

   parse_call_or_assignment = function(ps: ParseState, i: integer): integer, Node
      local exp: Node
      local istart = i
      i, exp = parse_expression(ps, i)
      if not exp then
         return i
      end

      if (exp.op and exp.op.op == "@funcall") or exp.failstore then
         return i, exp
      end

      if not is_lvalue(exp) then
         return fail(ps, i, "syntax error")
      end

      local asgn: Node = new_node(ps, istart, "assignment")
      asgn.vars = new_node(ps, istart, "variable_list")
      asgn.vars[1] = exp
      if ps.tokens[i].tk == "," then
         i = i + 1
         i = parse_trying_list(ps, i, asgn.vars, parse_variable)
         if #asgn.vars < 2 then
            return fail(ps, i, "syntax error")
         end
      end

      if ps.tokens[i].tk ~= "=" then
         verify_tk(ps, i, "=")
         return i
      end

      i, asgn = parse_assignment_expression_list(ps, i, asgn)
      return i, asgn
   end
end

local function parse_variable_declarations(ps: ParseState, i: integer, node_name: NodeKind): integer, Node
   local asgn: Node = new_node(ps, i, node_name)

   asgn.vars = new_node(ps, i, "variable_list")
   i = parse_trying_list(ps, i, asgn.vars, parse_variable_name)
   if #asgn.vars == 0 then
      return fail(ps, i, "expected a local variable definition")
   end

   i, asgn.decltuple = parse_type_list(ps, i, "decltuple")

   if ps.tokens[i].tk == "=" then
      -- produce nice error message when using <= 0.7.1 syntax
      local next_word = ps.tokens[i + 1].tk
      local tn = next_word as TypeName
      if parse_type_body_fns[tn] then
         local scope = node_name == "local_declaration" and "local" or "global"
         return failskip(ps, i + 1, "syntax error: this syntax is no longer valid; use '" .. scope .. " " .. next_word .. " " .. asgn.vars[1].tk .. "'", skip_type_body)
      elseif next_word == "functiontype" then
         local scope = node_name == "local_declaration" and "local" or "global"
         return failskip(ps, i + 1, "syntax error: this syntax is no longer valid; use '" .. scope .. " type " .. asgn.vars[1].tk .. " = function('...", parse_function_type as SkipFunction)
      end

      i, asgn = parse_assignment_expression_list(ps, i, asgn)
   end
   return i, asgn
end

parse_type_declaration = function(ps: ParseState, i: integer, node_name: NodeKind): integer, Node
   local asgn: Node = new_node(ps, i, node_name)
   local var: Node

   i, var = verify_kind(ps, i, "identifier")
   if not var then
      return fail(ps, i, "expected a type name")
   end
   local typeargs: {TypeArgType}
   if ps.tokens[i].tk == "<" then
      i, typeargs = parse_anglebracket_list(ps, i, parse_typearg)
   end
   asgn.var = var

   if node_name == "global_type" and ps.tokens[i].tk ~= "=" then
      return i, asgn
   end

   i = verify_tk(ps, i, "=")

   if ps.tokens[i].kind == "identifier" and ps.tokens[i].tk == "require" then
      local istart = i
      i, asgn.value = parse_call_or_assignment(ps, i)
      if asgn.value and not node_is_require_call(asgn.value) then
         fail(ps, istart, "require() for type declarations must have a literal argument")
      end
      return i, asgn
   end

   i, asgn.value = parse_newtype(ps, i)
   if not asgn.value then
      return i
   end

   local nt = asgn.value.newtype
   if nt is TypeDeclType then
      if typeargs then
         nt.typeargs = typeargs
      end

      local def = nt.def
      if def is RecordLikeType or def is EnumType then
         if not def.declname then
            def.declname = asgn.var.tk
         end
      end
   elseif nt is TypeAliasType then
      if typeargs then
         nt.typeargs = typeargs
      end
   end

   return i, asgn
end

local function parse_type_constructor(ps: ParseState, i: integer, node_name: NodeKind, type_name: TypeName, parse_body: ParseBody): integer, Node
   local asgn: Node = new_node(ps, i, node_name)
   local nt: Node = new_node(ps, i, "newtype")
   asgn.value = nt
   local itype = i
   local def = new_type(ps, i, type_name)

   i = i + 2 -- skip `local` or `global`, and the constructor name

   i, asgn.var = verify_kind(ps, i, "identifier")
   if not asgn.var then
      return fail(ps, i, "expected a type name")
   end

   assert(def is RecordType or def is InterfaceType or def is EnumType)
   def.declname = asgn.var.tk

   i = parse_body(ps, i, def, nt)

   nt.newtype = new_typedecl(ps, itype, def)

   return i, asgn
end

local function skip_type_declaration(ps: ParseState, i: integer): integer, Node
   return parse_type_declaration(ps, i + 1, "local_type")
end

local function parse_local_macroexp(ps: ParseState, i: integer): integer, Node
   local istart = i
   i = i + 2 -- skip `local`
   local node = new_node(ps, i, "local_macroexp")
   i, node.name = parse_identifier(ps, i)
   i, node.macrodef = parse_macroexp(ps, istart, i)
   end_at(node, ps.tokens[i - 1])
   return i, node
end

local function parse_local(ps: ParseState, i: integer): integer, Node
   local ntk = ps.tokens[i + 1].tk
   local tn = ntk as TypeName
   if ntk == "function" then
      return parse_local_function(ps, i)
   elseif ntk == "type" and ps.tokens[i + 2].kind == "identifier" then
      return parse_type_declaration(ps, i + 2, "local_type")
   elseif ntk == "macroexp" and ps.tokens[i+2].kind == "identifier" then
      return parse_local_macroexp(ps, i)
   elseif parse_type_body_fns[tn] and ps.tokens[i+2].kind == "identifier" then
      return parse_type_constructor(ps, i, "local_type", tn, parse_type_body_fns[tn])
   end
   return parse_variable_declarations(ps, i + 1, "local_declaration")
end

local function parse_global(ps: ParseState, i: integer): integer, Node
   local ntk = ps.tokens[i + 1].tk
   local tn = ntk as TypeName
   if ntk == "function" then
      return parse_function(ps, i + 1, "global")
   elseif ntk == "type" and ps.tokens[i + 2].kind == "identifier" then
      return parse_type_declaration(ps, i + 2, "global_type")
   elseif parse_type_body_fns[tn] and ps.tokens[i+2].kind == "identifier" then
      return parse_type_constructor(ps, i, "global_type", tn, parse_type_body_fns[tn])
   elseif ps.tokens[i+1].kind == "identifier" then
      return parse_variable_declarations(ps, i + 1, "global_declaration")
   end
   return parse_call_or_assignment(ps, i) -- global is a soft keyword
end

local function parse_record_function(ps: ParseState, i: integer): integer, Node
   return parse_function(ps, i, "record")
end

local parse_statement_fns: {string : function(ParseState, integer):(integer, Node)} = {
   ["::"] = parse_label,
   ["do"] = parse_do,
   ["if"] = parse_if,
   ["for"] = parse_for,
   ["goto"] = parse_goto,
   ["local"] = parse_local,
   ["while"] = parse_while,
   ["break"] = parse_break,
   ["global"] = parse_global,
   ["repeat"] = parse_repeat,
   ["return"] = parse_return,
   ["function"] = parse_record_function,
}

local function type_needs_local_or_global(ps: ParseState, i: integer): integer, Node
   local tk = ps.tokens[i].tk
   return failskip(ps, i, ("%s needs to be declared with 'local %s' or 'global %s'"):format(tk, tk, tk), skip_type_body)
end

local needs_local_or_global: {string : function(ParseState, integer):(integer, Node)} = {
   ["type"] = function(ps: ParseState, i: integer): integer, Node
      return failskip(ps, i, "types need to be declared with 'local type' or 'global type'", skip_type_declaration)
   end,
   ["record"] = type_needs_local_or_global,
   ["enum"] = type_needs_local_or_global,
}

parse_statements = function(ps: ParseState, i: integer, toplevel?: boolean): integer, Node
   local node = new_node(ps, i, "statements")
   local item: Node
   while true do
      while ps.tokens[i].kind == ";" do
         i = i + 1
         if item then
            item.semicolon = true
         end
      end

      if ps.tokens[i].kind == "$EOF$" then
         break
      end
      local tk = ps.tokens[i].tk
      if (not toplevel) and stop_statement_list[tk] then
         break
      end

      local fn = parse_statement_fns[tk]
      if not fn then
         local skip_fn = needs_local_or_global[tk]
         if skip_fn and ps.tokens[i + 1].kind == "identifier" then
            fn = skip_fn
         else
            fn = parse_call_or_assignment
         end
      end

      i, item = fn(ps, i)

      if item then
         table.insert(node, item)
      elseif i > 1 then
         -- heuristic to resync at the next line after an invalid statement
         local lasty = ps.tokens[i - 1].y
         while ps.tokens[i].kind ~= "$EOF$" and ps.tokens[i].y == lasty do
            i = i + 1
         end
      end
   end

   end_at(node, ps.tokens[i])
   return i, node
end

function tl.parse_program(tokens: {Token}, errs: {Error}, filename: string): Node, {string}
   errs = errs or {}
   local ps: ParseState = {
      tokens = tokens,
      errs = errs,
      filename = filename or "",
      required_modules = {},
   }
   local i = 1
   local hashbang: string
   if ps.tokens[i].kind == "hashbang" then
      hashbang = ps.tokens[i].tk
      i = i + 1
   end
   local _, node = parse_statements(ps, i, true)
   if hashbang then
      node.hashbang = hashbang
   end

   clear_redundant_errors(errs)
   return node, ps.required_modules
end

function tl.parse(input: string, filename: string): Node, {Error}, {string}
   local tokens, errs = tl.lex(input, filename)
   local node, required_modules = tl.parse_program(tokens, errs, filename)
   return node, errs, required_modules
end

end ----------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- AST traversal
--------------------------------------------------------------------------------

local record VisitorCallbacks<S, N, T>
   before: function(S, N)
   before_exp: function(S, {N}, {T})
   before_arguments: function(S, {N}, {T})
   before_statements: function(S, {N}, {T})
   before_e2: function(S, {N}, {T})
   after: function(S, N, {T}): T
end

local enum VisitorExtraCallback
   "before_arguments"
   "before_statements"
   "before_exp"
   "before_e2"
end

local type VisitorAfter = function<S, N, T>(S, N, {T}, T): T

local record Visitor<S, K, N, T>
   cbs: {K:VisitorCallbacks<S, N, T>}
   after: VisitorAfter<S, N, T>
   allow_missing_cbs: boolean
end

local enum MetaMode
   "meta"
end

local function fields_of(t: RecordLikeType, meta?: MetaMode): (function(): string, Type)
   local i = 1
   local field_order, fields: {string}, {string:Type}
   if meta then
      field_order, fields = t.meta_field_order, t.meta_fields
   else
      field_order, fields = t.field_order, t.fields
   end
   if not fields then
      return function(): string, Type
      end
   end
   return function(): string, Type
      local name = field_order[i]
      if not name then
         return nil
      end
      i = i + 1
      return name, fields[name]
   end
end

local show_type: function(Type, ? boolean, ? {Type:string}): string

local tl_debug_indent = 0
local record DebugEntry
   mark: string
   y: integer
   x: integer
   msg: string
end
local tl_debug_entry: DebugEntry = nil
local tl_debug_y = 1

local function tl_debug_loc(y: integer, x: integer): string
   return (tostring(y) or "?") .. ":" .. (tostring(x) or "?")
end

local function tl_debug_indent_push(mark: string, y: integer, x: integer, fmt: string, ...: any)
   if tl_debug_entry then
      if tl_debug_entry.y and (tl_debug_entry.y > tl_debug_y) then
         io.stderr:write("\n")
         tl_debug_y = tl_debug_entry.y
      end
      io.stderr:write(("   "):rep(tl_debug_indent) .. tl_debug_entry.mark .. " " ..
                      tl_debug_loc(tl_debug_entry.y, tl_debug_entry.x) .. " " ..
                      tl_debug_entry.msg .. "\n")
      io.stderr:flush()
      tl_debug_entry = nil
      tl_debug_indent = tl_debug_indent + 1
   end
   tl_debug_entry = {
      mark = mark,
      y = y,
      x = x,
      msg = fmt:format(...)
   }
end

local function tl_debug_indent_pop(mark: string, single: string, y: integer, x: integer, fmt?: string, ...: any)
   if tl_debug_entry then
      local msg = tl_debug_entry.msg
      if fmt then
         msg = fmt:format(...)
      end
      if y and (y > tl_debug_y) then
         io.stderr:write("\n")
         tl_debug_y = y
      end
      io.stderr:write(("   "):rep(tl_debug_indent) .. single .. " " .. tl_debug_loc(y, x) .. " " .. msg .. "\n")
      io.stderr:flush()
      tl_debug_entry = nil
   else
      tl_debug_indent = tl_debug_indent - 1
      if fmt then
         io.stderr:write(("   "):rep(tl_debug_indent) .. mark .. " " .. fmt:format(...) .. "\n")
         io.stderr:flush()
      end
   end
end

local function recurse_type<S, T>(s: S, ast: Type, visit: Visitor<S, TypeName, Type, T>): T
   local kind = ast.typename

   if TL_DEBUG then
      tl_debug_indent_push("---", ast.y, ast.x, "[%s] = %s", kind, show_type(ast))
   end

   local cbs = visit.cbs
   local cbkind = cbs and cbs[kind]
   if cbkind then
      local cbkind_before = cbkind.before
      if cbkind_before then
         cbkind_before(s, ast)
      end
   end

   local xs: {T} = {}

   if ast is TupleType then
      for i, child in ipairs(ast.tuple) do
         xs[i] = recurse_type(s, child, visit)
      end
   elseif ast is AggregateType then
      for _, child in ipairs(ast.types) do
         table.insert(xs, recurse_type(s, child, visit))
      end
   elseif ast is MapType then
      table.insert(xs, recurse_type(s, ast.keys, visit))
      table.insert(xs, recurse_type(s, ast.values, visit))
   elseif ast is RecordLikeType then
      if ast.typeargs then
         for _, child in ipairs(ast.typeargs) do
            table.insert(xs, recurse_type(s, child, visit))
         end
      end
      if ast.interface_list then
         for _, child in ipairs(ast.interface_list) do
            table.insert(xs, recurse_type(s, child, visit))
         end
      end
      if ast.elements then
         table.insert(xs, recurse_type(s, ast.elements, visit))
      end
      if ast.fields then
         for _, child in fields_of(ast) do
            table.insert(xs, recurse_type(s, child, visit))
         end
      end
      if ast.meta_fields then
         for _, child in fields_of(ast, "meta") do
            table.insert(xs, recurse_type(s, child, visit))
         end
      end
   elseif ast is FunctionType then
      if ast.typeargs then
         for _, child in ipairs(ast.typeargs) do
            table.insert(xs, recurse_type(s, child, visit))
         end
      end
      if ast.args then
         for _, child in ipairs(ast.args.tuple) do
            table.insert(xs, recurse_type(s, child, visit))
         end
      end
      if ast.rets then
         for _, child in ipairs(ast.rets.tuple) do
            table.insert(xs, recurse_type(s, child, visit))
         end
      end
   elseif ast is NominalType then
      if ast.typevals then
         for _, child in ipairs(ast.typevals) do
            table.insert(xs, recurse_type(s, child, visit))
         end
      end
   elseif ast is TypeArgType then
      if ast.constraint then
         table.insert(xs, recurse_type(s, ast.constraint, visit))
      end
   elseif ast is ArrayType then
      if ast.elements then
         table.insert(xs, recurse_type(s, ast.elements, visit))
      end
   elseif ast is LiteralTableItemType then
      if ast.ktype then
         table.insert(xs, recurse_type(s, ast.ktype, visit))
      end
      if ast.vtype then
         table.insert(xs, recurse_type(s, ast.vtype, visit))
      end
   elseif ast is TypeAliasType then
      if ast.typeargs then
         for _, child in ipairs(ast.typeargs) do
            table.insert(xs, recurse_type(s, child, visit))
         end
      end
      table.insert(xs, recurse_type(s, ast.alias_to, visit))
   elseif ast is TypeDeclType then
      if ast.typeargs then
         for _, child in ipairs(ast.typeargs) do
            table.insert(xs, recurse_type(s, child, visit))
         end
      end
      table.insert(xs, recurse_type(s, ast.def, visit))
   end

   local ret: T
   local cbkind_after = cbkind and cbkind.after
   if cbkind_after then
      ret = cbkind_after(s, ast, xs)
   end
   local visit_after = visit.after
   if visit_after then
      ret = visit_after(s, ast, xs, ret)
   end

   if TL_DEBUG then
      tl_debug_indent_pop("---", "---", ast.y, ast.x)
   end

   return ret
end

local function recurse_typeargs<S, T>(s: S, ast: Node, visit_type: Visitor<S, TypeName, Type, T>)
   if ast.typeargs then
      for _, typearg in ipairs(ast.typeargs) do
         recurse_type(s, typearg, visit_type)
      end
   end
end

local function extra_callback<S, T>(name: VisitorExtraCallback,
                                    s: S,
                                    ast: Node,
                                    xs: {T},
                                    visit_node: Visitor<S, NodeKind, Node, T>)
   local cbs = visit_node.cbs
   if not cbs then return end
   local nbs = cbs[ast.kind]
   if not nbs then return end
   local bs = nbs[name]
   if not bs then return end
   bs(s, ast, xs)
end

local no_recurse_node: {NodeKind : boolean} = {
   ["..."] = true,
   ["nil"] = true,
   ["cast"] = true,
   ["goto"] = true,
   ["break"] = true,
   ["label"] = true,
   ["number"] = true,
   ["string"] = true,
   ["boolean"] = true,
   ["integer"] = true,
   ["variable"] = true,
   ["error_node"] = true,
   ["identifier"] = true,
   ["type_identifier"] = true,
}

local function recurse_node<S, T>(s: S, root: Node,
                                  visit_node: Visitor<S, NodeKind, Node, T>,
                                  visit_type: Visitor<S, TypeName, Type, T>): T
   if not root then
      -- parse error
      return
   end

   local recurse: function(Node): T

   local function walk_children(ast: Node, xs: {T})
      for i, child in ipairs(ast) do
         xs[i] = recurse(child)
      end
   end

   local function walk_vars_exps(ast: Node, xs: {T})
      xs[1] = recurse(ast.vars)
      if ast.decltuple then
         xs[2] = recurse_type(s, ast.decltuple, visit_type)
      end
      extra_callback("before_exp", s, ast, xs, visit_node)
      if ast.exps then
         xs[3] = recurse(ast.exps)
      end
   end

   local function walk_var_value(ast: Node, xs: {T})
      xs[1] = recurse(ast.var)
      xs[2] = recurse(ast.value)
   end

   local function walk_named_function(ast: Node, xs: {T})
      recurse_typeargs(s, ast, visit_type)
      xs[1] = recurse(ast.name)
      xs[2] = recurse(ast.args)
      xs[3] = recurse_type(s, ast.rets, visit_type)
      extra_callback("before_statements", s, ast, xs, visit_node)
      xs[4] = recurse(ast.body)
   end

   local walkers: {NodeKind : function(Node, {T})} = {
      ["op"] = function(ast: Node, xs: {T})
         xs[1] = recurse(ast.e1)
         local p1 = ast.e1.op and ast.e1.op.prec or nil
         if ast.op.op == ":" and ast.e1.kind == "string" then
            p1 = -999
         end
         xs[2] = p1 as T
         if ast.op.arity == 2 then
            extra_callback("before_e2", s, ast, xs, visit_node)
            if ast.op.op == "is" or ast.op.op == "as" then
               xs[3] = recurse_type(s, ast.e2.casttype, visit_type)
            else
               xs[3] = recurse(ast.e2)
            end
            xs[4] = (ast.e2.op and ast.e2.op.prec) as T
         end
      end,

      ["statements"] = walk_children,
      ["argument_list"] = walk_children,
      ["literal_table"] = walk_children,
      ["variable_list"] = walk_children,
      ["expression_list"] = walk_children,

      ["literal_table_item"] = function(ast: Node, xs: {T})
         xs[1] = recurse(ast.key)
         xs[2] = recurse(ast.value)
         if ast.itemtype then
            xs[3] = recurse_type(s, ast.itemtype, visit_type)
         end
      end,

      ["assignment"] = walk_vars_exps,
      ["local_declaration"] = walk_vars_exps,
      ["global_declaration"] = walk_vars_exps,

      ["local_type"] = walk_var_value,
      ["global_type"] = function(ast: Node, xs: {T})
         xs[1] = recurse(ast.var)
         if ast.value then
            xs[2] = recurse(ast.value)
         end
      end,

      ["if"] = function(ast: Node, xs: {T})
         for _, e in ipairs(ast.if_blocks) do
            table.insert(xs, recurse(e))
         end
      end,

      ["if_block"] = function(ast: Node, xs: {T})
         if ast.exp then
            xs[1] = recurse(ast.exp)
         end
         extra_callback("before_statements", s, ast, xs, visit_node)
         xs[2] = recurse(ast.body)
      end,

      ["while"] = function(ast: Node, xs: {T})
         xs[1] = recurse(ast.exp)
         extra_callback("before_statements", s, ast, xs, visit_node)
         xs[2] = recurse(ast.body)
      end,

      ["repeat"] = function(ast: Node, xs: {T})
         xs[1] = recurse(ast.body)
         xs[2] = recurse(ast.exp)
      end,

      ["macroexp"] = function(ast: Node, xs: {T})
         recurse_typeargs(s, ast, visit_type)
         xs[1] = recurse(ast.args)
         xs[2] = recurse_type(s, ast.rets, visit_type)
         extra_callback("before_exp", s, ast, xs, visit_node)
         xs[3] = recurse(ast.exp)
      end,

      ["function"] = function(ast: Node, xs: {T})
         recurse_typeargs(s, ast, visit_type)
         xs[1] = recurse(ast.args)
         xs[2] = recurse_type(s, ast.rets, visit_type)
         extra_callback("before_statements", s, ast, xs, visit_node)
         xs[3] = recurse(ast.body)
      end,
      ["local_function"] = walk_named_function,
      ["global_function"] = walk_named_function,
      ["record_function"] = function(ast: Node, xs: {T})
         recurse_typeargs(s, ast, visit_type)
         xs[1] = recurse(ast.fn_owner)
         xs[2] = recurse(ast.name)
         extra_callback("before_arguments", s, ast, xs, visit_node)
         xs[3] = recurse(ast.args)
         xs[4] = recurse_type(s, ast.rets, visit_type)
         extra_callback("before_statements", s, ast, xs, visit_node)
         xs[5] = recurse(ast.body)
      end,
      ["local_macroexp"] = function(ast: Node, xs: {T})
         -- TODO: generic macroexp
         xs[1] = recurse(ast.name)
         xs[2] = recurse(ast.macrodef.args)
         xs[3] = recurse_type(s, ast.macrodef.rets, visit_type)
         extra_callback("before_exp", s, ast, xs, visit_node)
         xs[4] = recurse(ast.macrodef.exp)
      end,

      ["forin"] = function(ast: Node, xs: {T})
         xs[1] = recurse(ast.vars)
         xs[2] = recurse(ast.exps)
         extra_callback("before_statements", s, ast, xs, visit_node)
         xs[3] = recurse(ast.body)
      end,

      ["fornum"] = function(ast: Node, xs: {T})
         xs[1] = recurse(ast.var)
         xs[2] = recurse(ast.from)
         xs[3] = recurse(ast.to)
         xs[4] = ast.step and recurse(ast.step)
         extra_callback("before_statements", s, ast, xs, visit_node)
         xs[5] = recurse(ast.body)
      end,

      ["return"] = function(ast: Node, xs: {T})
         xs[1] = recurse(ast.exps)
      end,

      ["do"] = function(ast: Node, xs: {T})
         xs[1] = recurse(ast.body)
      end,

      ["paren"] = function(ast: Node, xs:{T})
         xs[1] = recurse(ast.e1)
      end,

      ["newtype"] = function(ast: Node, xs:{T})
         xs[1] = recurse_type(s, ast.newtype, visit_type)
      end,

      ["argument"] = function(ast: Node, xs:{T})
         if ast.argtype then
            xs[1] = recurse_type(s, ast.argtype, visit_type)
         end
      end,
   }

   if not visit_node.allow_missing_cbs and not visit_node.cbs then
      error("missing cbs in visit_node")
   end
   local visit_after = visit_node.after

   recurse = function(ast: Node): T
      local xs: {T} = {}
      local kind = assert(ast.kind)
      local kprint: string

      local cbs = visit_node.cbs
      local cbkind = cbs and cbs[kind]
      if cbkind then
         if cbkind.before then
            cbkind.before(s, ast)
         end
      end

      if TL_DEBUG then
         if ast.y > TL_DEBUG_MAXLINE then
            error("Halting execution at input line " .. ast.y)
         end
         kprint = kind == "op" and "op " .. ast.op.op
                  or kind == "identifier" and "identifier " .. ast.tk
                  or kind
         tl_debug_indent_push("{{{", ast.y, ast.x, "[%s]", kprint)
      end

      local fn = walkers[kind]
      if fn then
         fn(ast, xs)
      else
         assert(no_recurse_node[kind])
      end

      local ret: T
      local cbkind_after = cbkind and cbkind.after
      if cbkind_after then
         ret = cbkind_after(s, ast, xs)
      end
      if visit_after then
         ret = visit_after(s, ast, xs, ret)
      end

      if TL_DEBUG then
         local typ = ast.debug_type and " = " .. show_type(ast.debug_type) or ""
         tl_debug_indent_pop("}}}", "***", ast.y, ast.x, "[%s]%s", kprint, typ)
      end

      return ret
   end

   return recurse(root)
end

--------------------------------------------------------------------------------
-- Pretty-print AST
--------------------------------------------------------------------------------

local tight_op: {integer:{string:boolean}} = {
   [1] = {
      ["-"] = true,
      ["~"] = true,
      ["#"] = true,
   },
   [2] = {
      ["."] = true,
      [":"] = true,
   },
}

local spaced_op: {integer:{string:boolean}} = {
   [1] = {
      ["not"] = true,
   },
   [2] = {
      ["or"] = true,
      ["and"] = true,
      ["<"] = true,
      [">"] = true,
      ["<="] = true,
      [">="] = true,
      ["~="] = true,
      ["=="] = true,
      ["|"] = true,
      ["~"] = true,
      ["&"] = true,
      ["<<"] = true,
      [">>"] = true,
      [".."] = true,
      ["+"] = true,
      ["-"] = true,
      ["*"] = true,
      ["/"] = true,
      ["//"] = true,
      ["%"] = true,
      ["^"] = true,
   },
}


local default_pretty_print_ast_opts: PrettyPrintOptions = {
   preserve_indent = true,
   preserve_newlines = true,
   preserve_hashbang = false,
}

local fast_pretty_print_ast_opts: PrettyPrintOptions = {
   preserve_indent = false,
   preserve_newlines = true,
   preserve_hashbang = false,
}

local primitive: {TypeName:string} = {
   ["function"] = "function",
   ["enum"] = "string",
   ["boolean"] = "boolean",
   ["string"] = "string",
   ["nil"] = "nil",
   ["number"] = "number",
   ["integer"] = "number",
   ["thread"] = "thread",
}

function tl.pretty_print_ast(ast: Node, gen_target: GenTarget, mode: boolean | PrettyPrintOptions): string, string
   local err: string
   local indent = 0

   local opts: PrettyPrintOptions
   if mode is PrettyPrintOptions then
      opts = mode
   elseif mode == true then
      opts = fast_pretty_print_ast_opts
   else
      opts = default_pretty_print_ast_opts
   end

   local record Output
      {string}
      y: integer
      h: integer
   end

   local save_indent: {integer} = {}

   local function increment_indent(_: nil, node: Node)
      local child = node.body or node[1]
      if not child then
         return
      end
      if child.y ~= node.y then
         if indent == 0 and #save_indent > 0 then
            indent = save_indent[#save_indent] + 1
         else
            indent = indent + 1
         end
      else
         table.insert(save_indent, indent)
         indent = 0
      end
   end

   local function decrement_indent(node: Node, child: Node)
      if child.y ~= node.y then
         indent = indent - 1
      else
         indent = table.remove(save_indent)
      end
   end

   if not opts.preserve_indent then
      increment_indent = nil
      decrement_indent = function() end
   end

   local function add_string(out: Output, s: string)
      table.insert(out, s)
      if string.find(s, "\n", 1, true) then
         for _nl in s:gmatch("\n") do
            out.h = out.h + 1
         end
      end
   end

   local function add_child(out: Output, child: Output, space?: string, current_indent?: integer): integer
      if #child == 0 then
         return
      end

      if child.y ~= -1 and child.y < out.y then
         out.y = child.y
      end

      if child.y > out.y + out.h and opts.preserve_newlines then
         local delta = child.y - (out.y + out.h)
         out.h = out.h + delta
         table.insert(out, ("\n"):rep(delta))
      else
         if space then
            if space ~= "" then
               table.insert(out, space)
            end
            current_indent = nil
         end
      end
      if current_indent and opts.preserve_indent then
         table.insert(out, ("   "):rep(current_indent))
      end
      table.insert(out, child as string)
      out.h = out.h + child.h
   end

   local function concat_output(out: Output): string
      for i, s in ipairs(out) do
         if type(s) == "table" then
            out[i] = concat_output(s as Output)
         end
      end
      return table.concat(out)
   end

   local function print_record_def(typ: RecordLikeType): string
      local out: {string} = { "{" }
      for fname, ftype in fields_of(typ) do
         if ftype is TypeDeclType then
            local def = ftype.def
            if def is RecordLikeType then
               table.insert(out, fname)
               table.insert(out, " = ")
               table.insert(out, print_record_def(def))
               table.insert(out, ", ")
            end
         end
      end
      table.insert(out, "}")
      return table.concat(out)
   end

   local visit_node: Visitor<nil, NodeKind, Node, Output> = {}

   local lua_54_attribute <total>: {Attribute:string} = {
      ["const"] = " <const>",
      ["close"] = " <close>",
      ["total"] = " <const>",
   }

   local function emit_exactly(_: nil, node: Node, _children: {Output}): Output
      local out: Output = { y = node.y, h = 0 }
      add_string(out, node.tk)
      return out
   end

   local emit_exactly_visitor_cbs <const>: VisitorCallbacks<nil, Node, Output> = { after = emit_exactly }

   visit_node.cbs = {
      ["statements"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output
            if opts.preserve_hashbang and node.hashbang then
               out = { y = 1, h = 0 }
               table.insert(out, node.hashbang)
            else
               out = { y = node.y, h = 0 }
            end
            local space: string
            for i, child in ipairs(children) do
               add_child(out, child, space, indent)
               if node[i].semicolon then
                  table.insert(out, ";")
                  space = " "
               else
                  space = "; "
               end
            end
            return out
         end
      },
      ["local_declaration"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "local ")
            for i, var in ipairs(node.vars) do
               if i > 1 then
                  add_string(out, ", ")
               end
               add_string(out, var.tk)
               if var.attribute then
                  if gen_target ~= "5.4" and var.attribute == "close" then
                     err = "attempt to emit a <close> attribute for a non 5.4 target"
                  end

                  if gen_target == "5.4" then
                     add_string(out, lua_54_attribute[var.attribute])
                  end
               end
            end
            if children[3] then
               table.insert(out, " =")
               add_child(out, children[3], " ")
            end
            return out
         end,
      },
      ["local_type"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            if not node.var.elide_type then
               table.insert(out, "local")
               add_child(out, children[1], " ")
               table.insert(out, " =")
               add_child(out, children[2], " ")
            end
            return out
         end,
      },
      ["global_type"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            if children[2] then
               add_child(out, children[1])
               table.insert(out, " =")
               add_child(out, children[2], " ")
            end
            return out
         end,
      },
      ["global_declaration"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            if children[3] then
               add_child(out, children[1])
               table.insert(out, " =")
               add_child(out, children[3], " ")
            end
            return out
         end,
      },
      ["assignment"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            add_child(out, children[1])
            table.insert(out, " =")
            add_child(out, children[3], " ")
            return out
         end,
      },
      ["if"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            for i, child in ipairs(children) do
               add_child(out, child, i > 1 and " ", child.y ~= node.y and indent)
            end
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["if_block"] = {
         before = increment_indent,
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            if node.if_block_n == 1 then
               table.insert(out, "if")
            elseif not node.exp then
               table.insert(out, "else")
            else
               table.insert(out, "elseif")
            end
            if node.exp then
               add_child(out, children[1], " ")
               table.insert(out, " then")
            end
            add_child(out, children[2], " ")
            decrement_indent(node, node.body)
            return out
         end,
      },
      ["while"] = {
         before = increment_indent,
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "while")
            add_child(out, children[1], " ")
            table.insert(out, " do")
            add_child(out, children[2], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["repeat"] = {
         before = increment_indent,
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "repeat")
            add_child(out, children[1], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "until " }, " ", indent)
            add_child(out, children[2])
            return out
         end,
      },
      ["do"] = {
         before = increment_indent,
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "do")
            add_child(out, children[1], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["forin"] = {
         before = increment_indent,
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "for")
            add_child(out, children[1], " ")
            table.insert(out, " in")
            add_child(out, children[2], " ")
            table.insert(out, " do")
            add_child(out, children[3], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["fornum"] = {
         before = increment_indent,
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "for")
            add_child(out, children[1], " ")
            table.insert(out, " =")
            add_child(out, children[2], " ")
            table.insert(out, ",")
            add_child(out, children[3], " ")
            if children[4] then
               table.insert(out, ",")
               add_child(out, children[4], " ")
            end
            table.insert(out, " do")
            add_child(out, children[5], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["return"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "return")
            if #children[1] > 0 then
               add_child(out, children[1], " ")
            end
            return out
         end,
      },
      ["break"] = {
         after = function(_: nil, node: Node, _children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "break")
            return out
         end,
      },
      ["variable_list"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            local space: string
            for i, child in ipairs(children) do
               if i > 1 then
                  table.insert(out, ",")
                  space = " "
               end
               add_child(out, child, space, child.y ~= node.y and indent)
            end
            return out
         end,
      },
      ["literal_table"] = {
         before = increment_indent,
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            if #children == 0 then
               table.insert(out, "{}")
               return out
            end
            table.insert(out, "{")
            local n = #children
            for i, child in ipairs(children) do
               add_child(out, child, " ", child.y ~= node.y and indent)
               if i < n or node.yend ~= node.y then
                  table.insert(out, ",")
               end
            end
            decrement_indent(node, node[1])
            add_child(out, { y = node.yend, h = 0, [1] = "}" }, " ", indent)
            return out
         end,
      },
      ["literal_table_item"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            if node.key_parsed ~= "implicit" then
               if node.key_parsed == "short" then
                  children[1][1] = children[1][1]:sub(2, -2)
                  add_child(out, children[1])
                  table.insert(out, " = ")
               else
                  table.insert(out, "[")
                  if node.key_parsed == "long" and node.key.is_longstring then
                     table.insert(children[1], 1, " ")
                     table.insert(children[1], " ")
                  end
                  add_child(out, children[1])
                  table.insert(out, "] = ")
               end
            end
            add_child(out, children[2])
            return out
         end,
      },
      ["local_macroexp"] = {
         before = increment_indent,
         after = function(_: nil, node: Node, _children: {Output}): Output
            return { y = node.y, h = 0 }
         end,
      },
      ["local_function"] = {
         before = increment_indent,
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "local function")
            add_child(out, children[1], " ")
            table.insert(out, "(")
            add_child(out, children[2])
            table.insert(out, ")")
            add_child(out, children[4], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["global_function"] = {
         before = increment_indent,
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "function")
            add_child(out, children[1], " ")
            table.insert(out, "(")
            add_child(out, children[2])
            table.insert(out, ")")
            add_child(out, children[4], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["record_function"] = {
         before = increment_indent,
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "function")
            add_child(out, children[1], " ")
            table.insert(out, node.is_method and ":" or ".")
            add_child(out, children[2])
            table.insert(out, "(")
            if node.is_method then
               -- remove self
               table.remove(children[3], 1)
               if children[3][1] == "," then
                  table.remove(children[3], 1)
                  table.remove(children[3], 1)
               end
            end
            add_child(out, children[3])
            table.insert(out, ")")
            add_child(out, children[5], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["function"] = {
         before = increment_indent,
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "function(")
            add_child(out, children[1])
            table.insert(out, ")")
            add_child(out, children[3], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["cast"] = {
      },
      ["paren"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "(")
            add_child(out, children[1], "", indent)
            table.insert(out, ")")
            return out
         end,
      },
      ["op"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            if node.op.op == "@funcall" then
               add_child(out, children[1], "", indent)
               table.insert(out, "(")
               add_child(out, children[3], "", indent)
               table.insert(out, ")")
            elseif node.op.op == "@index" then
               add_child(out, children[1], "", indent)
               table.insert(out, "[")
               if node.e2.is_longstring then
                  table.insert(children[3], 1, " ")
                  table.insert(children[3], " ")
               end
               add_child(out, children[3], "", indent)
               table.insert(out, "]")
            elseif node.op.op == "as" then
               add_child(out, children[1], "", indent)
            elseif node.op.op == "is" then
               if node.e2.casttype.typename == "integer" then
                  table.insert(out, "math.type(")
                  add_child(out, children[1], "", indent)
                  table.insert(out, ") == \"integer\"")
               elseif node.e2.casttype.typename == "nil" then
                  add_child(out, children[1], "", indent)
                  table.insert(out, " == nil")
               else
                  table.insert(out, "type(")
                  add_child(out, children[1], "", indent)
                  table.insert(out, ") == \"")
                  add_child(out, children[3], "", indent)
                  table.insert(out, "\"")
               end
            elseif spaced_op[node.op.arity][node.op.op] or tight_op[node.op.arity][node.op.op] then
               local space = spaced_op[node.op.arity][node.op.op] and " " or ""
               if children[2] and node.op.prec > tonumber(children[2]) then
                  table.insert(children[1], 1, "(")
                  table.insert(children[1], ")")
               end
               if node.op.arity == 1 then
                  table.insert(out, node.op.op)
                  add_child(out, children[1], space, indent)
               elseif node.op.arity == 2 then
                  add_child(out, children[1], "", indent)
                  if space == " " then
                     table.insert(out, " ")
                  end
                  table.insert(out, node.op.op)
                  if children[4] and node.op.prec > tonumber(children[4]) then
                     table.insert(children[3], 1, "(")
                     table.insert(children[3], ")")
                  end
                  add_child(out, children[3], space, indent)
               end
            else
               error("unknown node op " .. node.op.op)
            end
            return out
         end,
      },
      ["newtype"] = {
         after = function(_: nil, node: Node, _children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            local nt = node.newtype
            if nt is TypeAliasType then
               table.insert(out, table.concat(nt.alias_to.names, "."))
            elseif nt is TypeDeclType then
               local def = nt.def
               if def is RecordLikeType then
                  table.insert(out, print_record_def(def))
               else
                  table.insert(out, "{}")
               end
            end
            return out
         end,
      },
      ["goto"] = {
         after = function(_: nil, node: Node, _children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "goto ")
            table.insert(out, node.label)
            return out
         end,
      },
      ["label"] = {
         after = function(_: nil, node: Node, _children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "::")
            table.insert(out, node.label)
            table.insert(out, "::")
            return out
         end,
      },
      ["string"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            -- translate escape sequences not supported by Lua 5.1
            -- in particular:
            --  - \z : removes trailing whitespace
            --  - \xXX : hex byte
            --  - \u{} : unicode

            if node.tk:sub(1, 1) == "[" or gen_target ~= "5.1" or not node.tk:find("\\", 1, true) then
               return emit_exactly(nil, node, children)
            end

            local out <const>: Output = { y = node.y, h = 0 }

            local replaced = node.tk
            for _ in replaced:gmatch("\n") do
               out.h = out.h + 1
            end

            replaced = replaced:gsub("()\\z(%s*)", function(index_in_disguise: string, ws: string): string
               local index <const> = index_in_disguise as integer - 1
               if replaced:sub(index, index) == "\\" then
                  return "\\z" .. ws
               end
               for _ in ws:gmatch("\n") do
                  out.h = out.h - 1
               end
               return ""
            end)

            replaced = replaced:gsub("()\\x(..)", function(index_in_disguise: string, digits: string): string
               local index <const> = index_in_disguise as integer - 1
               if replaced:sub(index, index) == "\\" then
                  return "\\x" .. digits
               end
               local byte <const> = tonumber(digits, 16)
               return byte and string.format("\\%03d", byte) or "\\x" .. digits
            end)

            replaced = replaced:gsub("()\\u{(.-)}", function(index_in_disguise: string, hex_digits: string): string
               local index <const> = index_in_disguise as integer - 1
               if replaced:sub(index, index) == "\\" then
                  return "\\u{" .. hex_digits .. "}"
               end
               local codepoint <const> = tonumber(hex_digits, 16)
               if not codepoint then
                  return "\\000"
               end
               local sequence <const> = utf8.char(codepoint)
               return (sequence:gsub(".", function(c: string): string
                  return ("\\%03d"):format(string.byte(c))
               end))
            end)

            out[1] = replaced
            return out
         end,
      },

      ["variable"] = emit_exactly_visitor_cbs,
      ["identifier"] = emit_exactly_visitor_cbs,
      ["number"] = emit_exactly_visitor_cbs,
      ["integer"] = emit_exactly_visitor_cbs,
      ["nil"] = emit_exactly_visitor_cbs,
      ["boolean"] = emit_exactly_visitor_cbs,
      ["..."] = emit_exactly_visitor_cbs,
      ["argument"] = emit_exactly_visitor_cbs,
      ["type_identifier"] = emit_exactly_visitor_cbs,
   }

   local visit_type: Visitor<nil, TypeName, Type, Output> = {}
   visit_type.cbs = {}
   local default_type_visitor = {
      after = function(_: nil, typ: Type, _children: {Output}): Output
         local out: Output = { y = typ.y or -1, h = 0 }
         local r = typ is NominalType and typ.resolved or typ
         local lua_type = primitive[r.typename] or "table"
         if r is RecordLikeType and r.is_userdata then
            lua_type = "userdata"
         end
         table.insert(out, lua_type)
         return out
      end,
   }

   visit_type.cbs["string"] = default_type_visitor
   visit_type.cbs["typedecl"] = default_type_visitor
   visit_type.cbs["typealias"] = default_type_visitor
   visit_type.cbs["typevar"] = default_type_visitor
   visit_type.cbs["typearg"] = default_type_visitor
   visit_type.cbs["function"] = default_type_visitor
   visit_type.cbs["thread"] = default_type_visitor
   visit_type.cbs["array"] = default_type_visitor
   visit_type.cbs["map"] = default_type_visitor
   visit_type.cbs["tupletable"] = default_type_visitor
   visit_type.cbs["record"] = default_type_visitor
   visit_type.cbs["enum"] = default_type_visitor
   visit_type.cbs["boolean"] = default_type_visitor
   visit_type.cbs["nil"] = default_type_visitor
   visit_type.cbs["number"] = default_type_visitor
   visit_type.cbs["integer"] = default_type_visitor
   visit_type.cbs["union"] = default_type_visitor
   visit_type.cbs["nominal"] = default_type_visitor
   visit_type.cbs["emptytable"] = default_type_visitor
   visit_type.cbs["literal_table_item"] = default_type_visitor
   visit_type.cbs["unresolved_emptytable_value"] = default_type_visitor
   visit_type.cbs["tuple"] = default_type_visitor
   visit_type.cbs["poly"] = default_type_visitor
   visit_type.cbs["any"] = default_type_visitor
   visit_type.cbs["unknown"] = default_type_visitor
   visit_type.cbs["invalid"] = default_type_visitor
   visit_type.cbs["none"] = default_type_visitor

   visit_node.cbs["expression_list"] = visit_node.cbs["variable_list"]
   visit_node.cbs["argument_list"] = visit_node.cbs["variable_list"]

   local out = recurse_node(nil, ast, visit_node, visit_type)
   if err then
      return nil, err
   end

   local code: Output
   if opts.preserve_newlines then
      code = { y = 1, h = 0 }
      add_child(code, out)
   else
      code = out
   end
   return (concat_output(code):gsub(" *\n", "\n"))
end

--------------------------------------------------------------------------------
-- Type collection for report
--------------------------------------------------------------------------------

local typename_to_typecode <total>: {TypeName:integer} = {
   ["typevar"] = tl.typecodes.TYPE_VARIABLE,
   ["typearg"] = tl.typecodes.TYPE_VARIABLE,
   ["unresolved_typearg"] = tl.typecodes.TYPE_VARIABLE,
   ["unresolvable_typearg"] = tl.typecodes.TYPE_VARIABLE,
   ["function"] = tl.typecodes.FUNCTION,
   ["array"] = tl.typecodes.ARRAY,
   ["map"] = tl.typecodes.MAP,
   ["tupletable"] = tl.typecodes.TUPLE,
   ["interface"] = tl.typecodes.INTERFACE,
   ["record"] = tl.typecodes.RECORD,
   ["enum"] = tl.typecodes.ENUM,
   ["boolean"] = tl.typecodes.BOOLEAN,
   ["string"] = tl.typecodes.STRING,
   ["nil"] = tl.typecodes.NIL,
   ["thread"] = tl.typecodes.THREAD,
   ["number"] = tl.typecodes.NUMBER,
   ["integer"] = tl.typecodes.INTEGER,
   ["union"] = tl.typecodes.UNION,
   ["nominal"] = tl.typecodes.NOMINAL,
   ["circular_require"] = tl.typecodes.NOMINAL,
   ["emptytable"] = tl.typecodes.EMPTY_TABLE,
   ["unresolved_emptytable_value"] = tl.typecodes.EMPTY_TABLE,
   ["poly"] = tl.typecodes.POLY,
   ["any"] = tl.typecodes.ANY,
   ["unknown"] = tl.typecodes.UNKNOWN,
   ["invalid"] = tl.typecodes.INVALID,
   -- types that should be skipped or not present:
   ["none"] = tl.typecodes.UNKNOWN,
   ["tuple"] = tl.typecodes.UNKNOWN,
   ["literal_table_item"] = tl.typecodes.UNKNOWN,
   ["typedecl"] = tl.typecodes.UNKNOWN,
   ["typealias"] = tl.typecodes.UNKNOWN,
   ["*"] = tl.typecodes.UNKNOWN,
}

local skip_types: {TypeName: boolean} = {
   ["none"] = true,
   ["tuple"] = true,
   ["literal_table_item"] = true,
}

local function sorted_keys<A,B>(m: {A:B}):{A}
   local keys = {}
   for k, _ in pairs(m) do
      table.insert(keys, k)
   end
   table.sort(keys)
   return keys
end

-- mark array for JSON-encoded reports in `tl types`
local function mark_array<T>(x: T): T
   local arr = x as {boolean}
   arr[0] = false
   return x
end

function tl.new_type_reporter(): TypeReporter
   local self: TypeReporter = {
      next_num = 1,
      typeid_to_num = {},
      typename_to_num = {},
      tr = {
         by_pos = {},
         types = {},
         symbols = mark_array {},
         globals = {},
      },
   }

   local names = {}
   for name, _ in pairs(simple_types) do
      table.insert(names, name)
   end
   table.sort(names)

   for _, name in ipairs(names) do
      local ti: TypeInfo = {
         t = assert(typename_to_typecode[name]),
         str = name,
      }
      local n = self.next_num
      self.typename_to_num[name] = n
      self.tr.types[n] = ti
      self.next_num = self.next_num + 1
   end

   return setmetatable(self, { __index = TypeReporter })
end

function TypeReporter:store_function(ti: TypeInfo, rt: FunctionType)
   local args: {{integer, string}} = {}
   for _, fnarg in ipairs(rt.args.tuple) do
      table.insert(args, mark_array { self:get_typenum(fnarg), nil })
   end
   ti.args = mark_array(args)
   local rets: {{integer, string}} = {}
   for _, fnarg in ipairs(rt.rets.tuple) do
      table.insert(rets, mark_array { self:get_typenum(fnarg), nil })
   end
   ti.rets = mark_array(rets)
   ti.vararg = not not rt.args.is_va
   ti.varret = not not rt.rets.is_va
end

function TypeReporter:get_typenum(t: Type): integer
   -- try simple types first
   local n = self.typename_to_num[t.typename]
   if n then
      return n
   end

   assert(t.typeid)
   -- try by typeid
   n = self.typeid_to_num[t.typeid]
   if n then
      return n
   end

   local tr = self.tr

   -- it's a new entry: store and increment
   n = self.next_num

   local rt = t
   if rt is TupleType and #rt.tuple == 1 then
      rt = rt.tuple[1]
   end

   if rt is TypeDeclType then
      rt = rt.def
   elseif rt is TypeAliasType then
      rt = rt.alias_to
   end

   local ti: TypeInfo = {
      t = assert(typename_to_typecode[rt.typename]),
      str = show_type(t, true),
      file = t.f,
      y = t.y,
      x = t.x,
   }
   tr.types[n] = ti
   self.typeid_to_num[t.typeid] = n
   self.next_num = self.next_num + 1

   if t is NominalType then
      if t.found then
         ti.ref = self:get_typenum(t.found)
      end
      if t.resolved then
         rt = t
      end
   end
   assert(not (rt is TypeDeclType or rt is TypeAliasType))

   if rt is RecordLikeType then
      -- store record field info
      local r = {}
      for _, k in ipairs(rt.field_order) do
         local v = rt.fields[k]
         r[k] = self:get_typenum(v)
      end
      ti.fields = r
   end

   if rt is ArrayLikeType then
      ti.elements = self:get_typenum(rt.elements)
   end

   if rt is MapType then
      ti.keys = self:get_typenum(rt.keys)
      ti.values = self:get_typenum(rt.values)
   elseif rt is EnumType then
      ti.enums = mark_array(sorted_keys(rt.enumset))
   elseif rt is FunctionType then
      self:store_function(ti, rt)
   elseif rt is AggregateType then
      local tis = {}
      for _, pt in ipairs(rt.types) do
         table.insert(tis, self:get_typenum(pt))
      end
      ti.types = mark_array(tis)
   end

   return n
end

local record TypeCollector
   record Symbol
      x: integer
      y: integer
      name: string
      typ: Type
      skip: boolean
   end

   filename: string
   symbol_list: {Symbol}

   store_type: function(y: integer, x: integer, typ: Type)
   reserve_symbol_list_slot: function(Node)
   add_to_symbol_list: function(node: Node, name: string, t: Type)
   begin_symbol_list_scope: function(node: Node)
   end_symbol_list_scope: function(node: Node)
end

function TypeReporter:get_collector(filename: string): TypeCollector
   local collector: TypeCollector = {
      filename = filename,
      symbol_list = {},
   }

   local ft: {integer:{integer:integer}} = {}
   self.tr.by_pos[filename] = ft

   local symbol_list = collector.symbol_list
   local symbol_list_n = 0

   collector.store_type = function(y: integer, x: integer, typ: Type)
      if not typ or skip_types[typ.typename] then
         return
      end

      local yt = ft[y]
      if not yt then
         yt = {}
         ft[y] = yt
      end

      yt[x] = self:get_typenum(typ)
   end

   collector.reserve_symbol_list_slot = function(node: Node)
      symbol_list_n = symbol_list_n + 1
      node.symbol_list_slot = symbol_list_n
   end

   collector.add_to_symbol_list = function(node: Node, name: string, t: Type)
      if not node then
         return
      end
      local slot: integer
      if node.symbol_list_slot then
         slot = node.symbol_list_slot
      else
         symbol_list_n = symbol_list_n + 1
         slot = symbol_list_n
      end
      symbol_list[slot] = { y = node.y, x = node.x, name = name, typ = t }
   end

   collector.begin_symbol_list_scope = function(node: Node)
      symbol_list_n = symbol_list_n + 1
      symbol_list[symbol_list_n] = { y = node.y, x = node.x, name = "@{" }
   end

   collector.end_symbol_list_scope = function(node: Node)
      if symbol_list[symbol_list_n].name == "@{" then
         symbol_list[symbol_list_n] = nil
         symbol_list_n = symbol_list_n - 1
      else
         symbol_list_n = symbol_list_n + 1
         symbol_list[symbol_list_n] = { y = assert(node.yend), x = assert(node.xend), name = "@}" }
      end
   end

   return collector
end

function TypeReporter:store_result(collector: TypeCollector, globals: {string:Variable})
   local tr = self.tr

   local filename = collector.filename
   local symbol_list = collector.symbol_list

   tr.by_pos[filename][0] = nil

   -- mark unneeded scope blocks to be skipped
   do
      local n = 0 -- number of symbols in current scope
      local p = 0 -- opening position of current scope block
      local n_stack, p_stack = {}, {}
      local level = 0
      for i, s in ipairs(symbol_list) do
         if s.typ then
            n = n + 1
         elseif s.name == "@{" then
            level = level + 1
            n_stack[level], p_stack[level] = n, p -- push current scope
            n, p = 0, i -- begin new scope
         else
            if n == 0 then -- nothing declared in this scope
               symbol_list[p].skip = true -- skip @{
               s.skip = true -- skip @}
            end
            n, p = n_stack[level], p_stack[level] -- pop previous scope
            level = level - 1
         end
      end
   end

   -- resolve scope cross references, skipping unneeded scope blocks
   do
      local stack = {}
      local level = 0
      local i = 0
      for _, s in ipairs(symbol_list) do
         if not s.skip then
            i = i + 1
            local id: integer
            if s.typ then
               id = self:get_typenum(s.typ)
            elseif s.name == "@{" then
               level = level + 1
               stack[level] = i
               id = -1 -- will be overwritten
            else
               local other = stack[level]
               level = level - 1
               tr.symbols[other][4] = i -- overwrite id from @{
               id = other - 1
            end
            local sym = mark_array({ s.y, s.x, s.name, id })
            table.insert(tr.symbols, sym)
         end
      end
   end

   local gkeys = sorted_keys(globals)
   for _, name in ipairs(gkeys) do
      if name:sub(1, 1) ~= "@" then
         local var = globals[name]
         tr.globals[name] = self:get_typenum(var.t)
      end
   end
end

function TypeReporter:get_report(): TypeReport
   return self.tr
end


--------------------------------------------------------------------------------
-- Report types
--------------------------------------------------------------------------------

function tl.symbols_in_scope(tr: TypeReport, y: integer, x: integer): {string:integer}
   local function find(symbols: {{integer, integer, string, integer}}, at_y: integer, at_x: integer): integer
      local function le(a: {integer, integer}, b: {integer, integer}): boolean
         return a[1] < b[1]
            or (a[1] == b[1] and a[2] <= b[2])
      end
      return binary_search(symbols, {at_y, at_x}, le) or 0
   end

   local ret: {string:integer} = {}

   local n = find(tr.symbols, y, x)

   local symbols = tr.symbols
   while n >= 1 do
      local s = symbols[n]
      if s[3] == "@{" then
         n = n - 1
      elseif s[3] == "@}" then
         n = s[4]
      else
         ret[s[3]] = s[4]
         n = n - 1
      end
   end

   return ret
end

--------------------------------------------------------------------------------
-- Errors
--------------------------------------------------------------------------------

function Errors.new(filename: string): Errors
   local self = {
      errors = {},
      warnings = {},
      unknown_dots = {},
      filename = filename,
   }
   return setmetatable(self, { __index = Errors })
end

local function Err(msg: string, t1?: Type, t2?: Type, t3?: Type): Error
   if t1 then
      local s1, s2, s3: string, string, string
      if t1 is InvalidType then
         return nil
      end
      s1 = show_type(t1)
      if t2 then
         if t2 is InvalidType then
            return nil
         end
         s2 = show_type(t2)
      end
      if t3 then
         if t3 is InvalidType then
            return nil
         end
         s3 = show_type(t3)
      end
      msg = msg:format(s1, s2, s3)
      return {
         msg = msg,
         x = t1.x,
         y = t1.y,
         filename = t1.f,
      }
   end

   return {
      msg = msg,
   }
end

local function insert_error(self: Errors, y: integer, x: integer, err: Error)
   err.y = assert(y)
   err.x = assert(x)
   err.filename = self.filename

   if TL_DEBUG then
      io.stderr:write("ERROR:" .. err.y .. ":" .. err.x .. ": " .. err.msg .. "\n")
   end

   table.insert(self.errors, err)
end

function Errors:add(w: Where, msg: string, ...:Type)
   local e = Err(msg, ...)
   if e then
      insert_error(self, w.y, w.x, e)
   end
end

local context_name: {NodeKind: string} = {
   ["local_declaration"] = "in local declaration",
   ["global_declaration"] = "in global declaration",
   ["assignment"] = "in assignment",
   ["literal_table_item"] = "in table item",
}

function Errors:get_context(ctx: Node|string, name?: string): string
   if not ctx then
      return ""
   end
   local ec = (ctx is Node)   and ctx.expected_context
   local cn = (ctx is string) and ctx or
              (ctx is Node)   and context_name[ec and ec.kind or ctx.kind]
   return (cn and cn .. ": " or "") .. (ec and ec.name and ec.name .. ": " or "") .. (name and name .. ": " or "")
end

function Errors:add_in_context(w: Where, ctx: Node, msg: string, ...:Type)
   local prefix = self:get_context(ctx)
   msg = prefix .. msg

   local e = Err(msg, ...)
   if e then
      insert_error(self, w.y, w.x, e)
   end
end


function Errors:collect(errs: {Error})
   for _, e in ipairs(errs) do
      insert_error(self, e.y, e.x, e)
   end
end

function Errors:add_warning(tag: WarningKind, w: Where, fmt: string, ...: any)
   assert(w.y)
   table.insert(self.warnings, {
      y = w.y,
      x = w.x,
      msg = fmt:format(...),
      filename = self.filename,
      tag = tag,
   })
end

function Errors:invalid_at(w: Where, msg: string, ...:Type): InvalidType
   self:add(w, msg, ...)
   return an_invalid(w)
end

function Errors:add_unknown(node: Node, name: string)
   self:add_warning("unknown", node, "unknown variable: %s", name)
end

function Errors:redeclaration_warning(node: Node, old_var?: Variable)
   if node.tk:sub(1, 1) == "_" then return end

   local var_kind = "variable"
   local var_name = node.tk
   if node.kind == "local_function" or node.kind == "record_function" then
      var_kind = "function"
      var_name = node.name.tk
   end

   local short_error = "redeclaration of " .. var_kind .. " '%s'"
   if old_var and old_var.declared_at then
      self:add_warning("redeclaration", node, short_error .. " (originally declared at %d:%d)", var_name, old_var.declared_at.y, old_var.declared_at.x)
   else
      self:add_warning("redeclaration", node, short_error, var_name)
   end
end

function Errors:unused_warning(name: string, var: Variable)
   local prefix <const> = name:sub(1,1)
   if var.declared_at
      and var.is_narrowed ~= "narrow"
      and prefix ~= "_"
      and prefix ~= "@"
   then
      local t = var.t
      self:add_warning(
         "unused",
         var.declared_at,
         "unused %s %s: %s",
         var.is_func_arg and "argument"
            or t is FunctionType and "function"
            or t is TypeDeclType and "type"
            or t is TypeAliasType and "type"
            or "variable",
         name,
         show_type(var.t)
      )
   end
end

function Errors:add_prefixing(w: Where, src: {Error}, prefix: string, dst?: {Error})
   if not src then
      return
   end

   for _, err in ipairs(src) do
      err.msg = prefix .. err.msg
      if w and (
         (err.filename ~= w.f)
         or (not err.y)
         or (w.y > err.y or (w.y == err.y and w.x > err.x))
      ) then
         err.y = w.y
         err.x = w.x
         err.filename = w.f
      end

      if dst then
         table.insert(dst, err)
      else
         insert_error(self, err.y, err.x, err)
      end
   end
end

local record Unused
   y: integer
   x: integer
   name: string
   var: Variable
end

local function check_for_unused_vars(scope: Scope, is_global?: boolean): {Unused}
   local vars = scope.vars
   if not next(vars) then
      return
   end
   local list: {Unused}
   for name, var in pairs(vars) do
      local t = var.t
      if var.declared_at and not var.used then
         if var.used_as_type then
            var.declared_at.elide_type = true
         else
            if (t is TypeDeclType or t is TypeAliasType) and not is_global then
               var.declared_at.elide_type = true
            end
            list = list or {}
            table.insert(list, { y = var.declared_at.y, x = var.declared_at.x, name = name, var = var })
         end
      elseif var.used and (t is TypeDeclType or t is TypeAliasType) and var.aliasing then
         var.aliasing.used = true
         var.aliasing.declared_at.elide_type = false
      end
   end
   if list then
      table.sort(list, function(a: Unused, b: Unused): boolean
         return a.y < b.y or (a.y == b.y and a.x < b.x)
      end)
   end
   return list
end

function Errors:warn_unused_vars(scope: Scope, is_global?: boolean)
   local unused = check_for_unused_vars(scope, is_global)
   if unused then
      for _, u in ipairs(unused) do
         self:unused_warning(u.name, u.var)
      end
   end

   if scope.labels then
      for name, node in pairs(scope.labels) do
         if not node.used_label then
            self:add_warning("unused", node, "unused label ::%s::", name)
         end
      end
   end
end

function Errors:add_unknown_dot(node: Node, name: string)
   if not self.unknown_dots[name] then
      self.unknown_dots[name] = true
      self:add_unknown(node, name)
   end
end

function Errors:fail_unresolved_labels(scope: Scope)
   if scope.pending_labels then
      for name, nodes in pairs(scope.pending_labels) do
         for _, node in ipairs(nodes) do
            self:add(node, "no visible label '" .. name .. "' for goto")
         end
      end
   end
end

function Errors:fail_unresolved_nominals(scope: Scope, global_scope: Scope)
   if global_scope and scope.pending_nominals then
      for name, types in pairs(scope.pending_nominals) do
         if not global_scope.pending_global_types[name] then
            for _, typ in ipairs(types) do
               assert(typ.x)
               assert(typ.y)
               self:add(typ, "unknown type %s", typ)
            end
         end
      end
   end
end

local type CheckableKey = string | number | boolean

function Errors:check_redeclared_key(w: Where, ctx: Node, seen_keys: {CheckableKey:Where}, key: CheckableKey)
   if key ~= nil then
      local s = seen_keys[key]
      if s then
         self:add_in_context(w, ctx, "redeclared key " .. tostring(key) .. " (previously declared at " .. self.filename .. ":" .. s.y .. ":" .. s.x .. ")")
      else
         seen_keys[key] = w
      end
   end
end

--------------------------------------------------------------------------------
-- Type check
--------------------------------------------------------------------------------

local numeric_binop = {
   ["number"] = {
      ["number"] = "number",
      ["integer"] = "number",
   },
   ["integer"] = {
      ["integer"] = "integer",
      ["number"] = "number",
   },
}

local float_binop = {
   ["number"] = {
      ["number"] = "number",
      ["integer"] = "number",
   },
   ["integer"] = {
      ["integer"] = "number",
      ["number"] = "number",
   },
}

local integer_binop = {
   ["number"] = {
      ["number"] = "integer",
      ["integer"] = "integer",
   },
   ["integer"] = {
      ["integer"] = "integer",
      ["number"] = "integer",
   },
}

local relational_binop = {
   ["number"] = {
      ["integer"] = "boolean",
      ["number"] = "boolean",
   },
   ["integer"] = {
      ["number"] = "boolean",
      ["integer"] = "boolean",
   },
   ["string"] = {
      ["string"] = "boolean",
   },
   ["boolean"] = {
      ["boolean"] = "boolean",
   },
}

local equality_binop = {
   ["number"] = {
      ["number"] = "boolean",
      ["integer"] = "boolean",
      ["nil"] = "boolean",
   },
   ["integer"] = {
      ["number"] = "boolean",
      ["integer"] = "boolean",
      ["nil"] = "boolean",
   },
   ["string"] = {
      ["string"] = "boolean",
      ["nil"] = "boolean",
   },
   ["boolean"] = {
      ["boolean"] = "boolean",
      ["nil"] = "boolean",
   },
   ["record"] = {
      ["emptytable"] = "boolean",
      ["record"] = "boolean",
      ["nil"] = "boolean",
   },
   ["array"] = {
      ["emptytable"] = "boolean",
      ["array"] = "boolean",
      ["nil"] = "boolean",
   },
   ["map"] = {
      ["emptytable"] = "boolean",
      ["map"] = "boolean",
      ["nil"] = "boolean",
   },
   ["thread"] = {
      ["thread"] = "boolean",
      ["nil"] = "boolean",
   }
}

local unop_types: {string:{TypeName:TypeName}} = {
   ["#"] = {
      ["string"] = "integer",
      ["array"] = "integer",
      ["tupletable"] = "integer",
      ["map"] = "integer",
      ["emptytable"] = "integer",
   },
   ["-"] = {
      ["number"] = "number",
      ["integer"] = "integer",
   },
   ["~"] = {
      ["number"] = "integer",
      ["integer"] = "integer",
   },
   ["not"] = {
      ["string"] = "boolean",
      ["number"] = "boolean",
      ["integer"] = "boolean",
      ["boolean"] = "boolean",
      ["record"] = "boolean",
      ["array"] = "boolean",
      ["tupletable"] = "boolean",
      ["map"] = "boolean",
      ["emptytable"] = "boolean",
      ["thread"] = "boolean",
   },
}

local unop_to_metamethod: {string:string} = {
   ["#"] = "__len",
   ["-"] = "__unm",
   ["~"] = "__bnot",
}

local binop_types: {string:{TypeName:{TypeName:TypeName}}} = {
   ["+"] = numeric_binop,
   ["-"] = numeric_binop,
   ["*"] = numeric_binop,
   ["%"] = numeric_binop,
   ["/"] = float_binop,
   ["//"] = numeric_binop,
   ["^"] = float_binop,
   ["&"] = integer_binop,
   ["|"] = integer_binop,
   ["<<"] = integer_binop,
   [">>"] = integer_binop,
   ["~"] = integer_binop,
   ["=="] = equality_binop,
   ["~="] = equality_binop,
   ["<="] = relational_binop,
   [">="] = relational_binop,
   ["<"] = relational_binop,
   [">"] = relational_binop,
   ["or"] = {
      ["boolean"] = {
         ["boolean"] = "boolean",
      },
      ["number"] = {
         ["integer"] = "number",
         ["number"] = "number",
         ["boolean"] = "boolean",
      },
      ["integer"] = {
         ["integer"] = "integer",
         ["number"] = "number",
         ["boolean"] = "boolean",
      },
      ["string"] = {
         ["string"] = "string",
         ["boolean"] = "boolean",
         ["enum"] = "string",
      },
      ["function"] = {
         ["boolean"] = "boolean",
      },
      ["array"] = {
         ["boolean"] = "boolean",
      },
      ["record"] = {
         ["boolean"] = "boolean",
      },
      ["map"] = {
         ["boolean"] = "boolean",
      },
      ["enum"] = {
         ["string"] = "string",
      },
      ["thread"] = {
         ["boolean"] = "boolean",
      }
   },
   [".."] = {
      ["string"] = {
         ["string"] = "string",
         ["enum"] = "string",
         ["number"] = "string",
         ["integer"] = "string",
      },
      ["number"] = {
         ["integer"] = "string",
         ["number"] = "string",
         ["string"] = "string",
         ["enum"] = "string",
      },
      ["integer"] = {
         ["integer"] = "string",
         ["number"] = "string",
         ["string"] = "string",
         ["enum"] = "string",
      },
      ["enum"] = {
         ["number"] = "string",
         ["integer"] = "string",
         ["string"] = "string",
         ["enum"] = "string",
      }
   },
}

local binop_to_metamethod: {string:string} = {
   ["+"] = "__add",
   ["-"] = "__sub",
   ["*"] = "__mul",
   ["/"] = "__div",
   ["%"] = "__mod",
   ["^"] = "__pow",
   ["//"] = "__idiv",
   ["&"] = "__band",
   ["|"] = "__bor",
   ["~"] = "__bxor",
   ["<<"] = "__shl",
   [">>"] = "__shr",
   [".."] = "__concat",
   ["=="] = "__eq",
   ["<"] = "__lt",
   ["<="] = "__le",
   ["@index"] = "__index",
   ["is"] = "__is",
}

local flip_binop_to_metamethod: {string:string} = {
   [">"] = "__lt",
   [">="] = "__le",
}

local function is_unknown(t: Type): boolean
   return t.typename == "unknown"
       or t.typename == "unresolved_emptytable_value"
end

local function display_typevar(typevar: string): string
   return TL_DEBUG and typevar or (typevar:gsub("@.*", ""))
end

local function show_fields(t: RecordLikeType, show: function(Type):(string)): string
   if t.declname and not t.typeargs then
      return " " .. t.declname
   end

   local out: {string} = {}
   if t.declname and not t.typeargs then
      table.insert(out, " " .. t.declname)
   end
   if t.typeargs then
      table.insert(out, "<")
      local typeargs = {}
      for _, v in ipairs(t.typeargs) do
         table.insert(typeargs, show(v))
      end
      table.insert(out, table.concat(typeargs, ", "))
      table.insert(out, ">")
   end
   if t.declname then
      return table.concat(out)
   end

   table.insert(out, " (")
   if t.elements then
      table.insert(out, "{" .. show(t.elements) .. "}")
   end
   local fs = {}
   for _, k in ipairs(t.field_order) do
      local v = t.fields[k]
      table.insert(fs, k .. ": " .. show(v))
   end
   table.insert(out, table.concat(fs, "; "))
   table.insert(out, ")")
   return table.concat(out)
end

local function show_type_base(t: Type, short: boolean, seen: {Type:string}): string
   -- FIXME this is a control for recursively built types, which should in principle not exist
   if seen[t] then
      return seen[t]
   end
   seen[t] = "..."

   local function show(typ: Type): string
      return show_type(typ, short, seen)
   end

   if t is NominalType then
      if #t.names == 1 and t.names[1] == "@self" then
         return "self"
      end

      if t.typevals then
         local out = { table.concat(t.names, "."), "<" }
         local vals: {string} = {}
         for _, v in ipairs(t.typevals) do
            table.insert(vals, show(v))
         end
         table.insert(out, table.concat(vals, ", "))
         table.insert(out, ">")
         return table.concat(out)
      else
         return table.concat(t.names, ".")
      end
   elseif t is TupleType then
      local out: {string} = {}
      for _, v in ipairs(t.tuple) do
         table.insert(out, show(v))
      end
      local list = table.concat(out, ", ")
      if short then
         return list
      end
      return "(" .. list .. ")"
   elseif t is TupleTableType then
      local out: {string} = {}
      for _, v in ipairs(t.types) do
         table.insert(out, show(v))
      end
      return "{" .. table.concat(out, ", ") .. "}"
   elseif t is PolyType then
      local out: {string} = {}
      for _, v in ipairs(t.types) do
         table.insert(out, show(v))
      end
      return "polymorphic function (with types " .. table.concat(out, " and ") .. ")"
   elseif t is UnionType then
      local out: {string} = {}
      for _, v in ipairs(t.types) do
         table.insert(out, show(v))
      end
      return table.concat(out, " | ")
   elseif t is EmptyTableType then
      return "{}"
   elseif t is MapType then
      return "{" .. show(t.keys) .. " : " .. show(t.values) .. "}"
   elseif t is ArrayType then
      return "{" .. show(t.elements) .. "}"
   elseif t is EnumType then
      return t.declname or "enum"
   elseif t is RecordLikeType then
      return short and t.typename or t.typename .. show_fields(t, show)
   elseif t is FunctionType then
      local out: {string} = {"function"}
      if t.typeargs then
         table.insert(out, "<")
         local typeargs = {}
         for _, v in ipairs(t.typeargs) do
            table.insert(typeargs, show(v))
         end
         table.insert(out, table.concat(typeargs, ", "))
         table.insert(out, ">")
      end
      table.insert(out, "(")
      local args = {}
      if t.is_method then
         table.insert(args, "self")
      end
      for i, v in ipairs(t.args.tuple) do
         if not t.is_method or i > 1 then
            table.insert(args, ((i == #t.args.tuple and t.args.is_va) and "...: "
                               or (i > t.min_arity) and "? "
                               or "") .. show(v))
         end
      end
      table.insert(out, table.concat(args, ", "))
      table.insert(out, ")")
      if t.rets.tuple and #t.rets.tuple > 0 then
         table.insert(out, ": ")
         local rets = {}
         for i, v in ipairs(t.rets.tuple) do
            table.insert(rets, show(v) .. (i == #t.rets.tuple and t.rets.is_va and "..." or ""))
         end
         table.insert(out, table.concat(rets, ", "))
      end
      return table.concat(out)
   elseif t.typename == "number"
       or t.typename == "integer"
       or t.typename == "boolean"
       or t.typename == "thread" then
      return t.typename
   elseif t is StringType then
      if short then
         return "string"
      else
         return t.typename ..
                (t.literal and string.format(" %q", t.literal) or "")
      end
   elseif t is TypeVarType then
      return display_typevar(t.typevar)
   elseif t is TypeArgType then
      return display_typevar(t.typearg)
   elseif t is UnresolvableTypeArgType then
      return display_typevar(t.typearg) .. " (unresolved generic)"
   elseif is_unknown(t) then
      return "<unknown type>"
   elseif t.typename == "invalid" then
      return "<invalid type>"
   elseif t.typename == "any" then
      return "<any type>"
   elseif t.typename == "nil" then
      return "nil"
   elseif t.typename == "none" then
      return ""
   elseif t is TypeAliasType then
      return "type " .. show(t.alias_to)
   elseif t is TypeDeclType then
      return "type " .. show(t.def)
   else
      return "<" .. t.typename .. " " .. tostring(t) .. ">"
   end
end

local function inferred_msg(t: Type, prefix?: string): string
   return " (" .. (prefix or "") .. "inferred at "..t.inferred_at.f..":"..t.inferred_at.y..":"..t.inferred_at.x..")"
end

show_type = function(t: Type, short?: boolean, seen?: {Type:string}): string
   seen = seen or {}
   if seen[t] then
      return seen[t]
   end
   local ret = show_type_base(t, short, seen)
   if t.inferred_at then
      ret = ret .. inferred_msg(t)
   end
   seen[t] = ret
   return ret
end

local function search_for(module_name: string, suffix: string, path: string, tried: {string}): string, FILE, {string}
   for entry in path:gmatch("[^;]+") do
      local slash_name = module_name:gsub("%.", "/")
      local filename = entry:gsub("?", slash_name)
      local tl_filename = filename:gsub("%.lua$", suffix)
      local fd = io.open(tl_filename, "rb")
      if fd then
         return tl_filename, fd, tried
      end
      table.insert(tried, "no file '" .. tl_filename .. "'")
   end
   return nil, nil, tried
end

function tl.search_module(module_name: string, search_dtl: boolean): string, FILE, {string}
   local found: string
   local fd: FILE
   local tried: {string} = {}
   local path = os.getenv("TL_PATH") or package.path
   if search_dtl then
      found, fd, tried = search_for(module_name, ".d.tl", path, tried)
      if found then
         return found, fd
      end
   end
   found, fd, tried = search_for(module_name, ".tl", path, tried)
   if found then
      return found, fd
   end
   found, fd, tried = search_for(module_name, ".lua", path, tried)
   if found then
      return found, fd
   end
   return nil, nil, tried
end

local function require_module(w: Where, module_name: string, feat_lax: boolean, env: Env): Type, string
   local mod = env.modules[module_name]
   if mod then
      return mod, env.module_filenames[module_name]
   end

   local found, fd = tl.search_module(module_name, true)
   if found and (feat_lax or found:match("tl$") as boolean) then

      env.module_filenames[module_name] = found
      env.modules[module_name] = a_typedecl(w, a_type(w, "circular_require", {}))

      local found_result, err: Result, string = tl.process(found, env, fd)
      assert(found_result, err)

      env.modules[module_name] = found_result.type

      return found_result.type, found
   elseif fd then
      fd:close()
   end

   return an_invalid(w), found
end

local compat_code_cache: {string:Node} = {}

local function add_compat_entries(program: Node, used_set: {string: boolean}, gen_compat: GenCompat)
   if gen_compat == "off" or not next(used_set) then
      return
   end

   local tl_debug = TL_DEBUG
   TL_DEBUG = nil

   local used_list: {string} = sorted_keys(used_set)

   local compat_loaded = false

   local n = 1
   local function load_code(name: string, text: string)
      local code: Node = compat_code_cache[name]
      if not code then
         code = tl.parse(text, "@internal")
         tl.type_check(code, "@internal", { feat_lax = "off", gen_compat = "off" })
         compat_code_cache[name] = code
      end
      for _, c in ipairs(code) do
         table.insert(program, n, c)
         n = n + 1
      end
   end

   local function req(m: string): string
      return (gen_compat == "optional")
             and "pcall(require, '" .. m .. "')"
             or  "true, require('" .. m .. "')"
   end

   for _, name in ipairs(used_list) do
      if name == "table.unpack" then
         load_code(name, "local _tl_table_unpack = unpack or table.unpack")
      elseif name == "bit32" then
         load_code(name, "local bit32 = bit32; if not bit32 then local p, m = " .. req("bit32") .. "; if p then bit32 = m end")
      elseif name == "mt" then
         load_code(name, "local _tl_mt = function(m, s, a, b) return (getmetatable(s == 1 and a or b)[m](a, b) end")
      elseif name == "math.maxinteger" then
         load_code(name, "local _tl_math_maxinteger = math.maxinteger or math.pow(2,53)")
      elseif name == "math.mininteger" then
         load_code(name, "local _tl_math_mininteger = math.mininteger or -math.pow(2,53) - 1")
      else
         if not compat_loaded then
            load_code("compat", "local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = " .. req("compat53.module") .. "; if p then _tl_compat = m end")
            compat_loaded = true
         end
         load_code(name, (("local $NAME = _tl_compat and _tl_compat.$NAME or $NAME"):gsub("$NAME", name)))
      end
   end
   program.y = 1

   TL_DEBUG = tl_debug
end

local function get_stdlib_compat(): {string:boolean}
   return {
      ["io"] = true,
      ["math"] = true,
      ["string"] = true,
      ["table"] = true,
      ["utf8"] = true,
      ["coroutine"] = true,
      ["os"] = true,
      ["package"] = true,
      ["debug"] = true,
      ["load"] = true,
      ["loadfile"] = true,
      ["assert"] = true,
      ["pairs"] = true,
      ["ipairs"] = true,
      ["pcall"] = true,
      ["xpcall"] = true,
      ["rawlen"] = true,
   }
end

local bit_operators: {string:string} = {
   ["&"] = "band",
   ["|"] = "bor",
   ["~"] = "bxor",
   [">>"] = "rshift",
   ["<<"] = "lshift",
}

local function node_at(w: Where, n: Node): Node
   n.f = assert(w.f)
   n.x = w.x
   n.y = w.y
   return n
end

local function convert_node_to_compat_call(node: Node, mod_name: string, fn_name: string, e1: Node, e2?: Node)
   node.op.op = "@funcall"
   node.op.arity = 2
   node.op.prec = 100
   node.e1 = node_at(node, { kind = "op", op = an_operator(node, 2, ".") })
   node.e1.e1 = node_at(node, { kind = "identifier", tk = mod_name })
   node.e1.e2 = node_at(node, { kind = "identifier", tk = fn_name })
   node.e2 = node_at(node, { kind = "expression_list" })
   node.e2[1] = e1
   node.e2[2] = e2
end

local function convert_node_to_compat_mt_call(node: Node, mt_name: string, which_self: integer, e1: Node, e2?: Node)
   node.op.op = "@funcall"
   node.op.arity = 2
   node.op.prec = 100
   node.e1 = node_at(node, { kind = "identifier", tk = "_tl_mt" })
   node.e2 = node_at(node, { kind = "expression_list" })
   node.e2[1] = node_at(node, { kind = "string", tk = "\"" .. mt_name .. "\"" })
   node.e2[2] = node_at(node, { kind = "integer", tk = tostring(which_self) })
   node.e2[3] = e1
   node.e2[4] = e2
end

local stdlib_globals: {string:Variable} = nil
local globals_typeid = new_typeid()
local fresh_typevar_ctr = 1

local function assert_no_stdlib_errors(errors: {Error}, name: string)
   if #errors ~= 0 then
      local out = {}
      for _, err in ipairs(errors) do
         table.insert(out, err.y .. ":" .. err.x .. " " .. err.msg .. "\n")
      end
      error("Internal Compiler Error: standard library contains " .. name .. ":\n" .. table.concat(out), 2)
   end
end

tl.new_env = function(opts?: EnvOptions): Env, string
   opts = opts or {}

   local env: Env = {
      modules = {},
      module_filenames = {},
      loaded = {},
      loaded_order = {},
      globals = {},
      defaults = opts.defaults or {},
   }

   if env.defaults.gen_target == "5.4" and env.defaults.gen_compat ~= "off" then
      return nil, "gen-compat must be explicitly 'off' when gen-target is '5.4'"
   end

   local w: Where = { f = "@stdlib", x = 1, y = 1 }

   if not stdlib_globals then
      local tl_debug = TL_DEBUG
      TL_DEBUG = nil

      local program, syntax_errors = tl.parse(stdlib, "stdlib.d.tl")
      assert_no_stdlib_errors(syntax_errors, "syntax errors")
      local result = tl.type_check(program, "@stdlib", {}, env)
      assert_no_stdlib_errors(result.type_errors, "type errors")
      stdlib_globals = env.globals

      TL_DEBUG = tl_debug

      -- special cases for compatibility
      local math_t = (stdlib_globals["math"].t as TypeDeclType).def as RecordType
      local table_t = (stdlib_globals["table"].t as TypeDeclType).def as RecordType
      math_t.fields["maxinteger"].needs_compat = true
      math_t.fields["mininteger"].needs_compat = true
      table_t.fields["unpack"].needs_compat = true

      -- only global scope and vararg functions accept `...`:
      -- `@is_va` is an internal sentinel value which is
      -- `any` if `...` is accepted in this scope or `nil` if it isn't.
      stdlib_globals["..."] = { t = a_vararg(w, { a_type(w, "string", {}) }) }
      stdlib_globals["@is_va"] = { t = a_type(w, "any", {}) }

      env.globals = {}
   end

   local stdlib_compat = get_stdlib_compat()
   for name, var in pairs(stdlib_globals) do
      env.globals[name] = var
      var.needs_compat = stdlib_compat[name]
      local t = var.t
      if t is TypeDeclType then
         -- make standard library tables available as modules for require()
         env.modules[name] = t
      end
   end

   if opts.predefined_modules then
      for _, name in ipairs(opts.predefined_modules) do
         local module_type = require_module(w, name, env.defaults.feat_lax == "on", env)

         if module_type is InvalidType then
            return nil, string.format("Error: could not predefine module '%s'", name)
         end
      end
   end

   return env
end


do
   local type TypeRelations = {TypeName:{TypeName:CompareTypes}}
   local type InvalidOrTupleType = InvalidType | TupleType

   local record TypeChecker
      env: Env
      st: {Scope}

      filename: string
      errs: Errors
      module_type: Type

      subtype_relations: TypeRelations
      eqtype_relations: TypeRelations
      type_priorities: {TypeName:integer}

      all_needs_compat: {string:boolean}
      dependencies: {string:string}
      collector: TypeCollector

      gen_compat: GenCompat
      gen_target: GenTarget
      feat_arity: boolean
      feat_lax: boolean

      same_type: function(TypeChecker, Type, Type): boolean, {Error}
      is_a: function(TypeChecker, Type, Type): boolean, {Error}

      type_check_funcall: function(TypeChecker, node: Node, a: Type, b: TupleType, argdelta?: integer): InvalidOrTupleType

      expand_type: function(TypeChecker, w: Where, old: Type, new: Type): Type

      get_rets: function(TupleType): TupleType
   end

   local enum VarUse
      "use"
      "lvalue"
      "use_type"
      "check_only"
   end

   function TypeChecker:find_var(name: string, use?: VarUse): Variable, integer, Attribute
      for i = #self.st, 1, -1 do
         local scope = self.st[i]
         local var = scope.vars[name]
         if var then
            if use == "lvalue" and var.is_narrowed then
               if var.narrowed_from then
                  var.used = true
                  return { t = var.narrowed_from, attribute = var.attribute }, i, var.attribute
               end
            else
               if i == 1 and var.needs_compat then
                  self.all_needs_compat[name] = true
               end
               if use == "use_type" then
                  var.used_as_type = true
               elseif use ~= "check_only" then
                  var.used = true
               end
               return var, i, var.attribute
            end
         end
      end
   end

   function TypeChecker:simulate_g(): RecordType, Attribute
      -- this is a static approximation of _G
      local globals: {string:Type} = {}
      for k, v in pairs(self.st[1].vars) do
         if k:sub(1,1) ~= "@" then
            globals[k] = v.t
         end
      end
      return {
         typeid = globals_typeid,
         typename = "record",
         field_order = sorted_keys(globals),
         fields = globals,
      }, nil
   end

   local type ResolveType = function<S>(S, Type): Type
   local typevar_resolver: function<S>(s: S, typ: Type, fn_var?: ResolveType<S>, fn_arg?: ResolveType<S>): boolean, Type, {Error}

   local function fresh_typevar(_: nil, t: TypeVarType): Type, Type, boolean
      return a_type(t, "typevar", {
         typevar = (t.typevar:gsub("@.*", "")) .. "@" .. fresh_typevar_ctr,
         constraint = t.constraint,
      } as TypeVarType)
   end

   local function fresh_typearg(_: nil, t: TypeArgType): Type
      return a_type(t, "typearg", {
         typearg = (t.typearg:gsub("@.*", "")) .. "@" .. fresh_typevar_ctr,
         constraint = t.constraint,
      } as TypeArgType)
   end

   function TypeChecker:ensure_fresh_typeargs<T is Type>(t: T): T
      if not t is HasTypeArgs then
         return t
      end

      fresh_typevar_ctr = fresh_typevar_ctr + 1
      local ok: boolean
      ok, t = typevar_resolver(nil, t, fresh_typevar, fresh_typearg)
      assert(ok and t, "Internal Compiler Error: error creating fresh type variables")
      return t
   end

   function TypeChecker:find_var_type(name: string, use?: VarUse): Type, Attribute, Type
      local var = self:find_var(name, use)
      if var then
         local t = var.t
         if t is UnresolvedTypeArgType then
            return nil, nil, t.constraint
         end
         t = self:ensure_fresh_typeargs(t)
         return t, var.attribute
      end
   end

   local function ensure_not_abstract(t: Type): boolean, string
      if t is FunctionType and t.macroexp then
         return nil, "macroexps are abstract; consider using a concrete function"
      elseif t is TypeDeclType then
         local def = t.def
         if def is InterfaceType then
            return nil, "interfaces are abstract; consider using a concrete record"
         end
      end
      return true
   end

   function TypeChecker:find_type(names: {string}, accept_typearg?: boolean): Type
      local typ = self:find_var_type(names[1], "use_type")
      if not typ then
         return nil
      end
      if typ is NominalType and typ.found then
         typ = typ.found
      end
      for i = 2, #names do
         if typ is TypeDeclType then
            typ = typ.def
         end

         local fields = typ is RecordLikeType and typ.fields
         if not fields then
            return nil
         end

         typ = fields[names[i]]
         if typ == nil then
            return nil
         end

         typ = self:ensure_fresh_typeargs(typ)
         if typ is NominalType and typ.found then
            typ = typ.found
         end
      end
      if typ is TypeDeclType or typ is TypeAliasType then
         return typ
      elseif accept_typearg and typ is TypeArgType then
         return typ
      end
   end

   local function type_for_union(t: Type): string, Type
      if t is TypeDeclType then
         return type_for_union(t.def), t.def
      elseif t is TypeAliasType then
         return type_for_union(t.alias_to), t.alias_to
      elseif t is TupleType then
         return type_for_union(t.tuple[1]), t.tuple[1]
      elseif t is NominalType then
         local typedecl = t.found
         if not typedecl then
            return "invalid"
         end
         return type_for_union(typedecl)
      elseif t is RecordLikeType then
         if t.is_userdata then
            return "userdata", t
         end
         return "table", t
      elseif table_types[t.typename] then
         return "table", t
      else
         return t.typename, t
      end
   end

   local function is_valid_union(typ: UnionType): boolean, string
      -- check for limitations in our union support
      -- due to codegen limitations (we only check with type() so far)
      local n_table_types = 0
      local n_table_is_types = 0
      local n_function_types = 0
      local n_userdata_types = 0
      local n_userdata_is_types = 0
      local n_string_enum = 0
      local has_primitive_string_type = false
      for _, t in ipairs(typ.types) do
         local ut, rt = type_for_union(t)
         if ut == "userdata" then -- must be tested before table_types
            assert(rt is RecordLikeType)
            if rt.meta_fields and rt.meta_fields["__is"] then
               n_userdata_is_types = n_userdata_is_types + 1
               if n_userdata_types > 0 then
                  return false, "cannot mix userdata types with and without __is metamethod: %s"
               end
            else
               n_userdata_types = n_userdata_types + 1
               if n_userdata_types > 1 then
                  return false, "cannot discriminate a union between multiple userdata types: %s"
               end
               if n_userdata_is_types > 0 then
                  return false, "cannot mix userdata types with and without __is metamethod: %s"
               end
            end
         elseif ut == "table" then
            if rt is RecordLikeType and rt.meta_fields and rt.meta_fields["__is"] then
               n_table_is_types = n_table_is_types + 1
               if n_table_types > 0 then
                  return false, "cannot mix table types with and without __is metamethod: %s"
               end
            else
               n_table_types = n_table_types + 1
               if n_table_types > 1 then
                  return false, "cannot discriminate a union between multiple table types: %s"
               end
               if n_table_is_types > 0 then
                  return false, "cannot mix table types with and without __is metamethod: %s"
               end
            end
         elseif ut == "function" then
            n_function_types = n_function_types + 1
            if n_function_types > 1 then
               return false, "cannot discriminate a union between multiple function types: %s"
            end
         elseif ut == "enum" or (ut == "string" and not has_primitive_string_type) then
            n_string_enum = n_string_enum + 1
            if n_string_enum > 1 then
               return false, "cannot discriminate a union between multiple string/enum types: %s"
            end
            if ut == "string" then
               has_primitive_string_type = true
            end
         elseif ut == "invalid" then
            return false, nil -- error message comes from invalid type
         end
      end
      return true
   end

   local function show_arity(f: FunctionType): string
      local nfargs = #f.args.tuple
      return f.min_arity < nfargs
             and "at least " .. f.min_arity .. (f.args.is_va and "" or " and at most " .. nfargs)
             or  tostring(nfargs or 0)
   end

   local function resolve_typedecl(t: Type): Type
      if t is TypeDeclType then
         return t.def
      elseif t is TypeAliasType then
         return t.alias_to
      else
         return t
      end
   end

   local no_nested_types: {string:boolean} = {
      ["string"] = true,
      ["number"] = true,
      ["integer"] = true,
      ["boolean"] = true,
      ["thread"] = true,
      ["any"] = true,
      ["enum"] = true,
      ["nil"] = true,
      ["unknown"] = true,
   }

   typevar_resolver = function<S>(self: S, typ: Type, fn_var?: ResolveType<S>, fn_arg?: ResolveType<S>): boolean, Type, {Error}
      local errs: {Error}
      local seen: {Type:Type} = {}
      local resolved: {string:boolean} = {}
      local resolve: function<T is Type>(t: T, all_same: boolean): T, boolean

      local function copy_typeargs(t: {TypeArgType}, same: boolean): {TypeArgType}, boolean
         local copy = {}
         for i, tf in ipairs(t) do
            copy[i], same = resolve(tf, same) as (TypeArgType, boolean)
         end
         return copy, same
      end

      resolve = function<T is Type>(t: T, all_same: boolean): T, boolean
         local same = true

         -- avoid copies of types that do not contain type variables
         if no_nested_types[t.typename] or (t is NominalType and not t.typevals) then
            return t, all_same
         end

         if seen[t] then
            return seen[t], all_same
         end

         local orig_t = t
         if t is TypeVarType then
            local rt = fn_var(self, t)
            if rt then
               resolved[t.typevar] = true
               if no_nested_types[rt.typename] or (rt is NominalType and not rt.typevals) then
                  seen[orig_t] = rt
                  return rt, false
               end
               all_same = false
               t = rt
            end
         end

         local copy: Type = {}
         seen[orig_t] = copy

         copy.typename = t.typename
         copy.f = t.f
         copy.x = t.x
         copy.y = t.y

         if t is ArrayType then
            assert(copy is ArrayType)

            copy.elements, same = resolve(t.elements, same)
            -- inferred_len is not propagated
         elseif t is TypeArgType then
            if fn_arg then
               copy = fn_arg(self, t)
            else
               assert(copy is TypeArgType)
               copy.typearg = t.typearg
               if t.constraint then
                  copy.constraint, same = resolve(t.constraint, same)
               end
            end
         elseif t is UnresolvableTypeArgType then
            assert(copy is UnresolvableTypeArgType)
            copy.typearg = t.typearg
         elseif t is TypeVarType then
            assert(copy is TypeVarType)
            copy.typevar = t.typevar
            if t.constraint then
               copy.constraint, same = resolve(t.constraint, same)
            end
         elseif t is TypeDeclType then
            assert(copy is TypeDeclType)

            if t.typeargs then
               copy.typeargs, same = copy_typeargs(t.typeargs, same)
            end

            copy.def, same = resolve(t.def, same)
         elseif t is TypeAliasType then
            assert(copy is TypeAliasType)
            copy.alias_to, same = resolve(t.alias_to, same)
            copy.is_nested_alias = t.is_nested_alias
         elseif t is NominalType then
            assert(copy is NominalType)
            copy.names = t.names
            copy.typevals = {}
            for i, tf in ipairs(t.typevals) do
               copy.typevals[i], same = resolve(tf, same)
            end
            copy.found = t.found
         elseif t is FunctionType then
            assert(copy is FunctionType)

            if t.typeargs then
               copy.typeargs, same = copy_typeargs(t.typeargs, same)
            end

            copy.macroexp = t.macroexp
            copy.min_arity = t.min_arity
            copy.is_method = t.is_method
            copy.args, same = resolve(t.args, same) as (TupleType, boolean)
            copy.rets, same = resolve(t.rets, same) as (TupleType, boolean)
         elseif t is RecordLikeType then
            assert(copy is RecordType or copy is InterfaceType)
            copy.declname = t.declname

            if t.typeargs then
               copy.typeargs, same = copy_typeargs(t.typeargs, same)
            end

            -- checking array interface
            if t.elements then
               copy.elements, same = resolve(t.elements, same)
            end

            copy.is_userdata = t.is_userdata

            copy.fields = {}
            copy.field_order = {}
            for i, k in ipairs(t.field_order) do
               copy.field_order[i] = k
               copy.fields[k], same = resolve(t.fields[k], same)
            end

            if t.meta_fields then
               copy.meta_fields = {}
               copy.meta_field_order = {}
               for i, k in ipairs(t.meta_field_order) do
                  copy.meta_field_order[i] = k
                  copy.meta_fields[k], same = resolve(t.meta_fields[k], same)
               end
            end
         elseif t is MapType then
            assert(copy is MapType)
            copy.keys, same = resolve(t.keys, same)
            copy.values, same = resolve(t.values, same)
         elseif t is UnionType then
            assert(copy is UnionType)
            copy.types = {}
            for i, tf in ipairs(t.types) do
               copy.types[i], same = resolve(tf, same)
            end

            local _, err = is_valid_union(copy)
            if err then
               errs = errs or {}
               table.insert(errs, Err(err, copy))
            end
         elseif t is PolyType then
            assert(copy is PolyType)
            copy.types = {}
            for i, tf in ipairs(t.types) do
               copy.types[i], same = resolve(tf, same) as (FunctionType, boolean)
            end
         elseif t is TupleTableType then
            assert(copy is TupleTableType)
            copy.inferred_at = t.inferred_at
            copy.types = {}
            for i, tf in ipairs(t.types) do
               copy.types[i], same = resolve(tf, same)
            end
         elseif t is TupleType then
            assert(copy is TupleType)
            copy.is_va = t.is_va
            copy.tuple = {}
            for i, tf in ipairs(t.tuple) do
               copy.tuple[i], same = resolve(tf, same)
            end
         end

         copy.typeid = same and t.typeid or new_typeid()
         return copy, same and all_same
      end

      local copy, same = resolve(typ, true)
      if errs then
         return false, an_invalid(typ), errs
      end

      if (not same) and
         (copy is FunctionType or copy is RecordLikeType) and
         copy.typeargs
      then
         for i = #copy.typeargs, 1, -1 do
            if resolved[copy.typeargs[i].typearg] then
               table.remove(copy.typeargs, i)
            end
         end
         if not copy.typeargs[1] then
            copy.typeargs = nil
         end
      end
      return true, copy
   end

   local function resolve_typevar(tc: TypeChecker, t: TypeVarType): Type
      local rt = tc:find_var_type(t.typevar)
      if not rt then
         return nil
      elseif rt is StringType then
         -- tk is not propagated
         return a_type(rt, "string", {})
      end
      return rt
   end



   function TypeChecker:infer_emptytable(emptytable: EmptyTableType, fresh_t: Type)
      local is_global = (emptytable.declared_at and emptytable.declared_at.kind == "global_declaration")
      local nst = is_global and 1 or #self.st
      for i = nst, 1, -1 do
         local scope = self.st[i]
         if scope.vars[emptytable.assigned_to] then
            scope.vars[emptytable.assigned_to] = { t = fresh_t }
         end
      end
   end

   local function resolve_tuple(t: Type): Type
      local rt = t
      if rt is TupleType then
         rt = rt.tuple[1]
      end
      if rt == nil then
         return a_type(t, "nil", {})
      end
      return rt
   end


   function TypeChecker:check_if_redeclaration(new_name: string, at: Node)
      local old <const> = self:find_var(new_name, "check_only")
      if old then
         self.errs:redeclaration_warning(at, old)
      end
   end


   local function type_at<T is Type>(w: Where, t: T): T
      t.x = w.x
      t.y = w.y
      return t
   end

   function TypeChecker:resolve_typevars_at<T is Type>(w: Where, t: T): T
      assert(w)
      local ok, ret, errs = typevar_resolver(self, t, resolve_typevar)
      if not ok then
         assert(w.y)
         self.errs:add_prefixing(w, errs, "")
      end

      if ret == t or t is TypeVarType then
         ret = shallow_copy_table(ret)
      end
      return type_at(w, ret)
   end

   function TypeChecker:infer_at<T is Type>(w: Where, t: T): T
      local ret = self:resolve_typevars_at(w, t)
      if ret is InvalidType then
         ret = t -- errors are produced by resolve_typevars_at
      end

      if ret == t or t is TypeVarType then
         ret = shallow_copy_table(ret)
      end
      assert(w.f)
      ret.inferred_at = w
      return ret
   end

   local function drop_constant_value(t: Type): Type
      if t is StringType and t.literal then
         local ret = shallow_copy_table(t)
         ret.literal = nil
         return ret
      end
      return t
   end

   function TypeChecker:add_to_scope(node: Node, name: string, t: Type, attribute: Attribute, narrow: Narrow, dont_check_redeclaration: boolean): Variable
      local scope <const> = self.st[#self.st]
      local var = scope.vars[name]
      if narrow then
         if var then
            if var.is_narrowed then
               var.t = t
               return var
            end

            var.is_narrowed = narrow
            var.narrowed_from = var.t
            var.t = t
         else
            var = { t = t, attribute = attribute, is_narrowed = narrow, declared_at = node }
            scope.vars[name] = var
         end

         scope.narrows = scope.narrows or {}
         scope.narrows[name] = true

         return var
      end

      if not dont_check_redeclaration
         and node
         and name ~= "self"
         and name ~= "..."
         and name:sub(1, 1) ~= "@"
      then
         self:check_if_redeclaration(name, node)
      end

      if var and not var.used then
         -- the old var is removed from the scope and won't be checked when it closes,
         -- so check it here
         self.errs:unused_warning(name, var)
      end

      var = { t = t, attribute = attribute, is_narrowed = nil, declared_at = node }
      scope.vars[name] = var

      return var
   end

   function TypeChecker:add_var(node: Node, name: string, t: Type, attribute?: Attribute, narrow?: Narrow, dont_check_redeclaration?: boolean): Variable
      if self.feat_lax and node and is_unknown(t) and (name ~= "self" and name ~= "...") and not narrow then
         self.errs:add_unknown(node, name)
      end
      if not attribute then
         t = drop_constant_value(t)
      end

      local var = self:add_to_scope(node, name, t, attribute, narrow, dont_check_redeclaration)

      if self.collector and node then
         self.collector.add_to_symbol_list(node, name, t)
      end

      return var
   end

   local type CompareTypes = function(TypeChecker, Type, Type): boolean, {Error}

   local enum ArgCheckMode
      "argument"
      "return"
      "self"
   end

   local enum VarianceMode
      "covariant"
      "contravariant"
      "bivariant"
      "invariant"
   end

   function TypeChecker:arg_check(w: Where, all_errs: {Error}, a: Type, b: Type, v: VarianceMode, mode: ArgCheckMode, n?: integer): boolean
      local ok, errs: boolean, {Error}

      if v == "covariant" then
         ok, errs = self:is_a(a, b)
      elseif v == "contravariant" then
         ok, errs = self:is_a(b, a)
      elseif v == "bivariant" then
         ok, errs = self:is_a(a, b)
         if ok then
            return true
         end
         ok = self:is_a(b, a)
         if ok then
            return true
         end
      elseif v == "invariant" then
         ok, errs = self:same_type(a, b)
      end

      if not ok then
         self.errs:add_prefixing(w, errs, mode .. (n and " " .. n or "") .. ": ", all_errs)
         return false
      end
      return true
   end

   function TypeChecker:has_all_types_of(t1s: {Type}, t2s: {Type}): boolean
      for _, t1 in ipairs(t1s) do
         local found = false
         for _, t2 in ipairs(t2s) do
            if self:same_type(t2, t1) then
               found = true
               break
            end
         end
         if not found then
            return false
         end
      end
      return true
   end

   local function any_errors(all_errs: {Error}): boolean, {Error}
      if #all_errs == 0 then
         return true
      else
         return false, all_errs
      end
   end

   local function close_nested_records(t: RecordLikeType)
      for _, ft in pairs(t.fields) do
         if ft is TypeDeclType then
            ft.closed = true
            local def = ft.def
            if def is RecordLikeType then
               close_nested_records(def)
            end
         end
      end
   end

   local function close_types(scope: Scope)
      for _, var in pairs(scope.vars) do
         local t = var.t
         if t is TypeDeclType then
            t.closed = true
            local def = t.def
            if def is RecordLikeType then
               close_nested_records(def)
            end
         end
      end
   end

   function TypeChecker:begin_scope(node?: Node)
      table.insert(self.st, { vars = {} })

      if self.collector and node then
         self.collector.begin_symbol_list_scope(node)
      end
   end

   function TypeChecker:end_scope(node?: Node)
      local st = self.st
      local scope = st[#st]
      local next_scope = st[#st - 1]

      if next_scope then
         if scope.pending_labels then
            next_scope.pending_labels = next_scope.pending_labels or {}
            for name, nodes in pairs(scope.pending_labels) do
               for _, n in ipairs(nodes) do
                  next_scope.pending_labels[name] = next_scope.pending_labels[name] or {}
                  table.insert(next_scope.pending_labels[name], n)
               end
            end
            scope.pending_labels = nil
         end
         if scope.pending_nominals then
            next_scope.pending_nominals = next_scope.pending_nominals or {}
            for name, types in pairs(scope.pending_nominals) do
               for _, typ in ipairs(types) do
                  next_scope.pending_nominals[name] = next_scope.pending_nominals[name] or {}
                  table.insert(next_scope.pending_nominals[name], typ)
               end
            end
            scope.pending_nominals = nil
         end
      end

      close_types(scope)
      self.errs:warn_unused_vars(scope)

      table.remove(st)

      if self.collector and node then
         self.collector.end_symbol_list_scope(node)
      end
   end

   -- This type must never be used for any values
   local NONE = a_type({ f = "@none", x = -1, y = -1 }, "none", {})

   local function end_scope_and_none_type(self: TypeChecker, node: Node, _children: {Type}): Type
      self:end_scope(node)
      return NONE
   end

   local type InvalidOrTypeDeclType = InvalidType | TypeDeclType

   do
      local function match_typevals(self: TypeChecker, t: NominalType, def: RecordLikeType | FunctionType): Type
         if t.typevals and def.typeargs then
            if #t.typevals ~= #def.typeargs then
               self.errs:add(t, "mismatch in number of type arguments")
               return nil
            end

            self:begin_scope()
            for i, tt in ipairs(t.typevals) do
               self:add_var(nil, def.typeargs[i].typearg, tt)
            end
            local ret = self:resolve_typevars_at(t, def)
            self:end_scope()
            return ret
         elseif t.typevals then
            self.errs:add(t, "spurious type arguments")
            return nil
         elseif def.typeargs then
            self.errs:add(t, "missing type arguments in %s", def)
            return nil
         else
            return def
         end
      end

      local function find_nominal_type_decl(self: TypeChecker, t: NominalType): Type, TypeDeclType
         if t.resolved then
            return t.resolved
         end

         local found = t.found or self:find_type(t.names)
         if not found then
            return self.errs:invalid_at(t, "unknown type %s", t)
         end

         if found is TypeAliasType then
            found = found.alias_to.found
         end

         if not found then
            return self.errs:invalid_at(t, table.concat(t.names, ".") .. " is not a resolved type")
         end

         if not found is TypeDeclType then
            return self.errs:invalid_at(t, table.concat(t.names, ".") .. " is not a type")
         end

         local def = found.def
         if def.typename == "circular_require" then
            -- return, but do not store resolution
            return def
         end

         assert(not def is NominalType)

         t.found = found

         return nil, found
      end

      local function resolve_decl_into_nominal(self: TypeChecker, t: NominalType, found: TypeDeclType): Type
         local def = found.def
         local resolved: Type
         if def is RecordLikeType or def is FunctionType then
            resolved = match_typevals(self, t, def)
            if not resolved then
               return self.errs:invalid_at(t, table.concat(t.names, ".") .. " cannot be resolved in scope")
            end
         else
            resolved = def
         end

         t.resolved = resolved
         return resolved
      end

      function TypeChecker:resolve_nominal(t: NominalType): Type
         local immediate, found = find_nominal_type_decl(self, t)
         if immediate then
            return immediate
         end

         return resolve_decl_into_nominal(self, t, found)
      end

      function TypeChecker:resolve_typealias(typealias: TypeAliasType): InvalidOrTypeDeclType
         local t = typealias.alias_to

         local immediate, found = find_nominal_type_decl(self, t)
         if immediate is InvalidOrTypeDeclType then
            return immediate
         end

         if not t.typevals then
            return found
         end

         local resolved = resolve_decl_into_nominal(self, t, found)

         local typedecl = a_type(typealias, "typedecl", { def = resolved } as TypeDeclType)
         t.resolved = typedecl
         return typedecl
      end
   end

   do
      local function are_same_unresolved_global_type(self: TypeChecker, t1: NominalType, t2: NominalType): boolean
         if t1.names[1] == t2.names[1] then
            local global_scope = self.st[1]
            if global_scope.pending_global_types[t1.names[1]] then
               return true
            end
         end
         return false
      end

      local function fail_nominals(self: TypeChecker, t1: NominalType, t2: NominalType): boolean, {Error}
         local t1name = show_type(t1)
         local t2name = show_type(t2)
         if t1name == t2name then
            self:resolve_nominal(t1)
            if t1.found then
               t1name = t1name .. " (defined in " .. t1.found.f .. ":" .. t1.found.y .. ")"
            end
            self:resolve_nominal(t2)
            if t2.found then
               t2name = t2name .. " (defined in " .. t2.found.f .. ":" .. t2.found.y .. ")"
            end
         end
         return false, { Err(t1name .. " is not a " .. t2name) }
      end

      function TypeChecker:are_same_nominals(t1: NominalType, t2: NominalType): boolean, {Error}
         local same_names: boolean
         if t1.found and t2.found then
            same_names = t1.found.typeid == t2.found.typeid
         else
            local ft1 = t1.found or self:find_type(t1.names)
            local ft2 = t2.found or self:find_type(t2.names)
            if ft1 and ft2 then
               same_names = ft1.typeid == ft2.typeid
            else
               if are_same_unresolved_global_type(self, t1, t2) then
                  return true
               end

               if not ft1 then
                  self.errs:add(t1, "unknown type %s", t1)
               end
               if not ft2 then
                  self.errs:add(t2, "unknown type %s", t2)
               end
               return false, {} -- errors were already produced
            end
         end

         if not same_names then
            return fail_nominals(self, t1, t2)
         elseif t1.typevals == nil and t2.typevals == nil then
            return true
         elseif t1.typevals and t2.typevals and #t1.typevals == #t2.typevals then
            local errs = {}
            for i = 1, #t1.typevals do
               local _, typeval_errs = self:same_type(t1.typevals[i], t2.typevals[i])
               self.errs:add_prefixing(nil, typeval_errs, "type parameter <" .. show_type(t2.typevals[i]) .. ">: ", errs)
            end
            return any_errors(errs)
         end
         return true
      end
   end

   local is_lua_table_type: function(t: Type): boolean

   function TypeChecker:to_structural(t: Type): Type
      assert(not t is TupleType)
      if t is NominalType then
         return self:resolve_nominal(t)
      end
      return t
   end

   local function unite(w: Where, types: {Type}, flatten_constants?: boolean): Type
      if #types == 1 then
         return types[1]
      end

      local ts: {Type} = {}
      local stack: {Type} = {}

      -- Make things like number | number resolve to number
      local types_seen: {(integer|string):boolean} = {}
      -- but never add nil as a type in the union
      types_seen["nil"] = true

      local i = 1
      while types[i] or stack[1] do
         local t: Type
         if stack[1] then
            t = table.remove(stack)
         else
            t = types[i]
            i = i + 1
         end
         t = resolve_tuple(t)
         if t is UnionType then
            for _, s in ipairs(t.types) do
               table.insert(stack, s)
            end
         else
            if primitive[t.typename] and (flatten_constants or (t is StringType and not t.literal)) then
               if not types_seen[t.typename] then
                  types_seen[t.typename] = true
                  table.insert(ts, t)
               end
            else
               local typeid = t.typeid
               if t is NominalType and t.found then
                  typeid = t.found.typeid
               end
               if not types_seen[typeid] then
                  types_seen[typeid] = true
                  table.insert(ts, t)
               end
            end
         end
      end

      if types_seen["invalid"] then
         return a_type(w, "invalid", {})
      end

      if #ts == 1 then
         return ts[1]
      else
         return a_union(w, ts)
      end
   end

   do
      local known_table_types: {TypeName:boolean} = {
         array = true,
         map = true,
         record = true,
         tupletable = true,
         interface = true,
      }

      -- Is the type represented concretely as a Lua table?
      is_lua_table_type = function(t: Type): boolean
         return known_table_types[t.typename]
                and not (t is RecordLikeType and t.is_userdata)
      end
   end

   function TypeChecker:arraytype_from_tuple(w: Where, tupletype: TupleTableType): ArrayType, {Error}
      -- first just try a basic union
      local element_type = unite(w, tupletype.types, true)
      local valid = (not element_type is UnionType) and true or is_valid_union(element_type)
      if valid then
         return an_array(w, element_type)
      end

      -- failing a basic union, expand the types
      local arr_type = an_array(w, tupletype.types[1])
      for i = 2, #tupletype.types do
         local expanded = self:expand_type(w, arr_type, an_array(w, tupletype.types[i]))
         if not expanded is ArrayType then
            return nil, { Err("unable to convert tuple %s to array", tupletype) }
         end
         arr_type = expanded
      end
      return arr_type
   end

   local function is_self(t: Type): boolean
      return t is NominalType and t.names[1] == "@self"
   end

   local function compare_true(_: TypeChecker, _: Type, _: Type): boolean, {Error}
      return true
   end

   function TypeChecker:subtype_nominal(a: Type, b: Type): boolean, {Error}
      if is_self(a) and is_self(b) then
         return true
      end

      local ra = a is NominalType and self:resolve_nominal(a) or a
      local rb = b is NominalType and self:resolve_nominal(b) or b
      local ok, errs = self:is_a(ra, rb)
      if errs and #errs == 1 and errs[1].msg:match("^got ") then
         return false -- translate to got-expected error with unresolved types
      end
      return ok, errs
   end

   function TypeChecker:subtype_array(a: ArrayLikeType, b: ArrayLikeType): boolean, {Error}
      if (not a.elements) or (not self:is_a(a.elements, b.elements)) then
         return false
      end
      if a.consttypes and #a.consttypes > 1 then
         -- constant array, check elements (useful for array of enums)
         for _, e in ipairs(a.consttypes) do
            if not self:is_a(e, b.elements) then
               return false, { Err("%s is not a member of %s", e, b.elements) }
            end
         end
      end
      return true
   end

   local function find_in_interface_list<T>(a: RecordLikeType, f: function(Type): T): T
      if not a.interface_list then
         return nil
      end

      for _, t in ipairs(a.interface_list) do
         local ret = f(t)
         if ret then
            return ret
         end
      end

      return nil
   end

   function TypeChecker:subtype_record(a: RecordLikeType, b: RecordLikeType): boolean, {Error}
      -- assert(b.typename == "record")
      if a.elements and b.elements then
         if not self:is_a(a.elements, b.elements) then
            return false, { Err("array parts have incompatible element types") }
         end
      end

      if a.is_userdata ~= b.is_userdata then
         return false, { Err(a.is_userdata and "userdata is not a record"
                                              or  "record is not a userdata") }
      end

      local errs: {Error} = {}
      for _, k in ipairs(a.field_order) do
         local ak = a.fields[k]
         local bk = b.fields[k]
         if bk then
            local ok, fielderrs = self:is_a(ak, bk)
            if not ok then
               self.errs:add_prefixing(nil, fielderrs, "record field doesn't match: " .. k .. ": ", errs)
            end
         end
      end
      if #errs > 0 then
         for _, err in ipairs(errs) do
            err.msg = show_type(a) .. " is not a " .. show_type(b) .. ": " .. err.msg
         end
         return false, errs
      end

      return true
   end

   function TypeChecker:eqtype_record(a: RecordType, b: RecordType): boolean, {Error}
      -- checking array interface
      if (a.elements ~= nil) ~= (b.elements ~= nil) then
         return false, { Err("types do not have the same array interface") }
      end
      if a.elements then
         local ok, errs = self:same_type(a.elements, b.elements)
         if not ok then
            return ok, errs
         end
      end

      local ok, errs = self:subtype_record(a, b)
      if not ok then
         return ok, errs
      end
      ok, errs = self:subtype_record(b, a)
      if not ok then
         return ok, errs
      end
      return true
   end

   local function compare_map(self: TypeChecker, ak: Type, bk: Type, av: Type, bv: Type, no_hack?: boolean): boolean, {Error}
      local ok1, errs_k = self:same_type(ak, bk)
      local ok2, errs_v = self:same_type(av, bv)

      -- FIXME hack for {any:any}
      if bk.typename == "any" and not no_hack then
         ok1, errs_k = true, nil
      end
      if bv.typename == "any" and not no_hack then
         ok2, errs_v = true, nil
      end

      if ok1 and ok2 then
         return true
      end

      -- combine errs_k and errs_v, prefixing errors
      for i = 1, errs_k and #errs_k or 0 do
         errs_k[i].msg = "in map key: " .. errs_k[i].msg
      end
      for i = 1, errs_v and #errs_v or 0 do
         errs_v[i].msg = "in map value: " .. errs_v[i].msg
      end
      if errs_k and errs_v then
         for i = 1, #errs_v do
            table.insert(errs_k, errs_v[i])
         end
         return false, errs_k
      end
      return false, errs_k or errs_v
   end

   function TypeChecker:compare_or_infer_typevar(typevar: string, a: Type, b: Type, cmp: CompareTypes): boolean, {Error}
      -- assert((a == nil and b ~= nil) or (a ~= nil and b == nil))

      -- does the typevar currently match to a type?
      local vt, _, constraint = self:find_var_type(typevar)
      if vt then
         -- If so, compare it to the other type
         return cmp(self, a or vt, b or vt)
      else
         -- otherwise, infer it to the other type
         local other = a or b

         -- but check interface constraint first if present
         if constraint then
            if not self:is_a(other, constraint) then
               return false, { Err("given type %s does not satisfy %s constraint in type variable " .. display_typevar(typevar), other, constraint) }
            end

            if self:same_type(other, constraint) then
               -- do not infer to some type as constraint right away,
               -- to give a chance to more specific inferences
               -- in other arguments/returns
               return true
            end
         end

         local ok, r, errs = typevar_resolver(self, other, resolve_typevar)
         if not ok then
            return false, errs
         end
         if r is TypeVarType and r.typevar == typevar then
            return true
         end
         self:add_var(nil, typevar, r)
         return true
      end
   end

   -- ∃ x ∈ xs. t <: x
   function TypeChecker:exists_supertype_in(t: Type, xs: AggregateType): Type
      for _, x in ipairs(xs.types) do
         if self:is_a(t, x) then
            return x
         end
      end
   end

   -- ∀ x ∈ xs, x <: t
   function TypeChecker:forall_are_subtype_of(xs: AggregateType, t: Type): boolean
      for _, x in ipairs(xs.types) do
         if not self:is_a(x, t) then
            return false
         end
      end
      return true
   end

   -- emptytable rules are the same in eqtype_relations and subtype_relations
   local emptytable_relations: {TypeName:CompareTypes} = {
      ["array"] = compare_true,
      ["map"] = compare_true,
      ["tupletable"] = compare_true,
      ["interface"] = function(_self: TypeChecker, _a: Type, b: InterfaceType): boolean, {Error}
         return not b.is_userdata
      end,
      ["record"] = function(_self: TypeChecker, _a: Type, b: RecordType): boolean, {Error}
         return not b.is_userdata
      end,
   }

   TypeChecker.eqtype_relations = {
      ["typevar"] = {
         ["typevar"] = function(self: TypeChecker, a: TypeVarType, b: TypeVarType): boolean, {Error}
            if a.typevar == b.typevar then
               return true
            end

            return self:compare_or_infer_typevar(b.typevar, a, nil, self.same_type)
         end,
         ["*"] = function(self: TypeChecker, a: TypeVarType, b: Type): boolean, {Error}
            return self:compare_or_infer_typevar(a.typevar, nil, b, self.same_type)
         end,
      },
      ["emptytable"] = emptytable_relations,
      ["tupletable"] = {
         ["tupletable"] = function(self: TypeChecker, a: TupleTableType, b: TupleTableType): boolean, {Error}
            for i = 1, math.min(#a.types, #b.types) do
               if not self:same_type(a.types[i], b.types[i]) then
                  return false, { Err("in tuple entry " .. tostring(i) .. ": got %s, expected %s", a.types[i], b.types[i]) }
               end
            end
            if #a.types ~= #b.types then
               return false, { Err("tuples have different size", a, b) }
            end
            return true
         end,
      },
      ["array"] = {
         ["array"] = function(self: TypeChecker, a: ArrayType, b: ArrayType): boolean, {Error}
            return self:same_type(a.elements, b.elements)
         end,
      },
      ["map"] = {
         ["map"] = function(self: TypeChecker, a: MapType, b: MapType): boolean, {Error}
            return compare_map(self, a.keys, b.keys, a.values, b.values, true)
         end,
      },
      ["union"] = {
         ["union"] = function(self: TypeChecker, a: UnionType, b: UnionType): boolean, {Error}
            return (self:has_all_types_of(a.types, b.types)
                and self:has_all_types_of(b.types, a.types))
         end,
      },
      ["nominal"] = {
         ["nominal"] = TypeChecker.are_same_nominals,
      },
      ["record"] = {
         ["record"] = TypeChecker.eqtype_record,
      },
      ["interface"] = {
         ["interface"] = function(_self:TypeChecker, a: InterfaceType, b: InterfaceType): boolean, {Error}
            return a.typeid == b.typeid
         end,
      },
      ["function"] = {
         ["function"] = function(self:TypeChecker, a: FunctionType, b: FunctionType): boolean, {Error}
            local argdelta = a.is_method and 1 or 0
            local naargs, nbargs = #a.args.tuple, #b.args.tuple
            if naargs ~= nbargs then
               if (not not a.is_method) ~= (not not b.is_method) then
                  return false, { Err("different number of input arguments: method and non-method are not the same type") }
               end
               return false, { Err("different number of input arguments: got " .. naargs - argdelta .. ", expected " .. nbargs - argdelta) }
            end
            local narets, nbrets = #a.rets.tuple, #b.rets.tuple
            if narets ~= nbrets then
               return false, { Err("different number of return values: got " .. narets .. ", expected " .. nbrets) }
            end
            local errs = {}
            for i = 1, naargs do
               self:arg_check(a, errs, a.args.tuple[i], b.args.tuple[i], "invariant", "argument", i - argdelta)
            end
            for i = 1, narets do
               self:arg_check(a, errs, a.rets.tuple[i], b.rets.tuple[i], "invariant", "return", i)
            end
            return any_errors(errs)
         end,
      },
      ["*"] = {
         ["typevar"] = function(self: TypeChecker, a: Type, b: TypeVarType): boolean, {Error}
            return self:compare_or_infer_typevar(b.typevar, a, nil, self.same_type)
         end,
      },
   }

   TypeChecker.subtype_relations = {
      ["tuple"] = {
         ["tuple"] = function(self: TypeChecker, a: TupleType, b: TupleType): boolean, {Error}  -- ∀ a[i] ∈ a, b[i] ∈ b. a[i] <: b[i]
            local at, bt = a.tuple, b.tuple                                  -- ──────────────────────────────────
            if #at ~= #bt then                                               --        a tuple <: b tuple
               return false
            end
            for i = 1, #at do
               if not self:is_a(at[i], bt[i]) then
                  return false
               end
            end
            return true
         end,
         ["*"] = function(self: TypeChecker, a: Type, b: Type): boolean, {Error}
            return self:is_a(resolve_tuple(a), b)
         end,
      },
      ["typevar"] = {
         ["typevar"] = function(self: TypeChecker, a: TypeVarType, b: TypeVarType): boolean, {Error}
            if a.typevar == b.typevar then
               return true
            end

            return self:compare_or_infer_typevar(b.typevar, a, nil, self.is_a)
         end,
         ["*"] = function(self: TypeChecker, a: TypeVarType, b: Type): boolean, {Error}
            return self:compare_or_infer_typevar(a.typevar, nil, b, self.is_a)
         end,
      },
      ["nil"] = {
         ["*"] = compare_true,
      },
      ["union"] = {
         ["nominal"] = function(self: TypeChecker, a: UnionType, b: NominalType): boolean, {Error}
            -- match unions structurally
            local rb = self:resolve_nominal(b)
            if rb.typename == "union" then
               return self:is_a(a, rb)
            end

            return self:forall_are_subtype_of(a, b)
         end,
         ["union"] = function(self: TypeChecker, a: UnionType, b: UnionType): boolean, {Error} -- ∀ t ∈ a. ∃ u ∈ b. t <: u
            local used = {}                                                 -- ────────────────────────
            for _, t in ipairs(a.types) do                                  --    a union <: b union
               self:begin_scope()
               local u = self:exists_supertype_in(t, b)
               self:end_scope() -- don't preserve failed inferences
               if not u then
                  return false
               end
               if not used[u] then -- FIXME the order of declared union items affects inference behavior
                  used[u] = t
               end
            end
            for u, t in pairs(used) do
               self:is_a(t, u) -- preserve valid inferences
            end
            return true
         end,
         ["*"] = TypeChecker.forall_are_subtype_of as CompareTypes,
      },
      ["poly"] = {
         ["*"] = function(self: TypeChecker, a: PolyType, b: Type): boolean, {Error}    -- ∃ t ∈ a, t <: b
            if self:exists_supertype_in(b, a) then                                      -- ───────────────
               return true                                                              --   a poly <: b
            end
            return false, { Err("cannot match against any alternatives of the polymorphic type") }
         end,
      },
      ["nominal"] = {
         ["nominal"] = function(self: TypeChecker, a: NominalType, b: NominalType): boolean, {Error}
            local ok, errs = self:are_same_nominals(a, b)
            if ok then
               return true
            end

            -- match unions structurally
            local ra = self:resolve_nominal(a)
            local rb = self:resolve_nominal(b)
            if ra is UnionType and rb is UnionType then
               return self:is_a(ra, rb)
            end
            if ra is UnionType then
               return self:is_a(ra, b)
            end
            if rb is UnionType then
               return self:is_a(a, rb)
            end

            -- match interface subtyping
            if rb is InterfaceType then
               return self:is_a(a, rb)
            end

            -- all other types nominally
            return ok, errs
         end,
         ["union"] = function(self: TypeChecker, a: NominalType, b: UnionType): boolean, {Error}
            -- match unions structurally
            local ra = self:resolve_nominal(a)
            if ra.typename == "union" then
               return self:is_a(ra, b)
            end

            return not not self:exists_supertype_in(a, b)
         end,
         ["*"] = TypeChecker.subtype_nominal,
      },
      ["enum"] = {
         ["string"] = compare_true,
      },
      ["string"] = {
         ["enum"] = function(_self: TypeChecker, a: StringType, b: EnumType): boolean, {Error}
            if not a.literal then
               return false, { Err("%s is not a %s", a, b) }
            end

            if b.enumset[a.literal] then
               return true
            end

            return false, { Err("%s is not a member of %s", a, b) }
         end,
      },
      ["integer"] = {
         ["number"] = compare_true,
      },
      ["interface"] = {
         ["interface"] = function(self: TypeChecker, a: InterfaceType, b: InterfaceType): boolean, {Error}
            if find_in_interface_list(a, function(t: Type): boolean return (self:is_a(t, b)) end) then
               return true
            end
            return self:same_type(a, b)
         end,
         ["array"] = TypeChecker.subtype_array,
         ["record"] = TypeChecker.subtype_record,
         ["tupletable"] = function(self: TypeChecker, a: Type, b: Type): boolean, {Error}
            return self.subtype_relations["record"]["tupletable"](self, a, b)
         end,
      },
      ["emptytable"] = emptytable_relations,
      ["tupletable"] = {
         ["tupletable"] = function(self: TypeChecker, a: TupleTableType, b: TupleTableType): boolean, {Error}
            for i = 1, math.min(#a.types, #b.types) do
               if not self:is_a(a.types[i], b.types[i]) then
                  return false, { Err("in tuple entry "
                     .. tostring(i) .. ": got %s, expected %s",
                     a.types[i], b.types[i]) }
               end
            end
            if #a.types > #b.types then
               return false, { Err("tuple %s is too big for tuple %s", a, b) }
            end
            return true
         end,
         ["record"] = function(self: TypeChecker, a: Type, b: RecordType): boolean, {Error}
            if b.elements then
               return self.subtype_relations["tupletable"]["array"](self, a, b)
            end
         end,
         ["array"] = function(self: TypeChecker, a: TupleTableType, b: ArrayType): boolean, {Error}
            if b.inferred_len and b.inferred_len > #a.types then
               return false, { Err("incompatible length, expected maximum length of " .. tostring(#a.types) .. ", got " .. tostring(b.inferred_len)) }
            end
            local aa, err = self:arraytype_from_tuple(a.inferred_at or a, a)
            if not aa then
               return false, err
            end
            if not self:is_a(aa, b) then
               return false, { Err("got %s (from %s), expected %s", aa, a, b) }
            end
            return true
         end,
         ["map"] = function(self: TypeChecker, a: TupleTableType, b: MapType): boolean, {Error}
            local aa = self:arraytype_from_tuple(a.inferred_at or a, a)
            if not aa then
               return false, { Err("Unable to convert tuple %s to map", a) }
            end

            return compare_map(self, a_type(a, "integer", {}), b.keys, aa.elements, b.values)
         end,
      },
      ["record"] = {
         ["record"] = TypeChecker.subtype_record,
         ["interface"] = function(self: TypeChecker, a: RecordType, b: InterfaceType): boolean, {Error}
            if find_in_interface_list(a, function(t: Type): boolean return (self:is_a(t, b)) end) then
               return true
            end
            if not a.declname then
               -- match inferred table (anonymous record) structurally to interface
               return self:subtype_record(a, b)
            end
         end,
         ["array"] = TypeChecker.subtype_array,
         ["map"] = function(self: TypeChecker, a: RecordType, b: MapType): boolean, {Error}
            if not self:is_a(b.keys, a_type(b, "string", {})) then
               return false, { Err("can't match a record to a map with non-string keys") }
            end

            for _, k in ipairs(a.field_order) do
               local bk = b.keys
               if bk is EnumType and not bk.enumset[k] then
                  return false, { Err("key is not an enum value: " .. k) }
               end
               if not self:is_a(a.fields[k], b.values) then
                  return false, { Err("record is not a valid map; not all fields have the same type") }
               end
            end

            return true
         end,
         ["tupletable"] = function(self: TypeChecker, a: RecordType, b: Type): boolean, {Error}
            if a.elements then
               return self.subtype_relations["array"]["tupletable"](self, a, b)
            end
         end,
      },
      ["array"] = {
         ["array"] = TypeChecker.subtype_array,
         ["record"] = function(self: TypeChecker, a: ArrayType, b: RecordType): boolean, {Error}
            if b.elements then
               return self:subtype_array(a, b)
            end
         end,
         ["map"] = function(self: TypeChecker, a: ArrayType, b: MapType): boolean, {Error}
            return compare_map(self, a_type(a, "integer", {}), b.keys, a.elements, b.values)
         end,
         ["tupletable"] = function(self: TypeChecker, a: ArrayType, b: TupleTableType): boolean, {Error}
            local alen = a.inferred_len or 0
            if alen > #b.types then
               return false, { Err("incompatible length, expected maximum length of " .. tostring(#b.types) .. ", got " .. tostring(alen)) }
            end

            -- for array literals (which is the only case where inferred_len is defined),
            -- only check the entries that are present
            for i = 1, (alen > 0) and alen or #b.types do
               if not self:is_a(a.elements, b.types[i]) then
                  return false, { Err("tuple entry " .. i .. " of type %s does not match type of array elements, which is %s", b.types[i], a.elements) }
               end
            end
            return true
         end,
      },
      ["map"] = {
         ["map"] = function(self: TypeChecker, a: MapType, b: MapType): boolean, {Error}
            return compare_map(self, a.keys, b.keys, a.values, b.values)
         end,
         ["array"] = function(self: TypeChecker, a: MapType, b: ArrayType): boolean, {Error}
            return compare_map(self, a.keys, a_type(b, "integer", {}), a.values, b.elements)
         end,
      },
      ["typedecl"] = {
         ["record"] = function(self: TypeChecker, a: TypeDeclType, b: RecordType): boolean, {Error}
            local def = a.def
            if def is RecordLikeType then
               return self:subtype_record(def, b) -- record as prototype
            end
         end,
      },
      ["function"] = {
         ["function"] = function(self: TypeChecker, a: FunctionType, b: FunctionType): boolean, {Error}
            local errs = {}

            local aa, ba = a.args.tuple, b.args.tuple
            if (not b.args.is_va) and a.min_arity > b.min_arity then
               table.insert(errs, Err("incompatible number of arguments: got " .. show_arity(a) .. " %s, expected " .. show_arity(b) .. " %s", a.args, b.args))
            else
               for i = ((a.is_method or b.is_method) and 2 or 1), #aa do
                  self:arg_check(nil, errs, aa[i], ba[i] or ba[#ba], "bivariant", "argument", i)
               end
            end

            local ar, br = a.rets.tuple, b.rets.tuple
            local diff_by_va = #br - #ar == 1 and b.rets.is_va
            if #ar < #br and not diff_by_va then
               table.insert(errs, Err("incompatible number of returns: got " .. #ar .. " %s, expected " .. #br .. " %s", a.rets, b.rets))
            else
               local nrets = #br
               if diff_by_va then
                  nrets = nrets - 1
               end
               for i = 1, nrets do
                  self:arg_check(nil, errs, ar[i], br[i], "bivariant", "return", i)
               end
            end

            return any_errors(errs)
         end,
      },
      ["typearg"] = {
         ["typearg"] = function(_self: TypeChecker, a: TypeArgType, b: TypeArgType): boolean, {Error}
            return a.typearg == b.typearg
         end,
         ["*"] = function(self: TypeChecker, a: TypeArgType, b: Type): boolean, {Error}
            if a.constraint then
               return self:is_a(a.constraint, b)
            end
         end,
      },
      ["*"] = {
         ["any"] = compare_true,
         ["tuple"] = function(self: TypeChecker, a: Type, b: Type): boolean, {Error}
            return self:is_a(a_tuple(a, {a}), b)
         end,
         ["typevar"] = function(self: TypeChecker, a: Type, b: TypeVarType): boolean, {Error}
            return self:compare_or_infer_typevar(b.typevar, a, nil, self.is_a)
         end,
         ["typearg"] = function(self: TypeChecker, a: Type, b: TypeArgType): boolean, {Error}
            if b.constraint then
               return self:is_a(a, b.constraint)
            end
         end,
         ["union"] = TypeChecker.exists_supertype_in as CompareTypes,                   -- ∃ t ∈ b, a <: t
                                                                                        -- ───────────────
                                                                                        --  a <: b union
         ["nominal"] = TypeChecker.subtype_nominal,
         ["poly"] = function(self: TypeChecker, a: Type, b: PolyType): boolean, {Error} -- ∀ t ∈ b, a <: t
            for _, t in ipairs(b.types) do                                              -- ───────────────
               if not self:is_a(a, t) then                                              --   a <: b poly
                  return false, { Err("cannot match against all alternatives of the polymorphic type") }
               end
            end
            return true
         end,
      },
   }

   -- evaluation strategy
   TypeChecker.type_priorities = {
      -- types that have catch-all rules evaluate first
      ["tuple"] = 2,
      ["typevar"] = 3,
      ["nil"] = 4,
      ["any"] = 5,
      ["union"] = 6,
      ["poly"] = 7,
      -- then typeargs
      ["typearg"] = 8,
      -- then nominals
      ["nominal"] = 9,
      -- then base types
      ["enum"] = 10,
      ["string"] = 10,
      ["integer"] = 10,
      ["boolean"] = 10,
      -- then interfaces
      ["interface"] = 11,
      -- then special cases of tables
      ["emptytable"] = 12,
      ["tupletable"] = 13,
      -- then other recursive types
      ["record"] = 14,
      ["array"] = 14,
      ["map"] = 14,
      ["function"] = 14,
   }

   local function compare_types(self: TypeChecker, relations: TypeRelations, t1: Type, t2: Type): boolean, {Error}
      if t1.typeid == t2.typeid then
         return true
      end

      local s1 = relations[t1.typename]
      local fn = s1 and s1[t2.typename]
      if not fn then
         local p1 = self.type_priorities[t1.typename] or 999
         local p2 = self.type_priorities[t2.typename] or 999
         fn = (p1 < p2 and (s1 and s1["*"]) or (relations["*"][t2.typename]))
      end

      local ok, err: boolean, {Error}
      if fn then
         if fn == compare_true then
            return true
         end
         ok, err = fn(self, t1, t2)
      else
         ok = t1.typename == t2.typename
      end

      if (not ok) and not err then
         return false, { Err("got %s, expected %s", t1, t2) }
      end
      return ok, err
   end

   -- subtyping comparison
   function TypeChecker:is_a(t1: Type, t2: Type): boolean, {Error}
      return compare_types(self, self.subtype_relations, t1, t2)
   end

   -- invariant type comparison
   function TypeChecker:same_type(t1: Type, t2: Type): boolean, {Error}
      -- except for error messages, behavior is the same as
      -- `return (is_a(t1, t2) and self:is_a(t2, t1))`
      return compare_types(self, self.eqtype_relations, t1, t2)
   end

   if TL_DEBUG then
      local orig_is_a = TypeChecker.is_a
      TypeChecker.is_a = function(self: TypeChecker, t1: Type, t2: Type): boolean, {Error}
         assert(type(t1) == "table")
         assert(type(t2) == "table")

         if t1.typeid == t2.typeid then
            local st1, st2 = show_type_base(t1, false, {}), show_type_base(t2, false, {})
            assert(st1 == st2, st1 .. " ~= " .. st2)
            return true
         end

         return orig_is_a(self, t1, t2)
      end
   end

   function TypeChecker:assert_is_a(w: Where, t1: Type, t2: Type, ctx?: string | Node, name?: string): boolean
      t1 = resolve_tuple(t1)
      t2 = resolve_tuple(t2)
      if self.feat_lax and (is_unknown(t1) or t2 is UnknownType) then
         return true
      end

      -- some flow-based inference
      if t1.typename == "nil" then
         return true
      elseif t2 is UnresolvedEmptyTableValueType then
         local t2keys = t2.emptytable_type.keys
         if t2keys is NumericType then -- ideally integer only
            self:infer_emptytable(t2.emptytable_type, self:infer_at(w, an_array(w, t1)))
         else
            self:infer_emptytable(t2.emptytable_type, self:infer_at(w, a_map(w, t2keys, t1)))
         end
         return true
      elseif t2 is EmptyTableType then
         if is_lua_table_type(t1) then
            self:infer_emptytable(t2, self:infer_at(w, t1))
         elseif not t1 is EmptyTableType then
            self.errs:add(w, self.errs:get_context(ctx, name) .. "assigning %s to a variable declared with {}", t1)
            return false
         end
         return true
      end

      local ok, match_errs = self:is_a(t1, t2)
      if not ok then
         self.errs:add_prefixing(w, match_errs, self.errs:get_context(ctx, name))
      end
      return ok
   end

   local function type_is_closable(t: Type): boolean
      if t is InvalidType then
         return false
      end
      if t.typename == "nil" then
         return true
      end
      if t is NominalType then
         t = assert(t.resolved)
      end
      if t is RecordLikeType then
         return t.meta_fields and t.meta_fields["__close"] ~= nil
      end
   end

   local definitely_not_closable_exprs <const>: {NodeKind:boolean} = {
      ["string"] = true,
      ["number"] = true,
      ["integer"] = true,
      ["boolean"] = true,
      ["literal_table"] = true,
   }
   local function expr_is_definitely_not_closable(e: Node): boolean
      return definitely_not_closable_exprs[e.kind]
   end

   function TypeChecker:same_in_all_union_entries(u: UnionType, check: function(Type): (Type, Type)): Type
      local t1, f = check(u.types[1])
      if not t1 then
         return nil
      end
      for i = 2, #u.types do
         local t2 = check(u.types[i])
         if not t2 or not self:same_type(t1, t2) then
            return nil
         end
      end
      return f or t1
   end

   function TypeChecker:same_call_mt_in_all_union_entries(u: UnionType): Type
      return self:same_in_all_union_entries(u, function(t: Type): (Type, Type)
         t = self:to_structural(t)
         if t is RecordLikeType then
            local call_mt = t.meta_fields and t.meta_fields["__call"]
            if call_mt is FunctionType then
               local args_tuple = a_tuple(u, {})
               for i = 2, #call_mt.args.tuple do
                  table.insert(args_tuple.tuple, call_mt.args.tuple[i])
               end
               return args_tuple, call_mt
            end
         end
      end)
   end

   function TypeChecker:resolve_for_call(func: Type, args: TupleType, is_method: boolean): Type, boolean
      -- resolve unknown in lax mode, produce a general unknown function
      if self.feat_lax and is_unknown(func) then
         local unk = func
         func = a_function(func, { min_arity = 0, args = a_vararg(func, { unk }), rets = a_vararg(func, { unk }) })
      end
      -- unwrap if tuple, resolve if nominal
      func = self:to_structural(func)
      if func.typename ~= "function" and func.typename ~= "poly" then
         -- resolve if union
         if func is UnionType then
            local r = self:same_call_mt_in_all_union_entries(func)
            if r then
               table.insert(args.tuple, 1, func.types[1]) -- FIXME: is this right?
               return self:to_structural(r), true
            end
         end
         -- resolve if prototype
         if func is TypeDeclType then
            local funcdef = func.def
            if funcdef is RecordType then
               func = func.def
            end
         end
         -- resolve if metatable
         if func is RecordLikeType and func.meta_fields and func.meta_fields["__call"] then
            table.insert(args.tuple, 1, func)
            func = func.meta_fields["__call"]
            func = self:to_structural(func)
            is_method = true
         end
      end
      return func, is_method
   end

   local type OnArgId = function<T>(node: Node, i: integer): T
   local type OnNode = function<S, T>(s: S, node: Node, children: {T}, ret: T): T

   local function traverse_macroexp<T>(macroexp: Node, on_arg_id: OnArgId<T>, on_node: OnNode<nil, T>): T
      local root = macroexp.exp
      local argnames = {}
      for i, a in ipairs(macroexp.args) do
         argnames[a.tk] = i
      end

      local visit_node: Visitor<nil, NodeKind, Node, T> = {
         cbs = {
            ["variable"] = {
               after = function(_: nil, node: Node, _children: {T}): T
                  local i = argnames[node.tk]
                  if not i then
                     return nil
                  end

                  return on_arg_id(node, i)
               end
            }
         },
         after = on_node as VisitorAfter<nil, Node, T>,
      }

      return recurse_node(nil, root, visit_node, {})
   end

   local function expand_macroexp(orignode: Node, args: {Node}, macroexp: Node)
      local on_arg_id = function(_node: Node, i: integer): {Node, Node}
         return { Node, args[i] }
      end

      local on_node = function(_: nil, node: Node, children: {{Node, Node}}, ret: {Node, Node}): {Node, Node}
         local orig = ret and ret[2] or node

         local out = shallow_copy_table(orig)

         local map = {}
         for _, pair in pairs(children as {integer:{Node, Node}}) do
            if type(pair) == "table" then
               map[pair[1]] = pair[2]
            end
         end

         for k, v in pairs(orig as {any:Node}) do
            if type(v) == "table" and map[v] then
               (out as {any:any})[k] = map[v]
            end
         end

         out.yend = out.yend and (orignode.y + (out.yend - out.y)) or nil
         out.xend = nil
         out.y = orignode.y
         out.x = orignode.x
         return { node, out }
      end

      local p = traverse_macroexp(macroexp, on_arg_id, on_node)
      orignode.expanded = p[2]
   end

   function TypeChecker:check_macroexp_arg_use(macroexp: Node)
      local used: {string:boolean} = {}

      local on_arg_id = function(node: Node, _i: integer): {Node, Node}
         if used[node.tk] then
            self.errs:add(node, "cannot use argument '" .. node.tk .. "' multiple times in macroexp")
         else
            used[node.tk] = true
         end
      end

      traverse_macroexp(macroexp, on_arg_id, nil)
   end

   local function apply_macroexp(orignode: Node)
      local expanded = orignode.expanded
      local saveknown = orignode.known
      orignode.expanded = nil

      for k, _ in pairs(orignode as {any:any}) do
         (orignode as {any:any})[k] = nil
      end
      for k, v in pairs(expanded as {any:any}) do
         (orignode as {any:any})[k] = v
      end
      orignode.known = saveknown
   end

   do
      local function mark_invalid_typeargs(self: TypeChecker, f: FunctionType)
         if f.typeargs then
            for _, a in ipairs(f.typeargs) do
               if not self:find_var_type(a.typearg) then
                  if a.constraint then
                     self:add_var(nil, a.typearg, a.constraint)
                  else
                     self:add_var(nil, a.typearg, self.feat_lax and an_unknown(a) or a_type(a, "unresolvable_typearg", {
                        typearg = a.typearg
                     } as UnresolvableTypeArgType))
                  end
               end
            end
         end
      end

      local function infer_emptytables(self: TypeChecker, w: Where, wheres: {Where}, xs: TupleType, ys: TupleType, delta: integer)
         local xt, yt = xs.tuple, ys.tuple
         local n_xs = #xt
         local n_ys = #yt
         -- resolve inference of emptytables used as arguments or returns
         for i = 1, n_xs do
            local x = xt[i]
            if x is EmptyTableType then
               local y = yt[i] or (ys.is_va and yt[n_ys])
               if y then -- y may not be present when inferring returns
                  local iw = wheres and wheres[i + delta] or w -- for self, a + argdelta is 0
                  local inferred_y = self:infer_at(iw, y)
                  self:infer_emptytable(x, inferred_y)
                  xt[i] = inferred_y
               end
            end
         end
      end

      local check_args_rets: function(TypeChecker, w: Where, where_args: {Node}, f: FunctionType, args: TupleType, expected_rets: TupleType, argdelta: integer): TupleType, {Error}
      do
         -- check if a tuple `xs` matches tuple `ys`
         local function check_func_type_list(self: TypeChecker, w: Where, wheres: {Where}, xs: TupleType, ys: TupleType, from: integer, delta: integer, v: VarianceMode, mode: ArgCheckMode): boolean, {Error}
            assert(xs.typename == "tuple", xs.typename)
            assert(ys.typename == "tuple", ys.typename)

            local errs = {}
            local xt, yt = xs.tuple, ys.tuple
            local n_xs = #xt
            local n_ys = #yt

            for i = from, math.max(n_xs, n_ys) do
               local pos = i + delta
               local x = xt[i] or (xs.is_va and xt[n_xs]) or a_type(w, "nil", {})
               local y = yt[i] or (ys.is_va and yt[n_ys])
               if y then
                  local iw = wheres and wheres[pos] or w
                  if not self:arg_check(iw, errs, x, y, v, mode, pos) then
                     return nil, errs
                  end
               end
            end

            return true
         end

         check_args_rets = function(self: TypeChecker, w: Where, where_args: {Node}, f: FunctionType, args: TupleType, expected_rets: TupleType, argdelta: integer): TupleType, {Error}
            local rets_ok = true
            local rets_errs: {Error}
            local args_ok: boolean
            local args_errs: {Error}
            local fargs = f.args.tuple

            local from = 1
            if argdelta == -1 then
               from = 2
               local errs = {}
               if (not is_self(fargs[1])) and not self:arg_check(w, errs, fargs[1], args.tuple[1], "contravariant", "self") then
                  return nil, errs
               end
            end

            if expected_rets then
               expected_rets = self:infer_at(w, expected_rets)
               infer_emptytables(self, w, nil, expected_rets, f.rets, 0)

               rets_ok, rets_errs = check_func_type_list(self, w, nil, f.rets, expected_rets, 1, 0, "covariant", "return")
            end

            args_ok, args_errs = check_func_type_list(self, w, where_args, f.args, args, from, argdelta, "contravariant", "argument")
            if (not args_ok) or (not rets_ok) then
               return nil, args_errs or {}
            end

            -- if we got to this point without returning,
            -- we got a valid function match

            infer_emptytables(self, w, where_args, args, f.args, argdelta)

            mark_invalid_typeargs(self, f)

            return self:resolve_typevars_at(w, f.rets)
         end
      end

      local function push_typeargs(self: TypeChecker, func: FunctionType)
         if func.typeargs then
            for _, fnarg in ipairs(func.typeargs) do
               self:add_var(nil, fnarg.typearg, a_type(fnarg, "unresolved_typearg", {
                  constraint = fnarg.constraint,
               } as UnresolvedTypeArgType))
            end
         end
      end

      local function pop_typeargs(self: TypeChecker, func: FunctionType)
         if func.typeargs then
            for _, fnarg in ipairs(func.typeargs) do
               if self.st[#self.st].vars[fnarg.typearg] then
                  self.st[#self.st].vars[fnarg.typearg] = nil
               end
            end
         end
      end

      local function resolve_function_type(func: FunctionType | PolyType, i: integer): FunctionType
         if func is PolyType then
            return func.types[i]
         else
            return func
         end
      end

      local function fail_call(self: TypeChecker, w: Where, func: FunctionType | PolyType, nargs: integer, errs: {Error}): TupleType
         if errs then
            self.errs:collect(errs)
         else
            -- found no arity match to try
            local expects: {string} = {}
            if func is PolyType then
               for _, f in ipairs(func.types) do
                  table.insert(expects, show_arity(f))
               end
               table.sort(expects)
               for i = #expects, 1, -1 do
                  if expects[i] == expects[i+1] then
                     table.remove(expects, i)
                  end
               end
            else
               table.insert(expects, show_arity(func))
            end
            self.errs:add(w, "wrong number of arguments (given " .. nargs .. ", expects " .. table.concat(expects, " or ") .. ")")
         end

         local f = resolve_function_type(func, 1)

         mark_invalid_typeargs(self, f)

         return self:resolve_typevars_at(w, f.rets)
      end

      local function check_call(self: TypeChecker, w: Where, where_args: {Node}, func: Type, args: TupleType, expected_rets: TupleType, is_typedecl_funcall: boolean, argdelta: integer): InvalidOrTupleType, FunctionType
         assert(type(func) == "table")
         assert(type(args) == "table")

         local is_method = (argdelta == -1)

         if not (func is FunctionType or func is PolyType) then
            func, is_method = self:resolve_for_call(func, args, is_method)
            if is_method then
               argdelta = -1
            end
            if not (func is FunctionType or func is PolyType) then
               return self.errs:invalid_at(w, "not a function: %s", func)
            end
         end

         if is_method and args.tuple[1] then
            self:add_var(nil, "@self", a_typedecl(w, args.tuple[1]))
         end

         local passes, n = 1, 1
         if func is PolyType then
            passes, n = 3, #func.types
         end

         local given = #args.tuple
         local tried: {integer:boolean}
         local first_errs: {Error}
         for pass = 1, passes do
            for i = 1, n do
               if (not tried) or not tried[i] then
                  local f = resolve_function_type(func, i)
                  local fargs = f.args.tuple
                  if f.is_method and not is_method then
                     if args.tuple[1] and self:is_a(args.tuple[1], fargs[1]) then
                        -- a non-"@funcall" means a synthesized call, e.g. from a metamethod
                        if not is_typedecl_funcall then
                           self.errs:add_warning("hint", w, "invoked method as a regular function: consider using ':' instead of '.'")
                        end
                     else
                        return self.errs:invalid_at(w, "invoked method as a regular function: use ':' instead of '.'")
                     end
                  end
                  local wanted = #fargs
                  local min_arity = self.feat_arity and f.min_arity or 0

                  -- simple functions:
                  if (passes == 1 and ((given <= wanted and given >= min_arity) or (f.args.is_va and given > wanted) or (self.feat_lax and given <= wanted)))
                  -- poly, pass 1: try exact arity matches first
                  or (passes == 3 and ((pass == 1 and given == wanted)
                  -- poly, pass 2: then try adjusting with nils to missing arguments or using '...'
                                    or (pass == 2 and given < wanted and (self.feat_lax or given >= min_arity))
                  -- poly, pass 3: then finally try vararg functions
                                    or (pass == 3 and f.args.is_va and given > wanted)))
                  then
                     push_typeargs(self, f)

                     local matched, errs = check_args_rets(self, w, where_args, f, args, expected_rets, argdelta)
                     if matched then
                        -- success!
                        return matched, f
                     end
                     first_errs = first_errs or errs

                     if expected_rets then
                        -- revert inferred returns
                        infer_emptytables(self, w, where_args, f.rets, f.rets, argdelta)
                     end

                     if passes == 3 then
                        tried = tried or {}
                        tried[i] = true
                        pop_typeargs(self, f)
                     end
                  end
               end
            end
         end

         return fail_call(self, w, func, given, first_errs)
      end

      function TypeChecker:type_check_function_call(node: Node, func: Type, args: TupleType, argdelta?: integer, e1?: Node, e2?: {Node}): InvalidOrTupleType, FunctionType
         e1 = e1 or node.e1
         e2 = e2 or node.e2

         local expected = node.expected
         local expected_rets: TupleType
         if expected and expected is TupleType then
            expected_rets = expected
         else
            expected_rets = a_tuple(node, { node.expected })
         end

         self:begin_scope()

         local is_typedecl_funcall: boolean
         if node.kind == "op" and node.op.op == "@funcall" and e1 and e1.receiver then
            local receiver = e1.receiver
            if receiver is NominalType then
               local resolved = receiver.resolved
               if resolved and resolved is TypeDeclType then
                  is_typedecl_funcall = true
               end
            end
         end

         local ret, f = check_call(self, node, e2, func, args, expected_rets, is_typedecl_funcall, argdelta or 0)

         ret = self:resolve_typevars_at(node, ret)
         self:end_scope()

         if self.collector then
            self.collector.store_type(e1.y, e1.x, f)
         end

         if f and f.macroexp then
            expand_macroexp(node, e2, f.macroexp)
         end

         return ret, f
      end
   end

   function TypeChecker:check_metamethod(node: Node, method_name: string, a: Type, b: Type, orig_a: Type, orig_b: Type): Type, integer
      if self.feat_lax and ((a and is_unknown(a)) or (b and is_unknown(b))) then
         return an_unknown(node), nil
      end
      local ameta = a is RecordLikeType and a.meta_fields
      local bmeta = b and b is RecordLikeType and b.meta_fields

      if not ameta and not bmeta then
         return nil, nil
      end

      local meta_on_operator = 1
      local metamethod: Type
      if method_name ~= "__is" then
         metamethod = ameta and ameta[method_name or ""]
      end
      if (not metamethod) and b and method_name ~= "__index" then
         metamethod = bmeta and bmeta[method_name or ""]
         meta_on_operator = 2
      end

      if metamethod then
         local e2 = { node.e1 }
         local args = a_tuple(node, { orig_a })
         if b and method_name ~= "__is" then
            e2[2] = node.e2
            args.tuple[2] = orig_b
         end
         return self:to_structural(resolve_tuple((self:type_check_function_call(node, metamethod, args, -1, node, e2)))), meta_on_operator
      else
         return nil, nil
      end
   end

   function TypeChecker:match_record_key(tbl: Type, rec: Node, key: string): Type, string
      assert(type(tbl) == "table")
      assert(type(rec) == "table")
      assert(type(key) == "string")

      tbl = self:to_structural(tbl)

      if tbl is StringType or tbl is EnumType then
         tbl = self:find_var_type("string") -- simulate string metatable
      end

      if tbl is TypeDeclType then
         tbl = tbl.def
      elseif tbl is TypeAliasType then
         if tbl.is_nested_alias then
            return nil, "cannot use a nested type alias as a concrete value"
         else
            tbl = self:resolve_nominal(tbl.alias_to)
         end
      end

      if tbl is UnionType then
         local t = self:same_in_all_union_entries(tbl, function(t: Type): (Type, Type)
            return (self:match_record_key(t, rec, key))
         end)

         if t then
            return t
         end
      end

      if (tbl is TypeVarType or tbl is TypeArgType) and tbl.constraint then
         local t = self:match_record_key(tbl.constraint, rec, key)

         if t then
            return t
         end
      end

      if tbl is RecordLikeType then
         assert(tbl.fields, "record has no fields!?")

         if tbl.fields[key] then
            return tbl.fields[key]
         end

         local str = a_type(rec, "string", {})
         local meta_t = self:check_metamethod(rec, "__index", tbl, str, tbl, str)
         if meta_t then
            return meta_t
         end

         if rec.kind == "variable" then
            if tbl is InterfaceType then
               return nil, "invalid key '" .. key .. "' in '" .. rec.tk .. "' of interface type %s"
            else
               return nil, "invalid key '" .. key .. "' in record '" .. rec.tk .. "' of type %s"
            end
         else
            return nil, "invalid key '" .. key .. "' in type %s"
         end
      elseif tbl is EmptyTableType or is_unknown(tbl) then
         if self.feat_lax then
            return an_unknown(rec)
         end
         return nil, "cannot index a value of unknown type"
      end

      if rec.kind == "variable" then
         return nil, "cannot index key '" .. key .. "' in " .. tbl.typename .. " '" .. rec.tk .. "' of type %s"
      else
         return nil, "cannot index key '" .. key .. "' in type %s"
      end
   end

   function TypeChecker:widen_in_scope(scope: Scope, var: string): boolean
      local v = scope.vars[var]
      assert(v, "no " .. var .. " in scope")
      local narrow_mode = scope.vars[var].is_narrowed
      if (not narrow_mode) or narrow_mode == "declaration" then
         return false
      end

      if v.narrowed_from then
         v.t = v.narrowed_from
         v.narrowed_from = nil
         v.is_narrowed = nil
      else
         scope.vars[var] = nil
      end

      if scope.narrows then
         scope.narrows[var] = nil
      end

      return true
   end

   function TypeChecker:widen_back_var(name: string): boolean
      local widened = false
      for i = #self.st, 1, -1 do
         local scope = self.st[i]
         if scope.vars[name] then
            if self:widen_in_scope(scope, name) then
               widened = true
            else
               break
            end
         end
      end
      return widened
   end

   local function assigned_anywhere(name: string, root: Node): boolean
      local visit_node: Visitor<nil, NodeKind, Node, boolean> = {
         cbs = {
            ["assignment"] = {
               after = function(_: nil, node: Node, _children: {boolean}): boolean
                  for _, v in ipairs(node.vars) do
                     if v.kind == "variable" and v.tk == name then
                        return true
                     end
                  end
                  return false
               end
            }
         },
         after = function(_: nil, _node: Node, children: {boolean}, ret: boolean): boolean
            ret = ret or false
            for _, c in ipairs(children) do
               local ca = c as any
               if ca is boolean then
                  ret = ret or c
               end
            end
            return ret
         end
      }

      local visit_type: Visitor<nil, TypeName, Type, boolean> = {
         after = function(): boolean
            return false
         end
      }

      return recurse_node(nil, root, visit_node, visit_type)
   end

   function TypeChecker:widen_all_unions(node?: Node)
      for i = #self.st, 1, -1 do
         local scope = self.st[i]
         if scope.narrows then
            for name, _ in pairs(scope.narrows) do
               if not node or assigned_anywhere(name, node) then
                  self:widen_in_scope(scope, name)
               end
            end
         end
      end
   end

   function TypeChecker:add_global(node: Node, varname: string, valtype: Type, is_assigning?: boolean): Variable
      if self.feat_lax and is_unknown(valtype) and (varname ~= "self" and varname ~= "...") then
         self.errs:add_unknown(node, varname)
      end

      local is_const = node.attribute ~= nil
      local existing, scope, existing_attr = self:find_var(varname)
      if existing then
         if scope > 1 then
            self.errs:add(node, "cannot define a global when a local with the same name is in scope")
         elseif is_assigning and existing_attr then
            self.errs:add(node, "cannot reassign to <" .. existing_attr .. "> global: " .. varname)
         elseif existing_attr and not is_const then
            self.errs:add(node, "global was previously declared as <" .. existing_attr .. ">: " .. varname)
         elseif (not existing_attr) and is_const then
            self.errs:add(node, "global was previously declared as not <" .. node.attribute .. ">: " .. varname)
         elseif valtype and not self:same_type(existing.t, valtype) then
            self.errs:add(node, "cannot redeclare global with a different type: previous type of " .. varname .. " is %s", existing.t)
         end
         return nil
      end

      local var = { t = valtype, attribute = is_const and "const" or nil }
      self.st[1].vars[varname] = var

      return var
   end

   function TypeChecker:add_internal_function_variables(node: Node, args: TupleType)
      self:add_var(nil, "@is_va", a_type(node, args.is_va and "any" or "nil", {}))
      self:add_var(nil, "@return", node.rets or a_tuple(node, {}))

      if node.typeargs then
         for _, t in ipairs(node.typeargs) do
            local v = self:find_var(t.typearg, "check_only")
            if not v or not v.used_as_type then
               self.errs:add(t, "type argument '%s' is not used in function signature", t)
            end
         end
      end
   end

   function TypeChecker:add_function_definition_for_recursion(node: Node, fnargs: TupleType)
      self:add_var(nil, node.name.tk, a_function(node, {
         min_arity = node.min_arity,
         typeargs = node.typeargs,
         args = fnargs,
         rets = self.get_rets(node.rets),
      }))
   end

   function TypeChecker:end_function_scope(node: Node)
      self.errs:fail_unresolved_labels(self.st[#self.st])
      self:end_scope(node)
   end

   local function flatten_tuple(vals: TupleType): TupleType
      local vt = vals.tuple
      local n_vals = #vt
      local ret = a_tuple(vals, {})
      local rt = ret.tuple

      if n_vals == 0 then
         return ret
      end

      -- get all arguments except the last...
      for i = 1, n_vals - 1 do
         rt[i] = resolve_tuple(vt[i])
      end

      local last = vt[n_vals]
      if last is TupleType then
         -- ...then unpack the last tuple
         local lt = last.tuple
         for _, v in ipairs(lt) do
            table.insert(rt, v)
         end
         ret.is_va = last.is_va
      else
         rt[n_vals] = vt[n_vals]
         ret.is_va = vals.is_va
      end

      return ret
   end

   local function get_assignment_values(w: Where, vals: TupleType, wanted: integer): TupleType
      if vals == nil then
         return a_tuple(w, {})
      end

      local ret = flatten_tuple(vals)

      -- ...if the last is vararg, repeat its type until it matches the number of wanted args
      if ret.is_va then
         local rt = ret.tuple
         local n_ret = #rt
         if n_ret > 0 and n_ret < wanted then
            local last = rt[n_ret]
            for _ = n_ret + 1, wanted do
               table.insert(rt, last)
            end
         end
      end
      return ret
   end

   function TypeChecker:match_all_record_field_names(node: Node, a: RecordLikeType, field_names: {string}, errmsg: string): Type
      local t: Type
      for _, k in ipairs(field_names) do
         local f = a.fields[k]
         if not t then
            t = f
         else
            if not self:same_type(f, t) then
               errmsg = errmsg .. string.format(" (types of fields '%s' and '%s' do not match)", field_names[1], k)
               t = nil
               break
            end
         end
      end
      if t then
         return t
      else
         return self.errs:invalid_at(node, errmsg)
      end
   end

   function TypeChecker:type_check_index(anode: Node, bnode: Node, a: Type, b: Type): Type
      assert(not a is TupleType)
      assert(not b is TupleType)

      local ra = resolve_typedecl(self:to_structural(a))
      local rb = self:to_structural(b)

      if self.feat_lax and is_unknown(a) then
         return a
      end

      local errm: string
      local erra: Type
      local errb: Type

      if ra is TupleTableType and rb is IntegerType then
         if bnode.constnum then
            if bnode.constnum >= 1 and bnode.constnum <= #ra.types and bnode.constnum == math.floor(bnode.constnum) then
               return ra.types[bnode.constnum as integer]
            end

            errm, erra = "index " .. tostring(bnode.constnum) .. " out of range for tuple %s", ra
         else
            local array_type = self:arraytype_from_tuple(bnode, ra)
            if array_type then
               return array_type.elements
            end

            errm = "cannot index this tuple with a variable because it would produce a union type that cannot be discriminated at runtime"
         end
      elseif ra is ArrayLikeType and rb is IntegerType then
         return ra.elements
      elseif ra is EmptyTableType then
         if ra.keys == nil then
            ra.keys = self:infer_at(bnode, b)
         end

         if self:is_a(b, ra.keys) then
            return a_type(anode, "unresolved_emptytable_value", {
               emptytable_type = ra
            } as UnresolvedEmptyTableValueType)
         end

         errm, erra, errb = "inconsistent index type: got %s, expected %s" .. inferred_msg(ra.keys, "type of keys "), b, ra.keys
      elseif ra is MapType then
         if self:is_a(b, ra.keys) then
            return ra.values
         end

         errm, erra, errb = "wrong index type: got %s, expected %s", b, ra.keys
      elseif rb is StringType and rb.literal then
         local t, e = self:match_record_key(a, anode, rb.literal)
         if t then
            return t
         end

         errm, erra = e, a
      elseif ra is RecordLikeType then
         if rb is EnumType then
            local field_names: {string} = sorted_keys(rb.enumset)
            for _, k in ipairs(field_names) do
               if not ra.fields[k] then
                  errm, erra = "enum value '" .. k .. "' is not a field in %s", ra
                  break
               end
            end
            if not errm then
               return self:match_all_record_field_names(bnode, ra, field_names,
                         "cannot index, not all enum values map to record fields of the same type")
            end
         elseif rb is StringType then
            errm, erra = "cannot index object of type %s with a string, consider using an enum", a
         else
            errm, erra, errb = "cannot index object of type %s with %s", a, b
         end
      else
         errm, erra, errb = "cannot index object of type %s with %s", a, b
      end

      local meta_t = self:check_metamethod(anode, "__index", ra, b, a, b)
      if meta_t then
         return meta_t
      end

      return self.errs:invalid_at(bnode, errm, erra, errb)
   end

   function TypeChecker:expand_type(w: Where, old: Type, new: Type): Type
      if not old or old.typename == "nil" then
         return new
      else
         if not self:is_a(new, old) then
            if old is MapType and new is RecordLikeType then
               local old_keys = old.keys
               if old_keys is StringType then
                  for _, ftype in fields_of(new) do
                     old.values = self:expand_type(w, old.values, ftype)
                  end
                  edit_type(w, old, "map") -- map changed, refresh typeid
               else
                  self.errs:add(w, "cannot determine table literal type")
               end
            elseif old is RecordLikeType and new is RecordLikeType then
               local values: Type
               for _, ftype in fields_of(old) do
                  if not values then
                     values = ftype
                  else
                     values = self:expand_type(w, values, ftype)
                  end
               end
               for _, ftype in fields_of(new) do
                  if not values then
                     values = ftype
                  else
                     values = self:expand_type(w, values, ftype)
                  end
               end
               old.fields = nil
               old.field_order = nil
               old.meta_fields = nil
               old.meta_fields = nil

               edit_type(w, old, "map")
               local map = old as MapType
               map.keys = a_type(w, "string", {})
               map.values = values
            elseif old is UnionType then
               edit_type(w, old, "union")
               table.insert(old.types, drop_constant_value(new))
            else
               return unite(w, { old, new }, true)
            end
         end
      end
      return old
   end

   function TypeChecker:find_record_to_extend(exp: Node): Type, Variable, string
      -- base
      if exp.kind == "type_identifier" then
         local v = self:find_var(exp.tk)
         if not v then
            return nil, nil, exp.tk
         end

         local t = v.t
         if t is TypeDeclType then
            if t.closed then
               return nil, nil, exp.tk
            end

            return t.def, v, exp.tk
         end

         return t, v, exp.tk
      -- recurse
      elseif exp.kind == "op" then -- assert(exp.op.op == ".")
         local t, v, rname = self:find_record_to_extend(exp.e1)
         local fname = exp.e2.tk
         local dname = rname .. "." .. fname
         if not t then
            return nil, nil, dname
         end
         if not t is RecordLikeType then
            return nil, nil, dname
         end
         t = t.fields[fname]

         if t is TypeDeclType then
            t = t.def
         elseif t is TypeAliasType then
            t = t.alias_to.resolved
         end

         return t, v, dname
      end
   end

   local function typedecl_to_nominal(node: Node, name: string, t: TypeDeclType, resolved?: Type): Type
      local typevals: {Type}
      local def = t.def
      if def is HasTypeArgs then
         typevals = {}
         for _, a in ipairs(def.typeargs) do
            table.insert(typevals, a_type(a, "typevar", {
               typevar = a.typearg,
               constraint = a.constraint,
            } as TypeVarType))
         end
      end
      local nom = a_nominal(node, { name })
      nom.typevals = typevals
      nom.found = t
      nom.resolved = resolved
      return nom
   end

   function TypeChecker:get_self_type(exp: Node): Type
      -- base
      if exp.kind == "type_identifier" then
         local t = self:find_var_type(exp.tk)
         if not t then
            return nil
         end

         if t is TypeDeclType then
            return typedecl_to_nominal(exp, exp.tk, t)
         else
            return t
         end
      -- recurse
      elseif exp.kind == "op" then -- assert(exp.op.op == ".")
         local t = self:get_self_type(exp.e1)
         if not t then
            return nil
         end

         if t is NominalType then
            local found = t.found
            if found then
               if found is TypeDeclType then
                  local def = found.def
                  if def is RecordLikeType and def.fields[exp.e2.tk] then
                     table.insert(t.names, exp.e2.tk)
                     local ft = def.fields[exp.e2.tk]
                     if ft is TypeType then
                        t.found = ft
                     else
                        return nil
                     end
                  end
               end
            end
         elseif t is RecordLikeType then
            return t.fields and t.fields[exp.e2.tk]
         end
         return t
      end
   end

   -- Inference engine for 'is' operator
   local facts_and: function(w: Where, f1: Fact, f2: Fact): Fact
   local facts_or: function(w: Where, f1: Fact, f2: Fact): Fact
   local facts_not: function(w: Where, f1: Fact): Fact
   local FACT_TRUTHY: Fact
   do
      local IsFact_mt: metatable<IsFact> = {
         __tostring = function(f: IsFact): string
            return ("(%s is %s)"):format(f.var, show_type(f.typ))
         end
      }

      setmetatable(IsFact, {
         __call = function(_: IsFact, fact: Fact): IsFact
            fact.fact = "is"
            assert(fact.w)
            return setmetatable(fact as IsFact, IsFact_mt)
         end,
      })

      local EqFact_mt: metatable<EqFact> = {
         __tostring = function(f: EqFact): string
            return ("(%s == %s)"):format(f.var, show_type(f.typ))
         end
      }

      setmetatable(EqFact, {
         __call = function(_: EqFact, fact: Fact): EqFact
            fact.fact = "=="
            assert(fact.w)
            return setmetatable(fact as EqFact, EqFact_mt)
         end,
      })

      local TruthyFact_mt: metatable<TruthyFact> = {
         __tostring = function(_f: TruthyFact): string
            return "*"
         end
      }

      setmetatable(TruthyFact, {
         __call = function(_: TruthyFact, fact: Fact): TruthyFact
            fact.fact = "truthy"
            return setmetatable(fact as TruthyFact, TruthyFact_mt)
         end,
      })

      local NotFact_mt: metatable<NotFact> = {
         __tostring = function(f: NotFact): string
            return ("(not %s)"):format(tostring(f.f1))
         end
      }

      setmetatable(NotFact, {
         __call = function(_: NotFact, fact: Fact): NotFact
            fact.fact = "not"
            return setmetatable(fact as NotFact, NotFact_mt)
         end,
      })

      local AndFact_mt: metatable<AndFact> = {
         __tostring = function(f: AndFact): string
            return ("(%s and %s)"):format(tostring(f.f1), tostring(f.f2))
         end
      }

      setmetatable(AndFact, {
         __call = function(_: AndFact, fact: Fact): AndFact
            fact.fact = "and"
            return setmetatable(fact as AndFact, AndFact_mt)
         end,
      })

      local OrFact_mt: metatable<OrFact> = {
         __tostring = function(f: OrFact): string
            return ("(%s or %s)"):format(tostring(f.f1), tostring(f.f2))
         end
      }

      setmetatable(OrFact, {
         __call = function(_: OrFact, fact: Fact): OrFact
            fact.fact = "or"
            return setmetatable(fact as OrFact, OrFact_mt)
         end,
      })

      FACT_TRUTHY = TruthyFact {}

      facts_and = function(w: Where, f1: Fact, f2: Fact): Fact
         return AndFact { f1 = f1, f2 = f2, w = w }
      end

      facts_or = function(w: Where, f1: Fact, f2: Fact): Fact
         if f1 and f2 then
            return OrFact { f1 = f1, f2 = f2, w = w }
         else
            return nil
         end
      end

      facts_not = function(w: Where, f1: Fact): Fact
         if f1 then
            return NotFact { f1 = f1, w = w }
         else
            return nil
         end
      end

      -- t1 ∪ t2
      local function unite_types(w: Where, t1: Type, t2: Type): Type, string
         return unite(w, {t2, t1})
      end

      -- t1 ∩ t2
      local function intersect_types(self: TypeChecker, w: Where, t1: Type, t2: Type): Type, string
         if t2 is UnionType then
            t1, t2 = t2, t1
         end
         if t1 is UnionType then
            local out = {}
            for _, t in ipairs(t1.types) do
               if self:is_a(t, t2) then
                  table.insert(out, t)
               end
            end
            return unite(w, out)
         else
            if self:is_a(t1, t2) then
               return t1
            elseif self:is_a(t2, t1) then
               return t2
            else
               return a_type(w, "nil", {}) -- because of implicit nil in all unions
            end
         end
      end

      function TypeChecker:resolve_if_union(t: Type): Type
         local rt = self:to_structural(t)
         if rt is UnionType then
            return rt
         end
         return t
      end

      -- t1 - t2
      local function subtract_types(self: TypeChecker, w: Where, t1: Type, t2: Type): Type
         local types: {Type} = {}

         t1 = self:resolve_if_union(t1)

         -- poly are not first-class, so we don't handle them here
         if not t1 is UnionType then
            return t1
         end

         t2 = self:resolve_if_union(t2)
         local t2types = t2 is UnionType and t2.types or { t2 }

         for _, at in ipairs(t1.types) do
            local not_present = true
            for _, bt in ipairs(t2types) do
               if self:same_type(at, bt) then
                  not_present = false
                  break
               end
            end
            if not_present then
               table.insert(types, at)
            end
         end

         if #types == 0 then
            return a_type(w, "nil", {}) -- because of implicit nil in all unions
         end

         return unite(w, types)
      end

      local eval_not: function(TypeChecker, f: Fact): {string:IsFact|EqFact}
      local not_facts: function(TypeChecker, fs: {string:IsFact|EqFact}): {string:IsFact|EqFact}
      local or_facts: function(TypeChecker, fs1: {string:IsFact|EqFact}, fs2: {string:IsFact|EqFact}): {string:IsFact|EqFact}
      local and_facts: function(TypeChecker, fs1: {string:IsFact|EqFact}, fs2: {string:IsFact|EqFact}): {string:IsFact|EqFact}
      local eval_fact: function(TypeChecker, f: Fact): {string:IsFact|EqFact}

      local function invalid_from(f: IsFact): IsFact
         return IsFact { fact = "is", var = f.var, typ = a_type(f.w, "invalid", {}), w = f.w }
      end

      not_facts = function(self: TypeChecker, fs: {string:IsFact|EqFact}): {string:IsFact|EqFact}
         local ret: {string:IsFact|EqFact} = {}
         for var, f in pairs(fs) do
            local typ = self:find_var_type(f.var, "check_only")

            if not typ then
               ret[var] = EqFact { var = var, typ = an_invalid(f.w), w = f.w, no_infer = f.no_infer }
            elseif f is EqFact then
               -- nothing is known from negation of equality; widen back
               ret[var] = EqFact { var = var, typ = typ, w = f.w, no_infer = true }
            elseif typ is TypeVarType then
               assert(f.fact == "is")
               -- nothing is known from negation on typeargs; widen back
               ret[var] = EqFact { var = var, typ = typ, w = f.w, no_infer = true }
            elseif not self:is_a(f.typ, typ) then
               assert(f.fact == "is")
               self.errs:add_warning("branch", f.w, f.var .. " (of type %s) can never be a %s", show_type(typ), show_type(f.typ))
               ret[var] = EqFact { var = var, typ = an_invalid(f.w), w = f.w, no_infer = f.no_infer }
            else
               assert(f.fact == "is")
               ret[var] = IsFact { var = var, typ = subtract_types(self, f.w, typ, f.typ), w = f.w, no_infer = f.no_infer }
            end
         end
         return ret
      end

      eval_not = function(self: TypeChecker, f: Fact): {string:IsFact|EqFact}
         if not f then
            return {}
         elseif f is IsFact then
            return not_facts(self, {[f.var] = f})
         elseif f is NotFact then
            return eval_fact(self, f.f1)
         elseif f is AndFact and f.f2 and f.f2.fact == "truthy" then
            return eval_not(self, f.f1)
         elseif f is OrFact and f.f2 and f.f2.fact == "truthy" then
            return eval_fact(self, f.f1)
         elseif f is AndFact then
            return or_facts(self, not_facts(self, eval_fact(self, f.f1)), not_facts(self, eval_fact(self, f.f2)))
         elseif f is OrFact then
            return and_facts(self, not_facts(self, eval_fact(self, f.f1)), not_facts(self, eval_fact(self, f.f2)))
         else
            return not_facts(self, eval_fact(self, f))
         end
      end

      or_facts = function(_self: TypeChecker, fs1: {string:IsFact|EqFact}, fs2: {string:IsFact|EqFact}): {string:IsFact|EqFact}
         local ret: {string:IsFact|EqFact} = {}

         for var, f in pairs(fs2) do
            if fs1[var] then
               local united = unite_types(f.w, f.typ, fs1[var].typ)
               if fs1[var].fact == "is" and f.fact == "is" then
                  ret[var] = IsFact { var = var, typ = united, w = f.w }
               else
                  ret[var] = EqFact { var = var, typ = united, w = f.w }
               end
            end
         end

         return ret
      end

      and_facts = function(self: TypeChecker, fs1: {string:IsFact|EqFact}, fs2: {string:IsFact|EqFact}): {string:IsFact|EqFact}
         local ret: {string:IsFact|EqFact} = {}
         local has: {FactType:boolean} = {}

         for var, f in pairs(fs1) do
            local rt: Type
            local ctor: IsFact | EqFact = EqFact
            if fs2[var] then
               if fs2[var].fact == "is" and f.fact == "is" then
                  ctor = IsFact
               end
               rt = intersect_types(self, f.w, f.typ, fs2[var].typ)
            else
               rt = f.typ
            end
            local ff = ctor { var = var, typ = rt, w = f.w, no_infer = f.no_infer }
            ret[var] = ff
            has[ff.fact] = true
         end

         for var, f in pairs(fs2) do
            if not fs1[var] then
               ret[var] = EqFact { var = var, typ = f.typ, w = f.w, no_infer = f.no_infer }
               has["=="] = true
            end
         end

         if has["is"] and has["=="] then
            for _, f in pairs(ret) do
               f.fact = "=="
            end
         end

         return ret
      end

      eval_fact = function(self: TypeChecker, f: Fact): {string:IsFact|EqFact}
         if not f then
            return {}
         elseif f is IsFact then
            local typ = self:find_var_type(f.var, "check_only")
            if not typ then
               return { [f.var] = invalid_from(f) }
            end
            if typ.typename ~= "typevar" then
               if self:is_a(typ, f.typ) then
                  -- drop this warning because of implicit nil in all unions
                  -- self.errs:add_warning("branch", f.w, f.var .. " (of type %s) is always a %s", show_type(typ), show_type(f.typ))
                  return { [f.var] = f }
               elseif not self:is_a(f.typ, typ) then
                  self.errs:add(f.w, f.var .. " (of type %s) can never be a %s", typ, f.typ)
                  return { [f.var] = invalid_from(f) }
               end
            end
            return { [f.var] = f }
         elseif f is EqFact then
            return { [f.var] = f }
         elseif f is NotFact then
            return eval_not(self, f.f1)
         elseif f is TruthyFact then
            return {}
         elseif f is AndFact and f.f2 and f.f2.fact == "truthy" then
            return eval_fact(self, f.f1)
         elseif f is OrFact and f.f2 and f.f2.fact == "truthy" then
            return eval_not(self, f.f1)
         elseif f is AndFact then
            return and_facts(self, eval_fact(self, f.f1), eval_fact(self, f.f2))
         elseif f is OrFact then
            return or_facts(self, eval_fact(self, f.f1), eval_fact(self, f.f2))
         end
      end

      function TypeChecker:apply_facts(w: Where, known: Fact)
         if not known then
            return
         end

         local facts = eval_fact(self, known)

         for v, f in pairs(facts) do
            if f.typ.typename == "invalid" then
               self.errs:add(w, "cannot resolve a type for " .. v .. " here")
            end
            local t = f.no_infer and f.typ or self:infer_at(w, f.typ)
            if f.no_infer then
               t.inferred_at = nil
            end
            self:add_var(nil, v, t, "const", "narrow")
         end
      end
   end

   function TypeChecker:dismiss_unresolved(name: string)
      for i = #self.st, 1, -1 do
         local scope = self.st[i]
         local uses = scope.pending_nominals and scope.pending_nominals[name]
         if uses then
            for _, t in ipairs(uses) do
               self:resolve_nominal(t)
            end
            scope.pending_nominals[name] = nil
            return
         end
      end
   end

   local function special_pcall_xpcall(self: TypeChecker, node: Node, _a: Type, b: TupleType, argdelta: integer): Type
      local base_nargs = (node.e1.tk == "xpcall") and 2 or 1
      local bool = a_type(node, "boolean", {})
      if #node.e2 < base_nargs then
         self.errs:add(node, "wrong number of arguments (given " .. #node.e2 .. ", expects at least " .. base_nargs .. ")")
         return a_tuple(node, { bool })
      end

      -- The function called by pcall/xpcall is invoked as a regular function,
      -- so we wish to avoid incorrect error messages / unnecessary warning messages
      -- associated with calling methods as functions
      local ftype = table.remove(b.tuple, 1)
      ftype = shallow_copy_new_type(ftype)
      if ftype is FunctionType then
         ftype.is_method = false
      end

      local fe2: Node = node_at(node.e2, {})
      if node.e1.tk == "xpcall" then
         base_nargs = 2
         local arg2 = node.e2[2]
         local msgh = table.remove(b.tuple, 1)
         local msgh_type = a_function(arg2, {
            min_arity = 1,
            args = a_tuple(arg2, { a_type(arg2, "any", {}) }),
            rets = a_tuple(arg2, {})
         })
         self:assert_is_a(arg2, msgh, msgh_type, "in message handler")
      end
      for i = base_nargs + 1, #node.e2 do
         table.insert(fe2, node.e2[i])
      end
      local fnode: Node = node_at(node, {
         kind = "op",
         op = { op = "@funcall" },
         e1 = node.e2[1],
         e2 = fe2,
      })
      local rets = self:type_check_funcall(fnode, ftype, b, argdelta + base_nargs)
      if rets is InvalidType then
         return rets
      end
      table.insert(rets.tuple, 1, bool)
      return rets
   end

   local special_functions: {string : function(TypeChecker, Node,Type,TupleType,integer):InvalidOrTupleType } = {
      ["pairs"] = function(self: TypeChecker, node: Node, a: Type, b: TupleType, argdelta: integer): InvalidOrTupleType
         if not b.tuple[1] then
            return self.errs:invalid_at(node, "pairs requires an argument")
         end
         local t = self:to_structural(b.tuple[1])
         if t is ArrayLikeType then
            self.errs:add_warning("hint", node, "hint: applying pairs on an array: did you intend to apply ipairs?")
         end

         if t.typename ~= "map" then
            if not (self.feat_lax and is_unknown(t)) then
               if t is RecordLikeType then
                  self:match_all_record_field_names(node.e2, t, t.field_order,
                     "attempting pairs on a record with attributes of different types")
                  local ct = t.typename == "record" and "{string:any}" or "{any:any}"
                  self.errs:add_warning("hint", node.e2, "hint: if you want to iterate over fields of a record, cast it to " .. ct)
               else
                  self.errs:add(node.e2, "cannot apply pairs on values of type: %s", t)
               end
            end
         end

         return (self:type_check_function_call(node, a, b, argdelta))
      end,

      ["ipairs"] = function(self: TypeChecker, node: Node, a: Type, b: TupleType, argdelta: integer): InvalidOrTupleType
         if not b.tuple[1] then
            return self.errs:invalid_at(node, "ipairs requires an argument")
         end
         local orig_t = b.tuple[1]
         local t = self:to_structural(orig_t)

         if t is TupleTableType then
            local arr_type = self:arraytype_from_tuple(node.e2, t)
            if not arr_type then
               return self.errs:invalid_at(node.e2, "attempting ipairs on tuple that's not a valid array: %s", orig_t)
            end
         elseif not t is ArrayLikeType then
            if not (self.feat_lax and (is_unknown(t) or t is EmptyTableType)) then
               return self.errs:invalid_at(node.e2, "attempting ipairs on something that's not an array: %s", orig_t)
            end
         end

         return (self:type_check_function_call(node, a, b, argdelta))
      end,

      ["rawget"] = function(self: TypeChecker, node: Node, _a: Type, b: TupleType, _argdelta: integer): InvalidOrTupleType
         -- TODO should those offsets be fixed by _argdelta?
         if #b.tuple == 2 then
            return a_tuple(node, { self:type_check_index(node.e2[1], node.e2[2], b.tuple[1], b.tuple[2]) })
         else
            return self.errs:invalid_at(node, "rawget expects two arguments")
         end
      end,

      ["require"] = function(self: TypeChecker, node: Node, _a: Type, b: TupleType, _argdelta: integer): InvalidOrTupleType
         if #b.tuple ~= 1 then
            return self.errs:invalid_at(node, "require expects one literal argument")
         end
         if node.e2[1].kind ~= "string" then
            return self.errs:invalid_at(node, "don't know how to resolve a dynamic require")
         end

         local module_name = assert(node.e2[1].conststr)
         local t, module_filename = require_module(node, module_name, self.feat_lax, self.env)

         if t.typename == "invalid" then
            if not module_filename then
               return self.errs:invalid_at(node, "module not found: '" .. module_name .. "'")
            end

            if self.feat_lax then
               return a_tuple(node, { an_unknown(node) })
            end
            return self.errs:invalid_at(node, "no type information for required module: '" .. module_name .. "'")
         end

         self.dependencies[module_name] = module_filename
         return a_tuple(node, { t })
      end,

      ["pcall"] = special_pcall_xpcall,
      ["xpcall"] = special_pcall_xpcall,

      ["assert"] = function(self: TypeChecker, node: Node, a: Type, b: TupleType, argdelta: integer): InvalidOrTupleType
         node.known = FACT_TRUTHY
         local r = self:type_check_function_call(node, a, b, argdelta)
         self:apply_facts(node, node.e2[1].known)
         return r
      end,
   }

   function TypeChecker:type_check_funcall(node: Node, a: Type, b: TupleType, argdelta?: integer): InvalidOrTupleType
      argdelta = argdelta or 0
      if node.e1.kind == "variable" then
         local special = special_functions[node.e1.tk]
         if special then
            return special(self, node, a, b, argdelta)
         else
            return (self:type_check_function_call(node, a, b, argdelta))
         end
      elseif node.e1.op and node.e1.op.op == ":" then
         table.insert(b.tuple, 1, node.e1.receiver)
         return (self:type_check_function_call(node, a, b, -1))
      else
         return (self:type_check_function_call(node, a, b, argdelta))
      end
   end

   -- is the i-th assignment in a local declaration of the form `x = x` ?
   local function is_localizing_a_variable(node: Node, i: integer): boolean
      return node.exps
         and node.exps[i]
         and node.exps[i].kind == "variable"
         and node.exps[i].tk == node.vars[i].tk
   end

   function TypeChecker:missing_initializer(node: Node, i: integer, name: string): (InvalidType | UnknownType)
      if self.feat_lax then
         return an_unknown(node)
      else
         if node.exps then
            return self.errs:invalid_at(node.vars[i], "assignment in declaration did not produce an initial value for variable '" .. name .. "'")
         else
            return self.errs:invalid_at(node.vars[i], "variable '" .. name .. "' has no type or initial value")
         end
      end
   end

   local function set_expected_types_to_decltuple(_: TypeChecker, node: Node, children: {Type})
      local decltuple = node.kind == "assignment" and children[1] or node.decltuple
      assert(decltuple is TupleType)
      local decls = decltuple.tuple
      if decls and node.exps then
         local ndecl = #decls
         local nexps = #node.exps
         for i = 1, nexps do
            local typ: Type
            typ = decls[i]
            if typ then
               if i == nexps and ndecl > nexps then
                  typ = a_tuple(node, {})
                  for a = i, ndecl do
                     table.insert(typ.tuple, decls[a])
                  end
               end
               node.exps[i].expected = typ
               node.exps[i].expected_context = { kind = node.kind, name = node.vars[i].tk }
            end
         end
      end
   end

   local function is_positive_int(n: number): boolean
      return n and n >= 1 and math.floor(n) == n
   end

   local function infer_table_literal(self: TypeChecker, node: Node, children: {LiteralTableItemType}): Type
      local is_record = false
      local is_array = false
      local is_map = false

      local is_tuple = false
      local is_not_tuple = false

      local last_array_idx = 1
      local largest_array_idx = -1

      local seen_keys: {CheckableKey:Where} = {}

      -- array, tupletable
      local types: {Type}
      -- record
      local fields: {string:Type}
      local field_order: {string}
      -- array, record
      local elements: Type
      -- map
      local keys, values: Type, Type

      for i, child in ipairs(children) do
         local ck = child.kname
         local cktype = child.ktype
         local n = node[i].key.constnum
         local b: boolean = nil
         if cktype is BooleanType then
            b = (node[i].key.tk == "true")
         end

         local key: CheckableKey = ck or n or b
         self.errs:check_redeclared_key(node[i], nil, seen_keys, key)

         local uvtype = resolve_tuple(child.vtype)
         if ck then
            is_record = true
            if not fields then
               fields = {}
               field_order = {}
            end
            fields[ck] = uvtype
            table.insert(field_order, ck)
         elseif cktype is NumericType then
            is_array = true
            if not is_not_tuple then
               is_tuple = true
            end
            if not types then
               types = {}
            end

            if node[i].key_parsed == "implicit" then
               local cv = child.vtype
               if i == #children and cv is TupleType then
                  -- need to expand last item in an array (e.g { 1, 2, 3, f() })
                  for _, c in ipairs(cv.tuple) do
                     elements = self:expand_type(node, elements, c)
                     types[last_array_idx] = resolve_tuple(c)
                     last_array_idx = last_array_idx + 1
                  end
               else
                  types[last_array_idx] = uvtype
                  last_array_idx = last_array_idx + 1
                  elements = self:expand_type(node, elements, uvtype)
               end
            else -- explicit
               if not is_positive_int(n) then
                  elements = self:expand_type(node, elements, uvtype)
                  is_not_tuple = true
               elseif n then
                  types[n as integer] = uvtype
                  if n > largest_array_idx then
                     largest_array_idx = n as integer
                  end
                  elements = self:expand_type(node, elements, uvtype)
               end
            end

            if last_array_idx > largest_array_idx then
               largest_array_idx = last_array_idx
            end
            if not elements then
               is_array = false
            end
         else
            is_map = true
            keys = self:expand_type(node, keys, drop_constant_value(cktype))
            values = self:expand_type(node, values, uvtype)
         end
      end

      local t: Type

      if is_array and is_map then
         self.errs:add(node, "cannot determine type of table literal")
         t = a_map(node,
            self:expand_type(node, keys, a_type(node, "integer", {})),
            self:expand_type(node, values, elements)
         )
      elseif is_record and is_array then
         t = a_type(node, "record", {
            fields = fields,
            field_order = field_order,
            elements = elements,
            interface_list = {
               an_array(node, elements)
            }
         } as RecordType)
         -- TODO adopt logic from self:is_array below when we accept tupletable as an interface
      elseif is_record and is_map then
         if keys is StringType then
            for _, fname in ipairs(field_order) do
               values = self:expand_type(node, values, fields[fname])
            end
            t = a_map(node, keys, values)
         else
            self.errs:add(node, "cannot determine type of table literal")
         end
      elseif is_array then
         local pure_array = true
         if not is_not_tuple then
            local last_t: Type
            for _, current_t in pairs(types as {integer:Type}) do
               if last_t then
                  if not self:same_type(last_t, current_t) then
                     pure_array = false
                     break
                  end
               end
               last_t = current_t
            end
         end
         if pure_array then
            t = an_array(node, elements)
            t.consttypes = types
            t.inferred_len = largest_array_idx - 1
         else
            t = a_type(node, "tupletable", { inferred_at = node }) as TupleTableType
            t.types = types
         end
      elseif is_record then
         t = a_type(node, "record", {
            fields = fields,
            field_order = field_order,
         } as RecordType)
      elseif is_map then
         t = a_map(node, keys, values)
      elseif is_tuple then
         t = a_type(node, "tupletable", { inferred_at = node }) as TupleTableType
         t.types = types
         if not types or #types == 0 then
            self.errs:add(node, "cannot determine type of tuple elements")
         end
      end

      if not t then
         t = a_type(node, "emptytable", {})
      end

      return type_at(node, t)
   end

   function TypeChecker:infer_negation_of_if_blocks(w: Where, ifnode: Node, n: integer)
      local f = facts_not(w, ifnode.if_blocks[1].exp.known)
      for e = 2, n do
         local b = ifnode.if_blocks[e]
         if b.exp then
            f = facts_and(w, f, facts_not(w, b.exp.known))
         end
      end
      self:apply_facts(w, f)
   end

   function TypeChecker:determine_declaration_type(var: Node, node: Node, infertypes: TupleType, i: integer): boolean, Type, boolean
      local ok = true
      local name = var.tk
      local infertype = infertypes and infertypes.tuple[i]
      if self.feat_lax and infertype and infertype.typename == "nil" then
         infertype = nil
      end

      local decltype = node.decltuple and node.decltuple.tuple[i]
      if decltype then
         local rdecltype = self:to_structural(decltype)
         if rdecltype is InvalidType then
            decltype = rdecltype
         end

         if infertype then
            local w = node.exps and node.exps[i] or node.vars[i]
            ok = self:assert_is_a(w, infertype, decltype, context_name[node.kind], name)
         end
      else
         if infertype then
            if infertype is UnresolvableTypeArgType then
               ok = false
               infertype = self.errs:invalid_at(node.vars[i], "cannot infer declaration type; an explicit type annotation is necessary")
            elseif infertype is FunctionType and infertype.is_method then
               -- If we assign a method to a variable, e.g:
               -- `local myfunc = myobj.dothing`,
               -- the variable should not be treated as a method
               infertype = shallow_copy_new_type(infertype)
               infertype.is_method = false
            end
         end
      end

      if var.attribute == "total" then
         local rd = decltype and self:to_structural(decltype)
         if rd and (rd.typename ~= "map" and rd.typename ~= "record") then
            self.errs:add(var, "attribute <total> only applies to maps and records")
            ok = false
         elseif not infertype then
            self.errs:add(var, "variable declared <total> does not declare an initialization value")
            ok = false
         else
            local valnode = node.exps[i]
            if not valnode or valnode.kind ~= "literal_table" then
               self.errs:add(var, "attribute <total> only applies to literal tables")
               ok = false
            else
               if not valnode.is_total then
                  local missing = ""
                  if valnode.missing then
                     missing = " (missing: " .. table.concat(valnode.missing, ", ") .. ")"
                  end
                  local ri = self:to_structural(infertype)
                  if ri is MapType then
                     self.errs:add(var, "map variable declared <total> does not declare values for all possible keys" .. missing)
                     ok = false
                  elseif ri is RecordType then
                     self.errs:add(var, "record variable declared <total> does not declare values for all fields" .. missing)
                     ok = false
                  end
               end
            end
         end
      end

      local t = decltype or infertype
      if t == nil then
         t = self:missing_initializer(node, i, name)
      elseif t is EmptyTableType then
         t.declared_at = node
         t.assigned_to = name
      elseif t is ArrayLikeType then
         t.inferred_len = nil
      elseif t is NominalType then
         self:resolve_nominal(t)
      end

      return ok, t, infertype ~= nil
   end

   function TypeChecker:get_typedecl(value: Node): InvalidOrTypeDeclType, Variable
      if value.kind == "op"
         and value.op.op == "@funcall"
         and value.e1.kind == "variable"
         and value.e1.tk == "require"
      then
         local t = special_functions["require"](self, value, self:find_var_type("require"), a_tuple(value.e2, { a_type(value.e2[1], "string", {}) }), 0)

         -- FIXME why is this ': Type' annotation needed?
         local ty: Type = t is TupleType and t.tuple[1] or t

         ty = (ty is TypeAliasType) and self:resolve_typealias(ty) or ty
         local td = (ty is TypeDeclType) and ty or a_type(value, "typedecl", { def = ty } as TypeDeclType)
         return td
      else
         local newtype = value.newtype
         if newtype is TypeAliasType then
            local aliasing = self:find_var(newtype.alias_to.names[1], "use_type")
            return self:resolve_typealias(newtype), aliasing
         elseif newtype is TypeDeclType then
            return newtype, nil
         end
      end
   end

   local function total_check_key(key: CheckableKey, seen_keys: {CheckableKey:Where}, is_total: boolean, missing: {string}): boolean, {string}
      if not seen_keys[key] then
         missing = missing or {}
         table.insert(missing, tostring(key))
         return false, missing
      end
      return is_total, missing
   end

   local function total_record_check(t: RecordLikeType, seen_keys: {CheckableKey:Where}): boolean, {string}
      local is_total = true
      local missing: {string}
      for _, key in ipairs(t.field_order) do
         local ftype = t.fields[key]
         if not (ftype is TypeDeclType or ftype is TypeAliasType or (ftype is FunctionType and ftype.is_record_function)) then
            is_total, missing = total_check_key(key, seen_keys, is_total, missing)
         end
      end
      return is_total, missing
   end

   local function total_map_check(keys: Type, seen_keys: {CheckableKey:Where}): boolean, {string}
      local is_total = true
      local missing: {string}
      if keys is EnumType then
         for _, key in ipairs(sorted_keys(keys.enumset)) do
            is_total, missing = total_check_key(key, seen_keys, is_total, missing)
         end
      elseif keys.typename == "boolean" then
         for _, key in ipairs({ true, false }) do
            is_total, missing = total_check_key(key, seen_keys, is_total, missing)
         end
      else
         is_total = false
      end
      return is_total, missing
   end

   local enum MissingError
      "missing"
   end

   function TypeChecker:check_assignment(varnode: Node, vartype: Type, valtype: Type): Type, Type, MissingError
      local varname = varnode.tk
      local attr = varnode.attribute

      if varname then
         if self:widen_back_var(varname) then
            vartype, attr = self:find_var_type(varname)
            if not vartype then
               self.errs:add(varnode, "unknown variable")
               return nil
            end
         end
      end
      if attr == "close" or attr == "const" or attr == "total" then
         self.errs:add(varnode, "cannot assign to <" .. attr .. "> variable")
         return nil
      end

      local var = self:to_structural(vartype)
      if var is TypeDeclType or var is TypeAliasType then
         self.errs:add(varnode, "cannot reassign a type")
         return nil
      end

      if not valtype then
         self.errs:add(varnode, "variable is not being assigned a value")
         return nil, nil, "missing"
      end

      self:assert_is_a(varnode, valtype, vartype, "in assignment")

      local val = self:to_structural(valtype)

      return var, val
   end

   local function discard_tuple(node: Node, t: Type, b: Type): Type
      if b.typename == "tuple" then
         node.discarded_tuple = true
      end
      return resolve_tuple(t)
   end

   local visit_node: Visitor<TypeChecker, NodeKind, Node, Type> = {}

   visit_node.cbs = {
      ["statements"] = {
         before = function(self: TypeChecker, node: Node)
            self:begin_scope(node)
         end,
         after = function(self: TypeChecker, node: Node, _children: {Type}): Type
            -- if at the top level
            if #self.st == 2 then
               self.errs:fail_unresolved_labels(self.st[2])
               self.errs:fail_unresolved_nominals(self.st[2], self.st[1])
            end

            if not node.is_repeat then
               self:end_scope(node)
            end

            return NONE
         end
      },
      ["local_type"] = {
         before = function(self: TypeChecker, node: Node)
            local name = node.var.tk
            local resolved, aliasing = self:get_typedecl(node.value)
            local var = self:add_var(node.var, name, resolved, node.var.attribute)
            if aliasing then
               var.aliasing = aliasing
            end
         end,
         after = function(self: TypeChecker, node: Node, _children: {Type}): Type
            self:dismiss_unresolved(node.var.tk)
            return NONE
         end,
      },
      ["global_type"] = {
         before = function(self: TypeChecker, node: Node)
            local global_scope = self.st[1]
            local name = node.var.tk
            if node.value then
               local resolved, aliasing = self:get_typedecl(node.value)
               local added = self:add_global(node.var, name, resolved)
               if resolved is InvalidType then
                  return
               end
               node.value.newtype = resolved
               if aliasing then
                  added.aliasing = aliasing
               end

               if global_scope.pending_global_types[name] then
                  global_scope.pending_global_types[name] = nil
               end
            else
               if not self.st[1].vars[name] then
                  global_scope.pending_global_types[name] = true
               end
            end
         end,
         after = function(self: TypeChecker, node: Node, _children: {Type}): Type
            self:dismiss_unresolved(node.var.tk)
            return NONE
         end,
      },
      ["local_declaration"] = {
         before = function(self: TypeChecker, node: Node)
            if self.collector then
               for _, var in ipairs(node.vars) do
                  self.collector.reserve_symbol_list_slot(var)
               end
            end
         end,
         before_exp = set_expected_types_to_decltuple,
         after = function(self: TypeChecker, node: Node, children: {Type}): Type
            local valtuple = children[3] as TupleType -- may be nil

            local encountered_close = false
            local infertypes = get_assignment_values(node, valtuple, #node.vars)
            for i, var in ipairs(node.vars) do
               if var.attribute == "close" then
                  if self.gen_target == "5.4" then
                     if encountered_close then
                        self.errs:add(var, "only one <close> per declaration is allowed")
                     else
                        encountered_close = true
                     end
                  else
                     self.errs:add(var, "<close> attribute is only valid for Lua 5.4 (current target is " .. tostring(self.gen_target) .. ")")
                  end
               end

               local ok, t = self:determine_declaration_type(var, node, infertypes, i)

               if var.attribute == "close" then
                  if not type_is_closable(t) then
                     self.errs:add(var, "to-be-closed variable " .. var.tk .. " has a non-closable type %s", t)
                  elseif node.exps and node.exps[i] and expr_is_definitely_not_closable(node.exps[i]) then
                     self.errs:add(var, "to-be-closed variable " .. var.tk .. " assigned a non-closable value")
                  end
               end

               assert(var)
               self:add_var(var, var.tk, t, var.attribute, is_localizing_a_variable(node, i) and "declaration")

               local infertype = infertypes.tuple[i]
               if ok and infertype then
                  local w = node.exps[i] or node.exps

                  local rt = self:to_structural(t)
                  if (not rt is EnumType)
                     and ((not t is NominalType) or (rt is UnionType))
                     and not self:same_type(t, infertype)
                  then
                     t = self:infer_at(w, infertype)
                     self:add_var(w, var.tk, t, "const", "narrowed_declaration")
                  end
               end

               if self.collector then
                  self.collector.store_type(var.y, var.x, t)
               end

               self:dismiss_unresolved(var.tk)
            end
            return NONE
         end,
      },
      ["global_declaration"] = {
         before_exp = set_expected_types_to_decltuple,
         after = function(self: TypeChecker, node: Node, children: {Type}): Type
            local valtuple = children[3] as TupleType -- may be nil

            local infertypes = get_assignment_values(node, valtuple, #node.vars)
            for i, var in ipairs(node.vars) do
               local _, t, is_inferred = self:determine_declaration_type(var, node, infertypes, i)

               if var.attribute == "close" then
                  self.errs:add(var, "globals may not be <close>")
               end

               self:add_global(var, var.tk, t, is_inferred)

               self:dismiss_unresolved(var.tk)
            end
            return NONE
         end,
      },
      ["assignment"] = {
         before_exp = set_expected_types_to_decltuple,
         after = function(self: TypeChecker, node: Node, children: {Type}): Type
            local vartuple = children[1]
            assert(vartuple is TupleType)
            local vartypes = vartuple.tuple
            local valtuple = children[3]
            assert(valtuple is TupleType)
            local valtypes = get_assignment_values(node, valtuple, #vartypes)
            for i, vartype in ipairs(vartypes) do
               local varnode = node.vars[i]
               local varname = varnode.tk
               local valtype = valtypes.tuple[i]
               local rvar, rval, err = self:check_assignment(varnode, vartype, valtype)
               if err == "missing" then
                  if #node.exps == 1 and node.exps[1].kind == "op" and node.exps[1].op.op == "@funcall" then
                     local msg = #valtuple.tuple == 1
                                 and "only 1 value is returned by the function"
                                 or ("only " .. #valtuple.tuple .. " values are returned by the function")
                     self.errs:add_warning("hint", varnode, msg)
                  end
               end

               if rval and rvar then
                  -- assigning a function
                  if rval is FunctionType then
                     self:widen_all_unions()
                  end

                  if varname and (rvar is UnionType or rvar is InterfaceType) then
                     -- narrow unions and interfaces
                     self:add_var(varnode, varname, rval, nil, "narrow")
                  end

                  if self.collector then
                     self.collector.store_type(varnode.y, varnode.x, valtype)
                  end
               end
            end

            return NONE
         end,
      },
      ["if"] = {
         after = function(self: TypeChecker, node: Node, _children: {Type}): Type
            local all_return = true
            for _, b in ipairs(node.if_blocks) do
               if not b.block_returns then
                  all_return = false
                  break
               end
            end
            if all_return then
               node.block_returns = true
               self:infer_negation_of_if_blocks(node, node, #node.if_blocks)
            end

            return NONE
         end,
      },
      ["if_block"] = {
         before = function(self: TypeChecker, node: Node)
            self:begin_scope(node)
            if node.if_block_n > 1 then
               self:infer_negation_of_if_blocks(node, node.if_parent, node.if_block_n - 1)
            end
            if node.exp then
               node.exp.expected = a_type(node, "boolean", {})
            end
         end,
         before_statements = function(self: TypeChecker, node: Node)
            if node.exp then
               self:apply_facts(node.exp, node.exp.known)
            end
         end,
         after = function(self: TypeChecker, node: Node, _children: {Type}): Type
            self:end_scope(node)

            if #node.body > 0 and node.body[#node.body].block_returns then
               node.block_returns = true
            end

            return NONE
         end
      },
      ["while"] = {
         before = function(self: TypeChecker, node: Node)
            -- widen all narrowed variables because we don't calculate a fixpoint yet
            self:widen_all_unions(node)
            node.exp.expected = a_type(node, "boolean", {})
         end,
         before_statements = function(self: TypeChecker, node: Node)
            self:begin_scope(node)
            self:apply_facts(node.exp, node.exp.known)
         end,
         after = end_scope_and_none_type,
      },
      ["label"] = {
         before = function(self: TypeChecker, node: Node)
            -- widen all narrowed variables because we don't calculate a fixpoint yet
            self:widen_all_unions()
            local label_id = node.label
            do
               local scope = self.st[#self.st]
               scope.labels = scope.labels or {}
               if scope.labels[label_id] then
                  self.errs:add(node, "label '" .. node.label .. "' already defined")
               else
                  scope.labels[label_id] = node
               end
            end

            --for i = #self.st, 1, -1 do
               local scope = self.st[#self.st]
               if scope.pending_labels and scope.pending_labels[label_id] then
                  node.used_label = true
                  scope.pending_labels[label_id] = nil
                  --break
               end
            --end
         end,
         after = function(): Type
            return NONE
         end
      },
      ["goto"] = {
         after = function(self: TypeChecker, node: Node, _children: {Type}): Type
            local label_id = node.label
            local found_label: Node
            for i = #self.st, 1, -1 do
               local scope = self.st[i]
               if scope.labels and scope.labels[label_id] then
                  found_label = scope.labels[label_id]
                  break
               end
            end

            if found_label then
               found_label.used_label = true
            else
               local scope = self.st[#self.st]
               scope.pending_labels = scope.pending_labels or {}
               scope.pending_labels[label_id] = scope.pending_labels[label_id] or {}
               table.insert(scope.pending_labels[label_id], node)
            end

            return NONE
         end,
      },
      ["repeat"] = {
         before = function(self: TypeChecker, node: Node)
            -- widen all narrowed variables because we don't calculate a fixpoint yet
            self:widen_all_unions(node)
            node.exp.expected = a_type(node, "boolean", {})
         end,
         -- only end scope after checking `until`, `statements` in repeat body has is_repeat == true
         after = end_scope_and_none_type,
      },
      ["forin"] = {
         before = function(self: TypeChecker, node: Node)
            self:begin_scope(node)
         end,
         before_statements = function(self: TypeChecker, node: Node, children: {Type})
            local exptuple = children[2]
            assert(exptuple is TupleType)
            local exptypes = exptuple.tuple

            local exp1 = node.exps[1]
            if #exptypes < 1 then
               self.errs:invalid_at(exp1, "expression in 'for' statement does not return any values")
               return
            end

            self:widen_all_unions(node)

            local args = a_tuple(node.exps, {
               node.exps[2] and exptypes[2],
               node.exps[3] and exptypes[3]
            })
            local exp1type = self:resolve_for_call(exptypes[1], args, false)

            if exp1type is PolyType then
               local _: Type
               _, exp1type = self:type_check_function_call(exp1, exp1type, args, 0, exp1, {node.exps[2], node.exps[3]})
            end

            if exp1type is FunctionType then
               -- TODO: check that exp1's arguments match with (optional self, explicit iterator, state)
               local last: Type
               local rets = exp1type.rets
               for i, v in ipairs(node.vars) do
                  local r = rets.tuple[i]
                  if not r then
                     if rets.is_va then
                        r = last
                     else
                        r = self.feat_lax and an_unknown(v) or an_invalid(v)
                     end
                  end
                  self:add_var(v, v.tk, r)

                  if self.collector then
                     self.collector.store_type(v.y, v.x, r)
                  end

                  last = r
               end
               local nrets = #rets.tuple
               if (not self.feat_lax) and (not rets.is_va and #node.vars > nrets) then
                  local at = node.vars[nrets + 1]
                  local n_values = nrets == 1 and "1 value" or tostring(nrets) .. " values"
                  self.errs:add(at, "too many variables for this iterator; it produces " .. n_values)
               end
            else
               if not (self.feat_lax and is_unknown(exp1type)) then
                  self.errs:add(exp1, "expression in for loop does not return an iterator")
               end
            end
         end,
         after = end_scope_and_none_type,
      },
      ["fornum"] = {
         before_statements = function(self: TypeChecker, node: Node, children: {Type})
            self:widen_all_unions(node)
            self:begin_scope(node)
            local from_t = self:to_structural(resolve_tuple(children[2]))
            local to_t = self:to_structural(resolve_tuple(children[3]))
            local step_t = children[4] and self:to_structural(children[4])
            local typename: TypeName = (from_t.typename == "integer" and
                                        to_t.typename == "integer" and
                                        (not step_t or step_t.typename == "integer"))
                                       and "integer"
                                       or  "number"
            self:add_var(node.var, node.var.tk, a_type(node.var, typename, {}))
         end,
         after = end_scope_and_none_type,
      },
      ["return"] = {
         before = function(self: TypeChecker, node: Node)
            local rets = self:find_var_type("@return")
            if rets and rets is TupleType then
               for i, exp in ipairs(node.exps) do
                  exp.expected = rets.tuple[i]
               end
            end
         end,
         after = function(self: TypeChecker, node: Node, children: {Type}): Type
            local got = children[1]
            assert(got is TupleType)
            local got_t = got.tuple
            local n_got = #got_t

            node.block_returns = true
            local expected = self:find_var_type("@return") as TupleType
            if not expected then
               -- if at the toplevel
               expected = self:infer_at(node, got)
               self.module_type = drop_constant_value(self:to_structural(resolve_tuple(expected)))
               self.st[2].vars["@return"] = { t = expected }
            end
            local expected_t = expected.tuple

            local what = "in return value"
            if expected.inferred_at then
               what = what .. inferred_msg(expected)
            end

            local n_expected = #expected_t
            local vatype: Type
            if n_expected > 0 then
               vatype = expected.is_va and expected.tuple[n_expected]
            end

            if n_got > n_expected and (not self.feat_lax) and not vatype then
               self.errs:add(node, what ..": excess return values, expected " .. n_expected .. " %s, got " .. n_got .. " %s", expected, got)
            end

            if n_expected > 1
            and #node.exps == 1
            and node.exps[1].kind == "op"
            and (node.exps[1].op.op == "and" or node.exps[1].op.op == "or")
            and node.exps[1].discarded_tuple then
               self.errs:add_warning("hint", node.exps[1].e2, "additional return values are being discarded due to '" .. node.exps[1].op.op .. "' expression; suggest parentheses if intentional")
            end

            for i = 1, n_got do
               local e = expected_t[i] or vatype
               if e then
                  e = resolve_tuple(e)
                  local w = (node.exps[i] and node.exps[i].x)
                            and node.exps[i]
                            or  node.exps
                  assert(w and w.x)
                  self:assert_is_a(w, got_t[i], e, what)
               end
            end

            return NONE
         end,
      },
      ["variable_list"] = {
         after = function(self: TypeChecker, node: Node, children: {Type}): Type
            local tuple = a_tuple(node, children)

            tuple = flatten_tuple(tuple)

            for i, t in ipairs(tuple.tuple) do
               local ok, err = ensure_not_abstract(t)
               if not ok then
                  self.errs:add(node[i], err)
               end
            end

            return tuple
         end,
      },
      ["literal_table"] = {
         before = function(self: TypeChecker, node: Node)
            if node.expected then
               local decltype = self:to_structural(node.expected)

               if decltype is TypeVarType and decltype.constraint then
                  decltype = resolve_typedecl(self:to_structural(decltype.constraint))
               end

               if decltype is TupleTableType then
                  for _, child in ipairs(node) do
                     local n = child.key.constnum
                     if n and is_positive_int(n) then
                        child.value.expected = decltype.types[n as integer]
                     end
                  end
               elseif decltype is ArrayLikeType then
                  for _, child in ipairs(node) do
                     if child.key.constnum then
                        child.value.expected = decltype.elements
                     end
                  end
               elseif decltype is MapType then
                  for _, child in ipairs(node) do
                     child.key.expected = decltype.keys
                     child.value.expected = decltype.values
                  end
               end

               if decltype is RecordLikeType then
                  for _, child in ipairs(node) do
                     if child.key.conststr then
                        child.value.expected = decltype.fields[child.key.conststr]
                     end
                  end
               end
            end
         end,
         after = function(self: TypeChecker, node: Node, children: {LiteralTableItemType}): Type
            node.known = FACT_TRUTHY

            if not node.expected then
               return infer_table_literal(self, node, children)
            end

            local decltype = self:to_structural(node.expected)

            local constraint: Type
            if decltype is TypeVarType and decltype.constraint then
               constraint = resolve_typedecl(decltype.constraint)
               decltype = self:to_structural(constraint)
            end

            if decltype is UnionType then
               local single_table_type: Type
               local single_table_rt: Type

               for _, t in ipairs(decltype.types) do
                  local rt = self:to_structural(t)
                  if is_lua_table_type(rt) then
                     if single_table_type then
                        -- multiple table types in union, give up
                        single_table_type = nil
                        single_table_rt = nil
                        break
                     end

                     single_table_type = t
                     single_table_rt = rt
                  end
               end

               if single_table_type then
                  node.expected = single_table_type
                  decltype = single_table_rt
               end
            end

            if not is_lua_table_type(decltype) then
               return infer_table_literal(self, node, children)
            end

            local force_array: Type = nil

            local seen_keys: {CheckableKey:Where} = {}

            for i, child in ipairs(children) do
               local cvtype = resolve_tuple(child.vtype)
               local ck = child.kname
               local cktype = child.ktype
               local n = node[i].key.constnum
               local b: boolean = nil
               if cktype is BooleanType then
                  b = (node[i].key.tk == "true")
               end
               self.errs:check_redeclared_key(node[i], node, seen_keys, ck or n or b)
               if decltype is RecordLikeType and ck then
                  local df = decltype.fields[ck]
                  if not df then
                     self.errs:add_in_context(node[i], node, "unknown field " .. ck)
                  else
                     if df is TypeDeclType or df is TypeAliasType then
                        self.errs:add_in_context(node[i], node, "cannot reassign a type")
                     else
                        self:assert_is_a(node[i], cvtype, df, "in record field", ck)
                     end
                  end
               elseif decltype is TupleTableType and cktype is NumericType then
                  local dt = decltype.types[n as integer]
                  if not n then
                     self.errs:add_in_context(node[i], node, "unknown index in tuple %s", decltype)
                  elseif not dt then
                     self.errs:add_in_context(node[i], node, "unexpected index " .. n .. " in tuple %s", decltype)
                  else
                     self:assert_is_a(node[i], cvtype, dt, node, "in tuple: at index " .. tostring(n))
                  end
               elseif decltype is ArrayLikeType and cktype is NumericType then
                  local cv = child.vtype
                  if cv is TupleType and i == #children and node[i].key_parsed == "implicit" then
                     -- need to expand last item in an array (e.g { 1, 2, 3, f() })
                     for ti, tt in ipairs(cv.tuple) do
                        self:assert_is_a(node[i], tt, decltype.elements, node, "expected an array: at index " .. tostring(i + ti - 1))
                     end
                  else
                     self:assert_is_a(node[i], cvtype, decltype.elements, node, "expected an array: at index " .. tostring(n))
                  end
               elseif node[i].key_parsed == "implicit" then
                  if decltype is MapType then
                     self:assert_is_a(node[i].key, a_type(node[i].key, "integer", {}), decltype.keys, node, "in map key")
                     self:assert_is_a(node[i].value, cvtype, decltype.values, node, "in map value")
                  end
                  force_array = self:expand_type(node[i], force_array, child.vtype)
               elseif decltype is MapType then
                  force_array = nil
                  self:assert_is_a(node[i].key, cktype, decltype.keys, node, "in map key")
                  self:assert_is_a(node[i].value, cvtype, decltype.values, node, "in map value")
               else
                  self.errs:add_in_context(node[i], node, "unexpected key of type %s in table of type %s", cktype, decltype)
               end
            end

            local t: Type
            if force_array then
               t = self:infer_at(node, an_array(node, force_array))
            else
               t = self:resolve_typevars_at(node, node.expected)
            end

            if decltype is RecordType then
               local rt = self:to_structural(t)
               if rt is RecordType then
                  node.is_total, node.missing = total_record_check(decltype, seen_keys)
               end
            elseif decltype is MapType then
               local rt = self:to_structural(t)
               if rt is MapType then
                  local rk = self:to_structural(rt.keys)
                  node.is_total, node.missing = total_map_check(rk, seen_keys)
               end
            end

            if constraint then
               return constraint
            end

            return t
         end,
      },
      ["literal_table_item"] = {
         after = function(self: TypeChecker, node: Node, children: {Type}): Type
            local kname = node.key.conststr
            local ktype = children[1]
            local vtype = children[2]
            if node.itemtype then
               vtype = node.itemtype
               self:assert_is_a(node.value, children[2], node.itemtype, node)
            end
            if vtype is FunctionType and vtype.is_method then
               -- If we assign a method to a table item, e.g.
               -- `local a = { myfunc = myobj.dothing }`
               -- the table item should not be treated as a method
               vtype = shallow_copy_new_type(vtype)
               vtype.is_method = false
            end
            return a_type(node, "literal_table_item", {
               kname = kname,
               ktype = ktype,
               vtype = vtype,
            } as LiteralTableItemType)
         end,
      },
      ["local_function"] = {
         before = function(self: TypeChecker, node: Node)
            self:widen_all_unions()
            if self.collector then
               self.collector.reserve_symbol_list_slot(node)
            end
            self:begin_scope(node)
         end,
         before_statements = function(self: TypeChecker, node: Node, children: {Type})
            local args = children[2]
            assert(args is TupleType)

            self:add_internal_function_variables(node, args)
            self:add_function_definition_for_recursion(node, args)
         end,
         after = function(self: TypeChecker, node: Node, children: {Type}): Type
            local args = children[2]
            assert(args is TupleType)
            local rets = children[3]
            assert(rets is TupleType)

            self:end_function_scope(node)

            local t = self:ensure_fresh_typeargs(a_function(node, {
               min_arity = node.min_arity,
               typeargs = node.typeargs,
               args = args,
               rets = self.get_rets(rets),
            }))

            self:add_var(node, node.name.tk, t)
            return t
         end,
      },
      ["local_macroexp"] = {
         before = function(self: TypeChecker, node: Node)
            self:widen_all_unions()
            if self.collector then
               self.collector.reserve_symbol_list_slot(node)
            end
            self:begin_scope(node)
         end,
         after = function(self: TypeChecker, node: Node, children: {Type}): Type
            local args = children[2]
            assert(args is TupleType)
            local rets = children[3]
            assert(rets is TupleType)

            self:end_function_scope(node)

            self:check_macroexp_arg_use(node.macrodef)

            local t = self:ensure_fresh_typeargs(a_function(node, {
               min_arity = node.macrodef.min_arity,
               typeargs = node.typeargs,
               args = args,
               rets = self.get_rets(rets),
               macroexp = node.macrodef,
            }))

            self:add_var(node, node.name.tk, t)
            return t
         end,
      },
      ["global_function"] = {
         before = function(self: TypeChecker, node: Node)
            self:widen_all_unions()
            self:begin_scope(node)
            if node.implicit_global_function then
               local typ = self:find_var_type(node.name.tk)
               if typ then
                  if typ is FunctionType then
                     node.is_predeclared_local_function = true
                  elseif not self.feat_lax then
                     self.errs:add(node, "cannot declare function: type of " .. node.name.tk .. " is %s", typ)
                  end
               elseif not self.feat_lax then
                  self.errs:add(node, "functions need an explicit 'local' or 'global' annotation")
               end
            end
         end,
         before_statements = function(self: TypeChecker, node: Node, children: {Type})
            local args = children[2]
            assert(args is TupleType)

            self:add_internal_function_variables(node, args)
            self:add_function_definition_for_recursion(node, args)
         end,
         after = function(self: TypeChecker, node: Node, children: {Type}): Type
            local args = children[2]
            assert(args is TupleType)
            local rets = children[3]
            assert(rets is TupleType)

            self:end_function_scope(node)
            if node.is_predeclared_local_function then
               return NONE
            end

            self:add_global(node, node.name.tk, self:ensure_fresh_typeargs(a_function(node, {
               min_arity = node.min_arity,
               typeargs = node.typeargs,
               args = args,
               rets = self.get_rets(rets),
            })))

            return NONE
         end,
      },
      ["record_function"] = {
         before = function(self: TypeChecker, node: Node)
            self:widen_all_unions()
            self:begin_scope(node)
         end,
         before_arguments = function(self: TypeChecker, _node: Node, children: {Type})
            local rtype = self:to_structural(resolve_typedecl(children[1]))

            -- add type arguments from the record implicitly
            if rtype is RecordLikeType and rtype.typeargs then
               for _, typ in ipairs(rtype.typeargs) do
                  self:add_var(nil, typ.typearg, a_type(typ, "typearg", {
                     typearg = typ.typearg,
                     constraint = typ.constraint,
                  } as TypeArgType))
               end
            end
         end,
         before_statements = function(self: TypeChecker, node: Node, children: {Type})
            local args = children[3]
            assert(args is TupleType)
            local rets = children[4]
            assert(rets is TupleType)

            local rtype = self:to_structural(resolve_typedecl(children[1]))

            if self.feat_lax and rtype is UnknownType then
               return
            end

            if rtype is EmptyTableType then
               edit_type(rtype, rtype, "record")
               local r = rtype as RecordType
               r.fields = {}
               r.field_order = {}
            end

            if not rtype is RecordLikeType then
               self.errs:add(node, "not a record: %s", rtype)
               return
            end

            local selftype = self:get_self_type(node.fn_owner)
            if node.is_method then
               if not selftype then
                  self.errs:add(node, "could not resolve type of self")
                  return
               end
               args.tuple[1] = selftype
               self:add_var(nil, "self", selftype)
            end

            local fn_type = self:ensure_fresh_typeargs(a_function(node, {
               min_arity = node.min_arity,
               is_method = node.is_method,
               typeargs = node.typeargs,
               args = args,
               rets = self.get_rets(rets),
               is_record_function = true,
            }))

            local open_t, open_v, owner_name = self:find_record_to_extend(node.fn_owner)
            local open_k = owner_name .. "." .. node.name.tk
            local rfieldtype = rtype.fields[node.name.tk]
            if rfieldtype then
               rfieldtype = self:to_structural(rfieldtype)

               if open_v and open_v.implemented and open_v.implemented[open_k] then
                  self.errs:redeclaration_warning(node)
               end

               local ok, err = self:same_type(fn_type, rfieldtype)
               if not ok then
                  if rfieldtype is PolyType then
                     self.errs:add_prefixing(node, err, "type signature does not match declaration: field has multiple function definitions (such polymorphic declarations are intended for Lua module interoperability): ")
                     return
                  end

                  local shortname = selftype and show_type(selftype) or owner_name
                  local msg = "type signature of '" .. node.name.tk .. "' does not match its declaration in " .. shortname .. ": "
                  self.errs:add_prefixing(node, err, msg)
                  return
               end
            else
               if self.feat_lax or rtype == open_t then
                  rtype.fields[node.name.tk] = fn_type
                  table.insert(rtype.field_order, node.name.tk)
               else
                  self.errs:add(node, "cannot add undeclared function '" .. node.name.tk .. "' outside of the scope where '" .. owner_name .. "' was originally declared")
                  return
               end

            end

            if open_v then
               if not open_v.implemented then
                  open_v.implemented = {}
               end
               open_v.implemented[open_k] = true
            end

            self:add_internal_function_variables(node, args)
         end,
         after = function(self: TypeChecker, node: Node, _children: {Type}): Type
            self:end_function_scope(node)
            return NONE
         end,
      },
      ["function"] = {
         before = function(self: TypeChecker, node: Node)
            self:widen_all_unions(node)
            self:begin_scope(node)
         end,
         before_statements = function(self: TypeChecker, node: Node, children: {Type})
            local args = children[1]
            assert(args is TupleType)

            self:add_internal_function_variables(node, args)
         end,
         after = function(self: TypeChecker, node: Node, children: {Type}): Type
            local args = children[1]
            assert(args is TupleType)
            local rets = children[2]
            assert(rets is TupleType)

            self:end_function_scope(node)
            return self:ensure_fresh_typeargs(a_function(node, {
               min_arity = node.min_arity,
               typeargs = node.typeargs,
               args = args,
               rets = self.get_rets(rets),
            }))
         end,
      },
      ["macroexp"] = {
         before = function(self: TypeChecker, node: Node)
            self:widen_all_unions(node)
            self:begin_scope(node)
         end,
         before_exp = function(self: TypeChecker, node: Node, children: {Type})
            local args = children[1]
            assert(args is TupleType)

            self:add_internal_function_variables(node, args)
         end,
         after = function(self: TypeChecker, node: Node, children: {Type}): Type
            local args = children[1]
            assert(args is TupleType)
            local rets = children[2]
            assert(rets is TupleType)

            self:end_function_scope(node)
            return self:ensure_fresh_typeargs(a_function(node, {
               min_arity = node.min_arity,
               typeargs = node.typeargs,
               args = args,
               rets = rets,
            }))
         end,
      },
      ["cast"] = {
         after = function(_self: TypeChecker, node: Node, _children: {Type}): Type
            return node.casttype
         end
      },
      ["paren"] = {
         before = function(_self: TypeChecker, node: Node)
            node.e1.expected = node.expected
         end,
         after = function(_self: TypeChecker, node: Node, children: {Type}): Type
            node.known = node.e1 and node.e1.known
            return resolve_tuple(children[1])
         end,
      },
      ["op"] = {
         before = function(self: TypeChecker, node: Node)
            self:begin_scope()
            if node.expected then
               if node.op.op == "and" then
                  node.e2.expected = node.expected
               elseif node.op.op == "or" then
                  node.e1.expected = node.expected
                  if not (node.e2.kind == "literal_table" and #node.e2 == 0) then
                     node.e2.expected = node.expected
                  end
               end
            end
         end,
         before_e2 = function(self: TypeChecker, node: Node, children: {Type})
            local e1type = children[1]

            if node.op.op == "and" then
               self:apply_facts(node, node.e1.known)
            elseif node.op.op == "or" then
               self:apply_facts(node, facts_not(node, node.e1.known))
            elseif node.op.op == "@funcall" then
               if e1type is FunctionType then
                  local argdelta = (node.e1.op and node.e1.op.op == ":") and -1 or 0
                  if node.expected then
                     -- this forces typevars in function return types
                     self:is_a(e1type.rets, node.expected)
                  end
                  local e1args = e1type.args.tuple
                  local at = argdelta
                  for _, typ in ipairs(e1args) do
                     at = at + 1
                     if node.e2[at] then
                        node.e2[at].expected = typ
                     end
                  end
                  if e1type.args.is_va then
                     local typ = e1args[#e1args]
                     for i = at + 1, #node.e2 do
                        node.e2[i].expected = typ
                     end
                  end
               end
            elseif node.op.op == "@index" then
               if e1type is MapType then
                  node.e2.expected = e1type.keys
               end
            end
         end,
         after = function(self: TypeChecker, node: Node, children: {Type}): Type
            self:end_scope()

            -- given a and b: may be TupleType
            local ga: Type = children[1]
            local gb: Type = children[3]

            -- unary a and b: not TupleType
            local ua = resolve_tuple(ga)
            local ub: Type

            -- resolved a and b: not NominalType
            local ra: Type = self:to_structural(ua)
            local rb: Type

            if ra.typename == "circular_require" or (ra is TypeDeclType and ra.def and ra.def.typename == "circular_require") then
               return self.errs:invalid_at(node, "cannot dereference a type from a circular require")
            end

            if node.op.op == "@funcall" then
               if self.feat_lax and is_unknown(ua) then
                  if node.e1.op and node.e1.op.op == ":" and node.e1.e1.kind == "variable" then
                     self.errs:add_unknown_dot(node, node.e1.e1.tk .. "." .. node.e1.e2.tk)
                  end
               end
               assert(gb is TupleType)
               local t = self:type_check_funcall(node, ua, gb)
               return t

            elseif node.op.op == "as" then
               return gb
            end

            local expected = node.expected and self:to_structural(resolve_tuple(node.expected))

            local ok, err = ensure_not_abstract(ra)
            if not ok then
               self.errs:add(node.e1, err)
            end
            if ra is TypeDeclType and ra.def.typename == "record" then
               ra = ra.def
            end

            -- "@funcall" and "as" are the only operators that use tuples, and always in the b position;
            -- after they are handled above, we can resolve b's tuple and only use that instead.
            if gb then
               ub = resolve_tuple(gb)
               rb = self:to_structural(ub)
               ok, err = ensure_not_abstract(rb)
               if not ok then
                  self.errs:add(node.e2, err)
               end
               if rb is TypeDeclType and rb.def.typename == "record" then
                  rb = rb.def
               end
            end

            if node.op.op == "." then
               node.receiver = ua

               assert(node.e2.kind == "identifier")
               local bnode: Node = node_at(node.e2, {
                  tk = node.e2.tk,
                  kind = "string",
               })
               local btype = a_type(node.e2, "string", { literal = node.e2.tk } as StringType)
               local t = self:type_check_index(node.e1, bnode, ua, btype)

               if t.needs_compat and self.gen_compat ~= "off" then
                  -- only apply to a literal use, not a propagated type
                  if node.e1.kind == "variable" and node.e2.kind == "identifier" then
                     local key = node.e1.tk .. "." .. node.e2.tk
                     node.kind = "variable"
                     node.tk = "_tl_" .. node.e1.tk .. "_" .. node.e2.tk
                     self.all_needs_compat[key] = true
                  end
               end

               return t
            end

            if node.op.op == "@index" then
               return self:type_check_index(node.e1, node.e2, ua, ub)
            end

            if node.op.op == "is" then
               if rb.typename == "integer" then
                  self.all_needs_compat["math"] = true
               end
               if ra is TypeDeclType then
                  self.errs:add(node, "can only use 'is' on variables, not types")
               elseif node.e1.kind == "variable" then
                  self:check_metamethod(node, "__is", ra, resolve_typedecl(rb), ua, ub)
                  node.known = IsFact { var = node.e1.tk, typ = ub, w = node }
               else
                  self.errs:add(node, "can only use 'is' on variables")
               end
               return a_type(node, "boolean", {})
            end

            if node.op.op == ":" then
               node.receiver = ua

               -- we handle ':' separately from '.' because ':' is specific to records,
               -- so we produce different error messages
               if self.feat_lax and (is_unknown(ua) or ua is TypeVarType) then
                  if node.e1.kind == "variable" then
                     self.errs:add_unknown_dot(node.e1, node.e1.tk .. "." .. node.e2.tk)
                  end
                  return an_unknown(node)
               end

               local t, e = self:match_record_key(ra, node.e1, node.e2.conststr or node.e2.tk)
               if not t then
                  return self.errs:invalid_at(node.e2, e, ua)
               end

               return t
            end

            if node.op.op == "not" then
               node.known = facts_not(node, node.e1.known)
               return a_type(node, "boolean", {})
            end

            if node.op.op == "and" then
               node.known = facts_and(node, node.e1.known, node.e2.known)
               return discard_tuple(node, ub, gb)
            end

            if node.op.op == "or" then
               local t: Type
               if ub.typename == "nil" then
                  node.known = nil
                  t = ua

               elseif is_lua_table_type(ra) and rb is EmptyTableType then
                  node.known = nil
                  t = ua

               elseif ((ra is EnumType and rb is StringType and self:is_a(rb, ra))
                  or (ra is StringType and rb is EnumType and self:is_a(ra, rb))) then
                  node.known = nil
                  t = (ra is EnumType and ra or rb)

               elseif expected and expected is UnionType then
                  -- must be checked after string/enum above
                  node.known = facts_or(node, node.e1.known, node.e2.known)
                  local u = unite(node, {ra, rb}, true)
                  if u is UnionType then
                     ok, err = is_valid_union(u)
                     if not ok then
                        u = err and self.errs:invalid_at(node, err, u) or an_invalid(node)
                     end
                  end
                  t = u

               else
                  local a_ge_b = self:is_a(rb, ra)
                  local b_ge_a = self:is_a(ra, rb)
                  if a_ge_b or b_ge_a then
                     node.known = facts_or(node, node.e1.known, node.e2.known)
                     if expected then
                        local a_is = self:is_a(ua, expected)
                        local b_is = self:is_a(ub, expected)
                        if a_is and b_is then
                           t = self:resolve_typevars_at(node, expected)
                        end
                     end
                     if not t then
                        local larger_type = b_ge_a and ub or ua
                        t = larger_type
                     end
                     t = drop_constant_value(t)
                  end

                  if expected and expected is BooleanType then
                     t = a_type(node, "boolean", {})
                  end
               end

               if t then
                  return discard_tuple(node, t, gb)
               end
               -- else fallthrough to general binop handler
            end

            if node.op.op == "==" or node.op.op == "~=" then
--               if is_lua_table_type(ra) and is_lua_table_type(rb) then
--                  self:check_metamethod(node, binop_to_metamethod[node.op.op], ra, rb)
--               end

               if ra is EnumType and rb is StringType then
                  if not (rb.literal and ra.enumset[rb.literal]) then
                     return self.errs:invalid_at(node, "%s is not a member of %s", ub, ua)
                  end
               elseif ra is TupleTableType and rb is TupleTableType and #ra.types ~= #rb.types then
                  return self.errs:invalid_at(node, "tuples are not the same size")
               elseif self:is_a(ub, ua) or ua is TypeVarType then
                  if node.op.op == "==" and node.e1.kind == "variable" then
                     node.known = EqFact { var = node.e1.tk, typ = ub, w = node }
                  end
               elseif self:is_a(ua, ub) or ub is TypeVarType then
                  if node.op.op == "==" and node.e2.kind == "variable" then
                     node.known = EqFact { var = node.e2.tk, typ = ua, w = node }
                  end
               elseif self.feat_lax and (is_unknown(ua) or is_unknown(ub)) then
                  return an_unknown(node)
               else
                  return self.errs:invalid_at(node, "types are not comparable for equality: %s and %s", ua, ub)
               end

               return a_type(node, "boolean", {})
            end

            if node.op.arity == 1 and unop_types[node.op.op] then
               if ra is UnionType then
                  ra = unite(node, ra.types, true) -- squash unions of string constants
               end

               local types_op = unop_types[node.op.op]

               local tn = types_op[ra.typename]
               local t = tn and a_type(node, tn, {})

               if not t and ra is RecordLikeType then
                  t = find_in_interface_list(ra, function(ty: Type): Type
                     local tname = types_op[ty.typename]
                     return tname and a_type(node, tname, {})
                  end)
               end

               local meta_on_operator: integer
               if not t then
                  local mt_name = unop_to_metamethod[node.op.op]
                  if mt_name then
                     t, meta_on_operator = self:check_metamethod(node, mt_name, ra, nil, ua, nil)
                  end
                  if not t then
                     t = self.errs:invalid_at(node, "cannot use operator '" .. node.op.op:gsub("%%", "%%%%") .. "' on type %s", ua)
                  end
               end

               if ra is MapType then
                  if ra.keys.typename == "number" or ra.keys.typename == "integer" then
                      self.errs:add_warning("hint", node, "using the '#' operator on a map with numeric key type may produce unexpected results")
                  else
                      self.errs:add(node, "using the '#' operator on this map will always return 0")
                  end
               end

               if t.typename ~= "boolean" and not is_unknown(t) then
                  node.known = FACT_TRUTHY
               end

               if node.op.op == "~" and self.gen_target == "5.1" then
                  if meta_on_operator then
                     self.all_needs_compat["mt"] = true
                     convert_node_to_compat_mt_call(node, unop_to_metamethod[node.op.op], 1, node.e1)
                  else
                     self.all_needs_compat["bit32"] = true
                     convert_node_to_compat_call(node, "bit32", "bnot", node.e1)
                  end
               end

               return t
            end

            if node.op.arity == 2 and binop_types[node.op.op] then
               if node.op.op == "or" then
                  node.known = facts_or(node, node.e1.known, node.e2.known)
               end

               if ra is UnionType then
                  ra = unite(ra, ra.types, true) -- squash unions of string constants
               end
               if rb is UnionType then
                  rb = unite(rb, rb.types, true) -- squash unions of string constants
               end

               local types_op = binop_types[node.op.op]

               local tn = types_op[ra.typename] and types_op[ra.typename][rb.typename]
               local t = tn and a_type(node, tn, {})

               local meta_on_operator: integer
               if not t then
                  local mt_name = binop_to_metamethod[node.op.op]
                  if not mt_name then
                     mt_name = flip_binop_to_metamethod[node.op.op]
                     if mt_name then
                        ra, rb = rb, ra
                        ua, ub = ub, ua
                     end
                  end
                  if mt_name then
                     t, meta_on_operator = self:check_metamethod(node, mt_name, ra, rb, ua, ub)
                  end
                  if not t then
                     t = self.errs:invalid_at(node, "cannot use operator '" .. node.op.op:gsub("%%", "%%%%") .. "' for types %s and %s", ua, ub)
                     if node.op.op == "or" then
                        local u = unite(node, {ua, ub})
                        if u is UnionType and is_valid_union(u) then
                           self.errs:add_warning("hint", node, "if a union type was intended, consider declaring it explicitly")
                        end
                     end
                  end
               end

               if ua is NominalType and ub is NominalType and not meta_on_operator then
                  if self:is_a(ua, ub) then
                     t = ua
                  else
                     self.errs:add(node, "cannot use operator '" .. node.op.op:gsub("%%", "%%%%") .. "' for distinct nominal types %s and %s", ua, ub)
                  end
               end

               if types_op == numeric_binop or node.op.op == ".." then
                  node.known = FACT_TRUTHY
               end

               if node.op.op == "//" and self.gen_target == "5.1" then
                  if meta_on_operator then
                     self.all_needs_compat["mt"] = true
                     convert_node_to_compat_mt_call(node, "__idiv", meta_on_operator, node.e1, node.e2)
                  else
                     local div: Node = node_at(node, { kind = "op", op = an_operator(node, 2, "/"), e1 = node.e1, e2 = node.e2 })
                     convert_node_to_compat_call(node, "math", "floor", div)
                  end
               elseif bit_operators[node.op.op] and self.gen_target == "5.1" then
                  if meta_on_operator then
                     self.all_needs_compat["mt"] = true
                     convert_node_to_compat_mt_call(node, binop_to_metamethod[node.op.op], meta_on_operator, node.e1, node.e2)
                  else
                     self.all_needs_compat["bit32"] = true
                     convert_node_to_compat_call(node, "bit32", bit_operators[node.op.op], node.e1, node.e2)
                  end
               end

               return t
            end

            error("unknown node op " .. node.op.op)
         end,
      },
      ["variable"] = {
         after = function(self: TypeChecker, node: Node, _children: {Type}): Type
            if node.tk == "..." then
               local va_sentinel = self:find_var_type("@is_va")
               if not va_sentinel or va_sentinel.typename == "nil" then
                  return self.errs:invalid_at(node, "cannot use '...' outside a vararg function")
               end
            end

            local t: Type
            if node.tk == "_G" then
               t, node.attribute = self:simulate_g()
            else
               local use: VarUse = node.is_lvalue and "lvalue" or "use"
               t, node.attribute = self:find_var_type(node.tk, use)
            end
            if not t then
               if self.feat_lax then
                  self.errs:add_unknown(node, node.tk)
                  return an_unknown(node)
               end

               return self.errs:invalid_at(node, "unknown variable: " .. node.tk)
            end

            if t is TypeDeclType then
               t = typedecl_to_nominal(node, node.tk, t, t)
            end

            return t
         end,
      },
      ["type_identifier"] = {
         after = function(self: TypeChecker, node: Node, _children: {Type}): Type
            local typ, attr = self:find_var_type(node.tk)
            node.attribute = attr
            if typ then
               return typ
            end

            if self.feat_lax then
               self.errs:add_unknown(node, node.tk)
               return an_unknown(node)
            end

            return self.errs:invalid_at(node, "unknown variable: " .. node.tk)
         end,
      },
      ["argument"] = {
         after = function(self: TypeChecker, node: Node, children: {Type}): Type
            local t = children[1]
            if not t then
               t = an_unknown(node)
            end
            if node.tk == "..." then
               t = a_vararg(node, { t })
            end
            self:add_var(node, node.tk, t).is_func_arg = true
            return t
         end,
      },
      ["identifier"] = {
         after = function(_self: TypeChecker, _node: Node, _children: {Type}): Type
            return NONE -- type is resolved elsewhere
         end,
      },
      ["newtype"] = {
         after = function(_self: TypeChecker, node: Node, _children: {Type}): Type
            return node.newtype
         end,
      },
      ["error_node"] = {
         after = function(_self: TypeChecker, node: Node, _children: {Type}): Type
            return an_invalid(node)
         end,
      }
   }

   visit_node.cbs["break"] = {
      after = function(_self: TypeChecker, _node: Node, _children: {Type}): Type
         return NONE
      end,
   }
   visit_node.cbs["do"] = visit_node.cbs["break"]

   local function after_literal(_self: TypeChecker, node: Node): Type
      node.known = FACT_TRUTHY
      return a_type(node, node.kind as TypeName, {})
   end

   visit_node.cbs["string"] = {
      after = function(self: TypeChecker, node: Node, _children: {Type}): Type
         local t = after_literal(self, node) as StringType
         t.literal = node.conststr

         local expected = node.expected and self:to_structural(node.expected)
         if expected and expected is EnumType and self:is_a(t, expected) then
            return node.expected
         end

         return t
      end,
   }
   visit_node.cbs["number"] = { after = after_literal }
   visit_node.cbs["integer"] = { after = after_literal }

   visit_node.cbs["boolean"] = {
      after = function(self: TypeChecker, node: Node, _children: {Type}): Type
         local t = after_literal(self, node)
         node.known = (node.tk == "true") and FACT_TRUTHY or nil
         return t
      end,
   }
   visit_node.cbs["nil"] = visit_node.cbs["boolean"]

   visit_node.cbs["..."] = visit_node.cbs["variable"]
   visit_node.cbs["argument_list"] = visit_node.cbs["variable_list"]
   visit_node.cbs["expression_list"] = visit_node.cbs["variable_list"]

   visit_node.after = function(_self: TypeChecker, node: Node, _children: {Type}, t: Type): Type
      if node.expanded then
         apply_macroexp(node)
      end

      return t
   end

   do
      local function add_interface_fields(self: TypeChecker, what: string, fields: {string:Type}, field_order: {string}, resolved: RecordLikeType, named: NominalType, list?: MetaMode)
         for fname, ftype in fields_of(resolved, list) do
            if fields[fname] then
               if not self:is_a(fields[fname], ftype) then
                  self.errs:add(fields[fname], what .." '" .. fname .. "' does not match definition in interface %s", named)
               end
            else
               table.insert(field_order, fname)
               fields[fname] = ftype
            end
         end
      end

      local function collect_interfaces(self: TypeChecker, list: {ArrayType | NominalType}, t: RecordLikeType, seen:{Type:boolean}): {ArrayType | NominalType}
         if t.interface_list then
            for _, iface in ipairs(t.interface_list) do
               if iface is NominalType then
                  local ri = self:resolve_nominal(iface)
                  if ri is InterfaceType then
                     if ri.interfaces_expanded and not seen[ri] then
                        seen[ri] = true
                        collect_interfaces(self, list, ri, seen)
                     end
                     table.insert(list, iface)
                  else
                     self.errs:add(iface, "attempted to use %s as interface, but its type is %s", iface, ri)
                  end
               else
                  if not seen[iface] then
                     seen[iface] = true
                     table.insert(list, iface)
                  end
               end
            end
         end
         return list
      end

      function TypeChecker:expand_interfaces(t: RecordLikeType)
         if t.interfaces_expanded then
            return
         end
         t.interfaces_expanded = true

         t.interface_list = collect_interfaces(self, {}, t, {})

         for _, iface in ipairs(t.interface_list) do
            if iface is NominalType then
               local ri = self:resolve_nominal(iface)
               assert(ri is InterfaceType)
               add_interface_fields(self, "field", t.fields, t.field_order, ri, iface)
               if ri.meta_fields then
                  t.meta_fields = t.meta_fields or {}
                  t.meta_field_order = t.meta_field_order or {}
                  add_interface_fields(self, "metamethod", t.meta_fields, t.meta_field_order, ri, iface, "meta")
               end
            else
               if not t.elements then
                  t.elements = iface
               else
                  if not self:same_type(iface.elements, t.elements) then
                     self.errs:add(t, "incompatible array interfaces")
                  end
               end
            end
         end
      end
   end

   local visit_type_with_typeargs = {
      before = function(self: TypeChecker, _typ: Type)
         self:begin_scope()
      end,
      after = function(self: TypeChecker, typ: Type, _children: {Type}): Type
         self:end_scope()
         return self:ensure_fresh_typeargs(typ)
      end,
   }

   local visit_type: Visitor<TypeChecker, TypeName,Type,Type>
   visit_type = {
      cbs = {
         ["record"] = {
            before = function(self: TypeChecker, typ: RecordType)
               self:begin_scope()
               self:add_var(nil, "@self", type_at(typ, a_typedecl(typ, typ)))

               for fname, ftype in fields_of(typ) do
                  if ftype is TypeAliasType then
                     self:resolve_nominal(ftype.alias_to)
                     self:add_var(nil, fname, ftype)
                  elseif ftype is TypeDeclType then
                     self:add_var(nil, fname, ftype)
                  end
               end
            end,
            after = function(self: TypeChecker, typ: RecordType, children: {Type}): Type
               local i = 1
               if typ.typeargs then
                  for _, _ in ipairs(typ.typeargs) do
                     typ.typeargs[i] = children[i] as TypeArgType
                     i = i + 1
                  end
               end
               if typ.interface_list then
                  for j, _ in ipairs(typ.interface_list) do
                     local iface = children[i]
                     if iface is ArrayType then
                        typ.interface_list[j] = iface
                     elseif iface is NominalType then
                        local ri = self:resolve_nominal(iface)
                        if ri is InterfaceType then
                           typ.interface_list[j] = iface
                        else
                           self.errs:add(children[i], "%s is not an interface", children[i])
                        end
                     end
                     i = i + 1
                  end
               end
               if typ.elements then
                  typ.elements = children[i]
                  i = i + 1
               end
               local fmacros: {FunctionType}
               for name, _ in fields_of(typ) do
                  local ftype = children[i]
                  if ftype is FunctionType then
                     if ftype.macroexp then
                        fmacros = fmacros or {}
                        table.insert(fmacros, ftype)
                     end

                     if ftype.is_method then
                        local fargs = ftype.args.tuple
                        if fargs[1] then
                           local record_name = typ.declname
                           if record_name then
                              local selfarg = fargs[1] as NominalType
                              if selfarg.names[1] ~= record_name or (typ.typeargs and not selfarg.typevals) then
                                 ftype.is_method = false
                              elseif typ.typeargs then
                                 for j=1,#typ.typeargs do
                                    local tv = selfarg.typevals[j]
                                    if not (tv and tv is TypeVarType and tv.typevar == typ.typeargs[j].typearg) then
                                       ftype.is_method = false
                                       break
                                    end
                                 end
                              end
                           end
                        end
                     end
                  elseif ftype is TypeAliasType then
                     self:resolve_typealias(ftype)
                  end

                  typ.fields[name] = ftype
                  i = i + 1
               end
               for name, _ in fields_of(typ, "meta") do
                  local ftype = children[i]
                  if ftype is FunctionType then
                     if ftype.macroexp then
                        fmacros = fmacros or {}
                        table.insert(fmacros, ftype)
                     end
                  end
                  typ.meta_fields[name] = ftype
                  i = i + 1
               end

               if typ.interface_list then
                  self:expand_interfaces(typ)
               end

               if fmacros then
                  for _, t in ipairs(fmacros) do
                     local macroexp_type = recurse_node(self, t.macroexp, visit_node, visit_type)

                     self:check_macroexp_arg_use(t.macroexp)

                     if not self:is_a(macroexp_type, t) then
                        self.errs:add(macroexp_type, "macroexp type does not match declaration")
                     end
                  end
               end

               self:end_scope()

               return typ
            end,
         },
         ["typearg"] = {
            after = function(self: TypeChecker, typ: TypeArgType, _children: {Type}): Type
               self:add_var(nil, typ.typearg, a_type(typ, "typearg", {
                  typearg = typ.typearg,
                  constraint = typ.constraint,
               } as TypeArgType))
               return typ
            end,
         },
         ["typevar"] = {
            after = function(self: TypeChecker, typ: TypeVarType, _children: {Type}): Type
               if not self:find_var_type(typ.typevar) then
                  self.errs:add(typ, "undefined type variable " .. typ.typevar)
               end
               return typ
            end,
         },
         ["nominal"] = {
            after = function(self: TypeChecker, typ: NominalType, _children: {Type}): Type
               if typ.found then
                  return typ
               end

               local t = self:find_type(typ.names, true)
               if t then
                  if t is TypeArgType then
                     -- convert nominal into a typevar
                     typ.names = nil
                     edit_type(typ, typ, "typevar")
                     local tv = typ as TypeVarType
                     tv.typevar = t.typearg
                     tv.constraint = t.constraint
                  elseif t is TypeDeclType then
                     if t.def.typename ~= "circular_require" then
                        typ.found = t
                     end
                  end
               else
                  local name = typ.names[1]
                  local scope = self.st[#self.st]
                  scope.pending_nominals = scope.pending_nominals or {}
                  scope.pending_nominals[name] = scope.pending_nominals[name] or {}
                  table.insert(scope.pending_nominals[name], typ)
               end
               return typ
            end,
         },
         ["union"] = {
            after = function(self: TypeChecker, typ: UnionType, _children: {Type}): Type
               local ok, err = is_valid_union(typ)
               if not ok then
                  return err and self.errs:invalid_at(typ, err, typ) or an_invalid(typ)
               end
               return typ
            end
         },
      },
   }

   local default_type_visitor = {
      after = function(_self: TypeChecker, typ: Type, _children: {Type}): Type
         return typ
      end,
   }

   visit_type.cbs["interface"] = visit_type.cbs["record"]

   visit_type.cbs["function"] = visit_type_with_typeargs
   visit_type.cbs["typedecl"] = visit_type_with_typeargs
   visit_type.cbs["typealias"] = visit_type_with_typeargs

   visit_type.cbs["string"] = default_type_visitor
   visit_type.cbs["tupletable"] = default_type_visitor
   visit_type.cbs["array"] = default_type_visitor
   visit_type.cbs["map"] = default_type_visitor
   visit_type.cbs["enum"] = default_type_visitor
   visit_type.cbs["boolean"] = default_type_visitor
   visit_type.cbs["nil"] = default_type_visitor
   visit_type.cbs["number"] = default_type_visitor
   visit_type.cbs["integer"] = default_type_visitor
   visit_type.cbs["thread"] = default_type_visitor
   visit_type.cbs["emptytable"] = default_type_visitor
   visit_type.cbs["literal_table_item"] = default_type_visitor
   visit_type.cbs["unresolved_emptytable_value"] = default_type_visitor
   visit_type.cbs["tuple"] = default_type_visitor
   visit_type.cbs["poly"] = default_type_visitor
   visit_type.cbs["any"] = default_type_visitor
   visit_type.cbs["unknown"] = default_type_visitor
   visit_type.cbs["invalid"] = default_type_visitor
   visit_type.cbs["none"] = default_type_visitor

   local type VisitorAfterPatcher = function<S, N, T>(VisitorAfter<S, N, T>): VisitorAfter<S, N, T>

   local function internal_compiler_check<S, N>(fn: VisitorAfter<S, N, Type>): VisitorAfter<S, N, Type>
      return function(s: S, n: N, children: {Type}, t: Type): Type
         t = fn and fn(s, n, children, t) or t

         if type(t) ~= "table" then
            error(((n as Node).kind or (n as Type).typename) .. " did not produce a type")
         end
         if type(t.typename) ~= "string" then
            error(((n as Node).kind or (n as Type).typename) .. " type does not have a typename")
         end

         return t
      end
   end

   local function store_type_after<N>(fn: VisitorAfter<TypeChecker, N, Type>): VisitorAfter<TypeChecker, N, Type>
      return function(self: TypeChecker, n: N, children: {Type}, t: Type): Type
         t = fn and fn(self, n, children, t) or t

         local w = n as Where

         if w.y then
            self.collector.store_type(w.y, w.x, t)
         end

         return t
      end
   end

   local function debug_type_after<S>(fn: VisitorAfter<S, Node, Type>): VisitorAfter<S, Node, Type>
      return function(s: S, node: Node, children: {Type}, t: Type): Type
         t = fn and fn(s, node, children, t) or t

         node.debug_type = t
         return t
      end
   end

   local function patch_visitors(my_visit_node: Visitor<TypeChecker, NodeKind, Node, Type>,
                                 after_node: VisitorAfterPatcher<TypeChecker, Node, Type>,
                                 my_visit_type?: Visitor<TypeChecker, TypeName, Type, Type>,
                                 after_type?: VisitorAfterPatcher<TypeChecker, Type, Type>):
                                 Visitor<TypeChecker, NodeKind, Node, Type>,
                                 Visitor<TypeChecker, TypeName, Type, Type>
      if my_visit_node == visit_node then
         my_visit_node = shallow_copy_table(my_visit_node)
      end
      my_visit_node.after = after_node(my_visit_node.after)
      if my_visit_type then
         if my_visit_type == visit_type then
            my_visit_type = shallow_copy_table(my_visit_type)
         end
         my_visit_type.after = after_type(my_visit_type.after)
      else
         my_visit_type = visit_type
      end
      return my_visit_node, my_visit_type
   end

   local function set_feat(feat: Feat, default: boolean): boolean
      if feat then
         return (feat == "on")
      else
         return default
      end
   end

   tl.type_check = function(ast: Node, filename: string, opts: TypeCheckOptions, env?: Env): Result, string
      assert(filename is string, "tl.type_check signature has changed, pass filename separately")
      assert((not opts) or (not (opts as {any:any}).env), "tl.type_check signature has changed, pass env separately")

      filename = filename or "?"

      opts = opts or {}

      if not env then
         local err: string
         env, err = tl.new_env({ defaults = opts })
         if err then
            return nil, err
         end
      end

      local self: TypeChecker = {
         filename = filename,
         env = env,
         st = {
            {
               vars = env.globals,
               pending_global_types = {},
            },
         },
         errs = Errors.new(filename),
         all_needs_compat = {},
         dependencies = {},
         subtype_relations = TypeChecker.subtype_relations,
         eqtype_relations = TypeChecker.eqtype_relations,
         type_priorities = TypeChecker.type_priorities,
      }

      setmetatable(self, { __index = TypeChecker })

      self.feat_lax   = set_feat(opts.feat_lax   or env.defaults.feat_lax,   false)
      self.feat_arity = set_feat(opts.feat_arity or env.defaults.feat_arity, true)
      self.gen_compat = opts.gen_compat or env.defaults.gen_compat or DEFAULT_GEN_COMPAT
      self.gen_target = opts.gen_target or env.defaults.gen_target or DEFAULT_GEN_TARGET

      if self.gen_target == "5.4" and self.gen_compat ~= "off" then
         return nil, "gen-compat must be explicitly 'off' when gen-target is '5.4'"
      end

      if self.feat_lax then
         self.type_priorities = shallow_copy_table(self.type_priorities)
         self.type_priorities["unknown"] = 0

         self.subtype_relations = shallow_copy_table(self.subtype_relations)

         self.subtype_relations["unknown"] = {}
         self.subtype_relations["unknown"]["*"] = compare_true

         self.subtype_relations["*"] = shallow_copy_table(self.subtype_relations["*"])
         self.subtype_relations["*"]["unknown"] = compare_true
         -- in .lua files, all values can be used in a boolean context
         self.subtype_relations["*"]["boolean"] = compare_true

         self.get_rets = function(rets: TupleType): TupleType
            if #rets.tuple == 0 then
               return a_vararg(rets, { an_unknown(rets) })
            end
            return rets
         end
      else
         self.get_rets = function(rets: TupleType): TupleType
            return rets
         end
      end

      if env.report_types then
         env.reporter = env.reporter or tl.new_type_reporter()
         self.collector = env.reporter:get_collector(filename)
      end

      local visit_node, visit_type = visit_node, visit_type
      if opts.run_internal_compiler_checks then
         visit_node, visit_type = patch_visitors(
            visit_node, internal_compiler_check,
            visit_type, internal_compiler_check
         )
      end
      if self.collector then
         visit_node, visit_type = patch_visitors(
            visit_node, store_type_after,
            visit_type, store_type_after
         )
      end
      if TL_DEBUG then
         visit_node, visit_type = patch_visitors(
            visit_node, debug_type_after
         )
      end

      assert(ast.kind == "statements")
      recurse_node(self, ast, visit_node, visit_type)

      local global_scope = self.st[1]
      close_types(global_scope)
      self.errs:warn_unused_vars(global_scope, true)

      clear_redundant_errors(self.errs.errors)

      add_compat_entries(ast, self.all_needs_compat, self.gen_compat)

      local result = {
         ast = ast,
         env = env,
         type = self.module_type or a_type(ast, "boolean", {}),
         filename = filename,
         warnings = self.errs.warnings,
         type_errors = self.errs.errors,
         dependencies = self.dependencies,
      }

      env.loaded[filename] = result
      table.insert(env.loaded_order, filename or "")

      if self.collector then
         env.reporter:store_result(self.collector, env.globals)
      end

      return result
   end
end

--------------------------------------------------------------------------------
-- High-level API
--------------------------------------------------------------------------------

local function read_full_file(fd: FILE): string, string
   local bom <const> = "\239\187\191" -- "\xEF\xBB\xBF"
   local content, err = fd:read("*a")
   if content:sub(1, bom:len()) == bom then
      content = content:sub(bom:len() + 1)
   end
   return content, err
end

local function feat_lax_heuristic(filename?: string, input?: string): Feat
   if filename then
      local _, extension = filename:match("(.*)%.([a-z]+)$")
      extension = extension and extension:lower()

      if extension == "tl" then
         return "off"
      elseif extension == "lua" then
         return "on"
      end
   end
   if input then
      return (input:match("^#![^\n]*lua[^\n]*\n")) and "on" or "off"
   end
   return "off"
end

tl.process = function(filename: string, env: Env, fd?: FILE): Result, string
   if env and env.loaded and env.loaded[filename] then
      return env.loaded[filename]
   end

   local input, err: string, string

   if not fd then
      fd, err = io.open(filename, "rb")
      if not fd then
         return nil, "could not open " .. filename .. ": " .. err
      end
   end

   input, err = read_full_file(fd)
   fd:close()
   if not input then
      return nil, "could not read " .. filename .. ": " .. err
   end

   return tl.process_string(input, env, filename)
end

function tl.target_from_lua_version(str: string): GenTarget
   if str == "Lua 5.1"
      or str == "Lua 5.2" then
      return "5.1"
   elseif str == "Lua 5.3" then
      return "5.3"
   elseif str == "Lua 5.4" then
      return "5.4"
   end
end

local function default_env_opts(runtime: boolean, filename?: string, input?: string): EnvOptions
   local gen_target = runtime and tl.target_from_lua_version(_VERSION) or DEFAULT_GEN_TARGET
   local gen_compat: GenCompat = (gen_target == "5.4") and "off" or DEFAULT_GEN_COMPAT
   return {
      defaults = {
         feat_lax = feat_lax_heuristic(filename, input),
         gen_target = gen_target,
         gen_compat = gen_compat,
         run_internal_compiler_checks = false,
      }
   }
end

function tl.process_string(input: string, env?: Env, filename?: string): Result
   assert(type(env) ~= "boolean", "tl.process_string signature has changed")

   env = env or tl.new_env(default_env_opts(false, filename, input))

   if env.loaded and env.loaded[filename] then
      return env.loaded[filename]
   end
   filename = filename or ""

   local program, syntax_errors = tl.parse(input, filename)

   if (not env.keep_going) and #syntax_errors > 0 then
      local result = {
         ok = false,
         filename = filename,
         type = a_type({ f = filename, y = 1, x = 1 }, "boolean", {}),
         type_errors = {},
         syntax_errors = syntax_errors,
         env = env,
      }
      env.loaded[filename] = result
      table.insert(env.loaded_order, filename)
      return result
   end

   local result = tl.type_check(program, filename, env.defaults, env)

   result.syntax_errors = syntax_errors

   return result
end

tl.gen = function(input: string, env: Env, pp: PrettyPrintOptions): string, Result
   env = env or assert(tl.new_env(default_env_opts(false, nil, input)), "Default environment initialization failed")
   local result = tl.process_string(input, env)

   if (not result.ast) or #result.syntax_errors > 0 then
      return nil, result
   end

   local code: string
   code, result.gen_error = tl.pretty_print_ast(result.ast, env.defaults.gen_target, pp)
   return code, result
end

local function tl_package_loader(module_name: string): any, any
   local found_filename, fd, tried = tl.search_module(module_name, false)
   if found_filename then
      local input = read_full_file(fd)
      if not input then
         return table.concat(tried, "\n\t")
      end
      fd:close()
      local program, errs = tl.parse(input, found_filename)
      if #errs > 0 then
         error(found_filename .. ":" .. errs[1].y .. ":" .. errs[1].x .. ": " .. errs[1].msg)
      end

      local env = tl.package_loader_env
      if not env then
         tl.package_loader_env = assert(tl.new_env(), "Default environment initialization failed")
         env = tl.package_loader_env
      end

      local opts = default_env_opts(true, found_filename)

      local w = { f = found_filename, x = 1, y = 1 }
      env.modules[module_name] = a_typedecl(w, a_type(w, "circular_require", {}))

      local result = tl.type_check(program, found_filename, opts.defaults, env)

      env.modules[module_name] = result.type

      -- TODO: should this be a hard error? this seems analogous to
      -- finding a lua file with a syntax error in it
      local code = assert(tl.pretty_print_ast(program, opts.defaults.gen_target, true))
      local chunk, err = load(code, "@" .. found_filename, "t")
      if chunk then
         return function(modname: string, loader_data: string): any
            if loader_data == nil then
               loader_data = found_filename
            end
            local ret = chunk(modname, loader_data)
            package.loaded[module_name] = ret
            return ret
         end, found_filename
      else
         error("Internal Compiler Error: Teal generator produced invalid Lua. Please report a bug at https://github.com/teal-language/tl\n\n" .. err)
      end
   end
   return table.concat(tried, "\n\t")
end

function tl.loader()
   if package.searchers then
      table.insert(package.searchers, 2, tl_package_loader)
   else
      table.insert(package.loaders, 2, tl_package_loader)
   end
end

local function env_for(opts: EnvOptions, env_tbl: {any:any}): Env
   if not env_tbl then
      if not tl.package_loader_env then
         tl.package_loader_env = tl.new_env(opts)
      end
      return tl.package_loader_env
   end

   if not tl.load_envs then
      tl.load_envs = setmetatable({}, { __mode = "k" })
   end

   tl.load_envs[env_tbl] = tl.load_envs[env_tbl] or tl.new_env(opts)
   return tl.load_envs[env_tbl]
end

tl.load = function(input: string, chunkname: string, mode: LoadMode, ...: {any:any}): LoadFunction, string
   local program, errs = tl.parse(input, chunkname)
   if #errs > 0 then
      return nil, (chunkname or "") .. ":" .. errs[1].y .. ":" .. errs[1].x .. ": " .. errs[1].msg
   end

   local opts = default_env_opts(true, chunkname)

   if not tl.package_loader_env then
      tl.package_loader_env = tl.new_env(opts)
   end

   local filename = chunkname or ("string \"" .. input:sub(45) .. (#input > 45 and "..." or "") .. "\"")
   local result = tl.type_check(program, filename, opts.defaults, env_for(opts, ...))

   if mode and mode:match("c") then
      if #result.type_errors > 0 then
         local errout = {}
         for _, err in ipairs(result.type_errors) do
            table.insert(errout, err.filename .. ":" .. err.y .. ":" .. err.x .. ": " .. (err.msg or ""))
         end
         return nil, table.concat(errout, "\n")
      end

      mode = mode:gsub("c", "") as LoadMode
   end

   local code, err = tl.pretty_print_ast(program, opts.defaults.gen_target, true)
   if not code then
      return nil, err
   end

   return load(code, chunkname, mode, ...)
end

--------------------------------------------------------------------------------
-- Backwards compatibility
--------------------------------------------------------------------------------

function tl.get_types(result: Result): TypeReport, TypeReporter
   return result.env.reporter:get_report(), result.env.reporter
end

tl.init_env = function(lax?: boolean, gen_compat?: boolean | GenCompat, gen_target?: GenTarget, predefined?: {string}): Env, string
   local opts = {
      defaults = {
         feat_lax = (lax and "on" or "off") as Feat,
         gen_compat = ((gen_compat is GenCompat) and gen_compat) or
                       (gen_compat == false and "off") or
                       (gen_compat == true or gen_compat == nil) and "optional",
         gen_target = gen_target or
                      ((_VERSION == "Lua 5.1" or _VERSION == "Lua 5.2") and "5.1") or
                      "5.3",
      },
      predefined_modules = predefined,
   }

   return tl.new_env(opts)
end

return tl
