#!/usr/bin/env node
'use strict';

// Node.js bridge for JSDuck's modern parser front-end.
//
// Reads JavaScript source from stdin, parses it with acorn (a maintained,
// modern ESTree parser) and writes a JSON document of the form
//
//     { "program": <ESTree Program node>, "comments": [ ... ] }
//
// to stdout. acorn nodes carry `start`/`end` character offsets and (because
// we enable `locations`) a `loc` object; the Ruby side (acorn_adapter.rb)
// turns those into JSDuck's expected 3-element `range` ([start, end, line]).
//
// Comments are collected via acorn's onComment hook in the exact shape the
// JSDuck Associator expects: { type: "Block"|"Line", value, range: [start, end] }.

var acorn = require('acorn');

function readStdin(cb) {
  var chunks = [];
  process.stdin.on('data', function (d) { chunks.push(d); });
  process.stdin.on('end', function () { cb(Buffer.concat(chunks).toString('utf8')); });
}

function parse(src, sourceType, comments) {
  return acorn.parse(src, {
    ecmaVersion: 'latest',
    sourceType: sourceType,
    locations: true,
    allowReturnOutsideFunction: true,
    allowAwaitOutsideFunction: true,
    allowHashBang: true,
    onComment: function (block, text, start, end) {
      comments.push({
        type: block ? 'Block' : 'Line',
        value: text,
        range: [start, end]
      });
    }
  });
}

readStdin(function (src) {
  var comments = [];
  var program;
  try {
    // ExtJS sources are classic scripts; fall back to module syntax just in case.
    program = parse(src, 'script', comments);
  } catch (e1) {
    comments.length = 0;
    try {
      program = parse(src, 'module', comments);
    } catch (e2) {
      process.stderr.write('ACORN_SYNTAX_ERROR: ' + e2.message + '\n');
      process.exit(2);
      return;
    }
  }
  process.stdout.write(JSON.stringify({ program: program, comments: comments }));
});
