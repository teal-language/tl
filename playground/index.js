// Setup editors
function setupInfoArea(id) {
  const e = ace.edit(id);
  e.setShowPrintMargin(false);
  e.setOptions({
    readOnly: true,
    highlightActiveLine: false,
    highlightGutterLine: false
  })
  e.renderer.$cursorLayer.element.style.opacity=0;
  return e;
}

function setupEditorArea(id, lsKey) {
  const e = ace.edit(id);
  e.setShowPrintMargin(false);
  e.setValue(localStorage.getItem(lsKey) || '');
  e.moveCursorTo(0, 0);
  return e;
}

const grammar = setupEditorArea("grammar-editor", "grammarText");
grammar.getSession().setMode("ace/mode/lua");
const code = setupEditorArea("code-editor", "codeText");
code.getSession().setMode("ace/mode/lua");

$('#opt-mode').val(localStorage.getItem('optimizationMode') || '2');
$('#packrat').prop('checked', localStorage.getItem('packrat') === 'true');
$('#auto-refresh').prop('checked', localStorage.getItem('autoRefresh') === 'true');
$('#runCmd').prop('disabled', $('#auto-refresh').prop('checked'));

function load_sample(self) {
  let base_url = "https://raw.githubusercontent.com/mingodad/tl/dad-playground/playground/"
  switch(self.options[self.selectedIndex].value) {
    case "Teal":
      $.get(base_url + "../tl.tl", function( data ) {
        grammar.setValue( data );
      });
      break;
    case "basic":
      $.get(base_url + "sample-basic.tl", function( data ) {
        grammar.setValue( data );
      });
      break;
    case "enums":
      $.get(base_url + "sample-enums.tl", function( data ) {
        grammar.setValue( data );
      });
      break;
    case "generics":
      $.get(base_url + "sample-generics.tl", function( data ) {
        grammar.setValue( data );
      });
      break;
    case "maps":
      $.get(base_url + "sample-maps.tl", function( data ) {
        grammar.setValue( data );
      });
      break;
    case "records":
      $.get(base_url + "sample-records.tl", function( data ) {
        grammar.setValue( data );
      });
      break;
    case "metamethods":
      $.get(base_url + "sample-metamethods.tl", function( data ) {
        grammar.setValue( data );
      });
      break;
  }
}

// RunCommand
function escapeHtml(unsafe) {
  return unsafe
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function nl2br(str) {
  return str.replace(/\n/g, '<br>\n')
}

function textToErrors(str) {
  let errors = [];
  var regExp = /([^\n]+?)\n/g, match;
  while (match = regExp.exec(str)) {
    let msg = match[1];
    let line_col = msg.match(/^code.tl:(\d+):(\d+)/);
    if (line_col) {
      errors.push({"ln": line_col[1], "col":line_col[2], "msg": msg});
    } else {
      errors.push({"msg": msg});
    }
  }
  return errors;
}

function generateErrorListHTML(errors) {
  let html = '<ul>';

  html += $.map(errors, function (x) {
    if (x.ln > 0) {
      return '<li data-ln="' + x.ln + '" data-col="' + x.col +
        '"><span>' + escapeHtml(x.msg) + '</span></li>';
    } else {
      return '<li><span>' + escapeHtml(x.msg) + '</span></li>';
    }
  }).join('');

  html += '<ul>';

  return html;
}

function updateLocalStorage() {
  localStorage.setItem('grammarText', grammar.getValue());
  localStorage.setItem('codeText', code.getValue());
  localStorage.setItem('optimizationMode', $('#opt-mode').val());
  localStorage.setItem('packrat', $('#packrat').prop('checked'));
  localStorage.setItem('autoRefresh', $('#auto-refresh').prop('checked'));
}

// convert a Javascript string to a C string
function jstr2C(s) {
  var size = lengthBytesUTF8(s) + 1;
  var ret = _malloc(size);
  stringToUTF8Array(s, HEAP8, ret, size);
  return ret;
}

function run_argc_argv(jfunc, jstrings) {
  let c_strings = jstrings.map(x => jstr2C(x));

  // allocate and populate the array. adapted from https://stackoverflow.com/a/23917034
	let argc = c_strings.length;
  let c_arr = _malloc((argc+1)*4); // 4-bytes per pointer
  c_strings.forEach(function(x, i) {
    Module.setValue(c_arr + i * 4, x, "i32");
  });
	c_arr[argc] = 0;

  // invoke our C function
  let rc = 1;
  try {
    rc = jfunc(argc, c_arr);
  } catch(e) {
	if(e.name == "ExitStatus")
	  rc = e.status;
  }

  // free c_strings
  for(let i = 0; i < argc; i++)
    _free(c_strings[i]);

  // free c_arr
  _free(c_arr);

  // return
  return rc;
}

function callCustomMain(mfunc, args) {
	Module["_main"] = Module[mfunc];
	return callMain(args);
}

function RunCommand() {
  const $grammarValidation = $('#grammar-validation');
  const $grammarInfo = $('#grammar-info');
  const grammarText = grammar.getValue();

  const $codeValidation = $('#code-validation');
  const $codeInfo = $('#code-info');
  const codeText = code.getValue();

  const optimizationMode = $('#opt-mode').val();
  const packrat = $('#packrat').prop('checked');
  const profile = $('#show-profile').prop('checked');

  $grammarInfo.html('');
  $grammarValidation.hide();
  $codeInfo.html('');
  $codeValidation.hide();

  outputs.compile_status = '';
  outputs.parse_status = '';
  outputs.default = '';

  if (grammarText.length === 0) {
    return;
  }

  $('#overlay').css({
    'z-index': '1',
    'display': 'block',
    'background-color': 'rgba(0, 0, 0, 0.1)'
  });

  window.setTimeout(() => {
    let code_teal_fname = "code.tl";
    let code_lua_fname = "code.lua";
    if(FS.findObject(code_teal_fname))
      FS.unlink(code_teal_fname);
    if(FS.findObject(code_lua_fname))
      FS.unlink(code_lua_fname);
    FS.createDataFile("/", code_teal_fname, grammar.getValue(), true, true, true);
    output = "parse_status";
    let rc = run_argc_argv(_lua_main, ["lua", "tl", "gen", "--check", code_teal_fname]);
    output = "default";
    if( rc == 0 ) {
      $grammarValidation.removeClass('validation-invalid').show();
      //$grammarInfo.html('<pre>' + FS.readdir("/") + '</pre>');
      code.setValue(FS.readFile(code_lua_fname, { encoding: 'utf8' }));
      run_argc_argv(_lua_main, ["lua", code_lua_fname]);
      $codeInfo.html('<pre>' + outputs.default + '</pre>');
    }
    else {
      $grammarValidation.addClass('validation-invalid').show();
      //$grammarInfo.html('<pre>' + outputs.parse_status + '</pre>');
      const errors = textToErrors(outputs.parse_status);
      const html = generateErrorListHTML(errors);
      $grammarInfo.html(html);
    }

    $('#overlay').css({
      'z-index': '-1',
      'display': 'none',
      'background-color': 'rgba(1, 1, 1, 1.0)'
    });

  }, 0);
}

// Event handing for text editing
let timer;
function setupTimer() {
  clearTimeout(timer);
  timer = setTimeout(() => {
    updateLocalStorage();
    if ($('#auto-refresh').prop('checked')) {
      RunCommand();
    }
  }, 200);
};
grammar.getSession().on('change', setupTimer);
code.getSession().on('change', setupTimer);

// Event handing in the info area
function makeOnClickInInfo(editor) {
  return function () {
    const el = $(this);
    let line = el.data('ln') - 1;
    let col = el.data('col') - 1;
    editor.navigateTo(line, col);
    editor.scrollToLine(line, true, false, null);
    editor.focus();
  }
};
$('#grammar-info').on('click', 'li[data-ln]', makeOnClickInInfo(grammar));
$('#code-info').on('click', 'li[data-ln]', makeOnClickInInfo(code));

// Event handing in the AST optimization
$('#runCmd').on('click', RunCommand);

let syncScroll_cb1, syncScroll_cb2;
function setupSyncScroll() {
    let s1 = grammar.getSession();
    let s2 = code.getSession();
    if ($('#syncScroll').prop('checked')) {
      syncScroll_cb1 = function() {
         s2.setScrollTop(s1.getScrollTop())
      }
      s1.on('changeScrollTop', syncScroll_cb1);

      syncScroll_cb2 = function() {
         s1.setScrollTop(s2.getScrollTop())
      }
      s2.on('changeScrollTop', syncScroll_cb2);
    }
    else {
      s1.removeListener('changeScrollTop', syncScroll_cb1);
      s2.removeListener('changeScrollTop', syncScroll_cb2);
    }
}
$('#syncScroll').on('change', setupSyncScroll);


// Resize editors to fit their parents
function resizeEditorsToParent() {
  code.resize();
  code.renderer.updateFull();
}

// Show windows
function setupToolWindow(lsKeyName, buttonSel, codeSel, showDefault) {
  let storedValue = localStorage.getItem(lsKeyName);
  if (!storedValue) {
    localStorage.setItem(lsKeyName, showDefault);
    storedValue = localStorage.getItem(lsKeyName);
  }
  let show = storedValue === 'true';
  $(buttonSel).prop('checked', show);
  $(codeSel).css({ 'display': show ? 'block' : 'none' });

  $(buttonSel).on('change', () => {
    show = !show;
    localStorage.setItem(lsKeyName, show);
    $(codeSel).css({ 'display': show ? 'block' : 'none' });
    resizeEditorsToParent();
  });
}

// Show page
$('#main').css({
  'display': 'flex',
});

// used to collect output from C
var outputs = {
  'default': '',
  'compile_status': '',
  'parse_status': '',
};

// current output (key in `outputs`)
var output = "default";

// results of the various stages
var result = {
  'compile': 0,
  'parse': 0,
};

// chpeg_parse function: initialized when emscripten runtime loads
var cql_main = null;
var lua_main = null;
var luac_main = null;
var ucpp_main = null;

// Emscripten
var Module = {

  // intercept stdout (print) and stderr (printErr)
  // note: text received is line based and missing final '\n'

  'print': function(text) {
    outputs[output] += text + "\n";
  },
  'printErr': function(text) {
    outputs[output] += text + "\n";
  },

  // called when emscripten runtime is initialized
  'onRuntimeInitialized': function() {
    // wrap the C `parse` function
    cql_main = cwrap('cql_main', ['number', 'array']);
    lua_main = cwrap('lua_main', ['number', 'array']);
    luac_main = cwrap('luac_main', ['number', 'array']);
    ucpp_main = cwrap('ucpp_main', ['number', 'array']);
    // Initial parse
    if ($('#auto-refresh').prop('checked')) {
      RunCommand();
    }
  },
};

// vim: sw=2:sts=2
