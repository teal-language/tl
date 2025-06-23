local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local debug = _tl_compat and _tl_compat.debug or debug; local io = _tl_compat and _tl_compat.io or io; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local load = _tl_compat and _tl_compat.load or load; local math = _tl_compat and _tl_compat.math or math; local _tl_math_maxinteger = math.maxinteger or math.pow(2, 53); local os = _tl_compat and _tl_compat.os or os; local package = _tl_compat and _tl_compat.package or package; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local type = type; local utf8 = _tl_compat and _tl_compat.utf8 or utf8
local VERSION = "0.24.6+dev"







local prelude = [=====[
do
   global interface any
   end
   global interface thread
   end
   global interface userdata
      is userdata
   end

   global record metatable<T>
      enum Mode
         "k" "v" "kv"
      end

      __call: function(T, any...): any...
      __mode: Mode
      __name: string
      __tostring: function(T): string
      __pairs: function<K, V>(T): function(): (K, V)

      __index: any --[[FIXME: function | table | anything with an __index metamethod]]
      __newindex: any --[[FIXME: function | table | anything with an __index metamethod]]

      __gc: function(T)
      __close: function(T)

      __add: function<A, B, C>(A, B): C
      __sub: function<A, B, C>(A, B): C
      __mul: function<A, B, C>(A, B): C
      __div: function<A, B, C>(A, B): C
      __idiv: function<A, B, C>(A, B): C
      __mod: function<A, B, C>(A, B): C
      __pow: function<A, B, C>(A, B): C
      __band: function<A, B, C>(A, B): C
      __bor: function<A, B, C>(A, B): C
      __bxor: function<A, B, C>(A, B): C
      __shl: function<A, B, C>(A, B): C
      __shr: function<A, B, C>(A, B): C
      __concat: function<A, B, C>(A, B): C

      __len: function<A>(T): A
      __unm: function<A>(T): A
      __bnot: function<A>(T): A

      __eq: function<A, B>(A, B): boolean
      __lt: function<A, B>(A, B): boolean
      __le: function<A, B>(A, B): boolean
   end
end
]=====]













local stdlib = [=====[
do
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
      is userdata

      enum SeekWhence
         "set" "cur" "end"
      end

      enum SetVBufMode
         "no" "full" "line"
      end

      close: function(FILE): boolean, string, integer
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
      input: function(? FILE | string): FILE
      flush: function()

      lines: function(? string): (function(): (string))
      lines: function(? string, FileNumberMode...): (function(): (number...))
      lines: function(? string, (number | FileStringMode)...): (function(): (string...))
      lines: function(? string, (number | FileMode)...): (function(): ((string | number)...))
      lines: function(? string, (number | string)...): (function(): (string...))

      open: function(string, ? OpenMode): FILE, string, integer
      output: function(? FILE | string): FILE
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

      frexp: function(number): number, integer
      huge: number
      ldexp: function(number, integer): number
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
      find: function(string, string, ? integer, ? boolean): integer, integer, string... --[[special_function]]
      format: function(string, any...): string --[[special_function]]
      gmatch: function(string, string, ? integer): (function(): string...) --[[special_function]]

      gsub: function(string, string, string, ? integer): string, integer --[[special_function]]
      gsub: function(string, string, {string:string|integer|number}, ? integer): string, integer --[[special_function]]
      gsub: function(string, string, {integer:string|integer|number}, ? integer): string, integer --[[special_function]]
      gsub: function(string, string, function((string|integer)...): ((string|integer|number)...), ? integer): string, integer --[[special_function]]

      len: function(string): integer
      lower: function(string): string
      match: function(string, string, ? integer): string... --[[special_function]]
      pack: function(string, any...): string --[[special_function]]
      packsize: function(string): integer
      rep: function(string, integer, ? string): string
      reverse: function(string): string
      sub: function(string, integer, ? integer): string
      unpack: function(string, string, ? integer): any... --[[special_function]]
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

      pack: function<T>(T...): PackTable<T> --[[needs_compat]]
      pack: function(any...): {any:any} --[[needs_compat]]

      remove: function<A>({A}, ? integer): A
      sort: function<A>({A}, ? SortFunction<A>)

      unpack: function<A>({A}, ? number, ? number): A... --[[needs_compat]]
      unpack: function<A1, A2>({A1, A2}): A1, A2 --[[needs_compat]]
      unpack: function<A1, A2, A3>({A1, A2, A3}): A1, A2, A3 --[[needs_compat]]
      unpack: function<A1, A2, A3, A4>({A1, A2, A3, A4}): A1, A2, A3, A4 --[[needs_compat]]
      unpack: function<A1, A2, A3, A4, A5>({A1, A2, A3, A4, A5}): A1, A2, A3, A4, A5 --[[needs_compat]]
   end

   global record utf8
      char: function(number...): string
      charpattern: string
      codepoint: function(string, ? number, ? number, ? boolean): number...
      codes: function(string, ? boolean): (function(string, ? number): (number, number))
      len: function(string, ? number, ? number, ? boolean): number
      offset: function(string, number, ? number): number
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
      assert: function<A, B>(A, ? B, ...: any): A --[[special_function]]

      collectgarbage: function(? CollectGarbageCommand): number
      collectgarbage: function(CollectGarbageSetValue, integer): number
      collectgarbage: function(CollectGarbageIsRunning): boolean
      collectgarbage: function(string, ? number): (boolean | number)

      dofile: function(? string): any...

      error: function(? any, ? integer)
      getmetatable: function<T>(T): metatable<T>
      ipairs: function<A>({A}): (function():(integer, A)) --[[special_function]]

      load: function((string | LoadFunction), ? string, ? LoadMode, ? table): (function, string)
      load: function((string | LoadFunction), ? string, ? string, ? table): (function, string)

      loadfile: function(? string, ? string, ? {any:any}): (function, string)

      next: function<K, V>({K:V}, ? K): (K, V)
      next: function<A>({A}, ? integer): (integer, A)

      pairs: function<K, V>({K:V}): (function():(K, V)) --[[special_function]]
      pcall: function(function(any...):(any...), any...): boolean, any... --[[special_function]]
      print: function(any...)
      rawequal: function(any, any): boolean

      rawget: function<K, V>({K:V}, K): V --[[special_function]]
      rawget: function({any:any}, any): any
      rawget: function(any, any): any

      rawlen: function<A>({A}): integer

      rawset: function<K, V>({K:V}, K, V): {K:V}
      rawset: function({any:any}, any, any): {any:any}
      rawset: function(any, any, any): any

      require: function(string): any --[[special_function]]

      select: function<T>(integer, T...): T...
      select: function(integer, any...): any...
      select: function(string, any...): integer

      setmetatable: function<T>(T, metatable<T>): T

      tonumber: function(any): number
      tonumber: function(any, integer): integer

      tostring: function(any): string
      type: function(any): string
      warn: function(string, string...)
      xpcall: function(function(any...):(any...), XpcallMsghFunction, any...): boolean, any... --[[special_function]]
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







local Errors = {}






local tl = { GenerateOptions = {}, CheckOptions = {}, Env = {}, Result = {}, Error = {}, TypeInfo = {}, TypeReport = {}, EnvOptions = {}, Comment = {}, Token = {}, TypeCheckOptions = {} }


























































































































































































































local TypeReporter = {}








local wk = {
   ["unknown"] = true,
   ["unused"] = true,
   ["redeclaration"] = true,
   ["branch"] = true,
   ["hint"] = true,
   ["debug"] = true,
   ["unread"] = true,
}
tl.warning_kinds = wk












tl.typecodes = {

   NIL = 0x00000001,
   NUMBER = 0x00000002,
   BOOLEAN = 0x00000004,
   STRING = 0x00000008,
   TABLE = 0x00000010,
   FUNCTION = 0x00000020,
   USERDATA = 0x00000040,
   THREAD = 0x00000080,

   INTEGER = 0x00010002,
   ENUM = 0x00010004,
   EMPTY_TABLE = 0x00000008,
   ARRAY = 0x00010008,
   RECORD = 0x00020008,
   MAP = 0x00040008,
   TUPLE = 0x00080008,
   INTERFACE = 0x00100008,
   SELF = 0x00200008,
   POLY = 0x20000020,
   UNION = 0x40000000,

   NOMINAL = 0x10000000,
   TYPE_VARIABLE = 0x08000000,

   ANY = 0xffffffff,
   UNKNOWN = 0x80008000,
   INVALID = 0x80000000,
}



















local DEFAULT_GEN_COMPAT = "optional"
local DEFAULT_GEN_TARGET = "5.3"



























local TL_DEBUG = os.getenv("TL_DEBUG")
local TL_DEBUG_FACTS = os.getenv("TL_DEBUG_FACTS")
local TL_DEBUG_MAXLINE = _tl_math_maxinteger

if TL_DEBUG_FACTS and not TL_DEBUG then
   TL_DEBUG = "1"
end

if TL_DEBUG then
   local max = assert(tonumber(TL_DEBUG), "TL_DEBUG was defined, but not a number")
   if max < 0 then
      TL_DEBUG_MAXLINE = math.tointeger(-max)
   elseif max > 1 then
      local count = 0
      local skip
      debug.sethook(function(event)
         if event == "call" or event == "tail call" or event == "return" then
            local info = debug.getinfo(2)

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
            io.stderr:write(name, " :: ", event, "\n")
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





do





































   local last_token_kind = {
      ["start"] = nil,
      ["any"] = nil,
      ["identifier"] = "identifier",
      ["got -"] = "op",
      ["got --"] = nil,
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
      ["got --["] = nil,
      ["string single"] = "$ERR$",
      ["string single got \\"] = "$ERR$",
      ["string double"] = "$ERR$",
      ["string double got \\"] = "$ERR$",
      ["string long"] = "$ERR$",
      ["string long got ]"] = "$ERR$",
      ["comment short"] = nil,
      ["comment long"] = "$ERR$",
      ["comment long got ]"] = "$ERR$",
      ["number dec"] = "integer",
      ["number decfloat"] = "number",
      ["number hex"] = "integer",
      ["number hexfloat"] = "number",
      ["number power"] = "number",
      ["number powersign"] = "$ERR$",
      ["pragma"] = nil,
      ["pragma any"] = nil,
      ["pragma word"] = "pragma_identifier",
   }

   local keywords = {
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

   local lex_any_char_states = {
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

   local lex_word = {}
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

   local lex_decimals = {}
   for c = string.byte("0"), string.byte("9") do
      lex_decimals[string.char(c)] = true
   end

   local lex_hexadecimals = {}
   for c = string.byte("0"), string.byte("9") do
      lex_hexadecimals[string.char(c)] = true
   end
   for c = string.byte("a"), string.byte("f") do
      lex_hexadecimals[string.char(c)] = true
   end
   for c = string.byte("A"), string.byte("F") do
      lex_hexadecimals[string.char(c)] = true
   end

   local lex_any_char_kinds = {}
   local single_char_kinds = { "[", "]", "(", ")", "{", "}", ",", ";", "?" }
   for _, c in ipairs(single_char_kinds) do
      lex_any_char_kinds[c] = c
   end
   for _, c in ipairs({ "#", "+", "*", "|", "&", "%", "^" }) do
      lex_any_char_kinds[c] = "op"
   end

   local lex_space = {}
   for _, c in ipairs({ " ", "\t", "\v", "\n", "\r" }) do
      lex_space[c] = true
   end

   local escapable_characters = {
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

   local function lex_string_escape(input, i, c)
      if escapable_characters[c] then
         return 0, true
      elseif c == "x" then
         return 2, (
         lex_hexadecimals[input:sub(i + 1, i + 1)] and
         lex_hexadecimals[input:sub(i + 2, i + 2)])

      elseif c == "u" then
         if input:sub(i + 1, i + 1) == "{" then
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
         local len = lex_decimals[input:sub(i + 1, i + 1)] and
         (lex_decimals[input:sub(i + 2, i + 2)] and 2 or 1) or
         0
         return len, tonumber(input:sub(i, i + len)) < 256
      else
         return 0, false
      end
   end

   tl.lex = function(input, filename)
      local tokens = {}

      local state = "any"
      local fwd = true
      local y = 1
      local x = 0
      local i = 0
      local lc_open_lvl = 0
      local lc_close_lvl = 0
      local ls_open_lvl = 0
      local ls_close_lvl = 0
      local errs = {}
      local nt = 0

      local tx
      local ty
      local ti
      local in_token = false

      local comments

      local function begin_token()
         tx = x
         ty = y
         ti = i
         in_token = true
      end

      local function end_token(kind, tk)
         nt = nt + 1
         tokens[nt] = {
            x = tx,
            y = ty,
            tk = tk,
            kind = kind,
            comments = comments,
         }
         comments = nil
         in_token = false
      end

      local function end_token_identifier()
         local tk = input:sub(ti, i - 1)
         nt = nt + 1
         tokens[nt] = {
            x = tx,
            y = ty,
            tk = tk,
            kind = keywords[tk] and "keyword" or "identifier",
            comments = comments,
         }
         comments = nil
         in_token = false
      end

      local function end_token_prev(kind)
         local tk = input:sub(ti, i - 1)
         nt = nt + 1
         tokens[nt] = {
            x = tx,
            y = ty,
            tk = tk,
            kind = kind,
            comments = comments,
         }
         comments = nil
         in_token = false
      end

      local function end_token_here(kind)
         local tk = input:sub(ti, i)
         nt = nt + 1
         tokens[nt] = {
            x = tx,
            y = ty,
            tk = tk,
            kind = kind,
            comments = comments,

         }
         comments = nil
         in_token = false
      end

      local function drop_token()
         in_token = false
      end

      local function add_syntax_error(msg)
         local t = tokens[nt]
         table.insert(errs, {
            filename = filename,
            y = t.y,
            x = t.x,
            msg = msg or "invalid token '" .. t.tk .. "'",
         })
      end

      local function add_comment(text)
         if not comments then
            comments = {}
         end
         comments[#comments + 1] = {
            x = tx,
            y = ty,
            text = text,
         }
      end

      local len = #input
      if input:sub(1, 2) == "#!" then
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

         local c = input:sub(i, i)

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
                  end_token_here("$ERR$")
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
               add_comment(input:sub(ti, i - 1))
               state = "any"
            end
         elseif state == "got =" then
            local t
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
            local t
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
            elseif c == "#" then
               state = "pragma"
            else
               fwd = false
               state = "comment short"
               drop_token()
            end
         elseif state == "pragma" then
            if not lex_word[c] then
               end_token_prev("pragma")
               if tokens[nt].tk == "--#pragma" then
                  state = "pragma any"
               else
                  state = "comment short"
                  table.remove(tokens)
                  nt = nt - 1
                  drop_token()
               end
               fwd = false
            end
         elseif state == "pragma any" then
            if c == "\n" then
               state = "any"
            elseif lex_word[c] then
               state = "pragma word"
               begin_token()
            elseif not lex_space[c] then
               begin_token()
               end_token_here("$ERR$")
               add_syntax_error()
            end
         elseif state == "pragma word" then
            if not lex_word[c] then
               end_token_prev("pragma_identifier")
               fwd = false
               state = (c == "\n") and "any" or "pragma any"
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
               add_comment(input:sub(ti, i))
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
               end_token_here("$ERR$")
               add_syntax_error("malformed string")
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
               end_token_here("$ERR$")
               add_syntax_error("malformed string")
            end
            x = x + skip
            state = "string single"
         elseif state == "got ~" then
            local t
            if c == "=" then
               t = "~="
            else
               t = "~"
               fwd = false
            end
            end_token("op", t)
            state = "any"
         elseif state == "got <" then
            local t
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
            local t
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
            local t
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
               end_token_here("$ERR$")
               add_syntax_error("malformed number")
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
            if last_token_kind[state] == "$ERR$" then
               local state_type = state:sub(1, 6)
               if state_type == "string" then
                  add_syntax_error("malformed string")
               elseif state_type == "number" then
                  add_syntax_error("malformed number")
               elseif state_type == "commen" then
                  add_syntax_error("unfinished long comment")
               else
                  add_syntax_error()
               end
            elseif keywords[tokens[nt].tk] then
               tokens[nt].kind = "keyword"
            end
         else
            drop_token()
         end
      end

      table.insert(tokens, { x = x + 1, y = y, i = i, tk = "$EOF$", kind = "$EOF$", comments = comments })

      return tokens, errs
   end
end

local function binary_search(list, item, cmp)
   local len = #list
   local mid
   local s, e = 1, len
   while s <= e do
      mid = math.floor((s + e) / 2)
      local val = list[mid]
      local res = cmp(val, item)
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

tl.get_token_at = function(tks, y, x)
   local _, found = binary_search(
   tks, nil,
   function(tk)
      return tk.y < y or
      (tk.y == y and tk.x <= x)
   end)


   if found and
      found.y == y and
      found.x <= x and x < found.x + #found.tk then

      return found.tk
   end
end





local last_typeid = 0

local function new_typeid()
   last_typeid = last_typeid + 1
   return last_typeid
end







































local table_types = {
   ["array"] = true,
   ["map"] = true,
   ["record"] = true,
   ["interface"] = true,
   ["self"] = true,
   ["emptytable"] = true,
   ["tupletable"] = true,

   ["generic"] = false,
   ["typedecl"] = false,
   ["typevar"] = false,
   ["typearg"] = false,
   ["function"] = false,
   ["enum"] = false,
   ["boolean"] = false,
   ["string"] = false,
   ["nil"] = false,
   ["thread"] = false,
   ["userdata"] = false,
   ["number"] = false,
   ["integer"] = false,
   ["union"] = false,
   ["nominal"] = false,
   ["literal_table_item"] = false,
   ["unresolved_emptytable_value"] = false,
   ["unresolved_typearg"] = false,
   ["unresolvable_typearg"] = false,
   ["circular_require"] = false,
   ["boolean_context"] = false,
   ["tuple"] = false,
   ["poly"] = false,
   ["any"] = false,
   ["unknown"] = false,
   ["invalid"] = false,
   ["none"] = false,
   ["*"] = false,
}






















































local function is_numeric_type(t)
   return t.typename == "number" or t.typename == "integer"
end




























































































































































































































































































































local TruthyFact = {}






local NotFact = {}








local AndFact = {}









local OrFact = {}









local EqFact = {}









local IsFact = {}





















local attributes = {
   ["const"] = true,
   ["close"] = true,
   ["total"] = true,
}
local is_attribute = attributes

local Node = { ExpectedContext = {} }



















































































































local show_type

local type_mt = {
   __tostring = function(t)
      return show_type(t)
   end,
}

local function a_type(w, typename, t)
   t.typeid = new_typeid()
   t.f = w.f
   t.x = w.x
   t.y = w.y
   t.typename = typename
   do
      local ty = t
      setmetatable(ty, type_mt)
   end
   return t
end

local function edit_type(w, t, typename)
   t.typeid = new_typeid()
   t.f = w.f
   t.x = w.x
   t.y = w.y
   t.typename = typename
   setmetatable(t, type_mt)
   return t
end

















local function a_function(w, t)
   assert(t.min_arity)
   return a_type(w, "function", t)
end

local function a_vararg(w, t)
   local typ = a_type(w, "tuple", { tuple = t })
   typ.is_va = true
   return typ
end





















local an_operator

local function shallow_copy_new_type(t)
   local copy = {}
   for k, v in pairs(t) do
      copy[k] = v
   end
   copy.typeid = new_typeid()
   do
      local ty = copy
      setmetatable(ty, type_mt)
   end
   return copy
end

local function shallow_copy_table(t)
   local copy = {}
   for k, v in pairs(t) do
      copy[k] = v
   end
   return copy
end


local function clear_redundant_errors(errors)
   local redundant = {}
   local lastx, lasty = 0, 0
   for i, err in ipairs(errors) do
      err.i = i
   end
   table.sort(errors, function(a, b)
      local af = assert(a.filename)
      local bf = assert(b.filename)
      return af < bf or
      (af == bf and (a.y < b.y or
      (a.y == b.y and (a.x < b.x or
      (a.x == b.x and (a.i < b.i))))))
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

local simple_types = {
   ["nil"] = true,
   ["any"] = true,
   ["number"] = true,
   ["string"] = true,
   ["thread"] = true,
   ["boolean"] = true,
   ["integer"] = true,
   ["self"] = true,
}

local function node_is_require_call(n)
   if not (n.e1 and n.e2) then
      return nil
   end
   if n.op and n.op.op == "." then

      return node_is_require_call(n.e1)
   elseif n.e1.kind == "variable" and n.e1.tk == "require" and
      n.e2.kind == "expression_list" and #n.e2 == 1 and
      n.e2[1].kind == "string" then


      return n.e2[1].conststr
   end
   return nil
end

local function node_is_funcall(node)
   return node.kind == "op" and node.op.op == "@funcall"
end










do
























   local parse_type_list
   local parse_typeargs_if_any
   local parse_expression
   local parse_expression_and_tk
   local parse_statements
   local parse_argument_list
   local parse_argument_type_list
   local parse_type
   local parse_type_declaration
   local parse_interface_name


   local parse_enum_body
   local parse_record_body
   local parse_type_body_fns

   local function fail(ps, i, msg)
      if not ps.tokens[i] then
         local eof = ps.tokens[#ps.tokens]
         table.insert(ps.errs, { filename = ps.filename, y = eof.y, x = eof.x, msg = msg or "unexpected end of file" })
         return #ps.tokens
      end
      table.insert(ps.errs, { filename = ps.filename, y = ps.tokens[i].y, x = ps.tokens[i].x, msg = assert(msg, "syntax error, but no error message provided") })
      return math.min(#ps.tokens, i + 1)
   end

   local function end_at(node, tk)
      node.yend = tk.y
      node.xend = tk.x + #tk.tk - 1
   end

   local function verify_tk(ps, i, tk)
      if ps.tokens[i].tk == tk then
         return i + 1
      end
      return fail(ps, i, "syntax error, expected '" .. tk .. "'")
   end

   local function verify_end(ps, i, istart, node)
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

   local node_mt = {
      __tostring = function(n)
         return n.f .. ":" .. n.y .. ":" .. n.x .. " " .. n.kind
      end,
   }

   local function new_node(ps, i, kind)
      local t = ps.tokens[i]
      return setmetatable({ f = ps.filename, y = t.y, x = t.x, tk = t.tk, kind = kind or (t.kind) }, node_mt)
   end

   local function new_type(ps, i, typename)
      local token = ps.tokens[i]
      local t = setmetatable({}, type_mt)
      t.typeid = new_typeid()
      t.f = ps.filename
      t.x = token.x
      t.y = token.y
      t.typename = typename
      return t
   end

   local function new_first_order_type(ps, i, tn)
      return new_type(ps, i, tn)
   end

   local function new_generic(ps, i, typeargs, typ)
      local gt = new_type(ps, i, "generic")
      gt.typeargs = typeargs
      gt.t = typ
      return gt
   end

   local function new_typedecl(ps, i, def)
      local t = new_type(ps, i, "typedecl")
      t.def = def
      return t
   end

   local function new_tuple(ps, i, types, is_va)
      local t = new_type(ps, i, "tuple")
      t.is_va = is_va
      t.tuple = types or {}
      return t, t.tuple
   end

   local function new_nominal(ps, i, name)
      local t = new_type(ps, i, "nominal")
      if name then
         t.names = { name }
      end
      return t
   end

   local function verify_kind(ps, i, kind, node_kind)
      if ps.tokens[i].kind == kind then
         return i + 1, new_node(ps, i, node_kind)
      end
      return fail(ps, i, "syntax error, expected " .. kind)
   end



   local function skip(ps, i, skip_fn)
      local err_ps = {
         filename = ps.filename,
         tokens = ps.tokens,
         errs = {},
         required_modules = {},
         parse_lang = ps.parse_lang,
      }
      return skip_fn(err_ps, i)
   end

   local function failskip(ps, i, msg, skip_fn, starti)
      local skip_i = skip(ps, starti or i, skip_fn)
      fail(ps, i, msg)
      return skip_i
   end

   local function parse_type_body(ps, i, istart, node, tn)
      local typeargs
      local def
      i, typeargs = parse_typeargs_if_any(ps, i)

      def = new_first_order_type(ps, istart, tn)

      local ok
      i, ok = parse_type_body_fns[tn](ps, i, def)
      if not ok then
         return fail(ps, i, "expected a type")
      end

      i = verify_end(ps, i, istart, node)

      if typeargs then
         return i, new_generic(ps, istart, typeargs, def)
      end

      return i, def
   end

   local function skip_type_body(ps, i)
      local tn = ps.tokens[i].tk
      i = i + 1
      assert(parse_type_body_fns[tn], tn .. " has no parse body function")
      local ii, tt = parse_type_body(ps, i, i - 1, {}, tn)
      return ii, not not tt
   end

   local function parse_table_value(ps, i)
      local next_word = ps.tokens[i].tk
      if next_word == "record" or next_word == "interface" then
         local skip_i, e = skip(ps, i, skip_type_body)
         if e then
            fail(ps, i, next_word == "record" and
            "syntax error: this syntax is no longer valid; declare nested record inside a record" or
            "syntax error: cannot declare interface inside a table; use a statement")
            return skip_i, new_node(ps, i, "error_node")
         end
      elseif next_word == "enum" and ps.tokens[i + 1].kind == "string" then
         i = failskip(ps, i, "syntax error: this syntax is no longer valid; declare nested enum inside a record", skip_type_body)
         return i, new_node(ps, i - 1, "error_node")
      end

      local e
      i, e = parse_expression(ps, i)
      if not e then
         e = new_node(ps, i - 1, "error_node")
      end
      return i, e
   end

   local function parse_table_item(ps, i, n)
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
         if ps.tokens[i + 1].tk == "=" then
            node.key_parsed = "short"
            i, node.key = verify_kind(ps, i, "identifier", "string")
            node.key.conststr = node.key.tk
            node.key.tk = '"' .. node.key.tk .. '"'
            i = verify_tk(ps, i, "=")
            i, node.value = parse_table_value(ps, i)
            return i, node, n
         elseif ps.tokens[i + 1].tk == ":" then
            node.key_parsed = "short"
            local orig_i = i
            local try_ps = {
               filename = ps.filename,
               tokens = ps.tokens,
               errs = {},
               required_modules = ps.required_modules,
               parse_lang = ps.parse_lang,
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








   local function parse_list(ps, i, list, close, sep, parse_item)
      local n = 1
      while ps.tokens[i].kind ~= "$EOF$" do
         if close[ps.tokens[i].tk] then
            end_at(list, ps.tokens[i])
            break
         end
         local item
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
            local msg

            if first == ")" and ps.tokens[i].tk == "=" then
               msg = "syntax error, cannot perform an assignment here (did you mean '=='?)"
               i = failskip(ps, i, msg, parse_expression, i + 1)
            else
               table.insert(options, "','")
               msg = "syntax error, expected one of: " .. table.concat(options, ", ")
               fail(ps, i, msg)
            end



            if first ~= "}" and ps.tokens[i].y ~= ps.tokens[i - 1].y then

               table.insert(ps.tokens, i, { tk = first, y = ps.tokens[i - 1].y, x = ps.tokens[i - 1].x + 1, kind = "keyword" })
               return i, list
            end
         end
      end
      return i, list
   end

   local function parse_bracket_list(ps, i, list, open, close, sep, parse_item)
      i = verify_tk(ps, i, open)
      i = parse_list(ps, i, list, { [close] = true }, sep, parse_item)
      i = verify_tk(ps, i, close)
      return i, list
   end

   local function parse_table_literal(ps, i)
      local node = new_node(ps, i, "literal_table")
      return parse_bracket_list(ps, i, node, "{", "}", "term", parse_table_item)
   end

   local function parse_trying_list(ps, i, list, parse_item, ret_lookahead)
      local try_ps = {
         filename = ps.filename,
         tokens = ps.tokens,
         errs = {},
         required_modules = ps.required_modules,
         parse_lang = ps.parse_lang,
      }
      local tryi, item = parse_item(try_ps, i)
      if not item then
         return i, list
      end
      for _, e in ipairs(try_ps.errs) do
         table.insert(ps.errs, e)
      end
      i = tryi
      table.insert(list, item)
      while ps.tokens[i].tk == "," and
         (not ret_lookahead or
         (not (ps.tokens[i + 1].kind == "identifier" and
         ps.tokens[i + 2] and ps.tokens[i + 2].tk == ":"))) do

         i = i + 1
         i, item = parse_item(ps, i)
         table.insert(list, item)
      end
      return i, list
   end

   local function parse_anglebracket_list(ps, i, parse_item)
      local second = ps.tokens[i + 1]
      if second.tk == ">" then
         return fail(ps, i + 1, "type argument list cannot be empty")
      elseif second.tk == ">>" then

         second.tk = ">"
         fail(ps, i + 1, "type argument list cannot be empty")
         return i + 1
      end

      local types = {}
      i = verify_tk(ps, i, "<")
      i = parse_list(ps, i, types, { [">"] = true, [">>"] = true }, "sep", parse_item)
      if ps.tokens[i].tk == ">" then
         i = i + 1
      elseif ps.tokens[i].tk == ">>" then

         ps.tokens[i].tk = ">"
      else
         return fail(ps, i, "syntax error, expected '>'")
      end
      return i, types
   end

   local function parse_typearg(ps, i)
      local name = ps.tokens[i].tk
      local constraint
      local t = new_type(ps, i, "typearg")
      i = verify_kind(ps, i, "identifier")
      if ps.tokens[i].tk == "is" then
         i = i + 1
         i, constraint = parse_interface_name(ps, i)
      end
      t.typearg = name
      t.constraint = constraint
      return i, t
   end

   local function parse_return_types(ps, i)
      local iprev = i - 1
      local t
      i, t = parse_type_list(ps, i, "rets")
      if #t.tuple == 0 then
         t.x = ps.tokens[iprev].x
         t.y = ps.tokens[iprev].y
      end
      return i, t
   end

   parse_typeargs_if_any = function(ps, i)
      if ps.tokens[i].tk == "<" then
         return parse_anglebracket_list(ps, i, parse_typearg)
      end
      return i
   end

   local function parse_function_type(ps, i)
      local typeargs
      local typ = new_type(ps, i, "function")
      i = i + 1

      i, typeargs = parse_typeargs_if_any(ps, i)
      if ps.tokens[i].tk == "(" then
         i, typ.args, typ.maybe_method, typ.min_arity = parse_argument_type_list(ps, i)
         i, typ.rets = parse_return_types(ps, i)
      else
         typ.args = new_tuple(ps, i, { new_type(ps, i, "any") }, true)
         typ.rets = new_tuple(ps, i, { new_type(ps, i, "any") }, true)
         typ.is_method = false
         typ.min_arity = 0
      end

      if typeargs then
         return i, new_generic(ps, i, typeargs, typ)
      end

      return i, typ
   end

   local function parse_simple_type_or_nominal(ps, i)
      local tk = ps.tokens[i].tk
      local st = simple_types[tk]
      if st then
         return i + 1, new_type(ps, i, tk)
      elseif tk == "table" and ps.tokens[i + 1].tk ~= "." then
         local typ = new_type(ps, i, "map")
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

   local function parse_base_type(ps, i)
      local tk = ps.tokens[i].tk
      if ps.tokens[i].kind == "identifier" then
         return parse_simple_type_or_nominal(ps, i)
      elseif tk == "{" then
         local istart = i
         i = i + 1
         local t
         i, t = parse_type(ps, i)
         if not t then
            return i
         end
         if ps.tokens[i].tk == "}" then
            local decl = new_type(ps, istart, "array")
            decl.elements = t
            end_at(decl, ps.tokens[i])
            i = verify_tk(ps, i, "}")
            return i, decl
         elseif ps.tokens[i].tk == "," then
            local decl = new_type(ps, istart, "tupletable")
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
            end_at(decl, ps.tokens[i])
            i = verify_tk(ps, i, "}")
            return i, decl
         elseif ps.tokens[i].tk == ":" then
            local decl = new_type(ps, istart, "map")
            i = i + 1
            decl.keys = t
            i, decl.values = parse_type(ps, i)
            if not decl.values then
               return i
            end
            end_at(decl, ps.tokens[i])
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

   parse_type = function(ps, i)
      if ps.tokens[i].tk == "(" then
         i = i + 1
         local t
         i, t = parse_type(ps, i)
         i = verify_tk(ps, i, ")")
         return i, t
      end

      local bt
      local istart = i
      i, bt = parse_base_type(ps, i)
      if not bt then
         return i
      end
      if ps.tokens[i].tk == "|" then
         local u = new_type(ps, istart, "union")
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

   parse_type_list = function(ps, i, mode)
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
      i = parse_trying_list(ps, i, list, parse_type, mode == "rets")
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

   local function parse_function_args_rets_body(ps, i, node)
      local istart = i - 1
      i, node.typeargs = parse_typeargs_if_any(ps, i)
      i, node.args, node.min_arity = parse_argument_list(ps, i)
      i, node.rets = parse_return_types(ps, i)
      i, node.body = parse_statements(ps, i)
      end_at(node, ps.tokens[i])
      i = verify_end(ps, i, istart, node)
      return i, node
   end

   local function parse_function_value(ps, i)
      local node = new_node(ps, i, "function")
      i = verify_tk(ps, i, "function")
      return parse_function_args_rets_body(ps, i, node)
   end

   local function unquote(str)
      local f = str:sub(1, 1)
      if f == '"' or f == "'" then
         return str:sub(2, -2), false
      end
      f = str:match("^%[=*%[")
      local l = #f + 1
      return str:sub(l, -l), true
   end

   local function parse_literal(ps, i)
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
         local node
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
      elseif kind == "$ERR$" then
         return fail(ps, i, "invalid token")
      end
      return fail(ps, i, "syntax error")
   end

   local function node_is_require_call_or_pcall(n)
      local r = node_is_require_call(n)
      if r then
         return r
      end
      if node_is_funcall(n) and
         n.e1 and n.e1.tk == "pcall" and
         n.e2 and #n.e2 == 2 and
         n.e2[1].kind == "variable" and n.e2[1].tk == "require" and
         n.e2[2].kind == "string" and n.e2[2].conststr then


         return n.e2[2].conststr
      end
      return nil
   end

   do
      local precedences = {
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

      local is_right_assoc = {
         ["^"] = true,
         [".."] = true,
      }

      local function new_operator(tk, arity, op)
         return { y = tk.y, x = tk.x, arity = arity, op = op, prec = precedences[arity][op] }
      end

      an_operator = function(node, arity, op)
         return { y = node.y, x = node.x, arity = arity, op = op, prec = precedences[arity][op] }
      end

      local args_starters = {
         ["("] = true,
         ["{"] = true,
         ["string"] = true,
      }

      local E

      local function after_valid_prefixexp(ps, prevnode, i)
         return ps.tokens[i - 1].kind == ")" or
         (prevnode.kind == "op" and
         (prevnode.op.op == "@funcall" or
         prevnode.op.op == "@index" or
         prevnode.op.op == "." or
         prevnode.op.op == ":")) or

         prevnode.kind == "identifier" or
         prevnode.kind == "variable"
      end



      local function failstore(ps, tkop, e1)
         return { f = ps.filename, y = tkop.y, x = tkop.x, kind = "paren", e1 = e1, failstore = true }
      end

      local function P(ps, i)
         if ps.tokens[i].kind == "$EOF$" then
            return i
         end
         local e1
         local t1 = ps.tokens[i]
         if precedences[1][t1.tk] ~= nil then
            local op = new_operator(t1, 1, t1.tk)
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
            if tkop.kind == "," or tkop.kind == ")" then
               break
            end
            if tkop.tk == "." or tkop.tk == ":" then
               local op = new_operator(tkop, 2, tkop.tk)

               local prev_i = i

               local key
               i = i + 1
               if ps.tokens[i].kind ~= "identifier" then
                  local skipped = skip(ps, i, parse_type)
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
               if tkop.y > prev_tk.y and ps.parse_lang ~= "lua" then
                  table.insert(ps.tokens, i, { y = prev_tk.y, x = prev_tk.x + #prev_tk.tk, tk = ";", kind = ";" })
                  break
               end

               local op = new_operator(tkop, 2, "@funcall")

               local prev_i = i

               local args = new_node(ps, i, "expression_list")
               i, args = parse_bracket_list(ps, i, args, "(", ")", "sep", parse_expression)

               if not after_valid_prefixexp(ps, e1, prev_i) then
                  fail(ps, prev_i, "cannot call this expression")
                  return i, failstore(ps, tkop, e1)
               end

               e1 = { f = ps.filename, y = args.y, x = args.x, kind = "op", op = op, e1 = e1, e2 = args }

               table.insert(ps.required_modules, node_is_require_call_or_pcall(e1))
            elseif tkop.tk == "[" then
               local op = new_operator(tkop, 2, "@index")

               local prev_i = i

               local idx
               i = i + 1
               i, idx = parse_expression_and_tk(ps, i, "]")

               if not after_valid_prefixexp(ps, e1, prev_i) then
                  fail(ps, prev_i, "cannot index this expression")
                  return i, failstore(ps, tkop, e1)
               end

               e1 = { f = ps.filename, y = tkop.y, x = tkop.x, kind = "op", op = op, e1 = e1, e2 = idx }
            elseif tkop.kind == "string" or tkop.kind == "{" then
               local op = new_operator(tkop, 2, "@funcall")

               local prev_i = i

               local args = new_node(ps, i, "expression_list")
               local argument
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

               table.insert(ps.required_modules, node_is_require_call_or_pcall(e1))
            elseif tkop.tk == "as" or tkop.tk == "is" then
               local op = new_operator(tkop, 2, tkop.tk)

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

      E = function(ps, i, lhs, min_precedence)
         local lookahead = ps.tokens[i].tk
         while precedences[2][lookahead] and precedences[2][lookahead] >= min_precedence do
            local t1 = ps.tokens[i]
            local op = new_operator(t1, 2, t1.tk)
            i = i + 1
            local rhs
            i, rhs = P(ps, i)
            if not rhs then
               fail(ps, i, "expected an expression")
               return i
            end
            lookahead = ps.tokens[i].tk
            while precedences[2][lookahead] and ((precedences[2][lookahead] > (precedences[2][op.op])) or
               (is_right_assoc[lookahead] and (precedences[2][lookahead] == precedences[2][op.op]))) do
               i, rhs = E(ps, i, rhs, precedences[2][lookahead])
               if not rhs then
                  fail(ps, i, "expected an expression")
                  return i
               end
               lookahead = ps.tokens[i].tk
            end
            lhs = { f = ps.filename, y = t1.y, x = t1.x, kind = "op", op = op, e1 = lhs, e2 = rhs }
         end
         return i, lhs
      end

      parse_expression = function(ps, i)
         local lhs
         local istart = i
         i, lhs = P(ps, i)
         if lhs then
            i, lhs = E(ps, i, lhs, 0)
         end
         if lhs then
            return i, lhs, 0
         end

         if i == istart then
            i = fail(ps, i, "expected an expression")
         end
         return i
      end
   end

   parse_expression_and_tk = function(ps, i, tk)
      local e
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

   local function parse_variable_name(ps, i)
      local node
      i, node = verify_kind(ps, i, "identifier")
      if not node then
         return i
      end
      if ps.tokens[i].tk == "<" then
         i = i + 1
         local annotation
         i, annotation = verify_kind(ps, i, "identifier")
         if annotation then
            if not is_attribute[annotation.tk] then
               fail(ps, i, "unknown variable annotation: " .. annotation.tk)
            end
            node.attribute = annotation.tk
         else
            fail(ps, i, "expected a variable annotation")
         end
         i = verify_tk(ps, i, ">")
      end
      return i, node
   end

   local function parse_argument(ps, i)
      local node
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
         local argtype

         i, argtype = parse_type(ps, i)

         if node then
            node.argtype = argtype
         end
      end
      return i, node, 0
   end

   parse_argument_list = function(ps, i)
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









   local function parse_argument_type(ps, i)
      local opt = 0
      local is_va = false
      local is_self = false
      local argument_name = nil

      if ps.tokens[i].kind == "identifier" then
         argument_name = ps.tokens[i].tk
         if ps.tokens[i + 1].tk == "?" then
            opt = i + 1
            if ps.tokens[i + 2].tk == ":" then
               i = i + 3
            end
         elseif ps.tokens[i + 1].tk == ":" then
            i = i + 2
         end
      elseif ps.tokens[i].kind == "?" then
         opt = i
         i = i + 1
      elseif ps.tokens[i].tk == "..." then
         if ps.tokens[i + 1].tk == "?" then
            fail(ps, i + 1, "cannot mix '?' and '...' in a declaration; '...' already implies optional")
            i = i + 1
         end
         if ps.tokens[i + 1].tk == ":" then
            i = i + 2
            is_va = true
         else
            return fail(ps, i, "cannot have untyped '...' when declaring the type of an argument")
         end
      end

      local typ; i, typ = parse_type(ps, i)
      if typ then
         if not is_va and ps.tokens[i].tk == "..." then
            i = i + 1
            is_va = true
            if opt > 0 then
               fail(ps, opt, "cannot mix '?' and '...' in a declaration; '...' already implies optional")
            end
         end

         if argument_name == "self" then
            is_self = true
         end
      end

      return i, { i = i, type = typ, is_va = is_va, is_self = is_self, opt = (opt > 0) or is_va }, 0
   end

   parse_argument_type_list = function(ps, i)
      local ars = {}
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

   local function parse_identifier(ps, i)
      if ps.tokens[i].kind == "identifier" then
         return i + 1, new_node(ps, i, "identifier")
      end
      i = fail(ps, i, "syntax error, expected identifier")
      return i, new_node(ps, i, "error_node")
   end

   local function parse_local_function(ps, i)
      i = verify_tk(ps, i, "local")
      i = verify_tk(ps, i, "function")
      local node = new_node(ps, i - 2, "local_function")
      i, node.name = parse_identifier(ps, i)
      return parse_function_args_rets_body(ps, i, node)
   end






   local function parse_function(ps, i, fk)
      local orig_i = i
      i = verify_tk(ps, i, "function")
      local fn = new_node(ps, i - 1, "global_function")
      local names = {}
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

   local function parse_if_block(ps, i, n, node, is_else)
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
      block.yend, block.xend = block.body.yend, block.body.xend
      table.insert(node.if_blocks, block)
      return i, node
   end

   local function parse_if(ps, i)
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

   local function parse_while(ps, i)
      local istart = i
      local node = new_node(ps, i, "while")
      i = verify_tk(ps, i, "while")
      i, node.exp = parse_expression_and_tk(ps, i, "do")
      i, node.body = parse_statements(ps, i)
      i = verify_end(ps, i, istart, node)
      return i, node
   end

   local function parse_fornum(ps, i)
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

   local function parse_forin(ps, i)
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

   local function parse_for(ps, i)
      if ps.tokens[i + 1].kind == "identifier" and ps.tokens[i + 2].tk == "=" then
         return parse_fornum(ps, i)
      else
         return parse_forin(ps, i)
      end
   end

   local function parse_repeat(ps, i)
      local node = new_node(ps, i, "repeat")
      i = verify_tk(ps, i, "repeat")
      i, node.body = parse_statements(ps, i)
      node.body.is_repeat = true
      i = verify_tk(ps, i, "until")
      i, node.exp = parse_expression(ps, i)
      end_at(node, ps.tokens[i - 1])
      return i, node
   end

   local function parse_do(ps, i)
      local istart = i
      local node = new_node(ps, i, "do")
      i = verify_tk(ps, i, "do")
      i, node.body = parse_statements(ps, i)
      i = verify_end(ps, i, istart, node)
      return i, node
   end

   local function parse_break(ps, i)
      local node = new_node(ps, i, "break")
      i = verify_tk(ps, i, "break")
      return i, node
   end

   local function parse_goto(ps, i)
      local node = new_node(ps, i, "goto")
      i = verify_tk(ps, i, "goto")
      node.label = ps.tokens[i].tk
      i = verify_kind(ps, i, "identifier")
      return i, node
   end

   local function parse_label(ps, i)
      local node = new_node(ps, i, "label")
      i = verify_tk(ps, i, "::")
      node.label = ps.tokens[i].tk
      i = verify_kind(ps, i, "identifier")
      i = verify_tk(ps, i, "::")
      return i, node
   end

   local stop_statement_list = {
      ["end"] = true,
      ["else"] = true,
      ["elseif"] = true,
      ["until"] = true,
   }

   local stop_return_list = {
      [";"] = true,
      ["$EOF$"] = true,
   }

   for k, v in pairs(stop_statement_list) do
      stop_return_list[k] = v
   end

   local function parse_return(ps, i)
      local node = new_node(ps, i, "return")
      i = verify_tk(ps, i, "return")
      node.exps = new_node(ps, i, "expression_list")
      i = parse_list(ps, i, node.exps, stop_return_list, "sep", parse_expression)
      if ps.tokens[i].kind == ";" then
         i = i + 1
         if ps.tokens[i].kind ~= "$EOF$" and not stop_statement_list[ps.tokens[i].kind] then
            return fail(ps, i, "return must be the last statement of its block")
         end
      end
      return i, node
   end

   local function store_field_in_record(ps, i, field_name, newt, def, comments, meta)
      local field_order, fields, field_comments
      if meta then
         field_order, fields, field_comments = def.meta_field_order, def.meta_fields, def.meta_field_comments
      else
         field_order, fields, field_comments = def.field_order, def.fields, def.field_comments
      end

      if comments and not field_comments then
         field_comments = {}
         if meta then
            def.meta_field_comments = field_comments
         else
            def.field_comments = field_comments
         end
      end

      if not fields[field_name] then
         fields[field_name] = newt
         if comments then
            field_comments[field_name] = { comments }
         end
         table.insert(field_order, field_name)
         return true
      end

      local oldt = fields[field_name]
      local oldf = oldt.typename == "generic" and oldt.t or oldt
      local newf = newt.typename == "generic" and newt.t or newt

      local function store_comment_for_poly(poly)
         if comments then
            if not field_comments[field_name] then
               field_comments[field_name] = {}
               for idx = 1, #poly.types - 1 do
                  field_comments[field_name][idx] = {}
               end
            end
            table.insert(field_comments[field_name], comments)
         elseif field_comments and field_comments[field_name] then
            table.insert(field_comments[field_name], {})
         end
      end

      if newf.typename == "function" then
         if oldf.typename == "function" then
            local p = new_type(ps, i, "poly")
            p.types = { oldt, newt }
            fields[field_name] = p
            store_comment_for_poly(p)
            return true
         elseif oldt.typename == "poly" then
            table.insert(oldt.types, newt)
            store_comment_for_poly(oldt)
            return true
         end
      end
      fail(ps, i, "attempt to redeclare field '" .. field_name .. "' (only functions can be overloaded)")
      return false
   end

   local function set_declname(def, declname)
      if def.typename == "generic" then
         def = def.t
      end

      if def.typename == "record" or def.typename == "interface" or def.typename == "enum" then
         if not def.declname then
            def.declname = declname
         end
      end
   end

   local function get_attached_comments(token)
      if not token.comments then
         return nil
      end

      local function is_long_comment(c)
         return c.text:match("^%-%-%[(=*)%[") ~= nil
      end
      local last_comment = token.comments[#token.comments]


      if is_long_comment(last_comment) then
         local _, newlines = string.gsub(last_comment.text, "\n", "")
         local diff_y = token.y - last_comment.y - newlines

         if diff_y >= 0 and diff_y <= 1 then
            return { last_comment }
         else
            return nil
         end
      end

      local diff_y = token.y - last_comment.y
      if diff_y < 0 or diff_y > 1 then
         return nil
      end
      local first_n = 1
      for i = #token.comments, 2, -1 do
         local prev = token.comments[i - 1]
         if is_long_comment(prev) then
            first_n = i
            break
         end

         if token.comments[i].y - prev.y > 1 then
            first_n = i
            break
         end
      end

      local attached_comments =
      table.move(token.comments, first_n, #token.comments, 1, {})

      return attached_comments
   end

   local function parse_nested_type(ps, i, def, tn)
      local istart = i
      i = i + 1
      local iv = i

      local v
      i, v = verify_kind(ps, i, "identifier", "type_identifier")
      if not v then
         return fail(ps, i, "expected a variable name")
      end

      local nt = new_node(ps, istart, "newtype")

      local ndef
      i, ndef = parse_type_body(ps, i, istart, nt, tn)
      if not ndef then
         return i
      end

      set_declname(ndef, v.tk)

      nt.newtype = new_typedecl(ps, istart, ndef)

      store_field_in_record(ps, iv, v.tk, nt.newtype, def, get_attached_comments(ps.tokens[istart]))
      return i
   end

   parse_enum_body = function(ps, i, def)
      def.enumset = {}
      while ps.tokens[i].tk ~= "$EOF$" and ps.tokens[i].tk ~= "end" do
         local item
         i, item = verify_kind(ps, i, "string", "string")
         if item then
            local name = unquote(item.tk)
            def.enumset[name] = true
            local comments = get_attached_comments(ps.tokens[i - 1])
            if comments then
               if not def.value_comments then
                  def.value_comments = {}
               end
               def.value_comments[name] = comments
            end
         end
      end
      return i, true
   end

   local metamethod_names = {
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

   local function parse_macroexp(ps, istart, iargs)
      local node = new_node(ps, istart, "macroexp")

      local i
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

   local function parse_where_clause(ps, i, def)
      local node = new_node(ps, i, "macroexp")

      node.is_method = true
      node.args = new_node(ps, i, "argument_list")
      node.args[1] = new_node(ps, i, "argument")
      node.args[1].tk = "self"
      node.args[1].argtype = new_type(ps, i, "self");
      (node.args[1].argtype).display_type = def
      node.min_arity = 1
      node.rets = new_tuple(ps, i)
      node.rets.tuple[1] = new_type(ps, i, "boolean")
      i, node.exp = parse_expression(ps, i)
      end_at(node, ps.tokens[i - 1])
      return i, node
   end

   parse_interface_name = function(ps, i)
      local istart = i
      local typ
      i, typ = parse_simple_type_or_nominal(ps, i)
      if not (typ.typename == "nominal") then
         return fail(ps, istart, "expected an interface")
      end
      return i, typ
   end

   local function parse_array_interface_type(ps, i, def)
      if def.interface_list then
         local first = def.interface_list[1]
         if first.typename == "array" then
            return failskip(ps, i, "duplicated declaration of array element type", parse_type)
         end
      end
      local t
      i, t = parse_base_type(ps, i)
      if not t then
         return i
      end
      if not (t.typename == "array") then
         fail(ps, i, "expected an array declaration")
         return i
      end
      def.elements = t.elements
      return i, t
   end












   local function extract_userdata_from_interface_list(ps, i, def)
      for j = #def.interface_list, 1, -1 do
         local iface = def.interface_list[j]
         if iface.typename == "nominal" and #iface.names == 1 and iface.names[1] == "userdata" then
            table.remove(def.interface_list, j)
            if def.is_userdata then
               fail(ps, i, "duplicated 'userdata' declaration")
            end
            def.is_userdata = true
         end
      end
   end

   parse_record_body = function(ps, i, def)
      def.fields = {}
      def.field_order = {}

      if ps.tokens[i].tk == "{" then
         local atype
         i, atype = parse_array_interface_type(ps, i, def)
         if atype then
            def.interface_list = { atype }
         end
      end

      if ps.tokens[i].tk == "is" then
         i = i + 1

         if ps.tokens[i].tk == "{" then
            local atype
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

         if def.interface_list then
            extract_userdata_from_interface_list(ps, i, def)
         end
      end

      if ps.tokens[i].tk == "where" then
         local wstart = i
         i = i + 1
         local where_macroexp
         i, where_macroexp = parse_where_clause(ps, i, def)

         local typ = new_type(ps, wstart, "function")

         typ.is_method = true
         typ.min_arity = 1
         typ.args = new_tuple(ps, wstart, {
            a_type(where_macroexp, "self", { display_type = def }),
         })
         typ.rets = new_tuple(ps, wstart, { new_type(ps, wstart, "boolean") })
         typ.macroexp = where_macroexp

         def.meta_fields = {}
         def.meta_field_order = {}
         store_field_in_record(ps, i, "__is", typ, def, nil, "meta")
      end

      while not (ps.tokens[i].kind == "$EOF$" or ps.tokens[i].tk == "end") do
         local tn = ps.tokens[i].tk
         if ps.tokens[i].tk == "userdata" and ps.tokens[i + 1].tk ~= ":" then
            if def.is_userdata then
               fail(ps, i, "duplicated 'userdata' declaration")
            else
               def.is_userdata = true
            end
            i = i + 1
         elseif ps.tokens[i].tk == "{" then
            return fail(ps, i, "syntax error: this syntax is no longer valid; declare array interface at the top with 'is {...}'")
         elseif ps.tokens[i].tk == "type" and ps.tokens[i + 1].tk ~= ":" then
            local comments = get_attached_comments(ps.tokens[i])
            i = i + 1
            local iv = i

            local lt
            i, lt = parse_type_declaration(ps, i, "local_type")
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
            if ntt.is_alias then
               ntt.is_nested_alias = true
            end

            store_field_in_record(ps, iv, v.tk, nt.newtype, def, comments)
         elseif parse_type_body_fns[tn] and ps.tokens[i + 1].tk ~= ":" then
            if def.typename == "interface" and tn == "record" then
               i = failskip(ps, i, "interfaces cannot contain record definitions", skip_type_body)
            else
               i = parse_nested_type(ps, i, def, tn)
            end
         else
            local comments = get_attached_comments(ps.tokens[i])
            local is_metamethod = false
            if ps.tokens[i].tk == "metamethod" and ps.tokens[i + 1].tk ~= ":" then
               is_metamethod = true
               i = i + 1
            end

            local v
            if ps.tokens[i].tk == "[" then
               i, v = parse_literal(ps, i + 1)
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
               local t
               i, t = parse_type(ps, i)
               if not t then
                  return fail(ps, i, "expected a type")
               end
               if t.typename == "function" and t.maybe_method then
                  t.is_method = true
               end

               local field_name = v.conststr or v.tk
               if is_metamethod then
                  if not def.meta_fields then
                     def.meta_fields = {}
                     def.meta_field_order = {}
                  end
                  if not metamethod_names[field_name] then
                     fail(ps, i - 1, "not a valid metamethod: " .. field_name)
                  end
               end

               if ps.tokens[i].tk == "=" and ps.tokens[i + 1].tk == "macroexp" then
                  local tt = t.typename == "generic" and t.t or t

                  if tt.typename == "function" then
                     i, tt.macroexp = parse_macroexp(ps, i + 1, i + 2)
                  else
                     fail(ps, i + 1, "macroexp must have a function type")
                  end
               end

               store_field_in_record(ps, iv, field_name, t, def, comments, is_metamethod and "meta" or nil)
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
      return i, true
   end

   parse_type_body_fns = {
      ["interface"] = parse_record_body,
      ["record"] = parse_record_body,
      ["enum"] = parse_enum_body,
   }

   local function parse_newtype(ps, i)
      local node = new_node(ps, i, "newtype")
      local def
      local tn = ps.tokens[i].tk
      local istart = i

      if parse_type_body_fns[tn] then
         i, def = parse_type_body(ps, i + 1, istart, node, tn)
      else
         i, def = parse_type(ps, i)
      end
      if not def then
         return fail(ps, i, "expected a type")
      end

      node.newtype = new_typedecl(ps, istart, def)

      if def.typename == "nominal" then
         node.newtype.is_alias = true
      elseif def.typename == "generic" then
         local deft = def.t
         if deft.typename == "nominal" then
            node.newtype.is_alias = true
         end
      end

      return i, node
   end

   local function parse_assignment_expression_list(ps, i, asgn)
      asgn.exps = new_node(ps, i, "expression_list")
      repeat
         i = i + 1
         local val
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

   local parse_call_or_assignment
   do
      local function is_lvalue(node)
         node.is_lvalue = node.kind == "variable" or
         (node.kind == "op" and
         (node.op.op == "@index" or node.op.op == "."))
         return node.is_lvalue
      end

      local function parse_variable(ps, i)
         local node
         i, node = parse_expression(ps, i)
         if not (node and is_lvalue(node)) then
            return fail(ps, i, "expected a variable")
         end
         return i, node
      end

      parse_call_or_assignment = function(ps, i)
         local exp
         local istart = i
         i, exp = parse_expression(ps, i)
         if not exp then
            return i
         end

         if node_is_funcall(exp) or exp.failstore then
            return i, exp
         end

         if not is_lvalue(exp) then
            return fail(ps, i, "syntax error")
         end

         local asgn = new_node(ps, istart, "assignment")
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

   local function parse_variable_declarations(ps, i, node_name)
      local asgn = new_node(ps, i, node_name)

      asgn.vars = new_node(ps, i, "variable_list")
      i = parse_trying_list(ps, i, asgn.vars, parse_variable_name)
      if #asgn.vars == 0 then
         return fail(ps, i, "expected a local variable definition")
      end

      i, asgn.decltuple = parse_type_list(ps, i, "decltuple")

      if ps.tokens[i].tk == "=" then

         local next_word = ps.tokens[i + 1].tk
         local tn = next_word
         if parse_type_body_fns[tn] then
            local scope = node_name == "local_declaration" and "local" or "global"
            return failskip(ps, i + 1, "syntax error: this syntax is no longer valid; use '" .. scope .. " " .. next_word .. " " .. asgn.vars[1].tk .. "'", skip_type_body)
         elseif next_word == "functiontype" then
            local scope = node_name == "local_declaration" and "local" or "global"
            return failskip(ps, i + 1, "syntax error: this syntax is no longer valid; use '" .. scope .. " type " .. asgn.vars[1].tk .. " = function('...", parse_function_type)
         end

         i, asgn = parse_assignment_expression_list(ps, i, asgn)
      end
      return i, asgn
   end

   local function parse_type_require(ps, i, asgn)
      local istart = i
      i, asgn.value = parse_expression(ps, i)
      if not asgn.value then
         return i
      end
      if asgn.value.op and asgn.value.op.op ~= "@funcall" and asgn.value.op.op ~= "." then
         fail(ps, istart, "require() in type declarations cannot be part of larger expressions")
         return i
      end
      if not node_is_require_call(asgn.value) then
         fail(ps, istart, "require() for type declarations must have a literal argument")
         return i
      end
      return i, asgn
   end

   local function parse_special_type_declaration(ps, i, asgn)
      if ps.tokens[i].tk == "require" then
         return true, parse_type_require(ps, i, asgn)
      elseif ps.tokens[i].tk == "pcall" then
         fail(ps, i, "pcall() cannot be used in type declarations")
         return true, i
      end
      return false, i, asgn
   end

   parse_type_declaration = function(ps, i, node_name)
      local asgn = new_node(ps, i, node_name)
      local var

      i, var = verify_kind(ps, i, "identifier")
      if not var then
         return fail(ps, i, "expected a type name")
      end
      local typeargs
      local itypeargs = i
      i, typeargs = parse_typeargs_if_any(ps, i)

      asgn.var = var

      if node_name == "global_type" and ps.tokens[i].tk ~= "=" then
         return i, asgn
      end

      i = verify_tk(ps, i, "=")
      local istart = i

      if ps.tokens[i].kind == "identifier" then
         local is_done
         is_done, i, asgn = parse_special_type_declaration(ps, i, asgn)
         if is_done then
            return i, asgn
         end
      end

      i, asgn.value = parse_newtype(ps, i)
      if not asgn.value then
         return i
      end

      local nt = asgn.value.newtype
      if nt.typename == "typedecl" then
         if typeargs then
            local def = nt.def
            if def.typename == "generic" then
               fail(ps, itypeargs, "cannot declare type arguments twice in type declaration")
            else
               nt.def = new_generic(ps, istart, typeargs, def)
            end
         end

         set_declname(nt.def, asgn.var.tk)
      end

      return i, asgn
   end

   local function parse_type_constructor(ps, i, node_name, tn)
      local asgn = new_node(ps, i, node_name)
      local nt = new_node(ps, i, "newtype")
      asgn.value = nt
      local istart = i
      local def

      i = i + 2

      i, asgn.var = verify_kind(ps, i, "identifier")
      if not asgn.var then
         return fail(ps, i, "expected a type name")
      end

      i, def = parse_type_body(ps, i, istart, nt, tn)
      if not def then
         return i
      end

      set_declname(def, asgn.var.tk)

      nt.newtype = new_typedecl(ps, istart, def)

      return i, asgn
   end

   local function skip_type_declaration(ps, i)
      return parse_type_declaration(ps, i + 1, "local_type")
   end

   local function parse_local_macroexp(ps, i)
      local istart = i
      i = i + 2
      local node = new_node(ps, i, "local_macroexp")
      i, node.name = parse_identifier(ps, i)
      i, node.macrodef = parse_macroexp(ps, istart, i)
      end_at(node, ps.tokens[i - 1])
      return i, node
   end

   local function parse_local(ps, i)
      local comments = get_attached_comments(ps.tokens[i])
      local ntk = ps.tokens[i + 1].tk
      local tn = ntk

      local node
      if ntk == "function" then
         i, node = parse_local_function(ps, i)
      elseif ntk == "type" and ps.tokens[i + 2].kind == "identifier" then
         i, node = parse_type_declaration(ps, i + 2, "local_type")
      elseif ntk == "macroexp" and ps.tokens[i + 2].kind == "identifier" then
         i, node = parse_local_macroexp(ps, i)
      elseif parse_type_body_fns[tn] and ps.tokens[i + 2].kind == "identifier" then
         i, node = parse_type_constructor(ps, i, "local_type", tn)
      else
         i, node = parse_variable_declarations(ps, i + 1, "local_declaration")
      end
      if node then
         node.comments = comments
      end
      return i, node
   end

   local function parse_global(ps, i)
      local comments = get_attached_comments(ps.tokens[i])
      local ntk = ps.tokens[i + 1].tk
      local tn = ntk

      local node
      if ntk == "function" then
         i, node = parse_function(ps, i + 1, "global")
      elseif ntk == "type" and ps.tokens[i + 2].kind == "identifier" then
         i, node = parse_type_declaration(ps, i + 2, "global_type")
      elseif parse_type_body_fns[tn] and ps.tokens[i + 2].kind == "identifier" then
         i, node = parse_type_constructor(ps, i, "global_type", tn)
      elseif ps.tokens[i + 1].kind == "identifier" then
         i, node = parse_variable_declarations(ps, i + 1, "global_declaration")
      else
         return parse_call_or_assignment(ps, i)
      end
      if node then
         node.comments = comments
      end
      return i, node
   end

   local function parse_record_function(ps, i)
      local comments = get_attached_comments(ps.tokens[i])
      local node
      i, node = parse_function(ps, i, "record")
      if node then
         node.comments = comments
      end
      return i, node
   end

   local function parse_pragma(ps, i)
      i = i + 1
      local pragma = new_node(ps, i, "pragma")

      if ps.tokens[i].kind ~= "pragma_identifier" then
         return fail(ps, i, "expected pragma name")
      end
      pragma.pkey = ps.tokens[i].tk
      i = i + 1

      if ps.tokens[i].kind ~= "pragma_identifier" then
         return fail(ps, i, "expected pragma value")
      end
      pragma.pvalue = ps.tokens[i].tk
      i = i + 1

      return i, pragma
   end

   local parse_statement_fns = {
      ["--#pragma"] = parse_pragma,
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

   local function type_needs_local_or_global(ps, i)
      local tk = ps.tokens[i].tk
      return failskip(ps, i, ("%s needs to be declared with 'local %s' or 'global %s'"):format(tk, tk, tk), skip_type_body)
   end

   local needs_local_or_global = {
      ["type"] = function(ps, i)
         return failskip(ps, i, "types need to be declared with 'local type' or 'global type'", skip_type_declaration)
      end,
      ["record"] = type_needs_local_or_global,
      ["enum"] = type_needs_local_or_global,
   }

   local function store_unattached_comments(node, token, item)
      for _, tc in ipairs(token.comments) do
         local is_attached = false
         if item.comments then
            for _, nc in ipairs(item.comments) do
               if tc == nc then
                  is_attached = true
                  break
               end
            end
         end
         if not is_attached then
            if not node.unattached_comments then
               node.unattached_comments = {}
            end
            table.insert(node.unattached_comments, tc)
         else
            break
         end
      end
   end

   parse_statements = function(ps, i, toplevel)
      local node = new_node(ps, i, "statements")
      local item
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
         local token = ps.tokens[i]
         local tk = token.tk
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
            if toplevel and token.comments then
               store_unattached_comments(node, token, item)
            end
            table.insert(node, item)
         elseif i > 1 then

            local lasty = ps.tokens[i - 1].y
            while ps.tokens[i].kind ~= "$EOF$" and ps.tokens[i].y == lasty do
               i = i + 1
            end
         end
      end

      end_at(node, ps.tokens[i])
      return i, node
   end

   function tl.parse_program(tokens, errs, filename, parse_lang)
      errs = errs or {}
      local ps = {
         tokens = tokens,
         errs = errs,
         filename = filename or "",
         required_modules = {},
         parse_lang = parse_lang,
      }
      local i = 1
      local hashbang
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

   function tl.parse(input, filename, parse_lang)
      local tokens, errs = tl.lex(input, filename)
      local node, required_modules = tl.parse_program(tokens, errs, filename, parse_lang)
      return node, errs, required_modules
   end

end





























local function fields_of(t, meta)
   local i = 1
   local field_order, fields
   if meta then
      field_order, fields = t.meta_field_order, t.meta_fields
   else
      field_order, fields = t.field_order, t.fields
   end
   if not fields then
      return function()
      end
   end
   return function()
      local name = field_order[i]
      if not name then
         return nil
      end
      i = i + 1
      return name, fields[name]
   end
end

local tl_debug_indent = 0






local tl_debug_entry = nil
local tl_debug_y = 1

local function tl_debug_loc(y, x)
   return (tostring(y) or "?") .. ":" .. (tostring(x) or "?")
end

local function tl_debug_indent_push(mark, y, x, fmt, ...)
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
      msg = fmt:format(...),
   }
end

local function tl_debug_indent_pop(mark, single, y, x, fmt, ...)
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

local recurse_type

local function aggregate_type_walker(s, ast, visit)
   local xs = {}
   for i, child in ipairs(ast.types) do
      xs[i] = recurse_type(s, child, visit)
   end
   return xs
end

local function record_like_type_walker(s, ast, visit)
   local xs = {}
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
   return xs
end

local type_walkers = {
   ["typevar"] = false,
   ["unresolved_typearg"] = false,
   ["unresolvable_typearg"] = false,
   ["self"] = false,
   ["enum"] = false,
   ["boolean"] = false,
   ["string"] = false,
   ["nil"] = false,
   ["thread"] = false,
   ["userdata"] = false,
   ["number"] = false,
   ["integer"] = false,
   ["circular_require"] = false,
   ["boolean_context"] = false,
   ["emptytable"] = false,
   ["unresolved_emptytable_value"] = false,
   ["any"] = false,
   ["unknown"] = false,
   ["invalid"] = false,
   ["none"] = false,
   ["*"] = false,

   ["generic"] = function(s, ast, visit)
      local xs = {}
      for _, child in ipairs(ast.typeargs) do
         table.insert(xs, recurse_type(s, child, visit))
      end
      table.insert(xs, recurse_type(s, ast.t, visit))
      return xs
   end,
   ["tuple"] = function(s, ast, visit)
      local xs = {}
      for i, child in ipairs(ast.tuple) do
         xs[i] = recurse_type(s, child, visit)
      end
      return xs
   end,
   ["union"] = aggregate_type_walker,
   ["tupletable"] = aggregate_type_walker,
   ["poly"] = aggregate_type_walker,
   ["map"] = function(s, ast, visit)
      return {
         recurse_type(s, ast.keys, visit),
         recurse_type(s, ast.values, visit),
      }
   end,
   ["record"] = record_like_type_walker,
   ["interface"] = record_like_type_walker,
   ["function"] = function(s, ast, visit)
      local xs = {}
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
      return xs
   end,
   ["nominal"] = function(s, ast, visit)
      local xs = {}
      if ast.typevals then
         for _, child in ipairs(ast.typevals) do
            table.insert(xs, recurse_type(s, child, visit))
         end
      end
      return xs
   end,
   ["typearg"] = function(s, ast, visit)
      return {
         ast.constraint and recurse_type(s, ast.constraint, visit),
      }
   end,
   ["array"] = function(s, ast, visit)
      return {
         recurse_type(s, ast.elements, visit),
      }
   end,
   ["literal_table_item"] = function(s, ast, visit)
      return {
         recurse_type(s, ast.ktype, visit),
         recurse_type(s, ast.vtype, visit),
      }
   end,
   ["typedecl"] = function(s, ast, visit)
      return {
         recurse_type(s, ast.def, visit),
      }
   end,
}

recurse_type = function(s, ast, visit)
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

   local xs
   local walker = type_walkers[ast.typename]
   if not (type(walker) == "boolean") then
      xs = walker(s, ast, visit)
   end

   local ret
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

local function recurse_typeargs(s, ast, visit_type)
   if ast.typeargs then
      for _, typearg in ipairs(ast.typeargs) do
         recurse_type(s, typearg, visit_type)
      end
   end
end

local function extra_callback(name,
   s,
   ast,
   xs,
   visit_node)
   local cbs = visit_node.cbs
   if not cbs then return end
   local nbs = cbs[ast.kind]
   if not nbs then return end
   local bs = nbs[name]
   if not bs then return end
   bs(s, ast, xs)
end

local no_recurse_node = {
   ["..."] = true,
   ["nil"] = true,
   ["cast"] = true,
   ["goto"] = true,
   ["break"] = true,
   ["label"] = true,
   ["number"] = true,
   ["pragma"] = true,
   ["string"] = true,
   ["boolean"] = true,
   ["integer"] = true,
   ["variable"] = true,
   ["error_node"] = true,
   ["identifier"] = true,
   ["type_identifier"] = true,
}

local function recurse_node(s, root,
   visit_node,
   visit_type)
   if not root then

      return
   end

   local recurse

   local function walk_children(ast, xs)
      for i, child in ipairs(ast) do
         xs[i] = recurse(child)
      end
   end

   local function walk_vars_exps(ast, xs)
      xs[1] = recurse(ast.vars)
      if ast.decltuple then
         xs[2] = recurse_type(s, ast.decltuple, visit_type)
      end
      extra_callback("before_exp", s, ast, xs, visit_node)
      if ast.exps then
         xs[3] = recurse(ast.exps)
      end
   end

   local function walk_named_function(ast, xs)
      recurse_typeargs(s, ast, visit_type)
      xs[1] = recurse(ast.name)
      xs[2] = recurse(ast.args)
      xs[3] = recurse_type(s, ast.rets, visit_type)
      extra_callback("before_statements", s, ast, xs, visit_node)
      xs[4] = recurse(ast.body)
   end

   local walkers = {
      ["op"] = function(ast, xs)
         xs[1] = recurse(ast.e1)
         local p1 = ast.e1.op and ast.e1.op.prec or nil
         if ast.op.op == ":" and ast.e1.kind == "string" then
            p1 = -999
         end
         xs[2] = p1
         if ast.op.arity == 2 then
            extra_callback("before_e2", s, ast, xs, visit_node)
            if ast.op.op == "is" or ast.op.op == "as" then
               xs[3] = recurse_type(s, ast.e2.casttype, visit_type)
            else
               xs[3] = recurse(ast.e2)
            end
            xs[4] = (ast.e2.op and ast.e2.op.prec)
         end
      end,

      ["statements"] = walk_children,
      ["argument_list"] = walk_children,
      ["literal_table"] = walk_children,
      ["variable_list"] = walk_children,
      ["expression_list"] = walk_children,

      ["literal_table_item"] = function(ast, xs)
         xs[1] = recurse(ast.key)
         xs[2] = recurse(ast.value)
         if ast.itemtype then
            xs[3] = recurse_type(s, ast.itemtype, visit_type)
         end
      end,

      ["assignment"] = walk_vars_exps,
      ["local_declaration"] = walk_vars_exps,
      ["global_declaration"] = walk_vars_exps,

      ["local_type"] = function(ast, xs)


         xs[1] = recurse(ast.var)
         xs[2] = recurse(ast.value)
      end,

      ["global_type"] = function(ast, xs)


         xs[1] = recurse(ast.var)
         if ast.value then
            xs[2] = recurse(ast.value)
         end
      end,

      ["if"] = function(ast, xs)
         for _, e in ipairs(ast.if_blocks) do
            table.insert(xs, recurse(e))
         end
      end,

      ["if_block"] = function(ast, xs)
         if ast.exp then
            xs[1] = recurse(ast.exp)
         end
         extra_callback("before_statements", s, ast, xs, visit_node)
         xs[2] = recurse(ast.body)
      end,

      ["while"] = function(ast, xs)
         xs[1] = recurse(ast.exp)
         extra_callback("before_statements", s, ast, xs, visit_node)
         xs[2] = recurse(ast.body)
      end,

      ["repeat"] = function(ast, xs)
         xs[1] = recurse(ast.body)
         xs[2] = recurse(ast.exp)
      end,

      ["macroexp"] = function(ast, xs)
         recurse_typeargs(s, ast, visit_type)
         xs[1] = recurse(ast.args)
         xs[2] = recurse_type(s, ast.rets, visit_type)
         extra_callback("before_exp", s, ast, xs, visit_node)
         xs[3] = recurse(ast.exp)
      end,

      ["function"] = function(ast, xs)
         recurse_typeargs(s, ast, visit_type)
         xs[1] = recurse(ast.args)
         xs[2] = recurse_type(s, ast.rets, visit_type)
         extra_callback("before_statements", s, ast, xs, visit_node)
         xs[3] = recurse(ast.body)
      end,
      ["local_function"] = walk_named_function,
      ["global_function"] = walk_named_function,
      ["record_function"] = function(ast, xs)
         recurse_typeargs(s, ast, visit_type)
         xs[1] = recurse(ast.fn_owner)
         xs[2] = recurse(ast.name)
         extra_callback("before_arguments", s, ast, xs, visit_node)
         xs[3] = recurse(ast.args)
         xs[4] = recurse_type(s, ast.rets, visit_type)
         extra_callback("before_statements", s, ast, xs, visit_node)
         xs[5] = recurse(ast.body)
      end,
      ["local_macroexp"] = function(ast, xs)

         xs[1] = recurse(ast.name)
         xs[2] = recurse(ast.macrodef.args)
         xs[3] = recurse_type(s, ast.macrodef.rets, visit_type)
         extra_callback("before_exp", s, ast, xs, visit_node)
         xs[4] = recurse(ast.macrodef.exp)
      end,

      ["forin"] = function(ast, xs)
         xs[1] = recurse(ast.vars)
         xs[2] = recurse(ast.exps)
         extra_callback("before_statements", s, ast, xs, visit_node)
         xs[3] = recurse(ast.body)
      end,

      ["fornum"] = function(ast, xs)
         xs[1] = recurse(ast.var)
         xs[2] = recurse(ast.from)
         xs[3] = recurse(ast.to)
         xs[4] = ast.step and recurse(ast.step)
         extra_callback("before_statements", s, ast, xs, visit_node)
         xs[5] = recurse(ast.body)
      end,

      ["return"] = function(ast, xs)
         xs[1] = recurse(ast.exps)
      end,

      ["do"] = function(ast, xs)
         xs[1] = recurse(ast.body)
      end,

      ["paren"] = function(ast, xs)
         xs[1] = recurse(ast.e1)
      end,

      ["newtype"] = function(ast, xs)
         xs[1] = recurse_type(s, ast.newtype, visit_type)
      end,

      ["argument"] = function(ast, xs)
         if ast.argtype then
            xs[1] = recurse_type(s, ast.argtype, visit_type)
         end
      end,
   }

   if not visit_node.allow_missing_cbs and not visit_node.cbs then
      error("missing cbs in visit_node")
   end
   local visit_after = visit_node.after

   recurse = function(ast)
      local xs = {}
      local kind = assert(ast.kind)
      local kprint

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
         kprint = kind == "op" and "op " .. ast.op.op or
         kind == "identifier" and "identifier " .. ast.tk or
         kind
         tl_debug_indent_push("{{{", ast.y, ast.x, "[%s]", kprint)
      end

      local fn = walkers[kind]
      if fn then
         fn(ast, xs)
      else
         assert(no_recurse_node[kind])
      end

      local ret
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





local tight_op = {
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

local spaced_op = {
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


local default_generate_opts = {
   preserve_indent = true,
   preserve_newlines = true,
   preserve_hashbang = false,
}

local fast_generate_opts = {
   preserve_indent = false,
   preserve_newlines = true,
   preserve_hashbang = false,
}

local primitive = {
   ["function"] = "function",
   ["enum"] = "string",
   ["boolean"] = "boolean",
   ["string"] = "string",
   ["nil"] = "nil",
   ["number"] = "number",
   ["integer"] = "number",
   ["thread"] = "thread",
}

function tl.generate(ast, gen_target, opts)
   local err
   local indent = 0

   opts = opts or default_generate_opts







   local save_indent = {}

   local function increment_indent(_, node)
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

   local function decrement_indent(node, child)
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

   local function add_string(out, s)
      table.insert(out, s)
      if string.find(s, "\n", 1, true) then
         for _nl in s:gmatch("\n") do
            out.h = out.h + 1
         end
      end
   end

   local function add_child(out, child, space, current_indent)
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
      table.insert(out, child)
      out.h = out.h + child.h
   end

   local function concat_output(out)
      for i, s in ipairs(out) do
         if type(s) == "table" then
            out[i] = concat_output(s)
         end
      end
      return table.concat(out)
   end

   local function print_record_def(typ)
      local out = { "{" }
      local i = 0
      for fname, ftype in fields_of(typ) do
         if ftype.typename == "typedecl" then
            local def = ftype.def
            if def.typename == "generic" then
               def = def.t
            end
            if def.typename == "record" then
               if i > 0 then
                  table.insert(out, ",")
               end
               i = i + 1
               table.insert(out, " ")
               table.insert(out, fname)
               table.insert(out, " = ")
               table.insert(out, print_record_def(def))
            end
         end
      end
      if i > 0 then
         table.insert(out, " ")
      end
      table.insert(out, "}")
      return table.concat(out)
   end

   local visit_node = {}

   local lua_54_attribute = {
      ["const"] = " <const>",
      ["close"] = " <close>",
      ["total"] = " <const>",
   }

   local function emit_exactly(_, node, _children)
      local out = { y = node.y, h = 0 }
      add_string(out, node.tk)
      return out
   end

   local emit_exactly_visitor_cbs = { after = emit_exactly }

   local emit_nothing_visitor_cbs = {
      after = function(_, node, _children)
         local out = { y = node.y, h = 0 }
         return out
      end,
   }

   local function starts_with_longstring(n)
      while n.e1 do n = n.e1 end
      return n.is_longstring
   end

   visit_node.cbs = {
      ["statements"] = {
         after = function(_, node, children)
            local out
            if opts.preserve_hashbang and node.hashbang then
               out = { y = 1, h = 0 }
               table.insert(out, node.hashbang)
            else
               out = { y = node.y, h = 0 }
            end
            local space
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
         end,
      },
      ["local_declaration"] = {
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
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
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
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
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            if children[2] then
               add_child(out, children[1])
               table.insert(out, " =")
               add_child(out, children[2], " ")
            end
            return out
         end,
      },
      ["global_declaration"] = {
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            if children[3] then
               add_child(out, children[1])
               table.insert(out, " =")
               add_child(out, children[3], " ")
            end
            return out
         end,
      },
      ["assignment"] = {
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            add_child(out, children[1])
            table.insert(out, " =")
            add_child(out, children[3], " ")
            return out
         end,
      },
      ["if"] = {
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            for i, child in ipairs(children) do
               add_child(out, child, i > 1 and " ", child.y ~= node.y and indent)
            end
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["if_block"] = {
         before = increment_indent,
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
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
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
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
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
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
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            table.insert(out, "do")
            add_child(out, children[1], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["forin"] = {
         before = increment_indent,
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
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
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
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
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            table.insert(out, "return")
            if #children[1] > 0 then
               add_child(out, children[1], " ")
            end
            return out
         end,
      },
      ["break"] = {
         after = function(_, node, _children)
            local out = { y = node.y, h = 0 }
            table.insert(out, "break")
            return out
         end,
      },
      ["variable_list"] = {
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            local space
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
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
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
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
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
         after = function(_, node, _children)
            return { y = node.y, h = 0 }
         end,
      },
      ["local_function"] = {
         before = increment_indent,
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
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
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
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
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            table.insert(out, "function")
            add_child(out, children[1], " ")
            table.insert(out, node.is_method and ":" or ".")
            add_child(out, children[2])
            table.insert(out, "(")
            if node.is_method then

               table.remove(children[3], 1)
               if children[3][1] == "," then
                  table.remove(children[3], 1)
                  if children[3][1] == " " then
                     table.remove(children[3], 1)
                  end
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
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            table.insert(out, "function(")
            add_child(out, children[1])
            table.insert(out, ")")
            add_child(out, children[3], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["paren"] = {
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            table.insert(out, "(")
            add_child(out, children[1], "", indent)
            table.insert(out, ")")
            return out
         end,
      },
      ["op"] = {
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            if node.op.op == "@funcall" then
               add_child(out, children[1], "", indent)
               table.insert(out, "(")
               add_child(out, children[3], "", indent)
               table.insert(out, ")")
            elseif node.op.op == "@index" then
               add_child(out, children[1], "", indent)
               table.insert(out, "[")
               if starts_with_longstring(node.e2) then
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
         after = function(_, node, _children)
            local out = { y = node.y, h = 0 }
            local nt = node.newtype
            if nt.typename == "typedecl" then
               local def = nt.def
               if def.fields then
                  table.insert(out, print_record_def(def))
               elseif def.typename == "nominal" then
                  table.insert(out, table.concat(def.names, "."))
               else
                  table.insert(out, "{}")
               end
            end
            return out
         end,
      },
      ["goto"] = {
         after = function(_, node, _children)
            local out = { y = node.y, h = 0 }
            table.insert(out, "goto ")
            table.insert(out, node.label)
            return out
         end,
      },
      ["label"] = {
         after = function(_, node, _children)
            local out = { y = node.y, h = 0 }
            table.insert(out, "::")
            table.insert(out, node.label)
            table.insert(out, "::")
            return out
         end,
      },
      ["string"] = {
         after = function(_, node, children)






            if node.tk:sub(1, 1) == "[" or gen_target ~= "5.1" or not node.tk:find("\\", 1, true) then
               return emit_exactly(nil, node, children)
            end

            local str = node.tk
            local replaced = {}

            local i = 1
            local currstrstart = 1
            while true do
               local slashpos = str:find("\\", i)
               if not slashpos then break end
               local nextc = str:sub(slashpos + 1, slashpos + 1)
               if nextc == "z" then
                  table.insert(replaced, str:sub(currstrstart, slashpos - 1))
                  local wsend = str:find("%S", slashpos + 2)
                  currstrstart = wsend
                  i = currstrstart
               elseif nextc == "x" then
                  table.insert(replaced, str:sub(currstrstart, slashpos - 1))
                  local digits = str:sub(slashpos + 2, slashpos + 3)
                  local byte = tonumber(digits, 16)
                  table.insert(replaced, string.format("\\%03d", byte))
                  currstrstart = slashpos + 4
                  i = currstrstart
               elseif nextc == "u" then
                  table.insert(replaced, str:sub(currstrstart, slashpos - 1))
                  local _, e, hex_digits = str:find("{(.-)}", slashpos + 2)
                  local codepoint = tonumber(hex_digits, 16)
                  local sequence = utf8.char(codepoint)
                  table.insert(replaced, (sequence:gsub(".", function(c)
                     return ("\\%03d"):format(string.byte(c))
                  end)))
                  currstrstart = e + 1
                  i = currstrstart
               else
                  i = slashpos + 2
               end
            end
            if currstrstart <= #str then
               table.insert(replaced, str:sub(currstrstart))
            end

            local h = 0
            local finalstr = table.concat(replaced)
            for _ in finalstr:gmatch("\n") do
               h = h + 1
            end
            return {
               y = node.y,
               h = h,
               finalstr,
            }
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

      ["cast"] = emit_nothing_visitor_cbs,
      ["pragma"] = emit_nothing_visitor_cbs,
   }

   local visit_type = {}
   visit_type.cbs = {}
   local default_type_visitor = {
      after = function(_, typ, _children)
         local out = { y = typ.y or -1, h = 0 }
         local r = typ.typename == "nominal" and typ.resolved or typ
         local lua_type = primitive[r.typename] or "table"
         if r.fields and r.is_userdata then
            lua_type = "userdata"
         end
         table.insert(out, lua_type)
         return out
      end,
   }

   visit_type.cbs["string"] = default_type_visitor
   visit_type.cbs["typedecl"] = default_type_visitor
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

   local code
   if opts.preserve_newlines then
      code = { y = 1, h = 0 }
      add_child(code, out)
   else
      code = out
   end
   return (concat_output(code):gsub(" *\n", "\n"))
end





local typename_to_typecode = {
   ["typevar"] = tl.typecodes.TYPE_VARIABLE,
   ["typearg"] = tl.typecodes.TYPE_VARIABLE,
   ["unresolved_typearg"] = tl.typecodes.TYPE_VARIABLE,
   ["unresolvable_typearg"] = tl.typecodes.TYPE_VARIABLE,
   ["function"] = tl.typecodes.FUNCTION,
   ["array"] = tl.typecodes.ARRAY,
   ["map"] = tl.typecodes.MAP,
   ["tupletable"] = tl.typecodes.TUPLE,
   ["interface"] = tl.typecodes.INTERFACE,
   ["self"] = tl.typecodes.SELF,
   ["record"] = tl.typecodes.RECORD,
   ["enum"] = tl.typecodes.ENUM,
   ["boolean"] = tl.typecodes.BOOLEAN,
   ["string"] = tl.typecodes.STRING,
   ["nil"] = tl.typecodes.NIL,
   ["thread"] = tl.typecodes.THREAD,
   ["userdata"] = tl.typecodes.USERDATA,
   ["number"] = tl.typecodes.NUMBER,
   ["integer"] = tl.typecodes.INTEGER,
   ["union"] = tl.typecodes.UNION,
   ["nominal"] = tl.typecodes.NOMINAL,
   ["circular_require"] = tl.typecodes.NOMINAL,
   ["boolean_context"] = tl.typecodes.BOOLEAN,
   ["emptytable"] = tl.typecodes.EMPTY_TABLE,
   ["unresolved_emptytable_value"] = tl.typecodes.EMPTY_TABLE,
   ["poly"] = tl.typecodes.POLY,
   ["any"] = tl.typecodes.ANY,
   ["unknown"] = tl.typecodes.UNKNOWN,
   ["invalid"] = tl.typecodes.INVALID,

   ["none"] = tl.typecodes.UNKNOWN,
   ["tuple"] = tl.typecodes.UNKNOWN,
   ["literal_table_item"] = tl.typecodes.UNKNOWN,
   ["typedecl"] = tl.typecodes.UNKNOWN,
   ["generic"] = tl.typecodes.UNKNOWN,
   ["*"] = tl.typecodes.UNKNOWN,
}

local skip_types = {
   ["none"] = true,
   ["tuple"] = true,
   ["literal_table_item"] = true,
}

local function sorted_keys(m)
   local keys = {}
   for k, _ in pairs(m) do
      table.insert(keys, k)
   end
   table.sort(keys)
   return keys
end


local function mark_array(x)
   local arr = x
   arr[0] = false
   return x
end

function tl.new_type_reporter()
   local self = setmetatable({
      next_num = 1,
      typeid_to_num = {},
      typename_to_num = {},
      tr = {
         by_pos = {},
         types = {},
         symbols_by_file = {},
         globals = {},
      },
   }, { __index = TypeReporter })

   local names = {}
   for name, _ in pairs(simple_types) do
      table.insert(names, name)
   end
   table.sort(names)

   for _, name in ipairs(names) do
      local ti = {
         t = assert(typename_to_typecode[name]),
         str = name,
      }
      local n = self.next_num
      self.typename_to_num[name] = n
      self.tr.types[n] = ti
      self.next_num = self.next_num + 1
   end

   return self
end

function TypeReporter:store_function(ti, rt)
   local args = {}
   for _, fnarg in ipairs(rt.args.tuple) do
      table.insert(args, mark_array({ self:get_typenum(fnarg), nil }))
   end
   ti.args = mark_array(args)
   local rets = {}
   for _, fnarg in ipairs(rt.rets.tuple) do
      table.insert(rets, mark_array({ self:get_typenum(fnarg), nil }))
   end
   ti.rets = mark_array(rets)
   ti.vararg = not not rt.args.is_va
   ti.varret = not not rt.rets.is_va
end

function TypeReporter:get_typenum(t)

   local n = self.typename_to_num[t.typename]
   if n then
      return n
   end

   assert(t.typeid)

   n = self.typeid_to_num[t.typeid]
   if n then
      return n
   end

   local tr = self.tr


   n = self.next_num

   local rt = t
   if rt.typename == "tuple" and #rt.tuple == 1 then
      rt = rt.tuple[1]
   end

   if rt.typename == "typedecl" then
      return self:get_typenum(rt.def)
   end


   if rt.typename == "generic" then
      rt = rt.t
   end

   local ti = {
      t = assert(typename_to_typecode[rt.typename]),
      str = show_type(t, true),
      file = t.f,
      y = t.y,
      x = t.x,
   }
   tr.types[n] = ti
   self.typeid_to_num[t.typeid] = n
   self.next_num = self.next_num + 1

   if t.typename == "nominal" then
      if t.found then
         ti.ref = self:get_typenum(t.found)
      end
      if t.resolved then
         rt = t
      end
   end
   assert(not (rt.typename == "typedecl"))

   if rt.fields then

      local r = {}
      for _, k in ipairs(rt.field_order) do
         local v = rt.fields[k]
         r[k] = self:get_typenum(v)
      end
      ti.fields = r
      if rt.meta_fields then

         local m = {}
         for _, k in ipairs(rt.meta_field_order) do
            local v = rt.meta_fields[k]
            m[k] = self:get_typenum(v)
         end
         ti.meta_fields = m
      end
   end

   if rt.elements then
      ti.elements = self:get_typenum(rt.elements)
   end

   if rt.typename == "map" then
      ti.keys = self:get_typenum(rt.keys)
      ti.values = self:get_typenum(rt.values)
   elseif rt.typename == "enum" then
      ti.enums = mark_array(sorted_keys(rt.enumset))
   elseif rt.typename == "function" then
      self:store_function(ti, rt)
   elseif rt.types then
      local tis = {}
      for _, pt in ipairs(rt.types) do
         table.insert(tis, self:get_typenum(pt))
      end
      ti.types = mark_array(tis)
   end

   return n
end

function TypeReporter:add_field(rtype, fname, ftype)
   local n = self:get_typenum(rtype)
   local ti = self.tr.types[n]
   assert(ti.fields)
   ti.fields[fname] = self:get_typenum(ftype)
end

function TypeReporter:set_ref(nom, resolved)
   local n = self:get_typenum(nom)
   local ti = self.tr.types[n]
   ti.ref = self:get_typenum(resolved)
end





















function TypeReporter:get_collector(filename)
   local collector = {
      filename = filename,
      symbol_list = {},
   }

   local ft = {}
   self.tr.by_pos[filename] = ft

   local symbol_list = collector.symbol_list
   local symbol_list_n = 0

   collector.store_type = function(y, x, typ)
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

   collector.reserve_symbol_list_slot = function(node)
      symbol_list_n = symbol_list_n + 1
      node.symbol_list_slot = symbol_list_n
   end

   collector.add_to_symbol_list = function(node, name, t)
      if not node then
         return
      end
      local slot
      if node.symbol_list_slot then
         slot = node.symbol_list_slot
      else
         symbol_list_n = symbol_list_n + 1
         slot = symbol_list_n
      end
      symbol_list[slot] = { y = node.y, x = node.x, name = name, typ = t }
   end

   collector.begin_symbol_list_scope = function(node)
      symbol_list_n = symbol_list_n + 1
      symbol_list[symbol_list_n] = { y = node.y, x = node.x, name = "@{" }
   end

   collector.rollback_symbol_list_scope = function()
      while symbol_list[symbol_list_n].name ~= "@{" do
         symbol_list[symbol_list_n] = nil
         symbol_list_n = symbol_list_n - 1
      end
   end

   collector.end_symbol_list_scope = function(node)
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

function TypeReporter:store_result(collector, globals)
   local tr = self.tr

   local filename = collector.filename
   local symbol_list = collector.symbol_list

   tr.by_pos[filename][0] = nil


   do
      local n = 0
      local p = 0
      local n_stack, p_stack = {}, {}
      local level = 0
      for i, s in ipairs(symbol_list) do
         if s.typ then
            n = n + 1
         elseif s.name == "@{" then
            level = level + 1
            n_stack[level], p_stack[level] = n, p
            n, p = 0, i
         else
            if n == 0 then
               symbol_list[p].skip = true
               s.skip = true
            end
            n, p = n_stack[level], p_stack[level]
            level = level - 1
         end
      end
   end

   local symbols = mark_array({})
   tr.symbols_by_file[filename] = symbols


   do
      local stack = {}
      local level = 0
      local i = 0
      for _, s in ipairs(symbol_list) do
         if not s.skip then
            i = i + 1
            local id
            if s.typ then
               id = self:get_typenum(s.typ)
            elseif s.name == "@{" then
               level = level + 1
               stack[level] = i
               id = -1
            else
               local other = stack[level]
               level = level - 1
               symbols[other][4] = i
               id = other - 1
            end
            local sym = mark_array({ s.y, s.x, s.name, id })
            table.insert(symbols, sym)
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

   if not tr.symbols then
      tr.symbols = tr.symbols_by_file[filename]
   end
end

function TypeReporter:get_report()
   return self.tr
end






function tl.symbols_in_scope(tr, y, x, filename)
   local function find(symbols, at_y, at_x)
      local function le(a, b)
         return a[1] < b[1] or
         (a[1] == b[1] and a[2] <= b[2])
      end
      return binary_search(symbols, { at_y, at_x }, le) or 0
   end

   local ret = {}

   local symbols = tr.symbols_by_file[filename]
   if not symbols then
      return ret
   end

   local n = find(symbols, y, x)

   while n >= 1 do
      local s = symbols[n]
      local symbol_name = s[3]
      if symbol_name == "@{" then
         n = n - 1
      elseif symbol_name == "@}" then
         n = s[4]
      else
         if ret[symbol_name] == nil then
            ret[symbol_name] = s[4]
         end
         n = n - 1
      end
   end

   return ret
end





function Errors.new(filename)
   local self = {
      errors = {},
      warnings = {},
      unknown_dots = {},
      filename = filename,
   }
   return setmetatable(self, { __index = Errors })
end

local function Err(msg, t1, t2, t3)
   if t1 then
      local s1, s2, s3
      if t1.typename == "invalid" then
         return nil
      end
      s1 = show_type(t1)
      if t2 then
         if t2.typename == "invalid" then
            return nil
         end
         s2 = show_type(t2)
      end
      if t3 then
         if t3.typename == "invalid" then
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

local function Err_at(w, msg)
   return {
      msg = msg,
      x = assert(w.x),
      y = assert(w.y),
      filename = assert(w.f),
   }
end

local function insert_error(self, y, x, f, err)
   err.y = assert(y)
   err.x = assert(x)
   err.filename = assert(f)

   if TL_DEBUG then
      io.stderr:write("ERROR:" .. err.y .. ":" .. err.x .. ": " .. err.msg .. "\n")
   end

   table.insert(self.errors, err)
end

function Errors:add(w, msg, ...)
   local e = Err(msg, ...)
   if e then
      insert_error(self, w.y, w.x, w.f, e)
   end
end

local context_name = {
   ["local_declaration"] = "in local declaration",
   ["global_declaration"] = "in global declaration",
   ["assignment"] = "in assignment",
   ["literal_table_item"] = "in table item",
}

function Errors:get_context(ctx, name)
   if not ctx then
      return ""
   end
   local ec = (ctx.kind ~= nil) and ctx.expected_context
   local cn = (type(ctx) == "string") and ctx or
   (ctx.kind ~= nil) and context_name[ec and ec.kind or ctx.kind]
   return (cn and cn .. ": " or "") .. (ec and ec.name and ec.name .. ": " or "") .. (name and name .. ": " or "")
end

function Errors:add_in_context(w, ctx, msg, ...)
   local prefix = self:get_context(ctx)
   msg = prefix .. msg

   local e = Err(msg, ...)
   if e then
      insert_error(self, w.y, w.x, w.f, e)
   end
end


function Errors:collect(errs)
   for _, e in ipairs(errs) do
      insert_error(self, e.y, e.x, e.filename, e)
   end
end

function Errors:add_warning(tag, w, fmt, ...)
   assert(w.y)
   table.insert(self.warnings, {
      y = w.y,
      x = w.x,
      msg = fmt:format(...),
      filename = assert(w.f),
      tag = tag,
   })
end

function Errors:invalid_at(w, msg, ...)
   self:add(w, msg, ...)
   return a_type(w, "invalid", {})
end

function Errors:add_unknown(node, name)
   self:add_warning("unknown", node, "unknown variable: %s", name)
end

function Errors:redeclaration_warning(at, var_name, var_kind, old_var)
   if var_name:sub(1, 1) == "_" then return end

   local short_error = var_kind .. " shadows previous declaration of '%s'"
   if old_var and old_var.declared_at then
      self:add_warning("redeclaration", at, short_error .. " (originally declared at %d:%d)", var_name, old_var.declared_at.y, old_var.declared_at.x)
   else
      self:add_warning("redeclaration", at, short_error, var_name)
   end
end

local function var_should_be_ignored_for_warnings(name, var)
   local prefix = name:sub(1, 1)
   return (not var.declared_at) or
   var.is_specialized == "narrow" or
   prefix == "_" or
   prefix == "@"
end

local function user_facing_variable_description(var)
   local t = var.t
   return var.is_func_arg and "argument" or
   t.typename == "function" and "function" or
   t.typename == "typedecl" and "type" or
   "variable"
end

function Errors:unused_warning(name, var)
   if var_should_be_ignored_for_warnings(name, var) then
      return
   end
   self:add_warning(
   "unused",
   var.declared_at,
   "unused %s %s: %s",
   user_facing_variable_description(var),
   name,
   show_type(var.t))

end

function Errors:add_prefixing(w, src, prefix, dst)
   if not src then
      return
   end

   for _, err in ipairs(src) do
      err.msg = prefix .. err.msg
      if w and (
         (err.filename ~= w.f) or
         (not err.y) or
         (w.y > err.y or (w.y == err.y and w.x > err.x))) then

         err.y = w.y
         err.x = w.x
         err.filename = w.f
      end

      if dst then
         table.insert(dst, err)
      else
         insert_error(self, err.y, err.x, err.filename, err)
      end
   end
end

local function ensure_not_abstract_type(def, node)
   if def.typename == "record" then
      return true
   elseif def.typename == "generic" then
      return ensure_not_abstract_type(def.t)
   elseif node and node_is_require_call(node) then
      return nil, "module type is abstract: " .. tostring(def)
   elseif def.typename == "interface" then
      return nil, "interfaces are abstract; consider using a concrete record"
   end
   return nil, "cannot use a type definition as a concrete value"
end

local function ensure_not_abstract(t, node)
   if t.typename == "function" and t.macroexp then
      return nil, "macroexps are abstract; consider using a concrete function"
   elseif t.typename == "generic" then
      return ensure_not_abstract(t.t, node)
   elseif t.typename == "typedecl" then
      return ensure_not_abstract_type(t.def, node)
   end
   return true
end














local function has_var_been_used(var)
   return var.has_been_read_from or var.has_been_written_to
end

local function check_var_usage(scope, is_global)
   local vars = scope.vars
   if not next(vars) then
      return
   end
   local usage_warnings
   for name, var in pairs(vars) do
      local t = var.t
      if not var_should_be_ignored_for_warnings(name, var) then
         if var.has_been_written_to and not var.has_been_read_from then
            usage_warnings = usage_warnings or {}
            table.insert(usage_warnings, {
               y = var.declared_at.y,
               x = var.declared_at.x,
               name = name,
               var = var,
               kind = "written but not read",
            })
         end

      end

      if var.declared_at and not has_var_been_used(var) then
         if var.used_as_type then
            var.declared_at.elide_type = true
         else
            if t.typename == "typedecl" and not is_global then
               var.declared_at.elide_type = true
            end
            usage_warnings = usage_warnings or {}
            table.insert(usage_warnings, { y = var.declared_at.y, x = var.declared_at.x, name = name, var = var, kind = "unused" })
         end
      elseif has_var_been_used(var) and t.typename == "typedecl" and var.aliasing then
         var.aliasing.has_been_written_to = var.has_been_written_to
         var.aliasing.has_been_read_from = var.has_been_read_from
         if ensure_not_abstract(t) then
            var.aliasing.declared_at.elide_type = false
         end
      end
   end
   if usage_warnings then
      table.sort(usage_warnings, function(a, b)
         return a.y < b.y or (a.y == b.y and a.x < b.x)
      end)
   end
   return usage_warnings
end

function Errors:check_var_usage(scope, is_global)
   local usage_warnings = check_var_usage(scope, is_global)
   if usage_warnings then
      for _, u in ipairs(usage_warnings) do
         if u.kind == "unused" then
            self:unused_warning(u.name, u.var)
         elseif u.kind == "written but not read" then
            self:add_warning(
            "unread",
            u.var.declared_at,
            "%s %s (of type %s) is never read",
            user_facing_variable_description(u.var),
            u.name,
            show_type(u.var.t))

         end
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

function Errors:add_unknown_dot(node, name)
   if not self.unknown_dots[name] then
      self.unknown_dots[name] = true
      self:add_unknown(node, name)
   end
end

function Errors:fail_unresolved_labels(scope)
   if scope.pending_labels then
      for name, nodes in pairs(scope.pending_labels) do
         for _, node in ipairs(nodes) do
            self:add(node, "no visible label '" .. name .. "' for goto")
         end
      end
   end
end

function Errors:fail_unresolved_nominals(scope, global_scope)
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



function Errors:check_redeclared_key(w, ctx, seen_keys, key)
   if key ~= nil then
      local s = seen_keys[key]
      if s then
         self:add_in_context(w, ctx, "redeclared key " .. tostring(key) .. " (previously declared at " .. self.filename .. ":" .. s.y .. ":" .. s.x .. ")")
      else
         seen_keys[key] = w
      end
   end
end





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
   },
}

local unop_types = {
   ["#"] = {
      ["enum"] = "integer",
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

local unop_to_metamethod = {
   ["#"] = "__len",
   ["-"] = "__unm",
   ["~"] = "__bnot",
}

local binop_types = {
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
      },
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
      },
   },
}

local binop_to_metamethod = {
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

local flip_binop_to_metamethod = {
   [">"] = "__lt",
   [">="] = "__le",
}

local function is_unknown(t)
   return t.typename == "unknown" or
   t.typename == "unresolved_emptytable_value"
end

local function display_typevar(typevar, what)
   return TL_DEBUG and
   (what .. " " .. typevar) or
   typevar:gsub("@.*", "")
end

local function show_fields(t, show)
   if t.declname then
      return " " .. t.declname
   end

   local out = {}
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

local function show_type_base(t, short, seen)

   if seen[t] then
      return seen[t]
   end
   seen[t] = "..."

   local function show(typ)
      return show_type(typ, short, seen)
   end

   if t.typename == "nominal" then
      local ret
      if t.typevals then
         local out = { table.concat(t.names, "."), "<" }
         local vals = {}
         for _, v in ipairs(t.typevals) do
            table.insert(vals, show(v))
         end
         table.insert(out, table.concat(vals, ", "))
         table.insert(out, ">")
         ret = table.concat(out)
      else
         ret = table.concat(t.names, ".")
      end
      if TL_DEBUG then
         ret = "nominal " .. ret
      end
      return ret
   elseif t.typename == "self" then
      if t.display_type then
         local ret = show_type_base(t.display_type, short, seen)
         if TL_DEBUG then
            ret = "self " .. ret
         end
         return ret
      end
      return "self"
   elseif t.typename == "tuple" then
      local out = {}
      for _, v in ipairs(t.tuple) do
         table.insert(out, show(v))
      end
      local list = table.concat(out, ", ")
      if t.is_va then
         list = list .. "..."
      end
      if short then
         return list
      end
      return "(" .. list .. ")"
   elseif t.typename == "tupletable" then
      local out = {}
      for _, v in ipairs(t.types) do
         table.insert(out, show(v))
      end
      return "{" .. table.concat(out, ", ") .. "}"
   elseif t.typename == "poly" then
      local out = {}
      for _, v in ipairs(t.types) do
         table.insert(out, show(v))
      end
      return "polymorphic function (with types " .. table.concat(out, " and ") .. ")"
   elseif t.typename == "union" then
      local out = {}
      for _, v in ipairs(t.types) do
         table.insert(out, show(v))
      end
      return table.concat(out, " | ")
   elseif t.typename == "emptytable" then
      return "{}"
   elseif t.typename == "map" then
      return "{" .. show(t.keys) .. " : " .. show(t.values) .. "}"
   elseif t.typename == "array" then
      return "{" .. show(t.elements) .. "}"
   elseif t.typename == "enum" then
      return t.declname or "enum"
   elseif t.fields then
      return short and (t.declname or t.typename) or t.typename .. show_fields(t, show)
   elseif t.typename == "function" then
      local out = { "function(" }
      local args = {}
      for i, v in ipairs(t.args.tuple) do
         table.insert(args, ((i == #t.args.tuple and t.args.is_va) and "...: " or
         (i > t.min_arity) and "? " or
         "") .. show(v))
      end
      table.insert(out, table.concat(args, ", "))
      table.insert(out, ")")
      if t.rets.tuple and #t.rets.tuple > 0 then
         table.insert(out, ": ")
         local rets = {}
         if #t.rets.tuple > 1 then
            table.insert(out, "(")
         end
         for i, v in ipairs(t.rets.tuple) do
            table.insert(rets, show(v) .. (i == #t.rets.tuple and t.rets.is_va and "..." or ""))
         end
         table.insert(out, table.concat(rets, ", "))
         if #t.rets.tuple > 1 then
            table.insert(out, ")")
         end
      end
      return table.concat(out)
   elseif t.typename == "generic" then
      local out = {}
      local name, rest
      local tt = t.t
      if tt.typename == "record" or tt.typename == "interface" or tt.typename == "function" then
         name, rest = show(tt):match("^(%a+)(.*)")
         table.insert(out, name)
      else
         rest = " " .. show(tt)
         table.insert(out, "generic")
      end
      table.insert(out, "<")
      local typeargs = {}
      for _, v in ipairs(t.typeargs) do
         table.insert(typeargs, show(v))
      end
      table.insert(out, table.concat(typeargs, ", "))
      table.insert(out, ">")
      table.insert(out, rest)
      return table.concat(out)
   elseif t.typename == "number" or
      t.typename == "integer" or
      t.typename == "boolean" or
      t.typename == "thread" then
      return t.typename
   elseif t.typename == "string" then
      if short then
         return "string"
      else
         return t.typename ..
         (t.literal and string.format(" %q", t.literal) or "")
      end
   elseif t.typename == "typevar" then
      return display_typevar(t.typevar, "typevar")
   elseif t.typename == "typearg" then
      local out = display_typevar(t.typearg, "typearg")
      if t.constraint then
         out = out .. " is " .. show(t.constraint)
      end
      return out
   elseif t.typename == "unresolvable_typearg" then
      return display_typevar(t.typearg, "typearg") .. " (unresolved generic)"
   elseif is_unknown(t) then
      return "<unknown type>"
   elseif t.typename == "invalid" then
      return "<invalid type>"
   elseif t.typename == "any" then
      return "<any type>"
   elseif t.typename == "nil" then
      return "nil"
   elseif t.typename == "boolean_context" then
      return "boolean"
   elseif t.typename == "none" then
      return ""
   elseif t.typename == "typedecl" then
      return (t.is_alias and "type alias to " or "type ") .. show(t.def)
   else
      return "<" .. t.typename .. ">"
   end
end

local function inferred_msg(t, prefix)
   return " (" .. (prefix or "") .. "inferred at " .. t.inferred_at.f .. ":" .. t.inferred_at.y .. ":" .. t.inferred_at.x .. ")"
end

show_type = function(t, short, seen)
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

local function search_for(module_name, suffix, path, tried)
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

tl.search_module = function(module_name, search_all)
   local found
   local fd
   local tried = {}
   local path = os.getenv("TL_PATH") or tl.path or package.path
   if search_all then
      found, fd, tried = search_for(module_name, ".d.tl", path, tried)
      if found then
         return found, fd
      end
   end
   found, fd, tried = search_for(module_name, ".tl", path, tried)
   if found then
      return found, fd
   end
   if search_all then
      found, fd, tried = search_for(module_name, ".lua", path, tried)
      if found then
         return found, fd
      end
   end
   return nil, nil, tried
end

local function require_module(w, module_name, opts, env)
   local mod = env.modules[module_name]
   if mod then
      return mod, env.module_filenames[module_name]
   end

   local found, fd = tl.search_module(module_name, true)
   if found and (opts.feat_lax == "on" or found:match("tl$")) then

      env.module_filenames[module_name] = found
      env.modules[module_name] = a_type(w, "typedecl", { def = a_type(w, "circular_require", {}) })

      local save_defaults = env.defaults
      local defaults = {
         feat_lax = opts.feat_lax or save_defaults.feat_lax,
         feat_arity = opts.feat_arity or save_defaults.feat_arity,
         gen_compat = opts.gen_compat or save_defaults.gen_compat,
         gen_target = opts.gen_target or save_defaults.gen_target,
         run_internal_compiler_checks = opts.run_internal_compiler_checks or save_defaults.run_internal_compiler_checks,
      }
      env.defaults = defaults

      local found_result, err = tl.check_file(found, env, fd)
      assert(found_result, err)

      env.defaults = save_defaults

      env.modules[module_name] = found_result.type

      return found_result.type, found
   elseif fd then
      fd:close()
   end

   return a_type(w, "invalid", {}), found
end

local compat_code_cache = {}

local function add_compat_entries(program, used_set, gen_compat)
   if gen_compat == "off" or not next(used_set) then
      return
   end

   local tl_debug = TL_DEBUG
   TL_DEBUG = nil

   local used_list = sorted_keys(used_set)

   local compat_loaded = false

   local n = 1
   local function load_code(name, text)
      local code = compat_code_cache[name]
      if not code then
         code = tl.parse(text, "@internal", "lua")
         tl.check(code, "@internal", { feat_lax = "off", gen_compat = "off" })
         compat_code_cache[name] = code
      end
      for _, c in ipairs(code) do
         table.insert(program, n, c)
         n = n + 1
      end
   end

   local function req(m)
      return (gen_compat == "optional") and
      "pcall(require, '" .. m .. "')" or
      "true, require('" .. m .. "')"
   end

   for _, name in ipairs(used_list) do
      if name == "table.unpack" then
         load_code(name, "local _tl_table_unpack = unpack or table.unpack")
      elseif name == "table.pack" then
         load_code(name, [[local _tl_table_pack = table.pack or function(...) return { n = select("#", ...), ... } end]])
      elseif name == "bit32" then
         load_code(name, "local bit32 = bit32; if not bit32 then local p, m = " .. req("bit32") .. "; if p then bit32 = m end")
      elseif name == "mt" then
         load_code(name, "local _tl_mt = function(m, s, a, b) return (getmetatable(s == 1 and a or b)[m](a, b) end")
      elseif name == "math.maxinteger" then
         load_code(name, "local _tl_math_maxinteger = math.maxinteger or math.pow(2,53)")
      elseif name == "math.mininteger" then
         load_code(name, "local _tl_math_mininteger = math.mininteger or -math.pow(2,53) - 1")
      elseif name == "type" then
         load_code(name, "local type = type")
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

local function get_stdlib_compat()
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

local bit_operators = {
   ["&"] = "band",
   ["|"] = "bor",
   ["~"] = "bxor",
   [">>"] = "rshift",
   ["<<"] = "lshift",
}

local function node_at(w, n)
   n.f = assert(w.f)
   n.x = w.x
   n.y = w.y
   return n
end

local function convert_node_to_compat_call(node, mod_name, fn_name, e1, e2)
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

local function convert_node_to_compat_mt_call(node, mt_name, which_self, e1, e2)
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

local stdlib_globals = nil
local globals_typeid = new_typeid()
local fresh_typevar_ctr = 1

local function assert_no_errors(errors, msg)
   if #errors ~= 0 then
      local out = {}
      for _, err in ipairs(errors) do
         table.insert(out, err.y .. ":" .. err.x .. " " .. err.msg .. "\n")
      end
      error("Internal Compiler Error: " .. msg .. ":\n" .. table.concat(out), 2)
   end
end

local function resolve_for_special_function(t)
   if t.typename == "poly" then
      t = t.types[1]
   end
   if t.typename == "generic" then
      t = t.t
   end
   if t.typename == "function" then
      return t
   end
end

local function set_special_function(t, fname)
   t = resolve_for_special_function(t)
   t.special_function_handler = fname
end

tl.new_env = function(opts)
   opts = opts or {}

   local env = {
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

   if not stdlib_globals then
      local tl_debug = TL_DEBUG
      TL_DEBUG = nil

      do
         local program, syntax_errors = tl.parse(prelude, "prelude.d.tl", "tl")
         assert_no_errors(syntax_errors, "prelude contains syntax errors")
         local result = tl.check(program, "@prelude", {}, env)
         assert_no_errors(result.type_errors, "prelude contains type errors")
      end

      do
         local program, syntax_errors = tl.parse(stdlib, "stdlib.d.tl", "tl")
         assert_no_errors(syntax_errors, "standard library contains syntax errors")
         local result = tl.check(program, "@stdlib", {}, env)
         assert_no_errors(result.type_errors, "standard library contains type errors")
      end

      stdlib_globals = env.globals

      TL_DEBUG = tl_debug


      local math_t = (stdlib_globals["math"].t).def
      local table_t = (stdlib_globals["table"].t).def
      math_t.fields["maxinteger"].needs_compat = true
      math_t.fields["mininteger"].needs_compat = true
      table_t.fields["pack"].needs_compat = true
      table_t.fields["unpack"].needs_compat = true


      local string_t = (stdlib_globals["string"].t).def
      set_special_function(string_t.fields["find"], "string.find")
      set_special_function(string_t.fields["format"], "string.format")
      set_special_function(string_t.fields["gmatch"], "string.gmatch")
      set_special_function(string_t.fields["gsub"], "string.gsub")
      set_special_function(string_t.fields["match"], "string.match")
      set_special_function(string_t.fields["pack"], "string.pack")
      set_special_function(string_t.fields["unpack"], "string.unpack")

      set_special_function(stdlib_globals["assert"].t, "assert")
      set_special_function(stdlib_globals["ipairs"].t, "ipairs")
      set_special_function(stdlib_globals["pairs"].t, "pairs")
      set_special_function(stdlib_globals["pcall"].t, "pcall")
      set_special_function(stdlib_globals["xpcall"].t, "xpcall")
      set_special_function(stdlib_globals["rawget"].t, "rawget")
      set_special_function(stdlib_globals["require"].t, "require")




      local w = { f = "@prelude", x = 1, y = 1 }
      stdlib_globals["..."] = { t = a_vararg(w, { a_type(w, "string", {}) }) }
      stdlib_globals["@is_va"] = { t = a_type(w, "any", {}) }

      env.globals = {}
   end

   local stdlib_compat = get_stdlib_compat()
   for name, var in pairs(stdlib_globals) do
      env.globals[name] = var
      var.needs_compat = stdlib_compat[name]
      local t = var.t
      if t.typename == "typedecl" then

         env.modules[name] = t
      end
   end

   if opts.predefined_modules then
      for _, name in ipairs(opts.predefined_modules) do
         local tc_opts = {
            feat_lax = env.defaults.feat_lax,
            feat_arity = env.defaults.feat_arity,
         }
         local w = { f = "@predefined", x = 1, y = 1 }
         local module_type = require_module(w, name, tc_opts, env)

         if module_type.typename == "invalid" then
            return nil, string.format("Error: could not predefine module '%s'", name)
         end
      end
   end

   return env
end


do



   local TypeChecker = {}








































   local function get_real_var_from_lower_scope(st, i, name)
      for j = i - 1, 1, -1 do
         local scope = st[j]
         local sv = scope.vars[name]
         if sv and ((not sv.is_specialized) or (sv.specialized_from)) then
            return sv
         end
      end
   end

   function TypeChecker:find_var(name, use)
      for i = #self.st, 1, -1 do
         local scope = self.st[i]
         local var = scope.vars[name]
         if var then
            if use == "lvalue" and var.is_specialized and var.is_specialized ~= "localizing" then
               if var.specialized_from then
                  var.has_been_written_to = true
                  return { t = var.specialized_from, attribute = var.attribute }, i, var.attribute
               end
            else
               if i == 1 and var.needs_compat then
                  self.all_needs_compat[name] = true
               end

               local real_var = var
               if var.is_specialized and var.is_specialized ~= "localizing" then
                  real_var = get_real_var_from_lower_scope(self.st, i, name) or real_var
               end
               if use == "use_type" then

                  real_var.used_as_type = true
               elseif use ~= "check_only" then
                  if use == "lvalue" then

                     real_var.has_been_written_to = true
                  else

                     real_var.has_been_read_from = true
                  end
               end

               return var, i, var.attribute
            end
         end
      end
   end

   function TypeChecker:simulate_g()

      local globals = {}
      for k, v in pairs(self.st[1].vars) do
         if k:sub(1, 1) ~= "@" then
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




   local map_type

   local fresh_typevar_fns = {
      ["typevar"] = function(typeargs, t, resolve)
         for _, ta in ipairs(typeargs) do
            if ta.typearg == t.typevar then
               return a_type(t, "typevar", {
                  typevar = (t.typevar:gsub("@.*", "")) .. "@" .. fresh_typevar_ctr,
                  constraint = t.constraint and resolve(t.constraint, false),
               }), true
            end
         end
         return t, false
      end,
      ["typearg"] = function(typeargs, t, resolve)
         for _, ta in ipairs(typeargs) do
            if ta.typearg == t.typearg then
               return a_type(t, "typearg", {
                  typearg = (t.typearg:gsub("@.*", "")) .. "@" .. fresh_typevar_ctr,
                  constraint = t.constraint and resolve(t.constraint, false),
               }), true
            end
         end
         return t, false
      end,
   }

   local function fresh_typeargs(self, g)
      fresh_typevar_ctr = fresh_typevar_ctr + 1

      local newg, errs = map_type(g.typeargs, g, fresh_typevar_fns)
      if newg.typename == "invalid" then
         self.errs:collect(errs)
         return g
      end
      assert(newg.typename == "generic", "Internal Compiler Error: error creating fresh type variables")
      assert(newg ~= g)
      newg.fresh = true

      return newg
   end

   local function wrap_generic_if_typeargs(typeargs, t)
      if not typeargs then
         return t
      end

      assert(not (t.typename == "typedecl"))

      local gt = a_type(t, "generic", { t = t })
      gt.typeargs = typeargs
      return gt
   end

   function TypeChecker:find_var_type(name, use)
      local var = self:find_var(name, use)
      if var then
         local t = var.t
         if t.typename == "unresolved_typearg" then
            return nil, nil, t.constraint
         end

         if t.typename == "generic" then
            t = fresh_typeargs(self, t)
         end

         return t, var.attribute
      end
   end

   local function ensure_not_method(t)

      if t.typename == "generic" then
         local tt = ensure_not_method(t.t)
         if tt ~= t.t then
            local gg = shallow_copy_new_type(t)
            gg.t = tt
            return gg
         end
      end

      if t.typename == "function" and t.is_method then
         t = shallow_copy_new_type(t);
         (t).is_method = false
      end
      return t
   end

   local function unwrap_for_find_type(typ)
      if typ.typename == "nominal" and typ.found then
         return unwrap_for_find_type(typ.found)
      elseif typ.typename == "typedecl" then
         return unwrap_for_find_type(typ.def)
      elseif typ.typename == "generic" then
         return unwrap_for_find_type(typ.t)
      end
      return typ
   end

   function TypeChecker:find_type(names)
      local typ = self:find_var_type(names[1], "use_type")
      if not typ then
         if #names == 1 and names[1] == "metatable" then
            return self:find_type({ "_metatable" })
         end
         return nil
      end
      for i = 2, #names do
         typ = unwrap_for_find_type(typ)
         if typ == nil then
            return nil
         end

         local fields = typ.fields and typ.fields
         if not fields then
            return nil
         end

         typ = fields[names[i]]
         if typ == nil then
            return nil
         end
      end


      if typ and typ.typename == "nominal" then
         typ = typ.found
      end
      if typ == nil then
         return nil
      end

      if typ.typename == "typedecl" then
         return typ
      elseif typ.typename == "typearg" then
         return nil, typ
      end
   end

   local function type_for_union(t)
      if t.typename == "typedecl" then
         return type_for_union(t.def)
      elseif t.typename == "tuple" then
         return type_for_union(t.tuple[1]), t.tuple[1]
      elseif t.typename == "nominal" then
         local typedecl = t.found
         if not typedecl then
            return "invalid"
         end
         return type_for_union(typedecl)
      elseif t.fields then
         if t.is_userdata then
            return "userdata", t
         end
         return "table", t
      elseif t.typename == "generic" then
         return type_for_union(t.t)
      elseif table_types[t.typename] then
         return "table", t
      else
         return t.typename, t
      end
   end

   local function is_valid_union(typ)


      local n_table_types = 0
      local n_table_is_types = 0
      local n_function_types = 0
      local n_userdata_types = 0
      local n_userdata_is_types = 0
      local n_string_enum = 0
      local has_primitive_string_type = false
      for _, t in ipairs(typ.types) do
         local ut, rt = type_for_union(t)
         if ut == "userdata" then
            assert(rt.fields)
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
            if rt.fields and rt.meta_fields and rt.meta_fields["__is"] then
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
            return false, nil
         end
      end
      return true
   end

   local function show_arity(f)
      local nfargs = #f.args.tuple
      if f.min_arity < nfargs then
         if f.min_arity > 0 then
            return "at least " .. f.min_arity .. (f.args.is_va and "" or " and at most " .. nfargs)
         else
            return (f.args.is_va and "any number" or "at most " .. nfargs)
         end
      else
         return tostring(nfargs or 0)
      end
   end

   local function drop_constant_value(t)
      if t.typename == "string" and t.literal then
         local ret = shallow_copy_new_type(t)
         ret.literal = nil
         return ret
      end
      return t
   end

   local function resolve_typedecl(t)
      if t.typename == "typedecl" then
         return t.def
      else
         return t
      end
   end

   local no_nested_types = {
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

   local resolve_typevars
   do





      local resolve_typevar_fns = {
         ["typevar"] = function(s, t)
            local rt = s.tc:find_var_type(t.typevar)
            if not rt then
               return t, false
            end

            rt = drop_constant_value(rt)
            s.resolved[t.typevar] = rt

            return rt, true
         end,
      }

      local function clear_resolved_typeargs(copy, resolved)
         for i = #copy.typeargs, 1, -1 do
            local r = resolved[copy.typeargs[i].typearg]
            if r then
               table.remove(copy.typeargs, i)
            end
         end
         if not copy.typeargs[1] then
            return copy.t
         end
         return copy
      end

      resolve_typevars = function(self, t)
         local state = {
            tc = self,
            resolved = {},
         }
         local rt, errs = map_type(state, t, resolve_typevar_fns)
         if errs then
            return rt, errs
         end

         if rt.typename == "generic" then
            rt = clear_resolved_typeargs(rt, state.resolved)
         end

         return rt
      end
   end

   map_type = function(self, ty, fns)
      local errs
      local seen = {}
      local resolve

      resolve = function(t, all_same)
         local same = true


         if no_nested_types[t.typename] or (t.typename == "nominal" and not t.typevals) then
            return t, all_same
         end

         if seen[t] then
            return seen[t], all_same
         end

         local orig_t = t
         local fn = fns[t.typename]
         if fn then
            local rt, is_resolved = fn(self, t, resolve)
            if rt ~= t then
               if is_resolved then
                  seen[t] = rt
                  return rt, false
               end
               return resolve(rt, false)
            end
         end

         local copy = {}
         seen[orig_t] = copy

         setmetatable(copy, type_mt)
         copy.typename = t.typename
         copy.f = t.f
         copy.x = t.x
         copy.y = t.y

         if t.typename == "generic" then
            assert(copy.typename == "generic")

            local ct = {}
            for i, tf in ipairs(t.typeargs) do
               ct[i], same = resolve(tf, same)
            end
            copy.typeargs = ct
            copy.t, same = resolve(t.t, same)
         elseif t.typename == "array" then
            assert(copy.typename == "array")

            copy.elements, same = resolve(t.elements, same)

         elseif t.typename == "typearg" then
            assert(copy.typename == "typearg")
            copy.typearg = t.typearg
            if t.constraint then
               copy.constraint, same = resolve(t.constraint, same)
            end
         elseif t.typename == "unresolvable_typearg" then
            assert(copy.typename == "unresolvable_typearg")
            copy.typearg = t.typearg
         elseif t.typename == "unresolved_emptytable_value" then
            assert(copy.typename == "unresolved_emptytable_value")
            copy.emptytable_type = t.emptytable_type
         elseif t.typename == "typevar" then
            assert(copy.typename == "typevar")
            copy.typevar = t.typevar
            if t.constraint then
               copy.constraint, same = resolve(t.constraint, same)
            end
         elseif t.typename == "typedecl" then
            assert(copy.typename == "typedecl")
            copy.def, same = resolve(t.def, same)
            copy.is_alias = t.is_alias
            copy.is_nested_alias = t.is_nested_alias
         elseif t.typename == "nominal" then
            assert(copy.typename == "nominal")
            copy.names = t.names
            copy.typevals = {}
            for i, tf in ipairs(t.typevals) do
               copy.typevals[i], same = resolve(tf, same)
            end
            copy.found = t.found
         elseif t.typename == "function" then
            assert(copy.typename == "function")
            copy.macroexp = t.macroexp
            copy.min_arity = t.min_arity
            copy.is_method = t.is_method
            copy.is_record_function = t.is_record_function
            copy.args, same = resolve(t.args, same)
            copy.rets, same = resolve(t.rets, same)
            copy.special_function_handler = t.special_function_handler
         elseif t.fields then
            assert(copy.typename == "record" or copy.typename == "interface")
            copy.declname = t.declname


            if t.elements then
               copy.elements, same = resolve(t.elements, same)
            end

            if t.interface_list then
               copy.interface_list = {}
               for i, v in ipairs(t.interface_list) do
                  copy.interface_list[i], same = resolve(v, same)
               end
            end

            copy.is_userdata = t.is_userdata

            copy.fields = {}
            copy.field_order = {}
            copy.field_comments = t.field_comments
            for i, k in ipairs(t.field_order) do
               copy.field_order[i] = k
               copy.fields[k], same = resolve(t.fields[k], same)
            end

            if t.meta_fields then
               copy.meta_fields = {}
               copy.meta_field_order = {}
               copy.meta_field_comments = t.meta_field_comments
               for i, k in ipairs(t.meta_field_order) do
                  copy.meta_field_order[i] = k
                  copy.meta_fields[k], same = resolve(t.meta_fields[k], same)
               end
            end
         elseif t.typename == "map" then
            assert(copy.typename == "map")
            copy.keys, same = resolve(t.keys, same)
            copy.values, same = resolve(t.values, same)
         elseif t.typename == "union" then
            assert(copy.typename == "union")
            copy.types = {}
            for i, tf in ipairs(t.types) do
               copy.types[i], same = resolve(tf, same)
            end

            local _, err = is_valid_union(copy)
            if err then
               errs = errs or {}
               table.insert(errs, Err(err, copy))
            end
         elseif t.typename == "poly" then
            assert(copy.typename == "poly")
            copy.types = {}
            for i, tf in ipairs(t.types) do
               copy.types[i], same = resolve(tf, same)
            end
         elseif t.typename == "tupletable" then
            assert(copy.typename == "tupletable")
            copy.inferred_at = t.inferred_at
            copy.types = {}
            for i, tf in ipairs(t.types) do
               copy.types[i], same = resolve(tf, same)
            end
         elseif t.typename == "tuple" then
            assert(copy.typename == "tuple")
            copy.is_va = t.is_va
            copy.tuple = {}
            for i, tf in ipairs(t.tuple) do
               copy.tuple[i], same = resolve(tf, same)
            end
         elseif t.typename == "self" then
            assert(copy.typename == "self")
            if t.display_type ~= nil then
               copy.display_type, same = resolve(t.display_type, same)
            end
         end

         copy.typeid = same and t.typeid or new_typeid()
         return copy, same and all_same
      end

      local copy = resolve(ty, true)
      if errs then
         return a_type(ty, "invalid", {}), errs
      end

      return copy
   end

   function TypeChecker:infer_emptytable(emptytable, fresh_t)
      local is_global = (emptytable.declared_at and emptytable.declared_at.kind == "global_declaration")
      local nst = is_global and 1 or #self.st
      for i = nst, 1, -1 do
         local scope = self.st[i]
         if scope.vars[emptytable.assigned_to] then
            scope.vars[emptytable.assigned_to] = { t = fresh_t }
         end
      end
   end

   local function resolve_tuple(t)
      local rt = t
      if rt.typename == "tuple" then
         rt = rt.tuple[1]
      end
      if rt == nil then
         return a_type(t, "nil", {})
      end
      return rt
   end

   function TypeChecker:check_if_redeclaration(new_name, node, t)
      local old
      if simple_types[new_name] then
         if t.typename ~= "typedecl" then
            return
         end
      else
         old = self:find_var(new_name, "check_only")
         if not old then
            return
         end
      end
      local var_name = node.tk
      local var_kind = "variable"
      if node.kind == "local_function" or node.kind == "record_function" then
         var_kind = "function"
         var_name = node.name.tk
      end
      self.errs:redeclaration_warning(node, var_name, var_kind, old)
   end

   local function type_at(w, t)
      t.x = w.x
      t.y = w.y
      return t
   end

   function TypeChecker:assert_resolved_typevars_at(w, t)
      local ret, errs = resolve_typevars(self, t)
      if errs then
         assert(w.y)
         self.errs:add_prefixing(w, errs, "")
      end


      if ret.typeid ~= t.typeid then
         return self:assert_resolved_typevars_at(w, ret)
      end

      if ret == t or t.typename == "typevar" then
         ret = shallow_copy_new_type(ret)
      end
      return type_at(w, ret)
   end

   function TypeChecker:infer_at(w, t)
      local ret = self:assert_resolved_typevars_at(w, t)
      if ret.typename == "invalid" then
         ret = t
      end

      if ret == t or t.typename == "typevar" then
         ret = shallow_copy_new_type(ret)
      end
      assert(w.f)
      ret.inferred_at = w
      return ret
   end

   do
      local function specialize_var(scope, node, name, t, attribute, specialization)
         local var = scope.vars[name]
         if var then
            if var.is_specialized then
               var.t = t
               return var
            end

            var.is_specialized = specialization
            var.specialized_from = var.t
            var.t = t
         else
            var = { t = t, attribute = attribute, is_specialized = specialization, declared_at = node }
            scope.vars[name] = var
         end

         if specialization == "widen" then
            scope.widens = scope.widens or {}
            scope.widens[name] = true
         else
            scope.narrows = scope.narrows or {}
            scope.narrows[name] = true
         end

         return var
      end

      function TypeChecker:add_var(node, name, t, attribute, specialization)

         if self.feat_lax and node and is_unknown(t) and (name ~= "self" and name ~= "...") and not specialization then
            self.errs:add_unknown(node, name)
         end
         if not attribute then
            t = drop_constant_value(t)
         end

         if self.collector and node then
            self.collector.add_to_symbol_list(node, name, t)
         end

         local scope = self.st[#self.st]
         if specialization then
            return specialize_var(scope, node, name, t, attribute, specialization)
         end

         if node then
            if name ~= "self" and name ~= "..." and name:sub(1, 1) ~= "@" then
               self:check_if_redeclaration(name, node, t)
            end
            if not ensure_not_abstract(t) then
               node.elide_type = true
            end
         end

         local var = scope.vars[name]
         if var and not has_var_been_used(var) then


            self.errs:unused_warning(name, var)
         end

         var = { t = t, attribute = attribute, declared_at = node }
         scope.vars[name] = var

         return var
      end
   end



   function TypeChecker:has_all_types_of(t1s, t2s)
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

   local function any_errors(all_errs)
      if #all_errs == 0 then
         return true
      else
         return false, all_errs
      end
   end

   local function close_nested_records(t)
      if t.closed then
         return
      end
      local tdef = t.def
      if tdef.fields then
         t.closed = true
         for _, ft in pairs(tdef.fields) do
            if ft.typename == "typedecl" then
               close_nested_records(ft)
            end
         end
      end
   end

   local function close_types(scope)
      for _, var in pairs(scope.vars) do
         local t = var.t
         if t.typename == "typedecl" then
            close_nested_records(t)
         end
      end
   end

   function TypeChecker:widen_in_scope(n, var)
      local scope = self.st[n]
      local v = scope.vars[var]
      assert(v, "no " .. var .. " in scope")
      local specialization = scope.vars[var].is_specialized
      if (not specialization) or
         not (specialization == "narrow" or
         specialization == "narrowed_declaration") then

         return false
      end

      local top = #self.st
      if n ~= top then
         local t = v.specialized_from
         if not t then
            local old
            for i = n - 1, 1, -1 do
               old = self.st[i].vars[var]
               if old then
                  if old.specialized_from then
                     t = old.specialized_from
                     break
                  elseif old.is_specialized == "localizing" or not old.is_specialized then
                     t = old.t
                     break
                  end
               end
            end


            if not t then
               return false
            end
         end
         self:add_var(nil, var, t, nil, "widen")
         return true
      end

      if v.specialized_from then
         v.t = v.specialized_from
         v.specialized_from = nil
         v.is_specialized = nil
      else
         scope.vars[var] = nil
      end

      if scope.narrows then
         scope.narrows[var] = nil
      end

      return true
   end

   function TypeChecker:widen_back_var(name)
      local widened = false
      for i = #self.st, 1, -1 do
         local scope = self.st[i]
         if scope.vars[name] then
            if self:widen_in_scope(i, name) then
               widened = true
            else
               break
            end
         end
      end
      return widened
   end

   function TypeChecker:collect_if_widens(widens)
      local st = self.st
      local scope = st[#st]
      if scope.widens then
         widens = widens or {}
         for k, _ in pairs(scope.widens) do
            widens[k] = true
         end
         scope.widens = nil
      end
      return widens
   end

   function TypeChecker:widen_all(widens, widen_types)
      for name, _ in pairs(widens) do
         local curr = self:find_var(name, "check_only")
         local prev = widen_types[name]
         if (not prev) or (curr and not self:same_type(curr.t, prev)) then
            self:widen_back_var(name)
         end
      end
   end

   function TypeChecker:begin_scope(node)
      table.insert(self.st, { vars = {} })

      if self.collector and node then
         self.collector.begin_symbol_list_scope(node)
      end
   end

   function TypeChecker:end_scope(node)
      local st = self.st
      local scope = st[#st]

      local widen_types
      if scope.widens then
         widen_types = {}
         for name, _ in pairs(scope.widens) do
            local var = self:find_var(name, "check_only")
            widen_types[name] = var.t
         end
      end

      table.remove(st)
      local next_scope = st[#st]

      assert(not scope.is_transaction)

      close_types(scope)
      self.errs:check_var_usage(scope)

      if scope.widens then
         self:widen_all(scope.widens, widen_types)
      end

      if self.collector and node then
         self.collector.end_symbol_list_scope(node)
      end

      if not next_scope then
         return
      end

      if scope.pending_labels then
         if next_scope.pending_labels then
            for name, nodes in pairs(scope.pending_labels) do
               for _, n in ipairs(nodes) do
                  next_scope.pending_labels[name] = next_scope.pending_labels[name] or {}
                  table.insert(next_scope.pending_labels[name], n)
               end
            end
         else
            next_scope.pending_labels = scope.pending_labels
         end
      end

      if scope.pending_nominals then
         if next_scope.pending_nominals then
            for name, types in pairs(scope.pending_nominals) do
               for _, typ in ipairs(types) do
                  next_scope.pending_nominals[name] = next_scope.pending_nominals[name] or {}
                  table.insert(next_scope.pending_nominals[name], typ)
               end
            end
         else
            next_scope.pending_nominals = scope.pending_nominals
         end
      end
   end

   function TypeChecker:begin_scope_transaction(node)
      self:begin_scope(node)
      local st = self.st
      st[#st].is_transaction = true
   end

   function TypeChecker:rollback_scope_transaction()
      local st = self.st
      local scope = st[#st]
      assert(scope.is_transaction)

      local vars = scope.vars
      for k, _ in pairs(vars) do
         vars[k] = nil
      end

      if self.collector then
         self.collector.rollback_symbol_list_scope()
      end
   end

   function TypeChecker:commit_scope_transaction(node)
      local st = self.st
      local scope = st[#st]
      local next_scope = st[#st - 1]

      assert(scope.is_transaction)
      assert(not scope.pending_labels)
      assert(not scope.pending_nominals)

      for name, var in pairs(scope.vars) do
         local t = var.t
         next_scope.vars[name] = var
         assert(t)
      end

      table.remove(st)

      if self.collector and node then
         self.collector.end_symbol_list_scope(node)
      end
   end


   local NONE = a_type({ f = "@none", x = -1, y = -1 }, "none", {})

   local function end_scope_and_none_type(self, node, _children)
      self:end_scope(node)
      return NONE
   end

   local function unresolved_typeargs_for(g)
      local ts = {}
      for _, ta in ipairs(g.typeargs) do
         table.insert(ts, a_type(ta, "unresolved_typearg", {
            constraint = ta.constraint,
         }))
      end
      return ts
   end

   function TypeChecker:apply_generic(w, g, typeargs)
      if not g.fresh then
         g = fresh_typeargs(self, g)
      end

      if not typeargs then
         typeargs = unresolved_typeargs_for(g)
      end

      assert(#g.typeargs == #typeargs)

      for i, ta in ipairs(g.typeargs) do
         self:add_var(nil, ta.typearg, typeargs[i])
      end
      local applied, errs = resolve_typevars(self, g)
      if errs then
         self.errs:add_prefixing(w, errs, "")
         return nil
      end

      if applied.typename == "generic" then
         return applied.t, g.typeargs
      else
         return applied, g.typeargs
      end
   end



   do
      local function check_metatable_contract(self, tv, ret)
         if not ret or not (tv.typename == "nominal") then
            return
         end
         local found = tv.found
         if not found then
            return
         end
         local rec = found.def
         if not (rec.fields and rec.meta_fields and ret.fields) then
            return
         end
         for fname, ftype in pairs(rec.meta_fields) do
            if ret.fields[fname] then
               if not self:is_a(ftype, ret.fields[fname]) then
                  self.errs:add(ftype, fname .. " does not follow metatable contract: got %s, expected %s", ftype, ret.fields[fname])
               end
            end
            ret.fields[fname] = ftype
         end
      end

      local function match_typevals(self, t, def)
         if not t.typevals then

            local deft = def.t
            if (not (deft.typename == "function")) and (not (deft.typename == "poly")) then
               self.errs:add(t, "missing type arguments in %s", def)
               return nil
            end
         elseif #t.typevals ~= #def.typeargs then
            self.errs:add(t, "mismatch in number of type arguments")
            return nil
         end

         self:begin_scope()

         local ret = self:apply_generic(t, def, t.typevals)
         if def == self.cache_std_metatable_type then
            check_metatable_contract(self, t.typevals[1], ret)
         end

         self:end_scope()

         return ret
      end

      local function find_nominal_type_decl(self, t)
         if t.resolved then
            return t.resolved
         end

         local found = t.found or self:find_type(t.names)
         if not found then
            return self.errs:invalid_at(t, "unknown type %s", t)
         end

         if found.typename == "typedecl" and found.is_alias then
            local def = found.def
            if def.typename == "nominal" then
               found = def.found
            end

         end

         if not found then
            return self.errs:invalid_at(t, table.concat(t.names, ".") .. " is not a resolved type")
         end

         if not (found.typename == "typedecl") then
            return self.errs:invalid_at(t, table.concat(t.names, ".") .. " is not a type")
         end

         local def = found.def
         if def.typename == "circular_require" then

            return def
         end

         assert(not (def.typename == "nominal"))

         t.found = found

         if self.collector then
            self.env.reporter:set_ref(t, found)
         end

         return nil, found
      end

      local function resolve_decl_in_nominal(self, t, found)
         local def = found.def
         local resolved
         if def.typename == "generic" then
            resolved = match_typevals(self, t, def)
            if not resolved then
               resolved = a_type(t, "invalid", {})
            end
         elseif t.typevals then
            resolved = self.errs:invalid_at(t, "unexpected type argument")
         else
            resolved = def
         end

         t.resolved = resolved

         return resolved
      end

      function TypeChecker:resolve_nominal(t)
         local immediate, found = find_nominal_type_decl(self, t)
         if immediate then
            return immediate
         end

         return resolve_decl_in_nominal(self, t, found)
      end

      function TypeChecker:resolve_typealias(ta)
         local def = ta.def

         local nom = def
         if def.typename == "generic" then
            nom = def.t
         end

         if not (nom.typename == "nominal") then
            return ta
         end


         local immediate, found = find_nominal_type_decl(self, nom)

         if immediate and (immediate.typename == "invalid" or immediate.typename == "typedecl") then
            return immediate
         end


         if not nom.typevals then
            nom.resolved = found
            return found
         end




         local struc = resolve_decl_in_nominal(self, nom, found or nom.found)

         if def.typename == "generic" then
            struc = wrap_generic_if_typeargs(def.typeargs, struc)
         end


         local td = a_type(ta, "typedecl", { def = struc })
         nom.resolved = td


         return td
      end
   end














   function TypeChecker:arg_check(w, all_errs, a, b, v, mode, n)
      local ok, err, errs

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

      if ok and b.typename == "nominal" then
         local rb = self:resolve_nominal(b)
         ok, err = ensure_not_abstract(rb)
         if not ok then
            errs = { Err_at(w, err) }
         end
      end

      if not ok then
         self.errs:add_prefixing(w, errs, mode .. (n and " " .. n or "") .. ": ", all_errs)
         return false
      end
      return true
   end

   do
      local function are_same_unresolved_global_type(self, t1, t2)

         if t1.names[1] == t2.names[1] then
            local global_scope = self.st[1]
            if global_scope.pending_global_types[t1.names[1]] then
               return true
            end
         end
         return false
      end

      local function fail_nominals(self, t1, t2)
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

      local function nominal_found_type(self, nom)
         local typedecl = nom.found
         if not typedecl then
            typedecl = self:find_type(nom.names)
            if not typedecl then
               return nil
            end
         end
         local t = typedecl.def

         if t.typename == "generic" then
            t = t.t
         end

         return t
      end

      function TypeChecker:are_same_nominals(t1, t2)
         local t1f = nominal_found_type(self, t1)
         local t2f = nominal_found_type(self, t2)
         if (not t1f or not t2f) then
            if are_same_unresolved_global_type(self, t1, t2) then
               return true
            end

            if not t1f then
               self.errs:add(t1, "unknown type %s", t1)
            end
            if not t2f then
               self.errs:add(t2, "unknown type %s", t2)
            end
            return false, {}
         end

         if t1f.typeid ~= t2f.typeid then
            return fail_nominals(self, t1, t2)
         end

         if t1.typevals == nil and t2.typevals == nil then
            return true
         end

         if t1.typevals and t2.typevals and #t1.typevals == #t2.typevals then
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

   local is_lua_table_type

   function TypeChecker:to_structural(t)
      assert(not (t.typename == "tuple"))
      if t.typename == "typevar" and t.constraint then
         t = t.constraint
      end
      if t.typename == "nominal" then
         t = self:resolve_nominal(t)
      end
      return t
   end

   local function unite(w, types, flatten_constants)
      if #types == 1 then
         return types[1]
      end

      local ts = {}
      local stack = {}


      local types_seen = {}

      types_seen["nil"] = true

      local i = 1
      while types[i] or stack[1] do
         local t
         if stack[1] then
            t = table.remove(stack)
         else
            t = types[i]
            i = i + 1
         end
         t = resolve_tuple(t)
         if t.typename == "union" then
            for _, s in ipairs(t.types) do
               table.insert(stack, s)
            end
         else
            if primitive[t.typename] and (flatten_constants or (t.typename == "string" and not t.literal)) then
               if not types_seen[t.typename] then
                  types_seen[t.typename] = true
                  table.insert(ts, t)
               end
            else
               local typeid = t.typeid
               if t.typename == "nominal" and t.found then
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
         return a_type(w, "union", { types = ts })
      end
   end

   do
      local known_table_types = {
         array = true,
         map = true,
         record = true,
         tupletable = true,
         interface = true,
      }


      is_lua_table_type = function(t)
         return known_table_types[t.typename] and
         not (t.fields and t.is_userdata)
      end
   end

   function TypeChecker:arraytype_from_tuple(w, tupletype)

      local element_type = unite(w, tupletype.types, true)
      local valid = (not (element_type.typename == "union")) and true or is_valid_union(element_type)
      if valid then
         return a_type(w, "array", { elements = element_type })
      end


      local arr_type = a_type(w, "array", { elements = tupletype.types[1] })
      for i = 2, #tupletype.types do
         local expanded = self:expand_type(w, arr_type, a_type(w, "array", { elements = tupletype.types[i] }))
         if not (expanded.typename == "array") then
            return nil, { Err("unable to convert tuple %s to array", tupletype) }
         end
         arr_type = expanded
      end
      return arr_type
   end

   local function compare_true(_, _, _)
      return true
   end

   function TypeChecker:subtype_nominal(a, b)
      local ra = a.typename == "nominal" and self:resolve_nominal(a) or a
      local rb = b.typename == "nominal" and self:resolve_nominal(b) or b
      local ok, errs = self:is_a(ra, rb)
      if errs and #errs == 1 and errs[1].msg:match("^got ") then
         return false
      end
      return ok, errs
   end

   function TypeChecker:subtype_array(a, b)
      if (not a.elements) or (not self:is_a(a.elements, b.elements)) then
         return false
      end
      if a.consttypes and #a.consttypes > 1 then

         for _, e in ipairs(a.consttypes) do
            if not self:is_a(e, b.elements) then
               return false, { Err("%s is not a member of %s", e, b.elements) }
            end
         end
      end
      return true
   end

   function TypeChecker:in_interface_list(r, iface)
      if not r.interface_list then
         return false
      end

      for _, t in ipairs(r.interface_list) do
         if self:is_a(t, iface) then
            return true
         end
      end

      return false
   end

   function TypeChecker:subtype_record(a, b)

      if a.elements and b.elements then
         if not self:is_a(a.elements, b.elements) then
            return false, { Err("array parts have incompatible element types") }
         end
      end

      if a.is_userdata ~= b.is_userdata then
         return false, { Err(a.is_userdata and "userdata is not a record" or
"record is not a userdata"), }
      end

      local errs = {}
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

   function TypeChecker:eqtype_record(a, b)

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

   local function compare_map(self, ak, bk, av, bv, no_hack)
      local ok1, errs_k = self:is_a(bk, ak)
      local ok2, errs_v = self:is_a(av, bv)


      if bk.typename == "any" and not no_hack then
         ok1, errs_k = true, nil
      end
      if bv.typename == "any" and not no_hack then
         ok2, errs_v = true, nil
      end

      if ok1 and ok2 then
         return true
      end


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

   function TypeChecker:compare_or_infer_typevar(typevar, a, b, cmp)



      local vt, _, constraint = self:find_var_type(typevar)
      if vt then

         return cmp(self, a or vt, b or vt)
      else

         local other = a or b


         if constraint then
            if not self:is_a(other, constraint) then
               return false, { Err("given type %s does not satisfy %s constraint in type variable " .. display_typevar(typevar, "typevar"), other, constraint) }
            end

            if self:same_type(other, constraint) then



               return true
            end
         end

         local r, errs = resolve_typevars(self, other)
         if errs then
            return false, errs
         end


         if r.typename == "boolean_context" then
            return true
         end

         if r.typename == "typevar" and r.typevar == typevar then
            return true
         end
         self:add_var(nil, typevar, r)
         return true
      end
   end

   function TypeChecker:type_of_self(w)
      local t = self:find_var_type("@self")
      if not t then
         return a_type(w, "invalid", {}), nil
      end
      assert(t.typename == "typedecl")
      return t.def, t
   end


   function TypeChecker:exists_supertype_in(t, xs)
      for _, x in ipairs(xs.types) do
         if self:is_a(t, x) then
            return x
         end
      end
   end


   function TypeChecker:forall_are_subtype_of(xs, t)
      for _, x in ipairs(xs.types) do
         if not self:is_a(x, t) then
            return false
         end
      end
      return true
   end

   local function compare_true_inferring_emptytable(self, a, b)
      self:infer_emptytable(b, self:infer_at(b, a))
      return true
   end

   local function compare_true_inferring_emptytable_if_not_userdata(self, a, b)
      if a.is_userdata then
         return false, { Err("{} cannot be used with userdata type %s", a) }
      end
      return compare_true_inferring_emptytable(self, a, b)
   end

   local function infer_emptytable_from_unresolved_value(self, w, u, values)
      local et = u.emptytable_type
      assert(et.typename == "emptytable", u.typename)
      local keys = et.keys
      if not (values.typename == "emptytable" or values.typename == "unresolved_emptytable_value") then
         local infer_to = is_numeric_type(keys) and
         a_type(w, "array", { elements = values }) or
         a_type(w, "map", { keys = keys, values = values })
         self:infer_emptytable(et, self:infer_at(w, infer_to))
      end
   end

   local function a_is_interface_b(self, a, b)
      if (not a.found) or (not b.found) then
         return false
      end

      local af = a.found.def
      if af.typename == "generic" then
         af = self:apply_generic(a, af, a.typevals)
      end

      if af.fields then
         if self:in_interface_list(af, b) then
            return true
         end
      end

      return self:is_a(a, self:resolve_nominal(b))
   end


   local emptytable_relations = {
      ["emptytable"] = compare_true,
      ["array"] = compare_true,
      ["map"] = compare_true,
      ["tupletable"] = compare_true,
      ["interface"] = function(_self, _a, b)
         return not b.is_userdata
      end,
      ["record"] = function(_self, _a, b)
         return not b.is_userdata
      end,
   }

   TypeChecker.eqtype_relations = {
      ["typevar"] = {
         ["typevar"] = function(self, a, b)
            if a.typevar == b.typevar then
               return true
            end

            return self:compare_or_infer_typevar(b.typevar, a, nil, self.same_type)
         end,
         ["*"] = function(self, a, b)
            return self:compare_or_infer_typevar(a.typevar, nil, b, self.same_type)
         end,
      },
      ["emptytable"] = emptytable_relations,
      ["tupletable"] = {
         ["tupletable"] = function(self, a, b)
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
         ["emptytable"] = compare_true_inferring_emptytable,
      },
      ["array"] = {
         ["array"] = function(self, a, b)
            return self:same_type(a.elements, b.elements)
         end,
         ["emptytable"] = compare_true_inferring_emptytable,
      },
      ["map"] = {
         ["map"] = function(self, a, b)
            return compare_map(self, a.keys, b.keys, a.values, b.values, true)
         end,
         ["emptytable"] = compare_true_inferring_emptytable,
      },
      ["union"] = {
         ["union"] = function(self, a, b)
            return (self:has_all_types_of(a.types, b.types) and
            self:has_all_types_of(b.types, a.types))
         end,
      },
      ["nominal"] = {
         ["nominal"] = TypeChecker.are_same_nominals,
         ["typedecl"] = function(self, a, b)

            return self:same_type(self:resolve_nominal(a), b.def)
         end,
      },
      ["record"] = {
         ["record"] = TypeChecker.eqtype_record,
         ["emptytable"] = compare_true_inferring_emptytable_if_not_userdata,
      },
      ["interface"] = {
         ["interface"] = function(_self, a, b)
            return a.typeid == b.typeid
         end,
         ["emptytable"] = compare_true_inferring_emptytable_if_not_userdata,
      },
      ["function"] = {
         ["function"] = function(self, a, b)
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
      ["self"] = {
         ["self"] = function(_self, _a, _b)
            return true
         end,
         ["*"] = function(self, a, b)
            return self:same_type(self:type_of_self(a), b)
         end,
      },
      ["boolean_context"] = {
         ["boolean"] = compare_true,
      },
      ["generic"] = {
         ["generic"] = function(self, a, b)
            if #a.typeargs ~= #b.typeargs then
               return false
            end
            for i = 1, #a.typeargs do
               if not self:same_type(a.typeargs[i], b.typeargs[i]) then
                  return false
               end
            end
            return self:same_type(a.t, b.t)
         end,
      },
      ["*"] = {
         ["boolean_context"] = compare_true,
         ["self"] = function(self, a, b)
            return self:same_type(a, (self:type_of_self(b)))
         end,
         ["typevar"] = function(self, a, b)
            return self:compare_or_infer_typevar(b.typevar, a, nil, self.same_type)
         end,
      },
   }

   TypeChecker.subtype_relations = {
      ["nil"] = {
         ["*"] = compare_true,
      },
      ["tuple"] = {
         ["tuple"] = function(self, a, b)
            local at, bt = a.tuple, b.tuple
            if #at ~= #bt then
               return false
            end
            for i = 1, #at do
               if not self:is_a(at[i], bt[i]) then
                  return false
               end
            end
            return true
         end,
         ["*"] = function(self, a, b)
            return self:is_a(resolve_tuple(a), b)
         end,
      },
      ["typevar"] = {
         ["typevar"] = function(self, a, b)
            if a.typevar == b.typevar then
               return true
            end

            return self:compare_or_infer_typevar(b.typevar, a, nil, self.is_a)
         end,
         ["*"] = function(self, a, b)
            return self:compare_or_infer_typevar(a.typevar, nil, b, self.is_a)
         end,
      },
      ["union"] = {
         ["nominal"] = function(self, a, b)

            local rb = self:resolve_nominal(b)
            if rb.typename == "union" then
               return self:is_a(a, rb)
            end

            return self:forall_are_subtype_of(a, b)
         end,
         ["union"] = function(self, a, b)
            local used = {}
            for _, t in ipairs(a.types) do
               self:begin_scope()
               local u = self:exists_supertype_in(t, b)
               self:end_scope()
               if not u then
                  return false
               end
               if not used[u] then
                  used[u] = t
               end
            end
            for u, t in pairs(used) do
               self:is_a(t, u)
            end
            return true
         end,
         ["*"] = TypeChecker.forall_are_subtype_of,
      },
      ["poly"] = {
         ["*"] = function(self, a, b)
            if self:exists_supertype_in(b, a) then
               return true
            end
            return false, { Err("cannot match against any alternatives of the polymorphic type") }
         end,
      },
      ["nominal"] = {
         ["nominal"] = function(self, a, b)
            local ok, errs = self:are_same_nominals(a, b)
            if ok then
               return true
            end

            local ra = self:resolve_nominal(a)
            local rb = self:resolve_nominal(b)


            local union_a = ra.typename == "union"
            local union_b = rb.typename == "union"
            if union_a or union_b then
               return self:is_a(union_a and ra or a, union_b and rb or b)
            end


            if rb.typename == "interface" then
               return a_is_interface_b(self, a, b)
            end


            return ok, errs
         end,
         ["union"] = function(self, a, b)

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
         ["enum"] = function(_self, a, b)
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
         ["interface"] = function(self, a, b)
            if self:in_interface_list(a, b) then
               return true
            end
            return self:same_type(a, b)
         end,
         ["array"] = TypeChecker.subtype_array,
         ["tupletable"] = function(self, a, b)
            return self.subtype_relations["record"]["tupletable"](self, a, b)
         end,
         ["emptytable"] = compare_true_inferring_emptytable_if_not_userdata,
      },
      ["emptytable"] = emptytable_relations,
      ["tupletable"] = {
         ["tupletable"] = function(self, a, b)
            for i = 1, math.min(#a.types, #b.types) do
               if not self:is_a(a.types[i], b.types[i]) then
                  return false, { Err("in tuple entry " ..
tostring(i) .. ": got %s, expected %s",
a.types[i], b.types[i]), }
               end
            end
            if #a.types > #b.types then
               return false, { Err("tuple %s is too big for tuple %s", a, b) }
            end
            return true
         end,
         ["record"] = function(self, a, b)
            if b.elements then
               return self.subtype_relations["tupletable"]["array"](self, a, b)
            end
         end,
         ["array"] = function(self, a, b)
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
         ["map"] = function(self, a, b)
            local aa = self:arraytype_from_tuple(a.inferred_at or a, a)
            if not aa then
               return false, { Err("Unable to convert tuple %s to map", a) }
            end

            return compare_map(self, a_type(a, "integer", {}), b.keys, aa.elements, b.values)
         end,
         ["emptytable"] = compare_true_inferring_emptytable,
      },
      ["record"] = {
         ["record"] = TypeChecker.subtype_record,
         ["interface"] = function(self, a, b)
            if self:in_interface_list(a, b) then
               return true
            end
            if not a.declname then

               return self:subtype_record(a, b)
            end
         end,
         ["array"] = TypeChecker.subtype_array,
         ["map"] = function(self, a, b)
            if not self:is_a(b.keys, a_type(b, "string", {})) then
               return false, { Err("can't match a record to a map with non-string keys") }
            end

            for _, k in ipairs(a.field_order) do
               local bk = b.keys
               if bk.typename == "enum" and not bk.enumset[k] then
                  return false, { Err("key is not an enum value: " .. k) }
               end
               if not self:is_a(a.fields[k], b.values) then
                  return false, { Err("record is not a valid map; not all fields have the same type") }
               end
            end

            return true
         end,
         ["tupletable"] = function(self, a, b)
            if a.elements then
               return self.subtype_relations["array"]["tupletable"](self, a, b)
            end
         end,
         ["emptytable"] = compare_true_inferring_emptytable_if_not_userdata,
      },
      ["array"] = {
         ["array"] = TypeChecker.subtype_array,
         ["record"] = function(self, a, b)
            if b.elements then
               return self:subtype_array(a, b)
            end
         end,
         ["map"] = function(self, a, b)
            return compare_map(self, a_type(a, "integer", {}), b.keys, a.elements, b.values)
         end,
         ["tupletable"] = function(self, a, b)
            local alen = a.inferred_len or 0
            if alen > #b.types then
               return false, { Err("incompatible length, expected maximum length of " .. tostring(#b.types) .. ", got " .. tostring(alen)) }
            end



            for i = 1, (alen > 0) and alen or #b.types do
               if not self:is_a(a.elements, b.types[i]) then
                  return false, { Err("tuple entry " .. i .. " of type %s does not match type of array elements, which is %s", b.types[i], a.elements) }
               end
            end
            return true
         end,
         ["emptytable"] = compare_true_inferring_emptytable,
      },
      ["map"] = {
         ["map"] = function(self, a, b)
            return compare_map(self, a.keys, b.keys, a.values, b.values)
         end,
         ["array"] = function(self, a, b)
            return compare_map(self, a.keys, a_type(b, "integer", {}), a.values, b.elements)
         end,
         ["emptytable"] = compare_true_inferring_emptytable,
      },
      ["typedecl"] = {
         ["*"] = function(self, a, b)
            return self:is_a(a.def, b)
         end,
      },
      ["function"] = {
         ["function"] = function(self, a, b)
            local errs = {}

            local aa, ba = a.args.tuple, b.args.tuple
            if (not b.args.is_va) and (self.feat_arity and (#aa > #ba and a.min_arity > b.min_arity)) then
               table.insert(errs, Err("incompatible number of arguments: got " .. show_arity(a) .. " %s, expected " .. show_arity(b) .. " %s", a.args, b.args))
            else
               for i = ((a.is_method or b.is_method) and 2 or 1), #aa do
                  local ai = aa[i]
                  local bi = ba[i] or (b.args.is_va and ba[#ba])
                  if bi then
                     self:arg_check(nil, errs, ai, bi, "bivariant", "argument", i)
                  end
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
      ["self"] = {
         ["self"] = function(_self, _a, _b)
            return true
         end,
         ["*"] = function(self, a, b)
            return self:is_a(self:type_of_self(a), b)
         end,
      },
      ["typearg"] = {
         ["typearg"] = function(_self, a, b)
            return a.typearg == b.typearg
         end,
         ["*"] = function(self, a, b)
            if a.constraint then
               return self:is_a(a.constraint, b)
            end
         end,
      },
      ["boolean_context"] = {
         ["boolean"] = compare_true,
      },
      ["generic"] = {
         ["*"] = function(self, a, b)


            local aa = self:apply_generic(a, a)
            local ok, errs = self:is_a(aa, b)

            return ok, errs
         end,
      },
      ["*"] = {
         ["any"] = compare_true,
         ["boolean_context"] = compare_true,
         ["emptytable"] = function(_self, a, _b)
            return false, { Err("assigning %s to a variable declared with {}", a) }
         end,
         ["unresolved_emptytable_value"] = function(self, a, b)
            infer_emptytable_from_unresolved_value(self, b, b, a)
            return true
         end,
         ["generic"] = function(self, a, b)


            local bb = self:apply_generic(b, b)
            local ok, errs = self:is_a(a, bb)

            return ok, errs
         end,
         ["self"] = function(self, a, b)
            return self:is_a(a, (self:type_of_self(b)))
         end,
         ["tuple"] = function(self, a, b)
            return self:is_a(a_type(a, "tuple", { tuple = { a } }), b)
         end,
         ["typedecl"] = function(self, a, b)
            return self:is_a(a, b.def)
         end,
         ["typevar"] = function(self, a, b)
            return self:compare_or_infer_typevar(b.typevar, a, nil, self.is_a)
         end,
         ["typearg"] = function(self, a, b)
            if b.constraint then
               return self:is_a(a, b.constraint)
            end
         end,
         ["union"] = TypeChecker.exists_supertype_in,


         ["nominal"] = TypeChecker.subtype_nominal,
         ["poly"] = function(self, a, b)
            for _, t in ipairs(b.types) do
               if not self:is_a(a, t) then
                  return false, { Err("cannot match against all alternatives of the polymorphic type") }
               end
            end
            return true
         end,
      },
   }


   TypeChecker.type_priorities = {

      ["generic"] = -1,
      ["nil"] = 0,
      ["unresolved_emptytable_value"] = 1,
      ["emptytable"] = 2,
      ["self"] = 3,
      ["tuple"] = 4,
      ["typevar"] = 5,
      ["typedecl"] = 6,
      ["any"] = 7,
      ["boolean_context"] = 8,
      ["union"] = 9,
      ["poly"] = 10,

      ["typearg"] = 11,

      ["nominal"] = 12,

      ["enum"] = 13,
      ["string"] = 13,
      ["integer"] = 13,
      ["boolean"] = 13,

      ["interface"] = 14,

      ["tupletable"] = 15,
      ["record"] = 15,
      ["array"] = 15,
      ["map"] = 15,
      ["function"] = 15,
   }

   local function compare_types(self, relations, t1, t2)
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

      local ok, err
      if fn then
         if fn == compare_true then
            return true
         end
         ok, err = fn(self, t1, t2)
      else
         ok = t1.typename == t2.typename
      end

      if (not ok) and not err then
         if t1.typename == "invalid" or t2.typename == "invalid" then
            return false, {}
         end
         local show_t1 = show_type(t1)
         local show_t2 = show_type(t2)
         if show_t1 == show_t2 then
            return false, { Err_at(t1, "types are incompatible") }
         else
            return false, { Err_at(t1, "got " .. show_t1 .. ", expected " .. show_t2) }
         end
      end
      return ok, err
   end


   function TypeChecker:is_a(t1, t2)
      return compare_types(self, self.subtype_relations, t1, t2)
   end


   function TypeChecker:same_type(t1, t2)


      return compare_types(self, self.eqtype_relations, t1, t2)
   end

   if TL_DEBUG then
      local orig_is_a = TypeChecker.is_a
      TypeChecker.is_a = function(self, t1, t2)
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

   function TypeChecker:assert_is_a(w, t1, t2, ctx, name)
      t1 = resolve_tuple(t1)
      t2 = resolve_tuple(t2)
      if self.feat_lax and (is_unknown(t1) or t2.typename == "unknown") then
         return true
      end

      if t2.typename == "emptytable" then
         t2 = type_at(w, t2)
      end

      local ok, match_errs = self:is_a(t1, t2)
      if not ok then
         self.errs:add_prefixing(w, match_errs, self.errs:get_context(ctx, name))
      end
      return ok
   end

   local function type_is_closable(t)
      if t.typename == "invalid" then
         return false
      end
      if t.typename == "nil" then
         return true
      end
      if t.typename == "nominal" then
         t = assert(t.resolved)
      end
      if t.fields then
         return t.meta_fields and t.meta_fields["__close"] ~= nil
      end
   end

   local definitely_not_closable_exprs = {
      ["string"] = true,
      ["number"] = true,
      ["integer"] = true,
      ["boolean"] = true,
      ["literal_table"] = true,
   }
   local function expr_is_definitely_not_closable(e)
      return definitely_not_closable_exprs[e.kind]
   end

   function TypeChecker:same_in_all_union_entries(u, check)
      assert(#u.types > 0)

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
      return f
   end

   function TypeChecker:same_call_mt_in_all_union_entries(u)
      return self:same_in_all_union_entries(u, function(t)
         t = self:to_structural(t)
         if t.fields then
            local call_mt = t.meta_fields and t.meta_fields["__call"]
            if call_mt.typename == "function" then
               local args_tuple = a_type(u, "tuple", { tuple = {} })
               for i = 2, #call_mt.args.tuple do
                  table.insert(args_tuple.tuple, call_mt.args.tuple[i])
               end
               return args_tuple, call_mt
            end
         end
      end)
   end

   function TypeChecker:resolve_for_call(func, args, is_method)

      if self.feat_lax and is_unknown(func) then
         local unk = func
         func = a_function(func, {
            min_arity = 0,
            args = a_vararg(func, { unk }),
            rets = a_vararg(func, { unk }),
         })
      end

      func = self:to_structural(func)

      if func.typename == "generic" then
         func = self:apply_generic(func, func)
      end

      if func.typename == "function" or func.typename == "poly" then
         return func, is_method
      end


      if func.typename == "union" then
         local r = self:same_call_mt_in_all_union_entries(func)
         if r then
            table.insert(args.tuple, 1, func.types[1])
            return r, true
         end

      elseif func.typename == "typedecl" then
         return self:resolve_for_call(func.def, args, is_method)

      elseif func.fields and func.meta_fields and func.meta_fields["__call"] then
         table.insert(args.tuple, 1, func)
         func = func.meta_fields["__call"]
         func = self:to_structural(func)
         is_method = true
      end

      if func.typename == "generic" then
         func = self:apply_generic(func, func)
      end

      return func, is_method
   end




   local function traverse_macroexp(macroexp, on_arg_id, on_node)
      local root = macroexp.exp
      local argnames = {}
      for i, a in ipairs(macroexp.args) do
         argnames[a.tk] = i
      end

      local visit_node = {
         cbs = {
            ["variable"] = {
               after = function(_, node, _children)
                  local i = argnames[node.tk]
                  if not i then
                     return nil
                  end

                  return on_arg_id(node, i)
               end,
            },
            ["..."] = {
               after = function(_, node, _children)
                  local i = argnames[node.tk]
                  if not i then
                     return nil
                  end

                  return on_arg_id(node, i)
               end,
            },
         },
         after = on_node,
      }

      return recurse_node(nil, root, visit_node, {})
   end

   local function expand_macroexp(orignode, args, macroexp)
      local on_arg_id = function(node, i)
         if node.kind == '...' then

            local nd = node_at(orignode, {
               kind = "expression_list",
            })
            for n = i, #args do
               nd[n - i + 1] = args[n]
            end
            return { Node, nd }
         else



            local nd = args[i] or node_at(orignode, { kind = "nil", tk = "nil" })
            return { Node, nd }
         end
      end

      local on_node = function(_, node, children, ret)
         local orig = ret and ret[2] or node

         local out = shallow_copy_table(orig)

         local map = {}
         for _, pair in pairs(children) do
            if type(pair) == "table" then
               map[pair[1]] = pair[2]
            end
         end

         for k, v in pairs(orig) do
            if type(v) == "table" and map[v] then
               (out)[k] = map[v]
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

   function TypeChecker:check_macroexp_arg_use(macroexp)
      local used = {}

      local on_arg_id = function(node, _i)
         if used[node.tk] then
            self.errs:add(node, "cannot use argument '" .. node.tk .. "' multiple times in macroexp")
         else
            used[node.tk] = true
         end
      end

      traverse_macroexp(macroexp, on_arg_id, nil)
   end

   local function apply_macroexp(orignode)
      local expanded = orignode.expanded
      local saveknown = orignode.known
      orignode.expanded = nil

      for k, _ in pairs(orignode) do
         (orignode)[k] = nil
      end
      for k, v in pairs(expanded) do
         (orignode)[k] = v
      end
      orignode.known = saveknown
   end

   do
      local function mark_invalid_typeargs(self, typeargs)
         for _, a in ipairs(typeargs) do
            if not self:find_var_type(a.typearg) then
               if a.constraint then
                  self:add_var(nil, a.typearg, a.constraint)
               else
                  self:add_var(nil, a.typearg, self.feat_lax and a_type(a, "unknown", {}) or a_type(a, "unresolvable_typearg", {
                     typearg = a.typearg,
                  }))
               end
            end
         end
      end

      local function infer_emptytables(self, w, wheres, xs, ys, delta)
         local xt, yt = xs.tuple, ys.tuple
         local n_xs = #xt
         local n_ys = #yt

         for i = 1, n_xs do
            local x = xt[i]
            if x.typename == "emptytable" then
               local y = yt[i] or (ys.is_va and yt[n_ys])
               if y then
                  local iw = wheres and wheres[i + delta] or w
                  local inferred_y = self:infer_at(iw, y)
                  self:infer_emptytable(x, inferred_y)
                  xt[i] = inferred_y
               end
            end
         end
      end







      local check_call
      do
         local check_args_rets
         do

            local function check_func_type_list(self, w, wheres, xs, ys, from, delta, v, mode)
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

            check_args_rets = function(self, w, wargs, f, args, expected_rets, argdelta, or_args, or_rets)
               local rets_ok = true
               local args_ok, args_errs = true, nil

               local fargs = or_args or f.args
               local frets = or_rets or f.rets

               local from = 1
               if argdelta == -1 then
                  from = 2
                  local errs = {}
                  local first = fargs.tuple[1]
                  if (not (first.typename == "self")) and not self:arg_check(w, errs, first, args.tuple[1], "contravariant", "self") then
                     return nil, errs
                  end
               end

               if expected_rets then
                  expected_rets = self:infer_at(w, expected_rets)
                  infer_emptytables(self, w, nil, expected_rets, frets, 0)

                  rets_ok = check_func_type_list(self, w, nil, frets, expected_rets, 1, 0, "covariant", "return")
               end

               args_ok, args_errs = check_func_type_list(self, w, wargs, fargs, args, from, argdelta, "contravariant", "argument")
               if (not args_ok) or (not rets_ok) then
                  return nil, args_errs or {}
               end

               infer_emptytables(self, w, wargs, args, fargs, argdelta)

               return true
            end
         end

         local function is_method_mismatch(self, w, arg1, farg1, cm)
            if cm == "method" or not farg1 then
               return false
            end
            if not (arg1 and self:is_a(arg1, farg1)) then
               self.errs:add(w, "invoked method as a regular function: use ':' instead of '.'")
               return true
            end
            if cm == "plain" then
               self.errs:add_warning("hint", w, "invoked method as a regular function: consider using ':' instead of '.'")
            end
            return false
         end

         check_call = function(self, w, wargs, f, args, expected_rets, cm, argdelta, or_args, or_rets)
            local arg1 = args.tuple[1]
            if cm == "method" and arg1 then
               local selftype = arg1
               if selftype.typename == "self" then
                  selftype = self:type_of_self(selftype)
               end
               self:add_var(nil, "@self", a_type(w, "typedecl", { def = selftype }))
            end

            local fargs = (or_args or f.args).tuple
            if f.is_method and is_method_mismatch(self, w, arg1, fargs[1], cm) then
               return false
            end

            local given = #args.tuple
            local wanted = #fargs
            local min_arity = self.feat_arity and f.min_arity or 0

            if given < min_arity or (given > wanted and not (or_args or f.args).is_va) then
               return nil, { Err_at(w, "wrong number of arguments (given " .. given .. ", expects " .. show_arity(f) .. ")") }
            end

            return check_args_rets(self, w, wargs, f, args, expected_rets, argdelta, or_args, or_rets)
         end
      end

      function TypeChecker:iterate_poly(p)
         local i = 0
         return function()
            i = i + 1
            local fg = p.types[i]
            if not fg then
               return
            elseif fg.typename == "function" then
               return i, fg
            elseif fg.typename == "generic" then
               return i, self:apply_generic(p, fg)
            end
         end
      end

      local check_poly_call
      do
         local function fail_poly_call_arity(self, w, p, given)
            local expects = {}
            for _, f in self:iterate_poly(p) do
               table.insert(expects, show_arity(f))
            end
            table.sort(expects)
            for i = #expects, 1, -1 do
               if expects[i] == expects[i + 1] then
                  table.remove(expects, i)
               end
            end
            return { Err_at(w, "wrong number of arguments (given " .. given .. ", expects " .. table.concat(expects, " or ") .. ")") }
         end

         check_poly_call = function(self, w, wargs, p, args, expected_rets, cm, argdelta, or_args, or_rets)
            local given = #args.tuple

            local tried = {}
            local first_rets
            local first_errs

            for pass = 1, 3 do
               for i, f in self:iterate_poly(p) do
                  assert(f.typename == "function", f.typename)
                  assert(f.args)
                  first_rets = first_rets or or_rets or f.rets

                  local wanted = #f.args.tuple
                  local min_arity = self.feat_arity and f.min_arity or 0

                  if (not tried[i]) and

                     ((pass == 1 and given == wanted) or

                     (pass == 2 and (given < wanted and given >= min_arity)) or

                     (pass == 3 and (f.args.is_va and given > wanted))) then

                     local ok, errs = check_call(self, w, wargs, f, args, expected_rets, cm, argdelta, or_args, or_rets)
                     if ok then
                        return f, or_rets or f.rets
                     elseif expected_rets then

                        infer_emptytables(self, w, wargs, or_rets or f.rets, or_rets or f.rets, argdelta)
                     end

                     self:rollback_scope_transaction()

                     first_errs = first_errs or errs
                     tried[i] = true
                  end
               end
            end

            if not first_errs then
               return nil, first_rets, fail_poly_call_arity(self, w, p, given)
            end

            return nil, first_rets, first_errs
         end
      end

      local function should_warn_dot(node, e1, is_method)
         if is_method then
            return "method"
         end
         if node_is_funcall(node) and e1 and e1.receiver then
            local receiver = e1.receiver
            if receiver.typename == "nominal" then
               local resolved = receiver.resolved
               if resolved and resolved.typename == "typedecl" then
                  return "type_dot"
               end
            end
         end
         return "plain"
      end

      function TypeChecker:type_check_function_call(node, func, args, argdelta, or_args, or_rets, e1, e2)
         e1 = e1 or node.e1
         e2 = e2 or node.e2

         local expected = node.expected
         local expected_rets
         if expected and expected.typename == "tuple" then
            expected_rets = expected
         else
            expected_rets = a_type(node, "tuple", { tuple = { node.expected } })
         end

         self:begin_scope_transaction(node)

         local g
         local typeargs
         if func.typename == "generic" then
            g = func
            func, typeargs = self:apply_generic(node, func)
         end

         local is_method = (argdelta == -1)

         if not (func.typename == "function" or func.typename == "poly") then
            func, is_method = self:resolve_for_call(func, args, is_method)
            if is_method then
               argdelta = -1
            end
         end

         local cm = should_warn_dot(node, e1, is_method)

         local errs
         local f, ret

         if func.typename == "poly" then
            f, ret, errs = check_poly_call(self, node, e2, func, args, expected_rets, cm, argdelta, or_args, or_rets)
         elseif func.typename == "function" then
            local _
            _, errs = check_call(self, node, e2, func, args, expected_rets, cm, argdelta, or_args, or_rets)
            f, ret = func, or_rets or func.rets
         else
            ret = self.errs:invalid_at(node, "not a function: %s", func)
         end

         if errs then
            self.errs:collect(errs)
         end

         if g then
            mark_invalid_typeargs(self, typeargs)
         end

         self:commit_scope_transaction(node)

         ret = self:assert_resolved_typevars_at(node, ret)

         if self.collector then
            self.collector.store_type(e1.y, e1.x, f)
         end

         if f and f.macroexp then
            local argexps
            if is_method then
               argexps = {}
               if e1.kind == "op" then
                  table.insert(argexps, e1.e1)
               else
                  table.insert(argexps, e1)
               end
               for _, e in ipairs(e2) do
                  table.insert(argexps, e)
               end
            else
               argexps = e2
            end
            expand_macroexp(node, argexps, f.macroexp)
         end

         return ret, f
      end
   end

   function TypeChecker:check_metamethod(node, method_name, a, b, orig_a, orig_b, flipped)
      if self.feat_lax and ((a and is_unknown(a)) or (b and is_unknown(b))) then
         return a_type(node, "unknown", {}), nil
      end

      local ameta = a.fields and a.meta_fields
      local bmeta = b and b.fields and b.meta_fields

      if not ameta and not bmeta then
         return nil, nil
      end

      local meta_on_operator = 1
      local metamethod
      if method_name ~= "__is" then
         metamethod = ameta and ameta[method_name or ""]
      end
      if (not metamethod) and b and method_name ~= "__index" then
         metamethod = bmeta and bmeta[method_name or ""]
         meta_on_operator = 2
      end

      if metamethod then
         local e2 = { node.e1 }
         local args = a_type(node, "tuple", { tuple = { orig_a } })
         if b and method_name ~= "__is" then
            e2[2] = node.e2
            args.tuple[2] = orig_b
         end
         if flipped then
            e2[2], e2[1] = e2[1], e2[2]
         end

         local mtdelta = metamethod.typename == "function" and metamethod.is_method and -1 or 0
         local ret_call = self:type_check_function_call(node, metamethod, args, mtdelta, nil, nil, node, e2)
         local ret_unary = resolve_tuple(ret_call)
         local ret = self:to_structural(ret_unary)
         return ret, meta_on_operator
      else
         return nil, nil
      end
   end

   local function make_is_node(self, var, v, t)
      local node = node_at(var, { kind = "op", op = { op = "is", arity = 2, prec = 3 } })
      node.e1 = var
      node.e2 = node_at(var, { kind = "cast", casttype = self:infer_at(var, t) })
      local _, has = self:check_metamethod(node, "__is", self:to_structural(v), self:to_structural(t), v, t)
      if node.expanded then
         apply_macroexp(node)
      end
      node.known = IsFact({ var = var.tk, typ = t, w = node })
      return node, has
   end

   local function convert_is_of_union_to_or_of_is(self, node, v, u)
      local var = node.e1
      node.op.op = "or"
      node.op.arity = 2
      node.op.prec = 1
      local has_any = nil
      node.e1, has_any = make_is_node(self, var, v, u.types[1])
      local at = node
      local n = #u.types
      for i = 2, n - 1 do
         at.e2 = node_at(var, { kind = "op", op = { op = "or", arity = 2, prec = 1 } })
         local has
         at.e2.e1, has = make_is_node(self, var, v, u.types[i])
         has_any = has_any or has
         node.known = OrFact({ f1 = at.e1.known, f2 = at.e2.known, w = node })
         at = at.e2
      end
      at.e2 = make_is_node(self, var, v, u.types[n])
      node.known = OrFact({ f1 = at.e1.known, f2 = at.e2.known, w = node })
      return not not has_any
   end

   function TypeChecker:match_record_key(t, rec, key)
      t = self:to_structural(t)

      if t.typename == "self" then
         t = self:type_of_self(t)
      end

      if t.typename == "string" or t.typename == "enum" then

         t = self.env.modules["string"]
         self.all_needs_compat["string"] = true
      end

      if t.typename == "typedecl" then
         if t.is_nested_alias then
            return nil, "cannot use a nested type alias as a concrete value"
         end
         local def = t.def
         if def.typename == "nominal" then
            assert(t.is_alias)
            t = self:resolve_nominal(def)
         else
            t = def
         end
      end

      if t.typename == "generic" then
         t = self:apply_generic(t, t)
      end

      if t.typename == "union" then
         local ty = self:same_in_all_union_entries(t, function(typ)
            local v = self:match_record_key(typ, rec, key)
            return v, v
         end)
         if ty then
            return ty
         end
      end

      if (t.typename == "typevar" or t.typename == "typearg") and t.constraint then
         local ty = self:match_record_key(t.constraint, rec, key)
         if ty then
            return ty
         end
      end

      local keyg = key:gsub("%%", "%%%%")

      if t.fields then
         assert(t.fields, "record has no fields!?")

         if t.fields[key] then
            return t.fields[key]
         end

         local str = a_type(rec, "string", {})
         local meta_t = self:check_metamethod(rec, "__index", t, str, t, str)
         if meta_t then
            return meta_t
         end

         if rec.kind == "variable" then
            if t.typename == "interface" then
               return nil, "invalid key '" .. keyg .. "' in '" .. rec.tk .. "' of interface type %s"
            else
               return nil, "invalid key '" .. keyg .. "' in record '" .. rec.tk .. "' of type %s"
            end
         else
            return nil, "invalid key '" .. keyg .. "' in type %s"
         end
      elseif t.typename == "emptytable" or is_unknown(t) then
         if self.feat_lax then
            return a_type(rec, "unknown", {})
         end
         return nil, "cannot index a value of unknown type"
      end

      if rec.kind == "variable" then
         return nil, "cannot index key '" .. keyg .. "' in variable '" .. rec.tk .. "' of type %s"
      else
         return nil, "cannot index key '" .. keyg .. "' in type %s"
      end
   end

   local function assigned_anywhere(name, root)
      local visit_node = {
         cbs = {
            ["assignment"] = {
               after = function(_, node, _children)
                  for _, v in ipairs(node.vars) do
                     if v.kind == "variable" and v.tk == name then
                        return true
                     end
                  end
                  return false
               end,
            },
         },
         after = function(_, _node, children, ret)
            ret = ret or false
            for _, c in ipairs(children) do
               local ca = c
               if type(ca) == "boolean" then
                  ret = ret or c
               end
            end
            return ret
         end,
      }

      local visit_type = {
         after = function()
            return false
         end,
      }

      return recurse_node(nil, root, visit_node, visit_type)
   end

   function TypeChecker:widen_all_unions(node)
      for i = #self.st, 1, -1 do
         local scope = self.st[i]
         if scope.narrows then
            for name, _ in pairs(scope.narrows) do
               if not node or assigned_anywhere(name, node) then
                  self:widen_in_scope(i, name)
               end
            end
         end
      end
   end

   function TypeChecker:add_global(node, varname, valtype, is_assigning)
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

   function TypeChecker:add_internal_function_variables(node, args)
      self:add_var(nil, "@is_va", a_type(node, args.is_va and "any" or "nil", {}))
      self:add_var(nil, "@return", node.rets or a_type(node, "tuple", { tuple = {} }))

      if node.typeargs then
         for _, t in ipairs(node.typeargs) do
            local v = self:find_var(t.typearg, "check_only")
            if not v or not v.used_as_type then
               self.errs:add(t, "type argument '%s' is not used in function signature", t)
            end
         end
      end
   end

   function TypeChecker:add_function_definition_for_recursion(node, fnargs, feat_arity)
      self:add_var(nil, node.name.tk, wrap_generic_if_typeargs(node.typeargs, a_function(node, {
         min_arity = feat_arity and node.min_arity or 0,
         args = fnargs,
         rets = self.get_rets(node.rets),
      })))
   end

   function TypeChecker:end_function_scope(node)
      self.errs:fail_unresolved_labels(self.st[#self.st])
      self:end_scope(node)
   end

   local function flat_tuple(w, vt)
      local n_vals = #vt
      local ret = a_type(w, "tuple", { tuple = {} })
      local rt = ret.tuple

      if n_vals == 0 then
         return ret
      end


      for i = 1, n_vals - 1 do
         rt[i] = resolve_tuple(vt[i])
      end

      local last = vt[n_vals]
      if last.typename == "tuple" then

         local lt = last.tuple
         for _, v in ipairs(lt) do
            table.insert(rt, v)
         end
         ret.is_va = last.is_va
      else
         rt[n_vals] = vt[n_vals]
      end

      return ret
   end

   local function get_assignment_values(w, vals, wanted)
      if vals == nil then
         return a_type(w, "tuple", { tuple = {} })
      end


      if vals.is_va then
         local vt = vals.tuple
         local n_vals = #vt
         if n_vals > 0 and n_vals < wanted then
            local last = vt[n_vals]
            local ret = a_type(w, "tuple", { tuple = {} })
            local rt = ret.tuple
            for i = 1, n_vals do
               table.insert(rt, vt[i])
            end
            for _ = n_vals + 1, wanted do
               table.insert(rt, last)
            end
            return ret
         end
      end
      return vals
   end

   function TypeChecker:match_all_record_field_names(node, a, field_names, errmsg)
      local t
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

   function TypeChecker:type_check_index(anode, bnode, a, b)
      assert(not (a.typename == "tuple"))
      assert(not (b.typename == "tuple"))

      local ra = resolve_typedecl(self:to_structural(a))
      local rb = self:to_structural(b)

      if self.feat_lax and is_unknown(a) then
         return a
      end

      local errm
      local erra
      local errb

      if ra.typename == "tupletable" and rb.typename == "integer" then
         if bnode.constnum then
            if bnode.constnum >= 1 and bnode.constnum <= #ra.types and bnode.constnum == math.floor(bnode.constnum) then
               return ra.types[bnode.constnum]
            end

            errm, erra = "index " .. tostring(bnode.constnum) .. " out of range for tuple %s", ra
         else
            local array_type = self:arraytype_from_tuple(bnode, ra)
            if array_type then
               return array_type.elements
            end

            errm = "cannot index this tuple with a variable because it would produce a union type that cannot be discriminated at runtime"
         end
      elseif ra.typename == "self" then
         return self:type_check_index(anode, bnode, self:type_of_self(a), b)
      elseif ra.elements and rb.typename == "integer" then
         return ra.elements
      elseif ra.typename == "emptytable" then
         if ra.keys == nil then
            ra.keys = self:infer_at(bnode, b)
         end

         if self:is_a(b, ra.keys) then
            return a_type(anode, "unresolved_emptytable_value", {
               emptytable_type = ra,
            })
         end

         errm, erra, errb = "inconsistent index type: got %s, expected %s" .. inferred_msg(ra.keys, "type of keys "), b, ra.keys
      elseif ra.typename == "unresolved_emptytable_value" then
         local et = a_type(ra, "emptytable", { keys = b })
         infer_emptytable_from_unresolved_value(self, a, ra, et)
         return a_type(anode, "unresolved_emptytable_value", {
            emptytable_type = et,
         })
      elseif ra.typename == "map" then
         if self:is_a(b, ra.keys) then
            return ra.values
         end

         errm, erra, errb = "wrong index type: got %s, expected %s", b, ra.keys
      elseif rb.typename == "string" and rb.literal then
         local t, e = self:match_record_key(a, anode, rb.literal)
         if t then

            if t.typename == "function" and t.is_method then
               local t2 = shallow_copy_new_type(t)
               t2.args = shallow_copy_new_type(t.args)
               t2.args.tuple = shallow_copy_table(t2.args.tuple)
               for i, p in ipairs(t2.args.tuple) do
                  if p.typename == "self" then
                     t2.args.tuple[i] = a
                  end
               end
               return t2
            end

            return t
         end

         errm, erra = e, a
      elseif ra.fields then
         if rb.typename == "enum" then
            local field_names = sorted_keys(rb.enumset)
            for _, k in ipairs(field_names) do
               if not ra.fields[k] then
                  errm, erra = "enum value '" .. k:gsub("%%", "%%%%") .. "' is not a field in %s", ra
                  break
               end
            end
            if not errm then
               return self:match_all_record_field_names(bnode, ra, field_names,
               "cannot index, not all enum values map to record fields of the same type")
            end
         elseif rb.typename == "string" then
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

   function TypeChecker:expand_type(w, old, new)
      if not old or old.typename == "nil" then
         return new
      end
      if self:is_a(new, old) then
         return old
      end

      if new.fields then
         local keys
         local values
         if old.typename == "map" then
            keys = old.keys
            if not (keys.typename == "string") then
               self.errs:add(w, "cannot determine table literal type")
               return old
            end
            values = old.values
         elseif old.fields then
            keys = a_type(w, "string", {})
            for _, ftype in fields_of(old) do
               values = self:expand_type(w, values, ftype)
            end
         end

         for _, ftype in fields_of(new) do
            values = self:expand_type(w, values, ftype)
         end

         return a_type(w, "map", { keys = keys, values = values })
      end

      return unite(w, { old, new }, true)
   end

   function TypeChecker:find_record_to_extend(exp)

      if exp.kind == "type_identifier" then
         local v = self:find_var(exp.tk)
         if not v then
            return nil, nil, exp.tk
         end

         local t = v.t
         if t.typename == "typedecl" then
            if t.closed then
               return nil, nil, exp.tk
            end

            return t.def, v, exp.tk
         end

         return t, v, exp.tk

      elseif exp.kind == "op" then
         local t, v, rname = self:find_record_to_extend(exp.e1)
         local fname = exp.e2.tk
         local dname = rname .. "." .. fname
         if not t then
            return nil, nil, dname
         end
         if not t.fields then
            return nil, nil, dname
         end
         t = t.fields[fname]

         if t.typename == "typedecl" then
            local def = t.def
            if def.typename == "nominal" then
               assert(t.is_alias)
               t = def.resolved
            else
               t = def
            end
         end

         return t, v, dname
      end
   end

   local function typedecl_to_nominal(w, name, t, resolved)
      local typevals
      local def = t.def
      if def.typename == "generic" then
         typevals = {}
         for _, a in ipairs(def.typeargs) do
            table.insert(typevals, a_type(a, "typevar", {
               typevar = a.typearg,
               constraint = a.constraint,
            }))
         end
      end
      local nom = a_type(w, "nominal", { names = { name } })
      nom.typevals = typevals
      nom.found = t
      nom.resolved = resolved
      return nom
   end

   function TypeChecker:get_self_type(exp)

      if exp.kind == "type_identifier" then
         local t = self:find_var_type(exp.tk)
         if not t then
            return nil
         end

         if t.typename == "typedecl" then
            return typedecl_to_nominal(exp, exp.tk, t)
         else
            return t
         end

      elseif exp.kind == "op" then
         local t = self:get_self_type(exp.e1)
         if not t then
            return nil
         end

         if t.typename == "nominal" then
            local found = t.found
            if found then
               if found.typename == "typedecl" then
                  local def = found.def
                  if def.fields and def.fields[exp.e2.tk] then
                     table.insert(t.names, exp.e2.tk)
                     local ft = def.fields[exp.e2.tk]
                     if ft.typename == "typedecl" then
                        t.found = ft
                     else
                        return nil
                     end
                  end
               end
            end
         elseif t.fields then
            return t.fields and t.fields[exp.e2.tk]
         end
         return t
      end
   end


   local facts_and
   local facts_or
   local facts_not
   local FACT_TRUTHY
   do
      local IsFact_mt = {
         __tostring = function(f)
            return ("(%s is %s)"):format(f.var, show_type(f.typ))
         end,
      }

      setmetatable(IsFact, {
         __call = function(_, fact)
            fact.fact = "is"
            assert(fact.w)
            return setmetatable(fact, IsFact_mt)
         end,
      })

      local EqFact_mt = {
         __tostring = function(f)
            return ("(%s == %s)"):format(f.var, show_type(f.typ))
         end,
      }

      setmetatable(EqFact, {
         __call = function(_, fact)
            fact.fact = "=="
            assert(fact.w)
            return setmetatable(fact, EqFact_mt)
         end,
      })

      local TruthyFact_mt = {
         __tostring = function(_f)
            return "*"
         end,
      }

      setmetatable(TruthyFact, {
         __call = function(_, fact)
            fact.fact = "truthy"
            return setmetatable(fact, TruthyFact_mt)
         end,
      })

      local NotFact_mt = {
         __tostring = function(f)
            return ("(not %s)"):format(tostring(f.f1))
         end,
      }

      setmetatable(NotFact, {
         __call = function(_, fact)
            fact.fact = "not"
            return setmetatable(fact, NotFact_mt)
         end,
      })

      local AndFact_mt = {
         __tostring = function(f)
            return ("(%s and %s)"):format(tostring(f.f1), tostring(f.f2))
         end,
      }

      setmetatable(AndFact, {
         __call = function(_, fact)
            fact.fact = "and"
            return setmetatable(fact, AndFact_mt)
         end,
      })

      local OrFact_mt = {
         __tostring = function(f)
            return ("(%s or %s)"):format(tostring(f.f1), tostring(f.f2))
         end,
      }

      setmetatable(OrFact, {
         __call = function(_, fact)
            fact.fact = "or"
            return setmetatable(fact, OrFact_mt)
         end,
      })

      FACT_TRUTHY = TruthyFact({})

      facts_and = function(w, f1, f2)
         if not f1 and not f2 then
            return
         end
         return AndFact({ f1 = f1, f2 = f2, w = w })
      end

      facts_or = function(w, f1, f2)
         return OrFact({ f1 = f1 or FACT_TRUTHY, f2 = f2 or FACT_TRUTHY, w = w })
      end

      facts_not = function(w, f1)
         if f1 then
            return NotFact({ f1 = f1, w = w })
         else
            return nil
         end
      end


      local function unite_types(w, t1, t2)
         return unite(w, { t2, t1 })
      end


      local function intersect_types(self, w, t1, t2)
         if t2.typename == "union" then
            t1, t2 = t2, t1
         end
         if t1.typename == "union" then
            local out = {}
            for _, t in ipairs(t1.types) do
               if self:is_a(t, t2) then
                  table.insert(out, t)
               end
            end
            if #out > 0 then
               return unite(w, out)
            end
         end
         if self:is_a(t1, t2) then
            return t1
         elseif self:is_a(t2, t1) then
            return t2
         else
            return a_type(w, "nil", {})
         end
      end

      function TypeChecker:resolve_if_union(t)
         local rt = self:to_structural(t)
         if rt.typename == "union" then
            return rt
         end
         return t
      end


      local function subtract_types(self, w, t1, t2)
         local types = {}

         t1 = self:resolve_if_union(t1)


         if not (t1.typename == "union") then
            return t1
         end

         t2 = self:resolve_if_union(t2)
         local t2types = t2.typename == "union" and t2.types or { t2 }

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
            return a_type(w, "nil", {})
         end

         return unite(w, types)
      end

      local eval_not
      local not_facts
      local or_facts
      local and_facts
      local eval_fact

      local function invalid_from(f)
         return IsFact({ fact = "is", var = f.var, typ = a_type(f.w, "invalid", {}), w = f.w })
      end

      not_facts = function(self, fs)
         local ret = {}
         for var, f in pairs(fs) do
            local typ = self:find_var_type(f.var, "check_only")

            if not typ then
               ret[var] = EqFact({ var = var, typ = a_type(f.w, "invalid", {}), w = f.w, no_infer = f.no_infer })
            elseif f.fact == "==" then

               ret[var] = EqFact({ var = var, typ = typ, w = f.w, no_infer = true })
            elseif typ.typename == "typevar" then
               assert(f.fact == "is")

               ret[var] = EqFact({ var = var, typ = typ, w = f.w, no_infer = true })
            elseif not self:is_a(f.typ, typ) then
               assert(f.fact == "is")
               self.errs:add_warning("branch", f.w, f.var .. " (of type %s) can never be a %s", show_type(typ), show_type(f.typ))
               ret[var] = EqFact({ var = var, typ = a_type(f.w, "invalid", {}), w = f.w, no_infer = f.no_infer })
            else
               assert(f.fact == "is")
               ret[var] = IsFact({ var = var, typ = subtract_types(self, f.w, typ, f.typ), w = f.w, no_infer = f.no_infer })
            end
         end
         return ret
      end

      eval_not = function(self, f)
         if not f then
            return {}
         elseif f.fact == "is" then
            return not_facts(self, { [f.var] = f })
         elseif f.fact == "not" then
            return eval_fact(self, f.f1)
         elseif f.fact == "and" and f.f2 and f.f2.fact == "truthy" then
            return eval_not(self, f.f1)
         elseif f.fact == "or" and f.f2 and f.f2.fact == "truthy" then
            return eval_not(self, f.f1)
         elseif f.fact == "and" then
            return or_facts(self, eval_not(self, f.f1), eval_not(self, f.f2))
         elseif f.fact == "or" then
            return and_facts(self, eval_not(self, f.f1), eval_not(self, f.f2))
         else
            return not_facts(self, eval_fact(self, f))
         end
      end

      or_facts = function(_self, fs1, fs2)
         local ret = {}

         for var, f in pairs(fs2) do
            if fs1[var] then
               local united = unite_types(f.w, f.typ, fs1[var].typ)
               if fs1[var].fact == "is" and f.fact == "is" then
                  ret[var] = IsFact({ var = var, typ = united, w = f.w })
               else
                  ret[var] = EqFact({ var = var, typ = united, w = f.w })
               end
            end
         end

         return ret
      end

      and_facts = function(self, fs1, fs2)
         local ret = {}
         local has = {}

         for var, f in pairs(fs1) do
            local rt
            local ctor = EqFact
            if fs2[var] then
               if fs2[var].fact == "is" and f.fact == "is" then
                  ctor = IsFact
               end
               rt = intersect_types(self, f.w, f.typ, fs2[var].typ)
            else
               rt = f.typ
            end
            local ff = ctor({ var = var, typ = rt, w = f.w, no_infer = f.no_infer })
            ret[var] = ff
            has[ff.fact] = true
         end

         for var, f in pairs(fs2) do
            if not fs1[var] then
               ret[var] = EqFact({ var = var, typ = f.typ, w = f.w, no_infer = f.no_infer })
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

      eval_fact = function(self, f)
         if not f then
            return {}
         elseif f.fact == "is" then
            local typ = self:find_var_type(f.var, "check_only")
            if not typ then
               return { [f.var] = invalid_from(f) }
            end
            if not (typ.typename == "typevar") then
               if self:is_a(typ, f.typ) then


                  return { [f.var] = f }
               elseif not self:is_a(f.typ, typ) then
                  self.errs:add(f.w, f.var .. " (of type %s) can never be a %s", typ, f.typ)
                  return { [f.var] = invalid_from(f) }
               end
            end
            return { [f.var] = f }
         elseif f.fact == "==" then
            return { [f.var] = f }
         elseif f.fact == "not" then
            return eval_not(self, f.f1)
         elseif f.fact == "truthy" then
            return {}
         elseif f.fact == "and" and f.f2 and f.f2.fact == "truthy" then
            return eval_fact(self, f.f1)
         elseif f.fact == "or" and f.f2 and f.f2.fact == "truthy" then
            return eval_not(self, f.f1)
         elseif f.fact == "and" then
            return and_facts(self, eval_fact(self, f.f1), eval_fact(self, f.f2))
         elseif f.fact == "or" then
            return or_facts(self, eval_fact(self, f.f1), eval_fact(self, f.f2))
         end
      end

      function TypeChecker:apply_facts(w, known)
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

      if TL_DEBUG_FACTS then
         local eval_indent = -1
         local real_eval_fact = eval_fact
         eval_fact = function(self, known)
            eval_indent = eval_indent + 1
            io.stderr:write(("   "):rep(eval_indent))
            io.stderr:write("eval fact: ", tostring(known), "\n")
            local facts = real_eval_fact(self, known)
            if facts then
               for _, k in ipairs(sorted_keys(facts)) do
                  local f = facts[k]
                  io.stderr:write(("   "):rep(eval_indent), "=> ", tostring(f), "\n")
               end
            else
               io.stderr:write(("   "):rep(eval_indent), "=> .\n")
            end
            eval_indent = eval_indent - 1
            return facts
         end
      end
   end

   function TypeChecker:dismiss_unresolved(name)
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

   local function special_pcall_xpcall(self, node, a, b, argdelta)
      local isx = a.special_function_handler == "xpcall"
      local base_nargs = isx and 2 or 1
      local bool = a_type(node, "boolean", {})
      if #node.e2 < base_nargs then
         self.errs:add(node, "wrong number of arguments (given " .. #node.e2 .. ", expects at least " .. base_nargs .. ")")
         return a_type(node, "tuple", { tuple = { bool } })
      end

      local ftype = table.remove(b.tuple, 1)




      ftype = ensure_not_method(ftype)

      local fe2 = node_at(node.e2, {})
      if isx then
         base_nargs = 2
         local arg2 = node.e2[2]
         local msgh = table.remove(b.tuple, 1)
         local msgh_type = a_function(arg2, {
            min_arity = self.feat_arity and 1 or 0,
            args = a_type(arg2, "tuple", { tuple = { a_type(arg2, "any", {}) } }),
            rets = a_type(arg2, "tuple", { tuple = {} }),
         })
         self:assert_is_a(arg2, msgh, msgh_type, "in message handler")
      end
      for i = base_nargs + 1, #node.e2 do
         table.insert(fe2, node.e2[i])
      end
      local fnode = node_at(node, {
         kind = "op",
         op = { op = "@funcall" },
         e1 = node.e2[1],
         e2 = fe2,
      })
      local rets = self:type_check_funcall(fnode, ftype, b, argdelta + base_nargs)
      if rets.typename == "invalid" then
         return rets
      end
      table.insert(rets.tuple, 1, bool)
      return rets
   end

   local function pattern_findclassend(pat, i, strict)
      local c = pat:sub(i, i)
      if c == "%" then
         local peek = pat:sub(i + 1, i + 1)
         if peek == "f" then

            if pat:sub(i + 2, i + 2) ~= "[" then
               return nil, nil, "malformed pattern: missing '[' after %f"
            end
            local e, _, err = pattern_findclassend(pat, i + 2, strict)
            if not e then
               return nil, nil, err
            else
               return e, false
            end
         elseif peek == "b" then
            if pat:sub(i + 3, i + 3) == "" then
               return nil, nil, "malformed pattern: need balanced characters"
            end
            return i + 3, false
         elseif peek == "" then
            return nil, nil, "malformed pattern: expected class"
         elseif peek:match("[1-9]") then
            return i + 1, false
         elseif strict and not peek:match("[][^$()%%.*+%-?AaCcDdGgLlPpSsUuWwXxZz]") then
            return nil, nil, "malformed pattern: invalid class '" .. peek .. "'"
         else
            return i + 1, true
         end
      elseif c == "[" then
         if pat:sub(i + 1, i + 1) == "^" then
            i = i + 2
         else
            i = i + 1
         end

         local isfirst = true
         repeat
            local c_ = pat:sub(i, i)
            if c_ == "" then
               return nil, nil, "malformed pattern: missing ']'"
            elseif c_ == "%" then
               if strict and not pat:sub(i + 1, i + 1):match("[][^$()%%.*+%-?AaCcDdGgLlPpSsUuWwXxZz]") then
                  return nil, nil, "malformed pattern: invalid escape"
               end
               i = i + 2
            elseif c_ == "-" and strict and not isfirst then
               return nil, nil, "malformed pattern: unexpected '-'"
            else
               local c2 = pat:sub(i + 1, i + 1)
               local c3 = pat:sub(i + 2, i + 2)
               if c2 == "-" then
                  if strict and c3 == "]" then
                     return nil, nil, "malformed pattern: unexpected ']'"
                  elseif strict and c3 == "-" then
                     return nil, nil, "malformed pattern: unexpected '-'"
                  elseif strict and c3 == "%" then
                     return nil, nil, "malformed pattern: unexpected '%'"
                  end

                  i = i + 2
               else
                  i = i + 1
               end
            end
            isfirst = false
         until pat:sub(i, i) == "]"

         return i, true
      else
         return i, true
      end
   end

   local pattern_isop = {
      ["?"] = true,
      ["+"] = true,
      ["-"] = true,
      ["*"] = true,
   }

   local function parse_pattern_string(node, pat, inclempty)





















      local strict = false

      local results = {}

      local i = pat:sub(1, 1) == "^" and 2 or 1
      local unclosed = 0

      while i <= #pat do
         local c = pat:sub(i, i)

         if i == #pat and c == "$" then
            break
         end

         local classend, canhavemul, err = pattern_findclassend(pat, i, strict)
         if not classend then
            return nil, err
         end

         local peek = pat:sub(classend + 1, classend + 1)

         if c == "(" and peek == ")" then

            table.insert(results, a_type(node, "integer", {}))
            i = i + 2
         elseif c == "(" then
            table.insert(results, a_type(node, "string", {}))
            unclosed = unclosed + 1
            i = i + 1
         elseif c == ")" then
            unclosed = unclosed - 1
            if unclosed < 0 then
               return nil, "malformed pattern: unexpected ')'"
            end
            i = i + 1
         elseif strict and c:match("[]^$()*+%-?]") then
            return nil, "malformed pattern: character was unexpected: '" .. c .. "'"
         elseif pattern_isop[peek] and canhavemul then
            i = classend + 2
         else

            i = classend + 1
         end
      end

      if inclempty and not results[1] then
         results[1] = a_type(node, "string", {})
      end
      if unclosed ~= 0 then
         return nil, "malformed pattern: " .. unclosed .. " capture" .. (unclosed == 1 and "" or "s") .. " not closed"
      end
      return results
   end

   local function parse_format_string(node, pat)
      local pos = 1
      local results = {}
      while pos <= #pat do

         local endc = pat:match("%%[-+#0-9. ]*()", pos)
         if not endc then return results end
         local c = pat:sub(endc, endc)
         if c == "" then
            return nil, "missing pattern specifier at end"
         end
         if c:match("[AaEefGg]") then
            table.insert(results, a_type(node, "number", {}))
         elseif c:match("[cdiouXx]") then
            table.insert(results, a_type(node, "integer", {}))
         elseif c == "q" then
            table.insert(results,
            a_type(node, "union", { types = {
               a_type(node, "string", {}),
               a_type(node, "number", {}),
               a_type(node, "integer", {}),
               a_type(node, "boolean", {}),
               a_type(node, "nil", {}),
            } }))

         elseif c == "p" or c == "s" then
            table.insert(results, a_type(node, "any", {}))
         elseif c == "%" then

         else
            return nil, "invalid pattern specifier: '" .. c .. "'"
         end
         pos = endc + 1
      end
      return results
   end

   local function pack_string_skipnum(pos, pat)

      return pat:match("[0-9]*()", pos)
   end

   local function parse_pack_string(node, pat)
      local pos = 1
      local results = {}
      local skip_next = false
      while pos <= #pat do
         local c = pat:sub(pos, pos)
         local to_add
         local goto_next
         if c:match("[<> =x]") then

            if skip_next then
               return nil, "expected argument for 'X'"
            end
            pos = pos + 1
            goto_next = true
         elseif c == "X" then
            if skip_next then
               return nil, "expected argument for 'X'"
            end
            skip_next = true
            pos = pos + 1
            goto_next = true
         elseif c == "!" then
            if skip_next then
               return nil, "expected argument for 'X'"
            end
            pos = pack_string_skipnum(pos + 1, pat)
            goto_next = true
         elseif c:match("[Ii]") then
            pos = pack_string_skipnum(pos + 1, pat)
            to_add = a_type(node, "integer", {})
         elseif c:match("[bBhHlLjJT]") then
            pos = pos + 1
            to_add = a_type(node, "integer", {})
         elseif c:match("[fdn]") then
            pos = pos + 1
            to_add = a_type(node, "number", {})
         elseif c == "z" or c == "s" or c == "c" then
            if c == "z" then
               pos = pos + 1
            else
               pos = pack_string_skipnum(pos + 1, pat)
            end

            to_add = a_type(node, "string", {})
         else
            return nil, "invalid format option: '" .. c .. "'"
         end
         if not goto_next then
            if skip_next then
               skip_next = false
            else
               table.insert(results, to_add)
            end
         end
      end
      if skip_next then
         return nil, "expected argument for 'X'"
      end
      return results
   end

   local special_functions = {
      ["pairs"] = function(self, node, a, b, argdelta)
         if not b.tuple[1] then
            return self.errs:invalid_at(node, "pairs requires an argument")
         end
         local t = self:to_structural(b.tuple[1])
         if t.elements then
            self.errs:add_warning("hint", node, "hint: applying pairs on an array: did you intend to apply ipairs?")
         end

         if not (t.typename == "map") then
            if not (self.feat_lax and is_unknown(t)) then
               if t.fields then
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

      ["ipairs"] = function(self, node, a, b, argdelta)
         if not b.tuple[1] then
            return self.errs:invalid_at(node, "ipairs requires an argument")
         end
         local orig_t = b.tuple[1]
         local t = self:to_structural(orig_t)

         if t.typename == "tupletable" then
            local arr_type = self:arraytype_from_tuple(node.e2, t)
            if not arr_type then
               return self.errs:invalid_at(node.e2, "attempting ipairs on tuple that's not a valid array: %s", orig_t)
            end
         elseif not t.elements then
            if not (self.feat_lax and (is_unknown(t) or t.typename == "emptytable")) then
               return self.errs:invalid_at(node.e2, "attempting ipairs on something that's not an array: %s", orig_t)
            end
         end

         return (self:type_check_function_call(node, a, b, argdelta))
      end,

      ["rawget"] = function(self, node, _a, b, _argdelta)

         if #b.tuple == 2 then
            return a_type(node, "tuple", { tuple = { self:type_check_index(node.e2[1], node.e2[2], b.tuple[1], b.tuple[2]) } })
         else
            return self.errs:invalid_at(node, "rawget expects two arguments")
         end
      end,

      ["require"] = function(self, node, _a, b, _argdelta)
         if #b.tuple ~= 1 then
            return self.errs:invalid_at(node, "require expects one literal argument")
         end
         if node.e2[1].kind ~= "string" then
            return a_type(node, "tuple", { tuple = { a_type(node, "any", {}) } })
         end

         local module_name = assert(node.e2[1].conststr)
         local tc_opts = {
            feat_lax = self.feat_lax and "on" or "off",
            feat_arity = self.feat_arity and "on" or "off",
         }
         local t, module_filename = require_module(node, module_name, tc_opts, self.env)

         if t.typename == "invalid" then
            if not module_filename then
               return self.errs:invalid_at(node, "module not found: '" .. module_name .. "'")
            end

            if self.feat_lax then
               return a_type(node, "tuple", { tuple = { a_type(node, "unknown", {}) } })
            end
            return self.errs:invalid_at(node, "no type information for required module: '" .. module_name .. "'")
         end

         self.dependencies[module_name] = module_filename
         return a_type(node, "tuple", { tuple = { t } })
      end,

      ["pcall"] = special_pcall_xpcall,
      ["xpcall"] = special_pcall_xpcall,
      ["assert"] = function(self, node, a, b, argdelta)
         node.known = FACT_TRUTHY
         local r = self:type_check_function_call(node, a, b, argdelta)
         self:apply_facts(node, node.e2[1].known)
         return r
      end,
      ["string.pack"] = function(self, node, a, b, argdelta)
         if #b.tuple < 1 then
            return self.errs:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects at least 1)")
         end

         local packstr = b.tuple[1]

         if packstr.typename == "string" and packstr.literal and a.typename == "function" then
            local st = packstr.literal
            local items, e = parse_pack_string(node, st)

            if e then
               if items then

                  self.errs:add_warning("hint", packstr, e)
               else
                  return self.errs:invalid_at(packstr, e)
               end
            end

            table.insert(items, 1, a_type(node, "string", {}))

            if #items ~= #b.tuple then
               return self.errs:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects " .. #items .. ")")
            end

            return (self:type_check_function_call(node, a, b, argdelta, a_type(node, "tuple", { tuple = items }), nil))
         else
            return (self:type_check_function_call(node, a, b, argdelta))
         end
      end,

      ["string.unpack"] = function(self, node, a, b, argdelta)
         if #b.tuple < 2 or #b.tuple > 3 then
            return self.errs:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects 2 or 3)")
         end

         local packstr = b.tuple[1]

         local rets

         if packstr.typename == "string" and packstr.literal then
            local st = packstr.literal
            local items, e = parse_pack_string(node, st)

            if e then
               if items then

                  self.errs:add_warning("hint", packstr, e)
               else
                  return self.errs:invalid_at(packstr, e)
               end
            end

            table.insert(items, a_type(node, "integer", {}))


            rets = a_type(node, "tuple", { tuple = items })
         end

         return (self:type_check_function_call(node, a, b, argdelta, nil, rets))
      end,

      ["string.format"] = function(self, node, a, b, argdelta)
         if #b.tuple < 1 then
            return self.errs:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects at least 1)")
         end

         local fstr = b.tuple[1]

         if fstr.typename == "string" and fstr.literal and a.typename == "function" then
            local st = fstr.literal
            local items, e = parse_format_string(node, st)

            if e then
               if items then

                  self.errs:add_warning("hint", fstr, e)
               else
                  return self.errs:invalid_at(fstr, e)
               end
            end

            table.insert(items, 1, a_type(node, "string", {}))

            if #items ~= #b.tuple then
               return self.errs:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects " .. #items .. ")")
            end


            return (self:type_check_function_call(node, a, b, argdelta, a_type(node, "tuple", { tuple = items }), nil))
         else
            return (self:type_check_function_call(node, a, b, argdelta))
         end
      end,

      ["string.match"] = function(self, node, a, b, argdelta)
         if #b.tuple < 2 or #b.tuple > 3 then
            return self.errs:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects 2 or 3)")
         end

         local rets
         local pat = b.tuple[2]

         if pat.typename == "string" and pat.literal then
            local st = pat.literal
            local items, e = parse_pattern_string(node, st, true)

            if e then
               if items then

                  self.errs:add_warning("hint", pat, e)
               else
                  return self.errs:invalid_at(pat, e)
               end
            end


            rets = a_type(node, "tuple", { tuple = items })
         end
         return (self:type_check_function_call(node, a, b, argdelta, nil, rets))
      end,

      ["string.find"] = function(self, node, a, b, argdelta)
         if #b.tuple < 2 or #b.tuple > 4 then
            return self.errs:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects at least 2 and at most 4)")
         end

         local plainarg = node.e2[4 + (argdelta or 0)]
         local pat = b.tuple[2]

         local rets

         if pat.typename == "string" and pat.literal and
            ((not plainarg) or (plainarg.kind == "boolean" and plainarg.tk == "false")) then

            local st = pat.literal

            local items, e = parse_pattern_string(node, st, false)

            if e then
               if items then

                  self.errs:add_warning("hint", pat, e)
               else
                  return self.errs:invalid_at(pat, e)
               end
            end

            table.insert(items, 1, a_type(pat, "integer", {}))
            table.insert(items, 1, a_type(pat, "integer", {}))


            rets = a_type(node, "tuple", { tuple = items })
         end

         return (self:type_check_function_call(node, a, b, argdelta, nil, rets))
      end,

      ["string.gmatch"] = function(self, node, a, b, argdelta)
         if #b.tuple < 2 or #b.tuple > 3 then
            return self.errs:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects 2 or 3)")
         end

         local rets
         local pat = b.tuple[2]

         if pat.typename == "string" and pat.literal then
            local st = pat.literal
            local items, e = parse_pattern_string(node, st, true)

            if e then
               if items then

                  self.errs:add_warning("hint", pat, e)
               else
                  return self.errs:invalid_at(pat, e)
               end
            end


            rets = a_type(node, "tuple", { tuple = {
               a_function(node, {
                  min_arity = 0,
                  args = a_type(node, "tuple", { tuple = {} }),
                  rets = a_type(node, "tuple", { tuple = items }),
               }),
            } })
         end

         return (self:type_check_function_call(node, a, b, argdelta, nil, rets))
      end,

      ["string.gsub"] = function(self, node, a, b, argdelta)



         if #b.tuple < 3 or #b.tuple > 4 then
            return self.errs:invalid_at(node, "wrong number of arguments (given " .. #b.tuple .. ", expects 3 or 4)")
         end
         local pat = b.tuple[2]
         local orig_t = b.tuple[3]
         local trepl = self:to_structural(orig_t)

         local has_fourth = b.tuple[4]

         local args

         if pat.typename == "string" and pat.literal then
            local st = pat.literal
            local items, e = parse_pattern_string(node, st, true)

            if e then
               if items then

                  self.errs:add_warning("hint", pat, e)
               else
                  return self.errs:invalid_at(pat, e)
               end
            end

            local i1 = items[1]






            local replarg_type

            local expected_pat_return = a_type(node, "union", { types = {
               a_type(node, "string", {}),
               a_type(node, "integer", {}),
               a_type(node, "number", {}),
            } })
            if self:is_a(trepl, expected_pat_return) then

               replarg_type = expected_pat_return
            elseif trepl.typename == "map" then
               replarg_type = a_type(node, "map", { keys = i1, values = expected_pat_return })
            elseif trepl.fields then
               if not (i1.typename == "string") then
                  self.errs:invalid_at(trepl, "expected a table with integers as keys")
               end
               replarg_type = a_type(node, "map", { keys = i1, values = expected_pat_return })
            elseif trepl.elements then
               if not (i1.typename == "integer") then
                  self.errs:invalid_at(trepl, "expected a table with strings as keys")
               end
               replarg_type = a_type(node, "array", { elements = expected_pat_return })
            elseif trepl.typename == "function" then
               local validftype = a_function(node, {
                  min_arity = self.feat_arity and #items or 0,
                  args = a_type(node, "tuple", { tuple = items }),
                  rets = a_vararg(node, { expected_pat_return }),
               })
               replarg_type = validftype
            end


            if replarg_type then
               args = a_type(node, "tuple", { tuple = {
                  a_type(node, "string", {}),
                  a_type(node, "string", {}),
                  replarg_type,
                  has_fourth and a_type(node, "integer", {}) or nil,
               } })
            end
         end

         return (self:type_check_function_call(node, a, b, argdelta, args, nil))
      end,
   }

   function TypeChecker:type_check_funcall(node, a, b, argdelta)
      if node.e1.op and node.e1.op.op == ":" then
         table.insert(b.tuple, 1, node.e1.receiver)
         argdelta = -1
      else
         argdelta = argdelta or 0
      end

      local sa = resolve_for_special_function(a)
      if sa then
         local special_tyck = special_functions[sa.special_function_handler]
         if special_tyck then
            return special_tyck(self, node, a, b, argdelta)
         end
      end

      return (self:type_check_function_call(node, a, b, argdelta))
   end


   local function is_localizing_a_variable(node, i)
      return node.exps and
      node.exps[i] and
      node.exps[i].kind == "variable" and
      node.exps[i].tk == node.vars[i].tk
   end

   function TypeChecker:missing_initializer(node, i, name)
      if self.feat_lax then
         return a_type(node, "unknown", {})
      else
         if node.exps then
            return self.errs:invalid_at(node.vars[i], "assignment in declaration did not produce an initial value for variable '" .. name .. "'")
         else
            return self.errs:invalid_at(node.vars[i], "variable '" .. name .. "' has no type or initial value")
         end
      end
   end

   local function set_expected_types_to_decltuple(self, node, children)
      local decltuple = node.kind == "assignment" and children[1] or node.decltuple
      assert(decltuple.typename == "tuple")
      local decls = decltuple.tuple
      if decls and node.exps then
         local ndecl = #decls
         local nexps = #node.exps
         for i = 1, nexps do
            local typ
            typ = decls[i]
            if typ then
               if i == nexps and ndecl > nexps and node_is_funcall(node.exps[i]) then
                  typ = a_type(node, "tuple", { tuple = {} })
                  for a = i, ndecl do
                     table.insert(typ.tuple, decls[a])
                  end
               end
               node.exps[i].expected = typ
               node.exps[i].expected_context = { kind = node.kind, name = node.vars[i].tk }
            end
         end
      end

      if node.decltuple then
         local ndecltuple = #node.decltuple.tuple
         local nvars = #node.vars
         if ndecltuple > nvars then
            self.errs:add(node.decltuple.tuple[nvars + 1], "number of types exceeds number of variables")
         end
      end
   end

   local function is_positive_int(n)
      return n and n >= 1 and math.floor(n) == n
   end

   local function infer_table_literal(self, node, children)
      local is_record = false
      local is_array = false
      local is_map = false

      local is_tuple = false
      local is_not_tuple = false

      local last_array_idx = 1
      local largest_array_idx = -1

      local seen_keys = {}


      local types

      local fields
      local field_order

      local elements

      local keys, values

      for i, child in ipairs(children) do
         local ck = child.kname
         local cktype = child.ktype
         local key = ck
         local n
         if not key then
            n = node[i].key.constnum
            key = n
            if not key and node[i].key.kind == "boolean" then
               key = (node[i].key.tk == "true")
            end
         end

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
         elseif is_numeric_type(cktype) then
            is_array = true
            if not is_not_tuple then
               is_tuple = true
            end
            if not types then
               types = {}
            end

            if node[i].key_parsed == "implicit" then
               local cv = child.vtype
               if i == #children and cv.typename == "tuple" then

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
            else
               if not is_positive_int(n) then
                  elements = self:expand_type(node, elements, uvtype)
                  is_not_tuple = true
               elseif n then
                  types[n] = uvtype
                  if n > largest_array_idx then
                     largest_array_idx = n
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

      local t

      if is_array and is_map then
         self.errs:add(node, "cannot determine type of table literal")
         t = a_type(node, "map", { keys =
self:expand_type(node, keys, a_type(node, "integer", {})), values =

self:expand_type(node, values, elements) })
      elseif is_record and is_array then
         t = a_type(node, "record", {
            fields = fields,
            field_order = field_order,
            elements = elements,
            interface_list = {
               a_type(node, "array", { elements = elements }),
            },
         })

      elseif is_record and is_map then
         if keys.typename == "string" then
            for _, fname in ipairs(field_order) do
               values = self:expand_type(node, values, fields[fname])
            end
            t = a_type(node, "map", { keys = keys, values = values })
         else
            self.errs:add(node, "cannot determine type of table literal")
         end
      elseif is_array then
         local pure_array = true
         if not is_not_tuple then
            local last_t
            for _, current_t in pairs(types) do
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
            t = a_type(node, "array", { elements = elements })
            t.consttypes = types
            t.inferred_len = largest_array_idx - 1
         else
            t = a_type(node, "tupletable", { inferred_at = node })
            t.types = types
         end
      elseif is_record then
         t = a_type(node, "record", {
            fields = fields,
            field_order = field_order,
         })
      elseif is_map then
         t = a_type(node, "map", { keys = keys, values = values })
      elseif is_tuple then
         t = a_type(node, "tupletable", { inferred_at = node })
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

   function TypeChecker:infer_negation_of_if_blocks(w, ifnode, n)
      local f = facts_not(w, ifnode.if_blocks[1].exp.known)
      for e = 2, n do
         local b = ifnode.if_blocks[e]
         if b.exp then
            f = facts_and(w, f, facts_not(w, b.exp.known))
         end
      end
      self:apply_facts(w, f)
   end

   function TypeChecker:determine_declaration_type(var, node, infertypes, i)
      local ok = true
      local name = var.tk
      local infertype = infertypes and infertypes.tuple[i]
      if self.feat_lax and infertype and infertype.typename == "nil" then
         infertype = nil
      end

      local decltype = node.decltuple and node.decltuple.tuple[i]
      if decltype then
         local rdecltype = self:to_structural(decltype)
         if rdecltype.typename == "invalid" then
            decltype = rdecltype
         end

         if infertype then
            local w = node.exps and node.exps[i] or node.vars[i]
            ok = self:assert_is_a(w, infertype, decltype, context_name[node.kind], name)
         end
      else
         if infertype then
            if infertype.typename == "unresolvable_typearg" then
               ok = false
               infertype = self.errs:invalid_at(node.vars[i], "cannot infer declaration type; an explicit type annotation is necessary")
            else



               infertype = ensure_not_method(infertype)
            end
         end
      end

      if var.attribute == "total" then
         local rd = decltype and self:to_structural(decltype)
         if rd and (not (rd.typename == "map")) and (not (rd.typename == "record")) then
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
                  if ri.typename == "map" then
                     self.errs:add(var, "map variable declared <total> does not declare values for all possible keys" .. missing)
                     ok = false
                  elseif ri.typename == "record" then
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
      elseif t.typename == "emptytable" then
         t.declared_at = node
         t.assigned_to = name
      elseif t.elements then
         t.inferred_len = nil
      elseif t.typename == "nominal" then
         self:resolve_nominal(t)
         local rt = t.resolved
         if rt and rt.typename == "typedecl" then
            t.resolved = rt.def
         end
      end

      return ok, t, infertype ~= nil
   end

   local function aliasing_variable(self, def)
      if def.typename == "nominal" then
         return (self:find_var(def.names[1], "use_type"))
      end

      if def.typename == "generic" then
         local nom = def.t
         if nom.typename == "nominal" then
            return (self:find_var(nom.names[1], "use_type"))
         end
      end
   end

   local function recurse_type_declaration(self, n)
      if n.kind == "op" then

         if n.op.op == "." then
            local ty = recurse_type_declaration(self, n.e1)
            if not (ty.typename == "typedecl") then
               return ty
            end
            local def = ty.def
            if not (def.typename == "record") then
               return self.errs:invalid_at(n.e1, "type is not a record")
            end
            local t = def.fields[n.e2.tk]
            if t and t.typename == "typedecl" then
               return t
            end
            return self.errs:invalid_at(n.e2, "nested type '" .. n.e2.tk .. "' not found in record")

         elseif n.op.op == "@funcall" and
            n.e1.kind == "variable" and
            n.e1.tk == "require" then

            local ty = resolve_tuple(
            special_functions["require"](
            self, n, self:find_var_type("require"),
            a_type(n.e2, "tuple", { tuple = { a_type(n.e2[1], "string", {}) } })))


            if not (ty.typename == "typedecl") then
               return self.errs:invalid_at(n.e1, "'require' did not return a type, got %s", ty)
            end
            if ty.is_alias then
               return self:resolve_typealias(ty)
            end
            return ty
         end
      end

      local newtype = n.newtype
      if newtype.is_alias then
         return self:resolve_typealias(newtype), aliasing_variable(self, newtype.def)
      end
      return newtype, nil
   end

   function TypeChecker:get_typedecl(value)
      local resolved, aliasing = recurse_type_declaration(self, value)
      local nt = value.newtype
      if nt and nt.is_alias and resolved.typename == "typedecl" then
         local ntdef = nt.def
         local rdef = resolved.def
         if ntdef.typename == "generic" and rdef.typename == "generic" then



            ntdef.typeargs = rdef.typeargs
         end
      end
      return resolved, aliasing
   end

   local function total_check_key(key, seen_keys, is_total, missing)
      if not seen_keys[key] then
         missing = missing or {}
         table.insert(missing, tostring(key))
         return false, missing
      end
      return is_total, missing
   end

   local function total_record_check(t, seen_keys)
      local is_total = true
      local missing
      for _, key in ipairs(t.field_order) do
         local ftype = t.fields[key]
         if not (ftype.typename == "typedecl" or (ftype.typename == "function" and ftype.is_record_function)) then
            is_total, missing = total_check_key(key, seen_keys, is_total, missing)
         end
      end
      return is_total, missing
   end

   local function total_map_check(keys, seen_keys)
      local is_total = true
      local missing
      if keys.typename == "enum" then
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





   function TypeChecker:check_assignment(varnode, vartype, valtype)
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
      if var.typename == "typedecl" then
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

   local function discard_tuple(node, t, b)
      if b.typename == "tuple" then
         node.discarded_tuple = true
      end
      return resolve_tuple(t)
   end

   local visit_node = {}

   visit_node.cbs = {
      ["statements"] = {
         before = function(self, node)
            self:begin_scope(node)
         end,
         after = function(self, node, _children)

            if #self.st == 2 then
               self.errs:fail_unresolved_labels(self.st[2])
               self.errs:fail_unresolved_nominals(self.st[2], self.st[1])
            end

            if not node.is_repeat then
               self:end_scope(node)
            end

            return NONE
         end,
      },
      ["local_type"] = {
         before = function(self, node)
            local name = node.var.tk
            local resolved, aliasing = self:get_typedecl(node.value)
            local var = self:add_var(node.var, name, resolved, node.var.attribute)
            if aliasing then
               var.aliasing = aliasing
            end
         end,
         after = function(self, node, _children)
            self:dismiss_unresolved(node.var.tk)
            return NONE
         end,
      },
      ["global_type"] = {
         before = function(self, node)
            local global_scope = self.st[1]
            local name = node.var.tk
            if node.value then
               local resolved, aliasing = self:get_typedecl(node.value)
               local added = self:add_global(node.var, name, resolved)
               if resolved.typename == "invalid" then
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
         after = function(self, node, _children)
            self:dismiss_unresolved(node.var.tk)
            return NONE
         end,
      },
      ["local_declaration"] = {
         before = function(self, node)
            if self.collector then
               for _, var in ipairs(node.vars) do
                  self.collector.reserve_symbol_list_slot(var)
               end
            end
         end,
         before_exp = set_expected_types_to_decltuple,
         after = function(self, node, children)
            local valtuple = children[3]

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
               self:add_var(var, var.tk, t, var.attribute, is_localizing_a_variable(node, i) and "localizing")
               if var.elide_type then
                  self.errs:add_warning("hint", node, "hint: consider using 'local type' instead")
               end

               local infertype = infertypes.tuple[i]
               if ok and infertype then
                  local w = node.exps[i] or node.exps

                  local rt = self:to_structural(t)
                  if (not (rt.typename == "enum")) and
                     ((not (t.typename == "nominal")) or (rt.typename == "union")) and
                     not self:same_type(t, infertype) then

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
         after = function(self, node, children)
            local valtuple = children[3]

            local infertypes = get_assignment_values(node, valtuple, #node.vars)
            for i, var in ipairs(node.vars) do
               local _, t, is_inferred = self:determine_declaration_type(var, node, infertypes, i)

               if var.attribute == "close" then
                  self.errs:add(var, "globals may not be <close>")
               end

               self:add_global(var, var.tk, t, is_inferred)
               if var.elide_type then
                  self.errs:add_warning("hint", node, "hint: consider using 'global type' instead")
               end

               self:dismiss_unresolved(var.tk)
            end
            return NONE
         end,
      },
      ["assignment"] = {
         before_exp = set_expected_types_to_decltuple,
         after = function(self, node, children)
            local vartuple = children[1]
            assert(vartuple.typename == "tuple")
            local vartypes = vartuple.tuple
            local valtuple = children[3]
            assert(valtuple.typename == "tuple")
            local valtypes = get_assignment_values(node, valtuple, #vartypes)
            for i, vartype in ipairs(vartypes) do
               local varnode = node.vars[i]
               local varname = varnode.tk
               local valtype = valtypes.tuple[i]
               local rvar, rval, err = self:check_assignment(varnode, vartype, valtype)
               if err == "missing" then
                  if #node.exps == 1 and node_is_funcall(node.exps[1]) then
                     local msg = #valtuple.tuple == 1 and
                     "only 1 value is returned by the function" or
                     ("only " .. #valtuple.tuple .. " values are returned by the function")
                     self.errs:add_warning("hint", varnode, msg)
                  end
               end

               if rval and rvar then

                  if rval.typename == "function" then
                     self:widen_all_unions()
                  end

                  if varname and (rvar.typename == "union" or rvar.typename == "interface") then

                     self:add_var(varnode, varname, valtype, nil, "narrow")
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
         after = function(self, node, _children)
            if node.if_widens then


               self:widen_all(node.if_widens, {})
            end

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
         before = function(self, node)
            self:begin_scope(node)
            if node.if_block_n > 1 then
               self:infer_negation_of_if_blocks(node, node.if_parent, node.if_block_n - 1)
            end
            if node.exp then
               node.exp.expected = a_type(node, "boolean_context", {})
            end
         end,
         before_statements = function(self, node)
            if node.exp then
               self:apply_facts(node.exp, node.exp.known)
            end
         end,
         after = function(self, node, _children)
            node.if_parent.if_widens = self:collect_if_widens(node.if_parent.if_widens)

            self:end_scope(node)

            if #node.body > 0 and node.body[#node.body].block_returns then
               node.block_returns = true
            end

            return NONE
         end,
      },
      ["while"] = {
         before = function(self, node)

            self:widen_all_unions(node)
            node.exp.expected = a_type(node, "boolean_context", {})
         end,
         before_statements = function(self, node)
            self:begin_scope(node)
            self:apply_facts(node.exp, node.exp.known)
         end,
         after = end_scope_and_none_type,
      },
      ["label"] = {
         before = function(self, node)

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


            local scope = self.st[#self.st]
            if scope.pending_labels and scope.pending_labels[label_id] then
               node.used_label = true
               scope.pending_labels[label_id] = nil

            end

         end,
         after = function()
            return NONE
         end,
      },
      ["goto"] = {
         after = function(self, node, _children)
            local label_id = node.label
            local found_label
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
         before = function(self, node)

            self:widen_all_unions(node)
            node.exp.expected = a_type(node, "boolean_context", {})
         end,

         after = end_scope_and_none_type,
      },
      ["forin"] = {
         before = function(self, node)
            self:begin_scope(node)
         end,
         before_statements = function(self, node, children)
            local exptuple = children[2]
            assert(exptuple.typename == "tuple")
            local exptypes = exptuple.tuple

            local exp1 = node.exps[1]
            if #exptypes < 1 then
               self.errs:invalid_at(exp1, "expression in 'for' statement does not return any values")
               return
            end

            self:widen_all_unions(node)

            local args = a_type(node.exps, "tuple", { tuple = {
               node.exps[2] and exptypes[2],
               node.exps[3] and exptypes[3],
            } })
            local exp1type = self:resolve_for_call(exptypes[1], args, false)

            if exp1type.typename == "poly" then
               local _r, f
               _r, f = self:type_check_function_call(exp1, exp1type, args, 0, nil, nil, exp1, { node.exps[2], node.exps[3] })
               if f then
                  exp1type = f
               else
                  self.errs:add(exp1, "cannot resolve polymorphic function given arguments")
               end
            end

            if exp1type.typename == "function" then

               local last
               local rets = exp1type.rets
               for i, v in ipairs(node.vars) do
                  local r = rets.tuple[i]
                  if not r then
                     if rets.is_va then
                        r = last
                     else
                        r = self.feat_lax and a_type(v, "unknown", {}) or a_type(v, "invalid", {})
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
         before_statements = function(self, node, children)
            self:widen_all_unions(node)
            self:begin_scope(node)
            local from_t = self:to_structural(resolve_tuple(children[2]))
            local to_t = self:to_structural(resolve_tuple(children[3]))
            local step_t = children[4] and self:to_structural(children[4])
            local typename = (from_t.typename == "integer" and
            to_t.typename == "integer" and
            (not step_t or step_t.typename == "integer")) and
            "integer" or
            "number"
            self:add_var(node.var, node.var.tk, a_type(node.var, typename, {}))
         end,
         after = end_scope_and_none_type,
      },
      ["return"] = {
         before = function(self, node)
            local rets = self:find_var_type("@return")
            if rets and rets.typename == "tuple" then
               for i, exp in ipairs(node.exps) do
                  exp.expected = rets.tuple[i]
               end
            end
         end,
         after = function(self, node, children)
            local got = children[1]
            assert(got.typename == "tuple")
            local got_t = got.tuple
            local n_got = #got_t

            node.block_returns = true
            local expected = self:find_var_type("@return")
            if not expected then

               local module_type = resolve_tuple(got)
               if module_type.typename == "nominal" then
                  self:resolve_nominal(module_type)
                  self.module_type = module_type.resolved
               else
                  self.module_type = drop_constant_value(module_type)
               end

               expected = self:infer_at(node, got)
               self.st[2].vars["@return"] = { t = expected }
            end
            local expected_t = expected.tuple

            local what = "in return value"
            if expected.inferred_at then
               what = what .. inferred_msg(expected)
            end

            local n_expected = #expected_t
            local vatype
            if n_expected > 0 then
               vatype = expected.is_va and expected.tuple[n_expected]
            end

            if n_got > n_expected and (not self.feat_lax) and not vatype then
               self.errs:add(node, what .. ": excess return values, expected " .. n_expected .. " %s, got " .. n_got .. " %s", expected, got)
            end

            if n_expected > 1 and
               #node.exps == 1 and
               node.exps[1].kind == "op" and
               (node.exps[1].op.op == "and" or node.exps[1].op.op == "or") and
               node.exps[1].discarded_tuple then
               self.errs:add_warning("hint", node.exps[1].e2, "additional return values are being discarded due to '" .. node.exps[1].op.op .. "' expression; suggest parentheses if intentional")
            end

            for i = 1, n_got do
               local e = expected_t[i] or vatype
               if e then
                  e = resolve_tuple(e)
                  local w = (node.exps[i] and node.exps[i].x) and
                  node.exps[i] or
                  node.exps
                  assert(w and w.x)
                  self:assert_is_a(w, got_t[i], e, what)
               end
            end

            return NONE
         end,
      },
      ["variable_list"] = {
         after = function(self, node, children)
            local tuple = flat_tuple(node, children)

            for i, t in ipairs(tuple.tuple) do
               local ok, err = ensure_not_abstract(t, node[i])
               if not ok then
                  self.errs:add(node[i], err)
               end
            end

            return tuple
         end,
      },
      ["literal_table"] = {
         before = function(self, node)
            if node.expected then
               local decltype = self:to_structural(node.expected)

               if decltype.typename == "typevar" and decltype.constraint then
                  decltype = resolve_typedecl(self:to_structural(decltype.constraint))
               end

               if decltype.typename == "generic" then
                  decltype = self:apply_generic(node, decltype)
               end

               if decltype.typename == "tupletable" then
                  for _, child in ipairs(node) do
                     local n = child.key.constnum
                     if n and is_positive_int(n) then
                        child.value.expected = decltype.types[n]
                     end
                  end
               elseif decltype.elements then
                  for _, child in ipairs(node) do
                     if child.key.constnum then
                        child.value.expected = decltype.elements
                     end
                  end
               elseif decltype.typename == "map" then
                  for _, child in ipairs(node) do
                     child.key.expected = decltype.keys
                     child.value.expected = decltype.values
                  end
               end

               if decltype.fields then
                  for _, child in ipairs(node) do
                     if child.key.conststr then
                        child.value.expected = decltype.fields[child.key.conststr]
                     end
                  end
               end
            end
         end,
         after = function(self, node, children)
            node.known = FACT_TRUTHY

            if not node.expected then
               return infer_table_literal(self, node, children)
            end

            local decltype = self:to_structural(node.expected)

            local constraint
            if decltype.typename == "typevar" and decltype.constraint then
               constraint = resolve_typedecl(decltype.constraint)
               decltype = self:to_structural(constraint)
            end

            if decltype.typename == "generic" then
               decltype = self:apply_generic(node, decltype)
            end

            if decltype.typename == "union" then
               local single_table_type
               local single_table_rt

               for _, t in ipairs(decltype.types) do
                  local rt = self:to_structural(t)
                  if is_lua_table_type(rt) then
                     if single_table_type then

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

            if decltype.fields then
               self:begin_scope()
               self:add_var(nil, "@self", a_type(node, "typedecl", { def = decltype }))
               decltype = self:resolve_self(decltype, true)
               self:end_scope()
            end

            local force_array = nil

            local seen_keys = {}

            for i, child in ipairs(children) do
               local cvtype = resolve_tuple(child.vtype)
               local ck = child.kname
               local cktype = child.ktype
               local n = node[i].key.constnum
               local b = nil
               if cktype.typename == "boolean" then
                  b = (node[i].key.tk == "true")
               end
               self.errs:check_redeclared_key(node[i], node, seen_keys, ck or n or b)
               if decltype.fields and ck then
                  local df = decltype.fields[ck]
                  if not df then
                     self.errs:add_in_context(node[i], node, "unknown field " .. ck)
                  else
                     if df.typename == "typedecl" then
                        self.errs:add_in_context(node[i], node, "cannot reassign a type")
                     else
                        self:assert_is_a(node[i], cvtype, df, "in record field", ck)
                     end
                  end
               elseif decltype.typename == "tupletable" and is_numeric_type(cktype) then
                  local dt = decltype.types[n]
                  if not n then
                     self.errs:add_in_context(node[i], node, "unknown index in tuple %s", decltype)
                  elseif not dt then
                     self.errs:add_in_context(node[i], node, "unexpected index " .. n .. " in tuple %s", decltype)
                  else
                     self:assert_is_a(node[i], cvtype, dt, node, "in tuple: at index " .. tostring(n))
                  end
               elseif decltype.elements and is_numeric_type(cktype) then
                  local cv = child.vtype
                  if cv.typename == "tuple" and i == #children and node[i].key_parsed == "implicit" then

                     for ti, tt in ipairs(cv.tuple) do
                        self:assert_is_a(node[i], tt, decltype.elements, node, "expected an array: at index " .. tostring(i + ti - 1))
                     end
                  else
                     self:assert_is_a(node[i], cvtype, decltype.elements, node, "expected an array: at index " .. tostring(n))
                  end
               elseif node[i].key_parsed == "implicit" then
                  if decltype.typename == "map" then
                     self:assert_is_a(node[i].key, a_type(node[i].key, "integer", {}), decltype.keys, node, "in map key")
                     self:assert_is_a(node[i].value, cvtype, decltype.values, node, "in map value")
                  end
                  force_array = self:expand_type(node[i], force_array, child.vtype)
               elseif decltype.typename == "map" then
                  force_array = nil
                  self:assert_is_a(node[i].key, cktype, decltype.keys, node, "in map key")
                  self:assert_is_a(node[i].value, cvtype, decltype.values, node, "in map value")
               else
                  self.errs:add_in_context(node[i], node, "unexpected key of type %s in table of type %s", cktype, decltype)
               end
            end

            local t = force_array and a_type(node, "array", { elements = force_array }) or node.expected
            t = self:infer_at(node, t)

            if decltype.typename == "record" then
               local rt = self:to_structural(t)
               if rt.typename == "record" then
                  node.is_total, node.missing = total_record_check(decltype, seen_keys)
               end
            elseif decltype.typename == "map" then
               local rt = self:to_structural(t)
               if rt.typename == "map" then
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
         after = function(self, node, children)
            local kname = node.key.conststr
            local ktype = children[1]
            local vtype = children[2]
            if node.itemtype then
               vtype = node.itemtype
               self:assert_is_a(node.value, children[2], node.itemtype, node)
            end



            vtype = ensure_not_method(vtype)
            return a_type(node, "literal_table_item", {
               kname = kname,
               ktype = ktype,
               vtype = vtype,
            })
         end,
      },
      ["local_function"] = {
         before = function(self, node)
            self:widen_all_unions()
            if self.collector then
               self.collector.reserve_symbol_list_slot(node)
            end
            self:begin_scope(node)
         end,
         before_statements = function(self, node, children)
            local args = children[2]
            assert(args.typename == "tuple")

            self:add_internal_function_variables(node, args)
            self:add_function_definition_for_recursion(node, args, self.feat_arity)
         end,
         after = function(self, node, children)
            local args = children[2]
            assert(args.typename == "tuple")
            local rets = children[3]
            assert(rets.typename == "tuple")

            self:end_function_scope(node)

            local t = wrap_generic_if_typeargs(node.typeargs, a_function(node, {
               min_arity = self.feat_arity and node.min_arity or 0,
               args = args,
               rets = self.get_rets(rets),
            }))

            self:add_var(node, node.name.tk, t)
            return t
         end,
      },
      ["local_macroexp"] = {
         before = function(self, node)
            self:widen_all_unions()
            if self.collector then
               self.collector.reserve_symbol_list_slot(node)
            end
            self:begin_scope(node)
         end,
         after = function(self, node, children)
            local args = children[2]
            assert(args.typename == "tuple")
            local rets = children[3]
            assert(rets.typename == "tuple")

            self:end_function_scope(node)

            self:check_macroexp_arg_use(node.macrodef)

            local t = wrap_generic_if_typeargs(node.typeargs, a_function(node, {
               min_arity = self.feat_arity and node.macrodef.min_arity or 0,
               args = args,
               rets = self.get_rets(rets),
               macroexp = node.macrodef,
            }))

            self:add_var(node, node.name.tk, t)
            return t
         end,
      },
      ["global_function"] = {
         before = function(self, node)
            self:widen_all_unions()
            self:begin_scope(node)
            if node.implicit_global_function then
               local typ = self:find_var_type(node.name.tk)
               if typ then
                  if typ.typename == "function" then
                     node.is_predeclared_local_function = true
                  elseif not self.feat_lax then
                     self.errs:add(node, "cannot declare function: type of " .. node.name.tk .. " is %s", typ)
                  end
               elseif not self.feat_lax then
                  self.errs:add(node, "functions need an explicit 'local' or 'global' annotation")
               end
            end
         end,
         before_statements = function(self, node, children)
            local args = children[2]
            assert(args.typename == "tuple")

            self:add_internal_function_variables(node, args)
            self:add_function_definition_for_recursion(node, args, self.feat_arity)
         end,
         after = function(self, node, children)
            local args = children[2]
            assert(args.typename == "tuple")
            local rets = children[3]
            assert(rets.typename == "tuple")

            self:end_function_scope(node)
            if node.is_predeclared_local_function then
               return NONE
            end

            self:add_global(node, node.name.tk, wrap_generic_if_typeargs(node.typeargs, a_function(node, {
               min_arity = self.feat_arity and node.min_arity or 0,
               args = args,
               rets = self.get_rets(rets),
            })))

            return NONE
         end,
      },
      ["record_function"] = {
         before = function(self, node)
            self:widen_all_unions()
            self:begin_scope(node)
         end,
         before_arguments = function(self, _node, children)
            local rtype = self:to_structural(resolve_typedecl(children[1]))


            if rtype.typename == "generic" then
               for _, typ in ipairs(rtype.typeargs) do
                  self:add_var(nil, typ.typearg, a_type(typ, "typearg", {
                     typearg = typ.typearg,
                     constraint = typ.constraint,
                  }))
               end
            end
         end,
         before_statements = function(self, node, children)
            local args = children[3]
            assert(args.typename == "tuple")
            local rets = children[4]
            assert(rets.typename == "tuple")

            local t = children[1]
            local rtype = self:to_structural(resolve_typedecl(t))

            if rtype.typename == "generic" then
               rtype = rtype.t
            end

            do
               local ok, err = ensure_not_abstract(t)
               if not ok then
                  self.errs:add(node, err)
               end
            end

            if self.feat_lax and rtype.typename == "unknown" then
               return
            end

            if rtype.typename == "emptytable" then
               edit_type(rtype, rtype, "record")
               local r = rtype
               r.fields = {}
               r.field_order = {}
            end

            if not rtype.fields then
               self.errs:add(node, "not a record: %s", rtype)
               return
            end

            local selftype = self:get_self_type(node.fn_owner)
            if node.is_method then
               if not selftype then
                  self.errs:add(node, "could not resolve type of self")
                  return
               end
               args.tuple[1] = a_type(node, "self", { display_type = selftype })
               self:add_var(nil, "self", selftype)
               self:add_var(nil, "@self", a_type(node, "typedecl", { def = selftype }))
               if self.collector then
                  self.collector.add_to_symbol_list(node.fn_owner, "self", selftype)
               end
            end

            local fn_type = wrap_generic_if_typeargs(node.typeargs, a_function(node, {
               min_arity = self.feat_arity and node.min_arity or 0,
               is_method = node.is_method,
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
                  self.errs:redeclaration_warning(node, node.name.tk, "function")
               end

               if fn_type.typename == "generic" and not (rfieldtype.typename == "generic") then
                  self:begin_scope()
                  fn_type = self:apply_generic(node, fn_type)
                  self:end_scope()
               end

               local ok, err = self:same_type(fn_type, rfieldtype)
               if not ok then
                  if rfieldtype.typename == "poly" then
                     self.errs:add_prefixing(node, err, "type signature does not match declaration: field has multiple function definitions (such polymorphic declarations are intended for Lua module interoperability): ")
                     return
                  end

                  local shortname = selftype and show_type(selftype) or owner_name
                  local msg = "type signature of '" .. node.name.tk .. "' does not match its declaration in " .. shortname .. ": "
                  self.errs:add_prefixing(node, err, msg)
                  return
               end
            else
               if open_t and open_t.typename == "generic" then
                  open_t = open_t.t
               end
               if self.feat_lax or rtype == open_t then





                  rtype.fields[node.name.tk] = fn_type
                  table.insert(rtype.field_order, node.name.tk)

                  if self.collector then
                     self.env.reporter:add_field(rtype, node.name.tk, fn_type)
                  end
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
         after = function(self, node, _children)
            self:end_function_scope(node)
            return NONE
         end,
      },
      ["function"] = {
         before = function(self, node)
            self:widen_all_unions(node)
            self:begin_scope(node)

            local expected = node.expected
            if expected and expected.typename == "function" then
               for i, t in ipairs(expected.args.tuple) do
                  if node.args[i] then
                     node.args[i].expected = t
                  end
               end
            end
         end,
         before_statements = function(self, node, children)
            local args = children[1]
            assert(args.typename == "tuple")

            self:add_internal_function_variables(node, args)
         end,
         after = function(self, node, children)
            local args = children[1]
            assert(args.typename == "tuple")
            local rets = children[2]
            assert(rets.typename == "tuple")

            self:end_function_scope(node)

            return wrap_generic_if_typeargs(node.typeargs, a_function(node, {
               min_arity = self.feat_arity and node.min_arity or 0,
               args = args,
               rets = self.get_rets(rets),
            }))
         end,
      },
      ["macroexp"] = {
         before = function(self, node)
            self:widen_all_unions(node)
            self:begin_scope(node)
         end,
         before_exp = function(self, node, children)
            local args = children[1]
            assert(args.typename == "tuple")

            self:add_internal_function_variables(node, args)
         end,
         after = function(self, node, children)
            local args = children[1]
            assert(args.typename == "tuple")
            local rets = children[2]
            assert(rets.typename == "tuple")

            self:end_function_scope(node)
            return wrap_generic_if_typeargs(node.typeargs, a_function(node, {
               min_arity = self.feat_arity and node.min_arity or 0,
               args = args,
               rets = rets,
            }))
         end,
      },
      ["cast"] = {
         after = function(_self, node, _children)
            return node.casttype
         end,
      },
      ["paren"] = {
         before = function(_self, node)
            node.e1.expected = node.expected
         end,
         after = function(_self, node, children)
            node.known = node.e1 and node.e1.known
            return resolve_tuple(children[1])
         end,
      },
      ["op"] = {
         before = function(self, node)
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
            if node.op.op == "not" then
               node.e1.expected = a_type(node, "boolean_context", {})
            end
         end,
         before_e2 = function(self, node, children)
            local e1type = children[1]

            if node.op.op == "and" then
               self:apply_facts(node, node.e1.known)
            elseif node.op.op == "or" then
               self:apply_facts(node, facts_not(node, node.e1.known))


               if node.e1.kind == "op" and node.e1.op.op == "and" and
                  node.e1.e1.kind == "op" and node.e1.e1.op.op == "is" and
                  node.e1.e2.kind == "variable" and
                  node.e1.e2.tk == node.e1.e1.e1.tk and
                  node.e1.e1.e2.casttype.typename ~= "boolean" and
                  node.e1.e1.e2.casttype.typename ~= "nil" then

                  self:apply_facts(node, facts_not(node, IsFact({ var = node.e1.e1.e1.tk, typ = node.e1.e1.e2.casttype, w = node })))
               end

            elseif node.op.op == "@funcall" then
               if e1type.typename == "generic" then
                  e1type = self:apply_generic(node, e1type)
               end
               if e1type.typename == "function" then
                  local argdelta = (node.e1.op and node.e1.op.op == ":") and -1 or 0
                  if node.expected then

                     self:is_a(e1type.rets, node.expected)
                  end
                  local e1args = e1type.args.tuple
                  local at = argdelta
                  for _, typ in ipairs(e1args) do
                     at = at + 1
                     if node.e2[at] then
                        node.e2[at].expected = self:infer_at(node.e2[at], typ)
                     end
                  end
                  if e1type.args.is_va then
                     local typ = e1args[#e1args]
                     for i = at + 1, #node.e2 do
                        node.e2[i].expected = self:infer_at(node.e2[i], typ)
                     end
                  end
               end
            elseif node.op.op == "@index" then
               if e1type.typename == "map" then
                  node.e2.expected = e1type.keys
               end
            end
         end,
         after = function(self, node, children)
            self:end_scope()


            local ga = children[1]
            local gb = children[3]


            local ua = resolve_tuple(ga)
            local ub


            local ra = self:to_structural(ua)
            local rb

            if ra.typename == "circular_require" or (ra.typename == "typedecl" and ra.def and ra.def.typename == "circular_require") then
               return self.errs:invalid_at(node, "cannot dereference a type from a circular require")
            end

            if node.op.op == "@funcall" then
               if self.feat_lax and is_unknown(ua) then
                  if node.e1.op and node.e1.op.op == ":" and node.e1.e1.kind == "variable" then
                     self.errs:add_unknown_dot(node, node.e1.e1.tk .. "." .. node.e1.e2.tk)
                  end
               end
               assert(gb.typename == "tuple")
               local t = self:type_check_funcall(node, ua, gb)
               return t

            elseif node.op.op == "as" then
               local ok, err = ensure_not_abstract(ra)
               if not ok then
                  return self.errs:invalid_at(node.e1, err)
               end
               return gb

            elseif node.op.op == "is" and ra.typename == "typedecl" then
               return self.errs:invalid_at(node, "can only use 'is' on variables, not types")
            end

            local ok, err = ensure_not_abstract(ra)
            if not ok then
               return self.errs:invalid_at(node.e1, err)
            end
            if ra.typename == "typedecl" and ra.def.typename == "record" then
               ra = ra.def
            end



            if gb then
               ub = resolve_tuple(gb)
               rb = self:to_structural(ub)
               ok, err = ensure_not_abstract(rb)
               if not ok then
                  return self.errs:invalid_at(node.e2, err)
               end
               if rb.typename == "typedecl" and rb.def.typename == "record" then
                  rb = rb.def
               end
            end

            if node.op.op == "." then
               node.receiver = ua

               assert(node.e2.kind == "identifier")
               local bnode = node_at(node.e2, {
                  tk = node.e2.tk,
                  kind = "string",
               })
               local btype = a_type(node.e2, "string", { literal = node.e2.tk })
               local t = self:type_check_index(node.e1, bnode, ua, btype)

               if t.needs_compat and self.gen_compat ~= "off" then

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
               local add_type = false
               if rb.typename == "integer" then
                  self.all_needs_compat["math"] = true
               elseif not (rb.typename == "nil") then
                  add_type = true
               end
               if ra.typename == "typedecl" then
                  self.errs:add(node, "can only use 'is' on variables, not types")
               elseif node.e1.kind == "variable" then
                  local has_meta
                  if rb.typename == "union" then
                     has_meta = convert_is_of_union_to_or_of_is(self, node, ra, rb)
                  else
                     local _, meta = self:check_metamethod(node, "__is", ra, resolve_typedecl(rb), ua, ub)
                     node.known = IsFact({ var = node.e1.tk, typ = ub, w = node })
                     has_meta = not not meta
                  end
                  if has_meta then
                     add_type = false
                  end
               else
                  self.errs:add(node, "can only use 'is' on variables")
               end
               if add_type then
                  self.all_needs_compat["type"] = true
               end
               return a_type(node, "boolean", {})
            end

            if node.op.op == ":" then
               node.receiver = ua



               if self.feat_lax and (is_unknown(ua) or ua.typename == "typevar") then
                  if node.e1.kind == "variable" then
                     self.errs:add_unknown_dot(node.e1, node.e1.tk .. "." .. node.e2.tk)
                  end
                  return a_type(node, "unknown", {})
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
               local t

               local expected = node.expected and self:to_structural(resolve_tuple(node.expected))

               if ub.typename == "nil" then
                  node.known = nil
                  t = ua

               elseif is_lua_table_type(ra) and rb.typename == "emptytable" then
                  node.known = nil
                  t = ua

               elseif ((ra.typename == "enum" and rb.typename == "string" and self:is_a(rb, ra)) or
                  (ra.typename == "string" and rb.typename == "enum" and self:is_a(ra, rb))) then
                  node.known = nil
                  t = (ra.typename == "enum" and ra or rb)

               elseif expected and expected.typename == "union" then

                  node.known = facts_or(node, node.e1.known, node.e2.known)
                  local u = unite(node, { ra, rb }, true)
                  if u.typename == "union" then
                     ok, err = is_valid_union(u)
                     if not ok then
                        u = err and self.errs:invalid_at(node, err, u) or a_type(node, "invalid", {})
                     end
                  end
                  t = u


               elseif ra.typename == "union" and not (rb.typename == "union") and self:is_a(rb, ra) then

                  t = drop_constant_value(ra)

               elseif rb.typename == "union" and not (ra.typename == "union") and self:is_a(ra, rb) then

                  t = drop_constant_value(rb)

               else


                  local a_ge_b = self:is_a(ub, ua)
                  local b_ge_a = self:is_a(ua, ub)
                  node.known = facts_or(node, node.e1.known, node.e2.known)


                  local is_same = self:same_type(ra, rb)


                  local ambiguous = a_ge_b and b_ge_a and not is_same



                  if is_same then
                     t = ua
                  elseif (a_ge_b or b_ge_a) and not ambiguous then
                     local larger_type = b_ge_a and ub or ua
                     t = larger_type
                  elseif expected and self:is_a(ua, expected) and self:is_a(ub, expected) then
                     t = self:infer_at(node, expected)
                  end

                  if ambiguous and not t then
                     if TL_DEBUG then
                        self.errs:add_warning("debug", node, "the resulting type is ambiguous: %s or %s", ua, ub)
                        self.errs:add_warning("debug", node, "currently choosing %s", ub)
                     end

                     t = ub
                  end
                  if t then
                     t = drop_constant_value(t)
                  end

                  if expected and expected.typename == "boolean_context" then
                     t = a_type(node, "boolean", {})
                  end
               end

               if t then
                  return discard_tuple(node, t, gb)
               end

            end

            if node.op.op == "==" or node.op.op == "~=" then
               if is_lua_table_type(ra) and is_lua_table_type(rb) then
                  self:check_metamethod(node, binop_to_metamethod[node.op.op], ra, rb, ua, ub)
               end

               if ra.typename == "enum" and rb.typename == "string" then
                  if not (rb.literal and ra.enumset[rb.literal]) then
                     return self.errs:invalid_at(node, "%s is not a member of %s", ub, ua)
                  end
               elseif ra.typename == "tupletable" and rb.typename == "tupletable" and #ra.types ~= #rb.types then
                  return self.errs:invalid_at(node, "tuples are not the same size")
               elseif self:is_a(ub, ua) or ua.typename == "typevar" then
                  if node.op.op == "==" and node.e1.kind == "variable" then
                     node.known = EqFact({ var = node.e1.tk, typ = ub, w = node })
                  end
               elseif self:is_a(ua, ub) or ub.typename == "typevar" then
                  if node.op.op == "==" and node.e2.kind == "variable" then
                     node.known = EqFact({ var = node.e2.tk, typ = ua, w = node })
                  end
               elseif self.feat_lax and (is_unknown(ua) or is_unknown(ub)) then
                  return a_type(node, "unknown", {})
               else
                  return self.errs:invalid_at(node, "types are not comparable for equality: %s and %s", ua, ub)
               end

               return a_type(node, "boolean", {})
            end

            if node.op.arity == 1 and unop_types[node.op.op] then
               if ra.typename == "union" then
                  ra = unite(node, ra.types, true)
               end

               local types_op = unop_types[node.op.op]

               local tn = types_op[ra.typename]
               local t = tn and a_type(node, tn, {})

               if not t and ra.fields then
                  if ra.interface_list then
                     for _, iface in ipairs(ra.interface_list) do
                        if types_op[iface.typename] then
                           t = a_type(node, types_op[iface.typename], {})
                           break
                        end
                     end
                  end
               end

               local meta_on_operator
               if not t then
                  local mt_name = unop_to_metamethod[node.op.op]
                  if mt_name then
                     t, meta_on_operator = self:check_metamethod(node, mt_name, ra, nil, ua, nil)
                  end
               end

               if ra.typename == "map" then
                  if ra.keys.typename == "number" or ra.keys.typename == "integer" then
                     self.errs:add_warning("hint", node, "using the '#' operator on a map with numeric key type may produce unexpected results")
                  else
                     self.errs:add(node, "using the '#' operator on this map will always return 0")
                  end
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

               if not t then
                  return self.errs:invalid_at(node, "cannot use operator '" .. node.op.op:gsub("%%", "%%%%") .. "' on type %s", ua)
               end

               if not (t.typename == "boolean" or is_unknown(t)) then
                  node.known = FACT_TRUTHY
               end

               return t
            end

            if node.op.arity == 2 and binop_types[node.op.op] then
               if node.op.op == "or" then
                  node.known = facts_or(node, node.e1.known, node.e2.known)
               end

               if ra.typename == "union" then
                  ra = unite(ra, ra.types, true)
               end
               if rb.typename == "union" then
                  rb = unite(rb, rb.types, true)
               end

               local types_op = binop_types[node.op.op]

               local tn = types_op[ra.typename] and types_op[ra.typename][rb.typename]
               local t = tn and a_type(node, tn, {})

               local meta_on_operator
               if not t then
                  local mt_name = binop_to_metamethod[node.op.op]
                  local flipped = false
                  if not mt_name then
                     mt_name = flip_binop_to_metamethod[node.op.op]
                     if mt_name then
                        flipped = true
                        ra, rb = rb, ra
                        ua, ub = ub, ua
                     end
                  end
                  if mt_name then
                     t, meta_on_operator = self:check_metamethod(node, mt_name, ra, rb, ua, ub, flipped)
                     if flipped and not meta_on_operator then
                        ra, rb = rb, ra
                        ua, ub = ub, ua
                     end
                  end
               end

               if (not t) and ua.typename == "nominal" and ub.typename == "nominal" and not meta_on_operator then
                  if self:is_a(ua, ub) then
                     t = ua
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
                     local div = node_at(node, { kind = "op", op = an_operator(node, 2, "/"), e1 = node.e1, e2 = node.e2 })
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

               if not t then
                  if node.op.op == "or" then
                     local u = unite(node, { ua, ub })
                     if u.typename == "union" and is_valid_union(u) then
                        self.errs:add_warning("hint", node, "if a union type was intended, consider declaring it explicitly")
                     end
                  end
                  return self.errs:invalid_at(node, "cannot use operator '" .. node.op.op:gsub("%%", "%%%%") .. "' for types %s and %s", ua, ub)
               end

               return t
            end

            error("unknown node op " .. node.op.op)
         end,
      },
      ["variable"] = {
         after = function(self, node, _children)
            if node.tk == "..." then
               local va_sentinel = self:find_var_type("@is_va")
               if not va_sentinel or va_sentinel.typename == "nil" then
                  return self.errs:invalid_at(node, "cannot use '...' outside a vararg function")
               end
            end

            local t
            if node.tk == "_G" then
               t, node.attribute = self:simulate_g()
            else
               local use = node.is_lvalue and "lvalue" or "use"
               t, node.attribute = self:find_var_type(node.tk, use)
            end
            if not t then
               if self.feat_lax then
                  self.errs:add_unknown(node, node.tk)
                  return a_type(node, "unknown", {})
               end

               return self.errs:invalid_at(node, "unknown variable: " .. node.tk)
            end

            if t.typename == "typedecl" then
               t = typedecl_to_nominal(node, node.tk, t, t)
            end

            return t
         end,
      },
      ["type_identifier"] = {
         after = function(self, node, _children)
            local typ, attr = self:find_var_type(node.tk)
            node.attribute = attr
            if typ then
               return typ
            end

            if self.feat_lax then
               self.errs:add_unknown(node, node.tk)
               return a_type(node, "unknown", {})
            end

            return self.errs:invalid_at(node, "unknown variable: " .. node.tk)
         end,
      },
      ["argument"] = {
         after = function(self, node, children)
            local t = children[1]
            if not t then
               if node.expected and node.tk == "self" then
                  t = node.expected
               else
                  t = self.feat_lax and
                  a_type(node, "unknown", {}) or
                  a_type(node, "any", {})
               end
            end
            if node.tk == "..." then
               t = a_vararg(node, { t })
            end
            self:add_var(node, node.tk, t).is_func_arg = true
            return t
         end,
      },
      ["identifier"] = {
         after = function(_self, _node, _children)
            return NONE
         end,
      },
      ["newtype"] = {
         after = function(_self, node, _children)
            return node.newtype
         end,
      },
      ["pragma"] = {
         after = function(self, node, _children)
            if node.pkey == "arity" then
               if node.pvalue == "on" then
                  self.feat_arity = true
               elseif node.pvalue == "off" then
                  self.feat_arity = false
               else
                  return self.errs:invalid_at(node, "invalid value for pragma 'arity': " .. node.pvalue)
               end
            else
               return self.errs:invalid_at(node, "invalid pragma: " .. node.pkey)
            end
            return NONE
         end,
      },
      ["error_node"] = {
         after = function(_self, node, _children)
            return a_type(node, "invalid", {})
         end,
      },
   }

   visit_node.cbs["break"] = {
      after = function(_self, _node, _children)
         return NONE
      end,
   }
   visit_node.cbs["do"] = visit_node.cbs["break"]

   local function after_literal(_self, node)
      node.known = FACT_TRUTHY
      return a_type(node, node.kind, {})
   end

   visit_node.cbs["string"] = {
      after = function(self, node, _children)
         local t = after_literal(self, node)
         t.literal = node.conststr

         local expected = node.expected and self:to_structural(node.expected)
         if expected and expected.typename == "enum" and self:is_a(t, expected) then
            return node.expected
         end

         return t
      end,
   }
   visit_node.cbs["number"] = { after = after_literal }
   visit_node.cbs["integer"] = { after = after_literal }

   visit_node.cbs["boolean"] = {
      after = function(self, node, _children)
         local t = after_literal(self, node)
         node.known = (node.tk == "true") and FACT_TRUTHY or nil
         return t
      end,
   }
   visit_node.cbs["nil"] = visit_node.cbs["boolean"]

   visit_node.cbs["..."] = visit_node.cbs["variable"]
   visit_node.cbs["argument_list"] = visit_node.cbs["variable_list"]
   visit_node.cbs["expression_list"] = visit_node.cbs["variable_list"]

   visit_node.after = function(_self, node, _children, t)
      if node.expanded then
         apply_macroexp(node)
      end

      return t
   end

   function TypeChecker:resolve_self(t, resolve_interface)
      local selftype, selfdecl = self:type_of_self(t)
      local checktype = selftype
      if selftype.typename == "generic" then
         checktype = selftype.t
      end

      if (resolve_interface and checktype.typename == "interface") or checktype.typename == "record" then
         return map_type(self, t, {
            ["self"] = function(_, typ)
               return typedecl_to_nominal(typ, checktype.declname, selfdecl)
            end,
         })
      else
         return t
      end
   end

   do
      local function add_interface_fields(self, fields, field_order, resolved, named, list)
         for fname, ftype in fields_of(resolved, list) do
            if fields[fname] then
               if not self:is_a(fields[fname], ftype) then
                  local what = list == "meta" and "metamethod" or "field"
                  self.errs:add(fields[fname], what .. " '" .. fname .. "' does not match definition in interface %s", named)
               end
            else
               table.insert(field_order, fname)
               if ftype.typename == "typedecl" then
                  fields[fname] = ftype
               else
                  fields[fname] = self:resolve_self(ftype)
               end
            end
         end
      end

      local function collect_interfaces(self, list, t, seen)
         if t.interface_list then
            for _, iface in ipairs(t.interface_list) do
               if iface.typename == "nominal" then
                  local ri = self:resolve_nominal(iface)
                  if ri.typename == "interface" then
                     table.insert(list, iface)
                     if ri.interfaces_expanded and not seen[ri] then
                        seen[ri] = true
                        collect_interfaces(self, list, ri, seen)
                     end
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

      function TypeChecker:expand_interfaces(t)
         if t.interfaces_expanded then
            return
         end
         t.interfaces_expanded = true

         t.interface_list = collect_interfaces(self, {}, t, {})

         for _, iface in ipairs(t.interface_list) do
            if iface.typename == "nominal" then
               local ri = self:resolve_nominal(iface)
               assert(ri.typename == "interface")
               add_interface_fields(self, t.fields, t.field_order, ri, iface)
               if ri.meta_fields then
                  t.meta_fields = t.meta_fields or {}
                  t.meta_field_order = t.meta_field_order or {}
                  add_interface_fields(self, t.meta_fields, t.meta_field_order, ri, iface, "meta")
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

   function TypeChecker:begin_temporary_record_types(typ)
      self:add_var(nil, "@self", a_type(typ, "typedecl", { def = typ }))

      for fname, ftype in fields_of(typ) do
         if ftype.typename == "typedecl" then
            local def = ftype.def
            if def.typename == "nominal" then
               assert(ftype.is_alias)
               self:resolve_nominal(def)
            end
            self:add_var(nil, fname, ftype)
         end
      end
   end

   function TypeChecker:end_temporary_record_types(typ)


      local scope = self.st[#self.st]
      scope.vars["@self"] = nil
      for fname, ftype in fields_of(typ) do
         if ftype.typename == "typedecl" then
            scope.vars[fname] = nil
         end
      end
   end

   local function ensure_is_method_self(typ, selfarg, g)
      if selfarg.typename == "self" then
         return true
      end
      if not (selfarg.typename == "nominal") then
         return false
      end

      if #selfarg.names ~= 1 or selfarg.names[1] ~= typ.declname then
         return false
      end

      if g then
         if not selfarg.typevals then
            return false
         end

         if g.t.typeid ~= typ.typeid then
            return false
         end

         for j = 1, #g.typeargs do
            local tv = selfarg.typevals[j]
            if not (tv and tv.typename == "typevar" and tv.typevar == g.typeargs[j].typearg) then
               return false
            end
         end
      end

      return true
   end

   local metamethod_is_method = {
      ["__bnot"] = true,
      ["__call"] = true,
      ["__close"] = true,
      ["__gc"] = true,
      ["__index"] = true,
      ["__is"] = true,
      ["__len"] = true,
      ["__newindex"] = true,
      ["__pairs"] = true,
      ["__tostring"] = true,
      ["__unm"] = true,
   }

   local visit_type
   visit_type = {
      cbs = {
         ["generic"] = {
            before = function(self, typ)
               self:begin_scope()
               self:add_var(nil, "@generic", typ)
            end,
            after = function(self, typ, _children)
               self:end_scope()
               return fresh_typeargs(self, typ)
            end,
         },
         ["function"] = {
            after = function(self, typ, _children)
               if self.feat_arity == false then
                  typ.min_arity = 0
               end
               return typ
            end,
         },
         ["record"] = {
            before = function(self, typ)
               self:begin_scope()
               self:begin_temporary_record_types(typ)
            end,
            after = function(self, typ, children)
               local i = 1
               if typ.interface_list then
                  for j, _ in ipairs(typ.interface_list) do
                     local iface = children[i]
                     if iface.typename == "array" then
                        typ.interface_list[j] = iface
                     elseif iface.typename == "nominal" then
                        local ri = self:resolve_nominal(iface)
                        if ri.typename == "interface" then
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
               local fmacros
               local g
               for name, _ in fields_of(typ) do
                  local ftype = children[i]
                  if ftype.typename == "function" then
                     if ftype.macroexp then
                        fmacros = fmacros or {}
                        table.insert(fmacros, ftype)
                     end

                     if ftype.is_method then
                        local fargs = ftype.args.tuple
                        if fargs[1] then
                           if not g then
                              g = self:find_var("@generic")
                           end
                           ftype.is_method = ensure_is_method_self(typ, fargs[1], g and g.t)
                           if ftype.is_method then
                              fargs[1] = a_type(fargs[1], "self", { display_type = typ })
                           end
                        end
                     end
                  elseif ftype.typename == "typedecl" and ftype.is_alias then
                     self:resolve_typealias(ftype)
                  end

                  typ.fields[name] = ftype
                  i = i + 1
               end
               for name, _ in fields_of(typ, "meta") do
                  local ftype = children[i]
                  if ftype.typename == "function" then
                     if ftype.macroexp then
                        fmacros = fmacros or {}
                        table.insert(fmacros, ftype)
                     end
                     ftype.is_method = metamethod_is_method[name]
                  end
                  typ.meta_fields[name] = ftype
                  i = i + 1
               end

               if typ.interface_list then
                  self:expand_interfaces(typ)

                  if self.collector then
                     for fname, ftype in fields_of(typ) do
                        self.env.reporter:add_field(typ, fname, ftype)
                     end
                  end
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

               self:end_temporary_record_types(typ)
               self:end_scope()

               return typ
            end,
         },
         ["typearg"] = {
            after = function(self, typ, _children)
               local name = typ.typearg
               local old = self:find_var(name, "check_only")
               if old then
                  self.errs:redeclaration_warning(typ, name, "type argument", old)
               end
               if simple_types[name] then
                  self.errs:add(typ, "cannot use base type name '" .. name .. "' as a type variable")
               end

               self:add_var(nil, name, a_type(typ, "typearg", {
                  typearg = name,
                  constraint = typ.constraint,
               }))
               return typ
            end,
         },
         ["typevar"] = {
            after = function(self, typ, _children)
               if not self:find_var_type(typ.typevar) then
                  self.errs:add(typ, "undefined type variable " .. typ.typevar)
               end
               return typ
            end,
         },
         ["nominal"] = {
            after = function(self, typ, _children)
               if typ.found then
                  return typ
               end

               local t, typearg = self:find_type(typ.names)
               if t then
                  local def = t.def
                  if t.is_alias then
                     if def.typename == "generic" then
                        def = def.t
                     end
                     if def.typename == "nominal" then
                        typ.found = def.found
                     end
                  elseif def.typename ~= "circular_require" then
                     typ.found = t
                  end
               elseif typearg then

                  typ.names = nil
                  edit_type(typ, typ, "typevar")
                  local tv = typ
                  tv.typevar = typearg.typearg
                  tv.constraint = typearg.constraint
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
            after = function(self, typ, _children)
               local _, err = is_valid_union(typ)
               if err then
                  return self.errs:invalid_at(typ, err, typ)
               end
               return typ
            end,
         },
      },
   }

   local default_type_visitor = {
      after = function(_self, typ, _children)
         return typ
      end,
   }

   visit_type.cbs["interface"] = visit_type.cbs["record"]

   visit_type.cbs["typedecl"] = default_type_visitor
   visit_type.cbs["self"] = default_type_visitor
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



   local function internal_compiler_check(fn)
      return function(s, n, children, t)
         t = fn and fn(s, n, children, t) or t

         if type(t) ~= "table" then
            error(((n).kind or (n).typename) .. " did not produce a type")
         end
         if type(t.typename) ~= "string" then
            error(((n).kind or (n).typename) .. " type does not have a typename")
         end

         return t
      end
   end

   local function store_type_after(fn)
      return function(self, n, children, t)
         t = fn and fn(self, n, children, t) or t

         local w = n

         if w.y then
            self.collector.store_type(w.y, w.x, t)
         end

         return t
      end
   end

   local function debug_type_after(fn)
      return function(s, node, children, t)
         t = fn and fn(s, node, children, t) or t

         node.debug_type = t
         return t
      end
   end

   local function patch_visitors(my_visit_node,
      after_node,
      my_visit_type,
      after_type)


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

   local function set_feat(feat, default)
      if feat then
         return (feat == "on")
      else
         return default
      end
   end

   tl.check = function(ast, filename, opts, env)
      filename = filename or "?"

      opts = opts or {}

      if not env then
         local err
         env, err = tl.new_env({ defaults = opts })
         if err then
            return nil, err
         end
      end

      local self = {
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

      self.cache_std_metatable_type = env.globals["metatable"] and (env.globals["metatable"].t).def

      setmetatable(self, {
         __index = TypeChecker,
         __tostring = function() return "TypeChecker" end,
      })

      self.feat_lax = set_feat(opts.feat_lax or env.defaults.feat_lax, false)
      self.feat_arity = set_feat(opts.feat_arity or env.defaults.feat_arity, true)
      self.gen_compat = opts.gen_compat or env.defaults.gen_compat or DEFAULT_GEN_COMPAT
      self.gen_target = opts.gen_target or env.defaults.gen_target or DEFAULT_GEN_TARGET

      if self.feat_lax then
         self.feat_arity = false
      end

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

         self.subtype_relations["*"]["boolean"] = compare_true

         self.get_rets = function(rets)
            if #rets.tuple == 0 then
               return a_vararg(rets, { a_type(rets, "unknown", {}) })
            end
            return rets
         end
      else
         self.get_rets = function(rets)
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
         visit_type, internal_compiler_check)

      end
      if self.collector then
         visit_node, visit_type = patch_visitors(
         visit_node, store_type_after,
         visit_type, store_type_after)

      end
      if TL_DEBUG then
         visit_node, visit_type = patch_visitors(
         visit_node, debug_type_after)

      end

      assert(ast.kind == "statements")
      recurse_node(self, ast, visit_node, visit_type)

      local global_scope = self.st[1]
      close_types(global_scope)
      self.errs:check_var_usage(global_scope, true)

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





local function read_full_file(fd)
   local bom = "\239\187\191"
   local content, err = fd:read("*a")
   if not content then
      return nil, err
   end

   if content:sub(1, bom:len()) == bom then
      content = content:sub(bom:len() + 1)
   end
   return content, err
end

local function lang_heuristic(filename, input)
   if filename then
      local pattern = "(.*)%.([a-z]+)$"
      local _, extension = filename:match(pattern)
      extension = extension and extension:lower()

      if extension == "tl" then
         return "tl"
      elseif extension == "lua" then
         return "lua"
      end
   end
   if input then
      return (input:match("^#![^\n]*lua[^\n]*\n")) and "lua" or "tl"
   end
   return "tl"
end

local function feat_lax_heuristic(lang)
   return lang == "tl" and "off" or "on"
end

tl.check_file = function(filename, env, fd)
   if env and env.loaded and env.loaded[filename] then
      return env.loaded[filename]
   end

   local input, err

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

   return tl.check_string(input, env, filename)
end

function tl.target_from_lua_version(str)
   if str == "Lua 5.1" or
      str == "Lua 5.2" then
      return "5.1"
   elseif str == "Lua 5.3" then
      return "5.3"
   elseif str == "Lua 5.4" then
      return "5.4"
   end
end

local function default_env_opts(runtime, parse_lang)
   local gen_target = runtime and tl.target_from_lua_version(_VERSION) or DEFAULT_GEN_TARGET
   local gen_compat = (gen_target == "5.4") and "off" or DEFAULT_GEN_COMPAT
   return {
      defaults = {
         feat_lax = feat_lax_heuristic(parse_lang),
         gen_target = gen_target,
         gen_compat = gen_compat,
         run_internal_compiler_checks = false,
      },
   }
end

function tl.check_string(input, env, filename, parse_lang)
   parse_lang = parse_lang or lang_heuristic(filename, input)
   env = env or tl.new_env(default_env_opts(false, parse_lang))

   if env.loaded and env.loaded[filename] then
      return env.loaded[filename]
   end
   filename = filename or ""

   local program, syntax_errors, _ = tl.parse(input, filename, parse_lang)

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

   local result = tl.check(program, filename, env.defaults, env)

   result.syntax_errors = syntax_errors

   return result
end

tl.gen = function(input, env, opts, parse_lang)
   parse_lang = parse_lang or lang_heuristic(nil, input)
   env = env or assert(tl.new_env(default_env_opts(false, parse_lang)), "Default environment initialization failed")
   local result = tl.check_string(input, env)

   if (not result.ast) or #result.syntax_errors > 0 then
      return nil, result
   end

   local code
   code, result.gen_error = tl.generate(result.ast, env.defaults.gen_target, opts)
   return code, result
end

local function tl_package_loader(module_name)
   local found_filename, fd, tried = tl.search_module(module_name, false)
   if found_filename then
      local parse_lang = lang_heuristic(found_filename)
      local input = read_full_file(fd)
      if not input then
         return table.concat(tried, "\n\t")
      end
      fd:close()
      local program, errs = tl.parse(input, found_filename, parse_lang)
      if #errs > 0 then
         error(found_filename .. ":" .. errs[1].y .. ":" .. errs[1].x .. ": " .. errs[1].msg)
      end

      local env = tl.package_loader_env
      if not env then
         tl.package_loader_env = assert(tl.new_env(), "Default environment initialization failed")
         env = tl.package_loader_env
      end

      local opts = default_env_opts(true, parse_lang)

      local w = { f = found_filename, x = 1, y = 1 }
      env.modules[module_name] = a_type(w, "typedecl", { def = a_type(w, "circular_require", {}) })

      local result = tl.check(program, found_filename, opts.defaults, env)

      env.modules[module_name] = result.type



      local code = assert(tl.generate(program, opts.defaults.gen_target, fast_generate_opts))
      local chunk, err = load(code, "@" .. found_filename, "t")
      if chunk then
         return function(modname, loader_data)
            if loader_data == nil then
               loader_data = found_filename
            end
            local ret = chunk(modname, loader_data)
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

local function env_for(opts, env_tbl)
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

tl.load = function(input, chunkname, mode, ...)
   local parse_lang = lang_heuristic(chunkname)
   local program, errs = tl.parse(input, chunkname, parse_lang)
   if #errs > 0 then
      return nil, (chunkname or "") .. ":" .. errs[1].y .. ":" .. errs[1].x .. ": " .. errs[1].msg
   end

   local opts = default_env_opts(true, parse_lang)

   if not tl.package_loader_env then
      tl.package_loader_env = tl.new_env(opts)
   end

   local filename = chunkname or ("string \"" .. input:sub(45) .. (#input > 45 and "..." or "") .. "\"")
   local result = tl.check(program, filename, opts.defaults, env_for(opts, ...))

   if mode and mode:match("c") then
      if #result.type_errors > 0 then
         local errout = {}
         for _, err in ipairs(result.type_errors) do
            table.insert(errout, err.filename .. ":" .. err.y .. ":" .. err.x .. ": " .. (err.msg or ""))
         end
         return nil, table.concat(errout, "\n")
      end

      mode = mode:gsub("c", "")
   end

   local code, err = tl.generate(program, opts.defaults.gen_target, fast_generate_opts)
   if not code then
      return nil, err
   end

   return load(code, chunkname, mode, ...)
end

tl.version = function()
   return VERSION
end





function tl.get_types(result)
   return result.env.reporter:get_report(), result.env.reporter
end

tl.init_env = function(lax, gen_compat, gen_target, predefined)
   local opts = {
      defaults = {
         feat_lax = (lax and "on" or "off"),
         gen_compat = ((type(gen_compat) == "string") and gen_compat) or
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

tl.type_check = function(ast, tc_opts)
   local opts = {
      feat_lax = tc_opts.lax and "on" or "off",
      feat_arity = tc_opts.env and tc_opts.env.defaults.feat_arity or "on",
      gen_compat = tc_opts.gen_compat,
      gen_target = tc_opts.gen_target,
      run_internal_compiler_checks = tc_opts.run_internal_compiler_checks,
   }
   return tl.check(ast, tc_opts.filename, opts, tc_opts.env)
end

tl.pretty_print_ast = function(ast, gen_target, mode)
   local opts
   if type(mode) == "table" then
      opts = mode
   elseif mode == true then
      opts = fast_generate_opts
   else
      opts = default_generate_opts
   end

   return tl.generate(ast, gen_target, opts)
end

tl.process = function(filename, env, fd)
   return tl.check_file(filename, env, fd)
end

tl.process_string = function(input, is_lua, env, filename, _module_name)
   return tl.check_string(input, env or tl.init_env(is_lua), filename)
end

return tl
