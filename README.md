# DogSwitch

原生 macOS 菜单栏应用。点击右上角柯基图标，选择已安装的浏览器，即可请求切换 HTTP 和 HTTPS 默认浏览器。macOS 可能要求确认，完成确认后应用才会根据系统实际设置显示成功。

支持 Google Chrome、Tabbit、Tabbit Browser、ego lite、Safari。两个 Tabbit 是不同 Bundle ID 的独立应用，分别展示。不会展示其他应用或缓存中的测试浏览器。

## 构建与启动

需要 macOS 12 或更新版本，以及包含 Swift 的 Apple Command Line Tools。无第三方依赖。本地脚本构建当前机器架构，并使用临时签名，不包含 Developer ID 签名或公证。

```sh
swift run BrowserSwitcherCoreTests
bash scripts/build-app.sh
open dist/DogSwitch.app
```

构建产物为 `dist/DogSwitch.app`。应用仅驻留菜单栏，无主窗口和 Dock 图标，可从菜单选择「退出」。也可以自行将应用复制到「应用程序」目录。

## 使用

1. 点击菜单栏柯基图标。
2. 勾选项代表 HTTP 和 HTTPS 均已使用的默认浏览器。
3. 选择目标浏览器，在系统要求时完成确认。
4. 再次打开菜单，查看实际默认状态及切换结果。

每次打开菜单都会刷新已安装浏览器和默认设置。若 HTTP 与 HTTPS 指向不同应用，菜单会分别显示。取消或部分失败会保留系统实际状态并提示，不自动回滚；可再次选择目标完成剩余协议的切换。

首版不修改 HTML 文件关联，不提供开机自启、自动更新或链接代理功能。默认浏览器只影响遵循系统默认设置的链接，应用内置浏览器或明确指定浏览器的操作不受影响。

## 验证

自动测试通过替身模拟系统行为，不修改本机默认浏览器。采用独立 Swift 断言程序，失败返回非零退出码；仅安装 Command Line Tools 即可运行，不依赖 XCTest。真实切换需单独授权并人工完成系统确认；当前验证状态见 `ROADMAP.md`。

## 图标资源

`Assets/AppIcon-source.png` 为柯基应用图标原图，`Assets/StatusIcon-source.png` 为柯基菜单栏单色原图。当前图像由用户提供，分别来自项目 `tmp/App Icon.png` 和 `tmp/Menu Bar Icon.png`，原始尺寸均为 1254×1254，保留透明通道。此前版本的提示词保存在 `Assets/PROMPTS.md`，不代表当前素材的实际生成记录。

打包时自动生成包含 16 至 1024 像素规格的 `AppIcon.icns`，以及 18／36 像素菜单栏图标。菜单栏图标使用 AppKit template 着色，随系统外观和选中状态适配。修改后重新打包并退出、重开应用即可加载新图标。
