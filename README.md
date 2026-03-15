# rime-ice 个人配置

基于 [雾凇拼音 (rime-ice)](https://github.com/iDvel/rime-ice) 的个人定制配置，仅保留全拼方案，适用于 macOS（鼠须管）和 Windows（小狼毫）。

## 主要定制

- **输入方案**：仅全拼（`rime_ice`），移除了双拼和九宫格方案
- **主题**：Gruvbox Dark 配色，Resource Han Rounded SC Regular 字体
- **Emoji**：默认关闭（可通过菜单切换开启）

## 安装

将本仓库克隆到 Rime 前端的配置目录，然后重新部署。

```bash
# macOS（鼠须管）
git clone https://github.com/MOSconfig/rime-ice.git ~/Library/Rime --depth 1

# Windows（小狼毫）
git clone https://github.com/MOSconfig/rime-ice.git %APPDATA%\Rime --depth 1
```

## 从上游合并更新

本仓库跟踪上游 [iDvel/rime-ice](https://github.com/iDvel/rime-ice)，通过 `origin` remote 拉取词库和功能更新。

```bash
# 拉取上游最新代码
git fetch origin

# 合并上游更新（保留本地定制）
git merge origin/main

# 如有冲突，解决后提交
# 冲突通常出现在：
#   - default.yaml（schema_list 已精简）
#   - squirrel.yaml（自定义主题）
#   - rime_ice.schema.yaml（emoji 开关）
# 解决后推送到个人仓库
git push myconfig main
```

合并后需要检查上游是否新增了 Lua 脚本或词库文件，按需保留或删除。

## 文件结构

```
├── rime_ice.schema.yaml       # 全拼方案（主方案）
├── melt_eng.schema.yaml       # 英文输入（rime_ice 依赖）
├── radical_pinyin.schema.yaml # 拆字反查（rime_ice 依赖）
├── default.yaml               # 全局配置
├── squirrel.yaml              # macOS 鼠须管外观配置（含 Gruvbox Dark 主题）
├── weasel.yaml                # Windows 小狼毫外观配置
├── cn_dicts/                  # 中文词库（8105 字表、base、ext、tencent、others）
├── en_dicts/                  # 英文词库（en、en_ext、cn_en 混合词）
├── lua/                       # Lua 扩展插件
├── opencc/                    # Emoji 及字符转换
├── symbols_v.yaml             # v 模式特殊符号
└── custom_phrase.txt          # 自定义短语
```

## 上游项目

原始项目：[iDvel/rime-ice](https://github.com/iDvel/rime-ice) · [详细介绍](https://dvel.me/posts/rime-ice/) · [常见问题](https://github.com/iDvel/rime-ice/issues/133)

