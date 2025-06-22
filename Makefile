LUA ?=

ifeq ($(OS), Windows_NT)
	BUSTED = busted.bat --suppress-pending --exclude-tags=unix
else
	BUSTED = busted --suppress-pending
endif

PRECOMPILED = teal/precompiled/default_env.lua
SOURCES = teal/debug.tl teal/errors.tl teal/lexer.tl teal/util.tl teal/embed/prelude.tl teal/embed/stdlib.tl teal/types.tl teal/facts.tl teal/parser.tl teal/traversal.tl teal/gen/lua_generator.tl teal/variables.tl teal/type_reporter.tl teal/type_errors.tl teal/environment.tl teal/checker/type_checker.tl teal/checker/file_checker.tl teal/checker/string_checker.tl teal/checker/require_file.tl tl.tl

all: selfbuild suite

precompiler.lua: precompiler.tl
	$(LUA) ./tl gen $< -o $@ || { rm $@; exit 1; }

teal/precompiled/default_env.lua: precompiler.lua teal/embed/prelude.tl teal/embed/stdlib.tl tl.tl
	lua precompiler.lua > teal/precompiled/default_env.lua || { rm $@; exit 1; }

%.lua.bak: %.lua
	cp $< $@

%.lua.1: %.tl $(PRECOMPILED)
	$(LUA) ./tl gen --check --gen-target=5.1 $< -o $@ || { rm $@; exit 1; }

%.lua.2: %.tl %.lua.1 $(PRECOMPILED)
	$(LUA) ./tl gen --check --gen-target=5.1 $< -o $@ || { for bak in $$(find . -name '*.lua.bak'); do cp $$bak `echo "$$bak" | sed 's/.bak$$//'`; done; for l in `find . -name '*.lua.1'`; do mv $$l $$l.err; done; exit 1 ;}

build1: $(addsuffix .lua.1,$(basename $(SOURCES)))

replace1:
	for f in $$(find . -name '*.lua.1'); do l=`echo "$$f" | sed 's/.1$$//'`; cp $$l $$l.bak; cp $$f $$l; done

build2: $(addsuffix .lua.2,$(basename $(SOURCES)))

selfbuild: build1 replace1 build2
	for f in $$(find . -name '*.lua.1'); do l=`echo "$$f" | sed 's/.1$$//'`; diff $$f $$l.2 || { for bak in $$(find . -name '*.lua.bak'); do cp $$bak `echo "$$bak" | sed 's/.bak$$//'`; done; for l in `find . -name '*.lua.1'`; do mv $$l $$l.err; done; exit 1 ;}; done && make cleantemp

suite:
	${BUSTED} -v $(TESTFLAGS) spec/lang
	${BUSTED} -v $(TESTFLAGS) spec/api
	${BUSTED} -v $(TESTFLAGS) spec/cli

cov:
	rm -f luacov.stats.out luacov.report.out
	${BUSTED} -c
	luacov tl.lua
	cat luacov.report.out

cleantemp:
	for f in $$(find . -name '*.lua.1'); do rm $$f; done
	for f in $$(find . -name '*.lua.1.err'); do rm $$f; done
	for f in $$(find . -name '*.lua.2'); do rm $$f; done
	for f in $$(find . -name '*.lua.bak'); do rm $$f; done

clean: cleantemp
