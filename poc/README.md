# JSDuck acorn front-end — PoC

Replaces JSDuck's ES5.1-only RKelly parser with a modern **acorn** front-end,
while keeping all of JSDuck's ExtJS analysis untouched.

## What was changed

| File | Change |
|------|--------|
| `lib/jsduck/js/acorn_bridge.js` | **new** — Node.js script: parses stdin with acorn, emits `{program, comments}` JSON (ESTree). |
| `lib/jsduck/js/acorn_adapter.rb` | **new** — runs the bridge, normalizes acorn output into JSDuck's Esprima-format AST (`range = [start, end, line]`, strips `start`/`end`/`loc`). |
| `lib/jsduck/js/parser.rb` | dispatch: `JSDUCK_PARSER=acorn` uses acorn, otherwise RKelly (default). |
| `lib/jsduck/js/associator.rb` | `child_nodes` made generic + sorted by source position, so modern node types no longer hit `Logger.fatal`. |

Everything downstream (`Js::Class`, `Js::Method`, `Js::Property`, `Js::Event`,
`Merger`, the custom `@async`/`@field`/`@param_` tags, ...) is unchanged.
See [../docs/acorn-parser.md](../docs/acorn-parser.md) for the full design.

## Setup

```bash
npm install     # installs acorn for the bridge (see ../package.json)
node --version  # the bridge needs node on PATH (or set JSDUCK_NODE=/path/to/node)
```

acorn must be resolvable by the bridge: either keep `node_modules/` next to the
installed gem / checkout, or set `NODE_PATH` to a directory containing acorn.

## Run

Run with JSDuck on `PATH` (a normal gem install of this fork). Running the
in-tree `bin/jsduck` directly does **not** activate the gem's Ruby
dependencies (e.g. `sass`), so prefer the installed executable.

```bash
# 1) Baseline: RKelly on the ES5 file (the modern file would CRASH RKelly)
jsduck poc/ExtClassic.js -o poc/out-rkelly --warnings=-all

# 2) acorn front-end on BOTH files (incl. the modern one, no Babel needed)
JSDUCK_PARSER=acorn jsduck \
    poc/ExtClassic.js poc/ExtModern.js -o poc/out-acorn --warnings=-all
```

## What to verify in `poc/out-acorn`

Open `poc/out-acorn/index.html` and check **`Poc.ModernWidget`**:

- [ ] class detected, `extend: Ext.Component`, mixin `observable`
- [ ] cfgs `title`, `width` (with default 100)
- [ ] event `titlechange`
- [ ] methods `applyTitle`, `loadTitle` (with `@async`), `updateTitle`
- [ ] statics `TYPE`, `fromAll`
- [ ] **"View source" shows the ORIGINAL modern code** (const/let, arrow,
      template literals, async/await) — not transpiled output

Compare `Poc.ClassicWidget` between `out-rkelly` and `out-acorn` — they should
be equivalent (proves the acorn front-end is a faithful drop-in).

## Note on the production pipeline

In production this means: **drop the Babel pre-processing step entirely** and
set `JSDUCK_PARSER=acorn`. The only runtime requirement added is a Node.js
binary available wherever JSDuck runs (e.g. the jsduck Docker image).
