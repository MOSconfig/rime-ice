# Copilot Instructions for rime-ice (雾凇拼音)

This is a Rime IME configuration repository — not a typical software project. There is no application code to compile or test in the traditional sense. The repo provides input method schemas, dictionaries, Lua plugins, and platform frontend configs for the [Rime Input Method Engine](https://rime.im/).

## Build System

A Go program in `others/script/` validates and processes dictionaries:

```bash
# Full pipeline: validate emoji, annotate pinyin, add weights, check format, sort
cd others/script && go run main.go --rime_path "$(git rev-parse --show-toplevel)"

# Sort dictionaries only
cd others/script && go run main.go --rime_path "$(git rev-parse --show-toplevel)" s
```

CI runs this on commits containing `[build]` in the message (see `.github/workflows/release.yml`).

## Architecture

### Schema → Dictionary → Lua pipeline

Schemas (`.schema.yaml`) are the top-level configs that define an input method. Each schema references:
- A **dictionary** (`translator/dictionary`) — e.g., `rime_ice` loads `rime_ice.dict.yaml`
- **Lua scripts** via `lua_processor@*name` / `lua_translator@*name` / `lua_filter@*name` — the `*` prefix loads from `lua/`
- **OpenCC configs** (`opencc_config: emoji.json`) from `opencc/` for emoji and character conversion
- **Symbols** via `__include: symbols_v:/symbols` or `symbols_caps_v` for special character input

### Dictionary hierarchy

`rime_ice.dict.yaml` and `melt_eng.dict.yaml` are index files that import sub-dictionaries:

- `cn_dicts/` — Chinese: `8105` (common chars), `base` (two-char words), `ext` (extended), `tencent` (large corpus), `others`
- `en_dicts/` — English: `en` (~20k words), `en_ext` (abbreviations/internet terms)

Dictionary entry format is tab-separated: `Word<TAB>Pinyin<TAB>Weight`

```
雾凇	wu song	500
```

### Schema variants

`rime_ice.schema.yaml` is the full-pinyin master schema. Double-pinyin schemas (`double_pinyin_flypy.schema.yaml`, etc.) share the same dictionary but use a different `prism` and `speller/algebra` to map keypresses to pinyin syllables. `t9.schema.yaml` is the 9-key variant.

### Configuration hierarchy

- `default.yaml` — global settings shared across schemas (punctuation, keybindings, schema list)
- `squirrel.yaml` — macOS frontend (Squirrel) appearance and behavior
- `weasel.yaml` — Windows frontend (Weasel) appearance and behavior
- `user.yaml` — auto-generated build metadata, not manually edited
- `custom_phrase.txt` — user-pinned phrases, format: `Word<TAB>Encoding<TAB>Weight`, loaded as `stabledb` (read-only, highest priority via `initial_quality: 99`)

### Symbols files

- `symbols_v.yaml` — for full-pinyin (prefix `v`, since no pinyin syllable starts with v)
- `symbols_caps_v.yaml` — for double-pinyin (prefix `V`, since `v` is a valid double-pinyin key)

## Key Conventions

### YAML `__include` and `__patch`

Rime uses `__include` for cross-file/cross-section imports and `__patch` for overrides. This is not standard YAML — it's Rime-specific syntax:

```yaml
punctuator:
  __include: default:/punctuator        # import entire section from default.yaml
symbols:
  __include: symbols_v:/symbols         # import from separate file
```

### Lua plugin pattern

Lua scripts in `lua/` are referenced with `@*` prefix in schemas. They receive config parameters from a same-named YAML section in the schema:

```yaml
filters:
  - lua_filter@*pin_cand_filter
pin_cand_filter:              # config passed to the lua script
  - d	的
```

### OpenCC for emoji

Emoji is implemented as an OpenCC conversion (not a dictionary). `opencc/emoji.json` chains `emoji.txt` and `others.txt` through `mmseg` segmentation. To add emoji, edit `opencc/emoji.txt` (format: `中文<TAB>Emoji1 Emoji2 ...`).

### Color values in frontend configs

Squirrel/Weasel color values are **BGR** (not RGB), 24-bit hex with `0x` prefix: `0xBBGGRR`. Alpha can be prepended: `0xAABBGGRR`.

### Plum recipes

`others/recipes/` contains [Plum](https://github.com/rime/plum) recipe files for distributing subsets of the config (full, cn_dicts, en_dicts, opencc, etc.).
