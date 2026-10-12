<p align="center">
  <img src="Assets/AppIcon-source.png" width="128" alt="DogSwitch 图标">
</p>

<h1 align="center">DogSwitch</h1>

<p align="center">
  住在 macOS 菜单栏里的默认浏览器切换器 🐶
</p>

<p align="center">
  <a href="https://github.com/leonzone/browser-switcher/releases/latest"><img src="https://img.shields.io/github/v/release/leonzone/browser-switcher" alt="Release"></a>
  <img src="https://img.shields.io/badge/macOS-12%2B-blue" alt="macOS 12+">
  <img src="https://img.shields.io/badge/Swift-5-orange" alt="Swift">
  <img src="https://img.shields.io/badge/依赖-零-green" alt="零依赖">
</p>

---

DogSwitch 是一个原生 macOS 菜单栏应用。点击菜单栏上的柯基图标，从列表中选择浏览器，即可一键切换系统的 HTTP / HTTPS 默认浏览器——不用再翻系统设置。

## ✨ 特性

- 🖱 **一键切换**：菜单栏点两下，同时切换 HTTP 和 HTTPS 默认浏览器
- 🔄 **状态实时刷新**：每次打开菜单都会重新读取系统实际默认设置，勾选状态永远真实
- 🧩 **双协议独立处理**：HTTP 与 HTTPS 指向不同浏览器时分别显示、分别补齐
- 🛡 **失败不隐瞒**：取消系统确认或部分失败时如实提示当前状态，可再次选择完成剩余切换
- 🪶 **纯菜单栏应用**：无主窗口、无 Dock 图标，零第三方依赖

## 📥 下载安装

从 [Releases](https://github.com/leonzone/browser-switcher/releases/latest) 下载最新的 `DogSwitch-vX.Y.Z.zip`：

1. 解压 zip，将 `DogSwitch.app` 拖入「应用程序」
2. 首次打开如提示"无法验证开发者"，前往 **系统设置 → 隐私与安全性**，点击"仍要打开"
   （当前版本为 ad-hoc 签名，未做 Developer ID 公证）
3. 点击菜单栏上的柯基图标开始使用

要求 **macOS 12 或更高版本**。

## 🚀 使用

1. 点击菜单栏柯基图标
2. 菜单顶部显示当前默认浏览器（勾选项）；HTTP 与 HTTPS 不一致时会分行显示
3. 选择目标浏览器，在系统弹窗中完成确认
4. 再次打开菜单即可看到切换结果

> 切换的是系统默认浏览器，只影响遵循系统设置的链接。应用内置浏览器或指定浏览器的操作不受影响。

### 支持的浏览器

| 浏览器 | Bundle ID |
| --- | --- |
| Google Chrome | `com.google.Chrome` |
| Tabbit | `com.tabbit-ai.Tabbit` |
| Tabbit Browser | `com.tab-browser.Tabbit` |
| ego lite | `com.citrolabs.ego.lite` |
| Safari | `com.apple.Safari` |

两个 Tabbit 是不同 Bundle ID 的独立应用，会分别展示。列表只包含实际已安装的浏览器。

## 🛠 从源码构建

需要 macOS 12+ 和 Apple Command Line Tools（含 Swift），无第三方依赖：

```sh
git clone git@github.com:leonzone/browser-switcher.git
cd browser-switcher
bash scripts/build-app.sh
open dist/DogSwitch.app
```

构建脚本会编译 release 版本、生成图标资源、组装 `dist/DogSwitch.app` 并进行 ad-hoc 签名。

## ✅ 测试

```sh
swift run BrowserSwitcherCoreTests
```

测试通过替身（fake）模拟系统行为，**不会修改本机默认浏览器**。采用独立 Swift 断言程序，失败返回非零退出码，仅需 Command Line Tools，不依赖 XCTest。真实切换的验证状态见 [ROADMAP.md](ROADMAP.md)。

## 📁 项目结构

```
Sources/BrowserSwitcherCore/   浏览器模型与切换协调（纯逻辑，可测试）
Sources/BrowserSwitcher/       AppKit 菜单栏应用与 macOS 系统适配
Tests/BrowserSwitcherCoreTests/ 使用 fake 系统访问的确定性测试
scripts/build-app.sh           本地构建打包脚本
Assets/                        图标原图与生成记录
```

## 🎨 图标

`Assets/AppIcon-source.png` 为柯基应用图标原图，`Assets/StatusIcon-source.png` 为菜单栏单色图标原图。打包时自动生成 16–1024px 的 `AppIcon.icns` 和 18/36px 菜单栏 template 图标（随系统外观自动着色）。
