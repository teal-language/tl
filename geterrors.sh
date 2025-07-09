#!/usr/bin/env bash
set -euo pipefail

make selfbuild LUA=./lua || {
  echo "Failed to build the project. Please check the errors above."
  exit 1
}

FILTER="${1:-}"

./lua_modules/bin/busted -v --suppress-pending -o json --sort --defer-print ./spec/block-lang/ | \
jq -r --arg filter "$FILTER" '
  # ------------ gather unique errors ------------
  ( [ .errors[] as $e
      | ( $e.trace
          + { testname: $e.name
              , test_src: { src: $e.element.trace.short_src
                           , line: $e.element.trace.currentline } } ) ]
    | sort_by(.traceback)
    | unique_by(.traceback) ) as $uniq

  # ------------ optionally filter ------------
  | (if $filter == ""              # no arg → keep all
       then $uniq
       else [ $uniq[]
               | select( (.testname|test($filter;"i"))
                       or (.message|test($filter;"i")) ) ]
     end) as $sel

  # ------------ emit selected errors ------------
  | $sel[]
    | "Test \"\(.testname)\" at \(.test_src.src):\(.test_src.line)\n"
      + "Error: \(.message)"
      + ( .traceback
          | (fromjson? // .)
          | gsub("\\\\n"; "\n") )

  # ------------ final count ------------
  , "Total unique errors: \($sel|length)"
'
