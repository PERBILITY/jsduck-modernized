# Modern parser front-end (acorn)

This fork replaces JSDuck's JavaScript parser with [acorn][], so that modern
JavaScript can be documented **without a Babel pre-processing step**, while
leaving JSDuck's entire Ext JS analysis untouched.

## Background: how JSDuck parses JavaScript

JSDuck does **not** analyse a raw parser AST directly. Its pipeline is:

```
JS source
   │
   ▼
RKelly (Ruby parser, ECMAScript 5.1 only)     ← the bottleneck
   │
   ▼
RKellyAdapter  ──►  Esprima-compatible ESTree AST   ← a clean seam
   │
   ▼
┌──────────────────────────────────────────────────────┐
│  Ext JS analysis — operates purely on the ESTree AST   │
│  Js::Class    Ext.define / extend / override, mixins   │
│  Js::Method   methods, apply/update                    │
│  Js::Property cfg, statics, properties                 │
│  Js::Event    @event / fireEvent                       │
│  Associator   doc-comment ↔ code node association      │
│  Merger, Process::*, custom tags, ...                  │
└──────────────────────────────────────────────────────┘
```

All of JSDuck's Ext JS knowledge sits **below a clean seam: the
Esprima-format AST**. RKelly is already adapted *into* that format by
`RKellyAdapter` purely so the downstream code can run on it.

Modern JavaScript fails because **RKelly only understands ECMAScript 5.1**.
This fork swaps the front-end (RKelly + RKellyAdapter) for acorn, which emits
ESTree natively. Nothing downstream of the seam changes.

## What changed

| File | Type | Purpose |
|------|------|---------|
| `lib/jsduck/js/acorn_bridge.js` | **new** | Node.js script: reads JS from stdin, parses with acorn, prints `{program, comments}` as ESTree JSON. |
| `lib/jsduck/js/acorn_adapter.rb` | **new** | Runs the bridge, normalizes acorn's output into JSDuck's Esprima-format AST. |
| `lib/jsduck/js/parser.rb` | modified | Always uses the acorn front-end; the original RKelly parse path is removed. |
| `lib/jsduck/js/associator.rb` | modified | `child_nodes` made generic + position-sorted, so comment association works for any syntax acorn emits — without enumerating every ESTree node type. |
| `package.json` | **new** | Declares the acorn dependency for the bridge. |

Everything else — `Js::Class`, `Js::Method`, `Js::Property`, `Js::Event`,
`Js::Node`, `Serializer`, `Evaluator`, `Merger`, custom tags — is unchanged.

### The AST contract

`acorn_adapter.rb` reproduces exactly the hash shape the rest of JSDuck
expects. The only two structural differences between acorn output and JSDuck's
expectations are handled in the adapter:

1. **`range`** — JSDuck expects a 3-element `range = [start, end, line]`
   (`Js::Node#linenr` reads `range[2]`). acorn provides `start`/`end` offsets
   and a `loc` object; the adapter builds the 3-element range from them.
2. **acorn-specific keys** — acorn nodes carry `start`/`end`/`loc`. Those are
   removed after building `range`, because `Js::Node#body` treats every nested
   Hash as a child node and would otherwise mistake them for AST nodes.

### The Associator change

JSDuck's original `Associator#child_nodes` recursed using a hardcoded
`NODE_TYPES` table and aborted (`Logger.fatal`) on any unknown node type.
Modern syntax (`ArrowFunctionExpression`, `TemplateLiteral`, class bodies, …)
would therefore crash it as soon as a comment sat nearby.

The replacement collects child nodes generically — every nested Hash that
carries a `range` — and sorts them by start offset (so the nearest node
following a comment is chosen). Comment plumbing (`Program["comments"]` and the
`comment["next"]` links, which also carry ranges) is explicitly excluded;
treating those as code breaks class detection.

## Runtime requirements

- **Node.js** on `PATH` (or set `JSDUCK_NODE=/path/to/node`).
- **acorn** resolvable by the bridge script. Either run `npm install` so
  `node_modules/` sits next to the bridge, or point `JSDUCK_NODE_PATH` at a
  directory containing acorn. `JSDUCK_NODE_PATH` is prepended to `NODE_PATH`
  **only for the bridge's Node process**, so it never interferes with other
  Node tooling (e.g. Babel) running in the same build.

## Usage

```bash
npm install                 # installs acorn (see package.json)
jsduck path/to/src -o out   # acorn is the only parser; no flag needed
```

## Build-pipeline impact

For an Ext JS project currently transpiling with Babel just to satisfy
JSDuck, the migration is:

1. Drop the Babel pre-processing step; feed JSDuck the original sources.
2. Ensure Node.js + acorn are available wherever JSDuck runs (e.g. add them to
   the JSDuck Docker image). acorn is the only parser — there is no flag to set.

The documented source shown in the generated UI is then the original,
un-transpiled code.

## Limitations / open points

- **Documented-surface coverage.** Tested broadly against the real codebase.
  Rare modern syntax appearing on the *documented surface* (not inside method
  bodies) may still need small additions to the member detectors.
- **Per-file Node process.** The bridge is invoked once per parsed file. Fine
  in practice, but a long-lived Node process would be faster for huge trees.
- **Module vs script.** The bridge parses as a classic script and falls back
  to module syntax on failure. Ext JS sources are scripts, so this is a
  non-issue in practice.

[acorn]: https://github.com/acornjs/acorn
