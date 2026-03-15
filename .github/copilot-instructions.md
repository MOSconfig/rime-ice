# Copilot Instructions for rime-ice (雾凇拼音)

This is a personal fork of [iDvel/rime-ice](https://github.com/iDvel/rime-ice) — a Rime IME configuration repository. It is trimmed to full-pinyin only, for macOS (Squirrel) and Windows (Weasel).

## Upstream Sync

- `origin` → `iDvel/rime-ice` (upstream)
- `myconfig` → `MOSconfig/rime-ice` (personal)

```bash
git fetch origin && git merge origin/main    # merge upstream updates
git push myconfig main                        # push to personal repo
```

Conflicts are expected in `default.yaml` (schema_list), `squirrel.yaml` (custom theme), and `rime_ice.schema.yaml` (emoji switch). Always keep the personal customizations.

After merging, check if upstream added new Lua scripts or dict files referenced by `rime_ice.schema.yaml` — add them if needed, discard double-pinyin/t9 additions.

## Architecture

### Schema → Dictionary → Lua pipeline

`rime_ice.schema.yaml` is the sole input schema. It references:
- **Dictionary**: `rime_ice.dict.yaml` (imports from `cn_dicts/`: 8105, base, ext, tencent, others)
- **English**: `melt_eng.schema.yaml` + `melt_eng.dict.yaml` (imports `en_dicts/en`, `en_dicts/en_ext`)
- **Radical lookup**: `radical_pinyin.schema.yaml` + `radical_pinyin.dict.yaml`
- **Lua scripts** via `lua_processor@*name` / `lua_translator@*name` / `lua_filter@*name` — the `*` prefix loads from `lua/`
- **OpenCC**: `opencc/emoji.json` for emoji conversion
- **Symbols**: `__include: symbols_v:/symbols` for v-mode special characters
- **Mixed vocab**: `en_dicts/cn_en.txt` for Chinese-English mixed input

Dictionary entry format is tab-separated: `Word<TAB>Pinyin<TAB>Weight`

### Configuration hierarchy

- `default.yaml` — global settings (punctuation, keybindings, schema list)
- `squirrel.yaml` — macOS Squirrel appearance (Gruvbox Dark theme, Resource Han Rounded SC font)
- `weasel.yaml` — Windows Weasel appearance
- `custom_phrase.txt` — user-pinned phrases, format: `Word<TAB>Encoding<TAB>Weight`, loaded as `stabledb` (highest priority via `initial_quality: 99`)

### Personal customizations

- Emoji off by default (`reset: 0` in rime_ice.schema.yaml switches)
- Gruvbox Dark color scheme in `squirrel.yaml` (`preset_color_schemes/gruvbox_dark`)
- Font: Resource Han Rounded SC Regular, 15pt
- Flat appearance: no border, no shadow
- Only `rime_ice` in `default.yaml` schema_list

## Key Conventions

### YAML `__include` and `__patch`

Rime-specific (not standard YAML) syntax for cross-file imports and overrides:

```yaml
punctuator:
  __include: default:/punctuator        # import section from default.yaml
symbols:
  __include: symbols_v:/symbols         # import from separate file
```

### Lua plugin pattern

Lua scripts in `lua/` are referenced with `@*` prefix in schemas. Config parameters come from a same-named YAML section:

```yaml
filters:
  - lua_filter@*pin_cand_filter
pin_cand_filter:              # config passed to the lua script
  - d	的
```

### OpenCC for emoji

Emoji is an OpenCC conversion (not a dictionary). To add emoji, edit `opencc/emoji.txt` (format: `中文<TAB>Emoji1 Emoji2 ...`).

### Color values in frontend configs

Squirrel/Weasel color values are **BGR** (not RGB): `0xBBGGRR`. Alpha can be prepended: `0xAABBGGRR`.
