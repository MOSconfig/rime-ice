# rime-ice 个人配置

基于 [雾凇拼音 (rime-ice)](https://github.com/iDvel/rime-ice) 的个人定制配置，仅保留全拼方案，适用于 macOS（鼠须管）和 Windows（小狼毫）。

## 主要定制

- **输入方案**：仅全拼（`rime_ice`），移除了双拼和九宫格方案
- **语法模型**：启用万象语法模型（`wanxiang-lts-zh-hans`），提升长句选词，见下文
- **模糊音**：l/n、en/eng、in/ing
- **主题**：Gruvbox Dark 配色，Resource Han Rounded SC Regular 字体
- **Emoji**：默认关闭（可通过菜单切换开启）

## 安装

将本仓库克隆到 Rime 前端的配置目录，下载语法模型，然后重新部署。

```bash
# macOS（鼠须管）
git clone https://github.com/MOSconfig/rime-ice.git ~/Library/Rime --depth 1
bash ~/Library/Rime/scripts/fetch-grammar.sh

# Windows（小狼毫）
git clone https://github.com/MOSconfig/rime-ice.git %APPDATA%\Rime --depth 1
```

Windows 上手动下载 [wanxiang-lts-zh-hans.gram](https://github.com/amzxyz/RIME-LMDG/releases/download/LTS/wanxiang-lts-zh-hans.gram)，放到 `%APPDATA%\Rime\` 根目录。

## 语法模型

`rime_ice.schema.yaml` 的 `grammar:` 块启用了 librime-octagram 语法模型，参数取自上游 `grammar.recipe`。主流鼠须管、小狼毫都已内置该插件，但模型文件（约 391 MB）需要单独下载，不放进 Git。

```bash
bash scripts/fetch-grammar.sh           # 下载到仓库根目录并校验 sha256，已校验则跳过
bash scripts/fetch-grammar.sh --update  # 上游发布新模型后重新下载，并输出新的 sha256
```

下载后重新部署（鼠须管菜单 →「重新部署」）。

- **效果**：鼠须管 librime 1.16 实测，16 个长句中修正 4 个（如「开会把→开会吧」「现在德兴市→现在的形势」），变差 1 个（「买东西→卖东西」）。
- **代价**：首次部署约 8 秒；模型以 mmap 方式映射，常驻内存约多 165 MB（实测 209 MB 对 44 MB）。
- **没有模型**：日志会出现 `failed to load grammar database`，但输入照常工作，候选与不启用语法模型时完全相同。
- **关闭**：删除 `rime_ice.schema.yaml` 中的 `grammar:` 块（或删除 `.gram` 文件），重新部署。

## 测试

`tests/run.sh` 用鼠须管自带的 librime，在临时目录部署当前工作区并检查候选。它不会修改 `~/Library/Rime` 或用户词库。

```bash
bash tests/run.sh                    # 有模型时同时测试语法模型
RIME_SKIP_GRAM=1 bash tests/run.sh   # 不用模型，并与「无 grammar 块」对照
bash tests/fetch-grammar.test.sh     # 下载脚本的校验与回退
```

覆盖：常用词和长句、模糊音、日期时间（`rq` `sj` `xq` `dt` `ts` `rqzh` `rqen`）、农历（`nl` `N19700101`）、数字大写、计算器、Unicode、拆字、`vhelp`、繁简切换、Emoji 默认关闭、语法模型。用例在 `tests/cases.tsv`。

## 从上游合并更新

本仓库跟踪上游 [iDvel/rime-ice](https://github.com/iDvel/rime-ice)，通过 `origin` remote 拉取词库和功能更新。

```bash
git fetch origin
git merge origin/main

# 冲突处理：
#   - 本仓库已删除的文件（双拼、九宫格、41448、cn_en_* 变体、spacer 脚本等）：git rm，保持删除
#   - README.md：保留本仓库版本
#   - 上游新增但本仓库不需要的：others/、recipe.yaml、AGENTS.md、.github/workflows/、build/.gitkeep
# 注意 lua/convert_ar_num_to_zh.lua 被 date_translator.lua 依赖，不能删

bash tests/run.sh                    # 合并后必须通过
git push myconfig main
```

合并后检查上游是否新增了 `rime_ice.schema.yaml` 引用的 Lua 脚本或词库文件，按需保留。

## 文件结构

```
├── rime_ice.schema.yaml       # 全拼方案（主方案，含语法模型配置）
├── melt_eng.schema.yaml       # 英文输入（rime_ice 依赖）
├── radical_pinyin.schema.yaml # 拆字反查（rime_ice 依赖）
├── default.yaml               # 全局配置
├── squirrel.yaml              # macOS 鼠须管外观配置（含 Gruvbox Dark 主题）
├── weasel.yaml                # Windows 小狼毫外观配置
├── cn_dicts/                  # 中文词库（8105 字表、base、ext、tencent、others）
├── en_dicts/                  # 英文词库（en、en_ext、cn_en 混合词）
├── lua/                       # Lua 扩展插件（lunar.db 为农历数据）
├── opencc/                    # Emoji 及字符转换
├── symbols_v.yaml             # v 模式特殊符号（vhelp 查看全部）
├── custom_phrase.txt          # 自定义短语
├── scripts/fetch-grammar.sh   # 语法模型下载
└── tests/                     # 回归测试（librime harness + 用例）
```

## 上游项目

原始项目：[iDvel/rime-ice](https://github.com/iDvel/rime-ice) · [详细介绍](https://dvel.me/posts/rime-ice/) · [常见问题](https://github.com/iDvel/rime-ice/issues/133)
