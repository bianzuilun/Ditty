# Ditty

**中文** | [English](README_EN.md)

**[Ditto](https://sabrogden.github.io/Ditto/) 的 Mac 版** — 非官方的原生 macOS 剪贴板管理器，外观与使用方式贴近 Windows 原版。

<img src="docs/screenshot.png" width="365" alt="Ditty 弹出窗口：已保存的剪贴列表，下方为搜索框">

Ditty 会保存你复制过的内容，之后可随时再贴回去。按下快捷键，选一条（或输入搜索），再按 Enter。

> **状态：早期版本。** 作者在自己的 Mac 上日常可用，但项目仍较新。若有问题，请[提交 Issue](../../issues)。

Ditty 与 Ditto 及其作者 Scott Brogden 无关联，也未获其背书。这是用 Swift 从零编写的独立程序；借鉴 Ditto 的外观、默认设置与交互，是因为从 Windows 迁过来的用户常希望得到同样的体验。

## 功能

- 保存文本、富文本、HTML、图片，以及在访达中复制的文件
- 在文本插入点（或鼠标位置）弹出窗口，沿用 Ditto 默认外观，并提供深色主题
- 边输入边搜索，匹配内容高亮
- Enter 粘贴，Shift+Enter 以纯文本粘贴，⌘1–⌘0 粘贴第 1–10 条
- 特殊粘贴：大小写转换、首字母大写、句首大写、驼峰、slugify、去除换行、去首尾空白等
- 分组、置顶剪贴，以及「永不自动删除」
- 剪贴属性，包括编辑剪贴文本
- 默认保留最近 500 次复制，可选按天数过期
- 跳过密码管理器标记为机密的复制内容
- 界面支持 15 种语言（见下文），按系统语言自动选择
- 数据仅保存在本机，位于 `~/Library/Application Support/Ditty` 下的 SQLite 数据库

相对 Ditto 尚未提供的功能：网络同步（「Friends」）、导入/导出（含导入 Ditto 数据库）、单条剪贴的全局快捷键，以及剪贴对比工具。

## 安装

使用 [Homebrew](https://brew.sh)：

```sh
brew install --cask 20101997/tap/ditty
```

或手动安装：

1. 从[最新发布页](https://github.com/20101997/Ditty/releases/latest)下载 **Ditty.zip** 并解压。
2. 将 **Ditty.app** 拖入「应用程序」文件夹并打开。
3. 首次打开时 macOS 会拦截，因为 Ditty 未使用付费的 Apple 开发者证书签名。打开 **系统设置 → 隐私与安全性**，向下滚动，在关于 Ditty 的提示旁点击 **仍要打开**。

菜单栏会出现 〃 图标。Ditty 支持 macOS 13 及以上，同时兼容 Apple Silicon 与 Intel Mac。

若更习惯用终端，下面这条命令与第 3 步效果相同（Homebrew 安装会自动处理）：

```sh
xattr -dr com.apple.quarantine /Applications/Ditty.app
```

### 自行编译

需要 Apple 命令行工具（`xcode-select --install`）；不必安装完整版 Xcode。

```sh
git clone https://github.com/20101997/Ditty.git
cd Ditty
./build.sh --install
```

### 让 Ditty 代为粘贴

要向其他应用粘贴，Ditty 需要代你按下 ⌘V，而 macOS 只有在你授权后才允许这样做：在 **系统设置 → 隐私与安全性 → 辅助功能** 中开启 **Ditty**。

未开启时，选择一条剪贴仍会写入剪贴板，但需要你自己按 ⌘V。

macOS 将此项权限与具体构建绑定，因此安装新版本后需重新开启：从列表中移除 Ditty，再重新添加。（若自行编译，运行 `build.sh` 时将 `SIGN_ID` 设为签名身份即可避免这一问题。）

## 使用方法

| 按键 | 作用 |
|---|---|
| `⌃` + `` ` `` | 打开 Ditty（可在「选项 → 键盘快捷键」中修改） |
| `↩` | 粘贴所选剪贴 |
| `⇧↩` | 以纯文本粘贴 |
| `⌘1` – `⌘0` | 粘贴第 1 – 10 条 |
| `↑` `↓` | 在列表中移动（按住 `⇧` 可多选） |
| `⌘⌫` 或 `⌦` | 删除所选剪贴 |
| `⌘C` | 复制到剪贴板但不粘贴 |
| `F3` | 显示完整剪贴内容 |
| `F7` | 新建分组 |
| `⌥↩` | 剪贴属性 |
| `⎋` | 先清除搜索，再关闭 |

右键点击剪贴，或点击 `···`，可进行其他操作。点击菜单栏图标可打开 Ditty；右键点击可打开「选项」和「退出」。

## 界面语言

Ditty 支持 15 种语言，在「选项 → 通用 → 语言」中以其本地名称列出：

English · 简体中文 · हिन्दी · Español · Français · العربية · বাংলা · Português · Русский · اردو · Bahasa Indonesia · Deutsch · 繁體中文 · 日本語 · 한국어

- **默认跟随系统语言**（「系统默认」）：每次启动时，macOS 会在已捆绑的翻译中选择最匹配的语言。在选项中选择某语言后会固定使用该语言。
- 阿拉伯语与乌尔都语会自动切换为从右到左布局。
- 翻译文件位于 `Resources/<code>.lproj/Localizable.strings`，每种语言一张表；英文字符串同时作为查找键，缺失条目会回退到英文。添加或编辑语言后，运行 `python3 scripts/validate_l10n.py`，可对照英文检查键名与 printf 风格占位符。

## 支持

Ditty 免费使用。若它帮你节省了时间，可以[请我喝杯咖啡](https://buymeacoffee.com/ahmedchemkC) ☕

## 许可证

[GPL-3.0](LICENSE)，与 Ditto 相同。
