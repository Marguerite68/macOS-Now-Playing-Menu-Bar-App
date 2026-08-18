# NowPlayingBar

一个原生 macOS 菜单栏应用：在菜单栏中显示当前正在播放的歌曲信息，让你无需切换到播放器也能快速查看曲目与歌手。

> **开发中（Work in Progress）**
>
> NowPlayingBar 仍处于积极开发阶段。功能、界面、支持的播放器及构建方式都可能调整；目前不建议将其用于依赖稳定性的生产环境。

## 功能概览

- 在菜单栏显示当前曲目、歌手或两者组合
- 支持 Apple Music 与 Spotify，并优先显示正在播放的内容
- 长文本可选择省略或滚动显示，提供循环与往返两种滚动方式
- 可调整菜单栏显示长度、滚动速度与字体粗细
- 左键打开歌曲详情，显示封面；右键进入设置或退出应用
- 设置会保存在本机，并在修改后即时生效
- 可选 Apple Music 音质标识：仅在能够可靠验证时显示 Lossless 或 Hi-Res

## 当前支持范围

macOS 目前没有面向第三方应用的统一公开 Now Playing 接口。因此，本项目通过 Apple Events / AppleScript 分别读取 Apple Music 和 Spotify 的播放状态。

- 支持：Apple Music、Spotify
- 暂不支持：Safari、YouTube 和其他网页或应用内播放器
- 两个播放器同时运行时，优先显示正在播放的一个；均暂停时优先 Apple Music

首次读取播放器信息时，macOS 可能要求授予“自动化”权限。拒绝该权限不会影响应用运行，但应用无法读取相应播放器的媒体信息。

Apple Music 音质识别默认关闭；启用后还需要在“系统设置 → 隐私与安全性 → 辅助功能”中授权 NowPlayingBar。该功能只读取播放控制区对辅助功能公开的文字信息，不操作播放器、不读取音频内容；无法验证时不会猜测音质。

## 运行项目

需要 macOS 13 或更高版本，以及 Apple Swift 工具链。

构建并启动应用：

```bash
./scripts/run-poc.sh
```

生成的应用位于：

```text
build/debug/NowPlayingBar.app
```

仅构建应用：

```bash
./scripts/build-app.sh debug
```

`Package.swift` 也可在安装 Xcode 后直接打开。项目的构建脚本不依赖完整 Xcode；`SwiftToolchainOverlay.yaml` 仅用于兼容部分 Command Line Tools 环境，不会修改系统工具链。

## 开发与反馈

欢迎通过 Issue 提交问题、功能建议或兼容性反馈。在提交代码前，建议运行与改动相关的检查脚本，例如：

```bash
./scripts/test-menu-label-size.sh
./scripts/test-preferences-layout.sh
```

内存回归检查可使用：

```bash
./scripts/memory-smoke.sh
```

## 许可协议

本项目采用 [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International（CC BY-NC-SA 4.0）](https://creativecommons.org/licenses/by-nc-sa/4.0/deed.zh-hans) 协议发布。

使用、复制、修改或再发布本项目时，必须遵守该协议：

- **署名（BY）**：保留对原项目及作者的恰当署名。
- **非商业性使用（NC）**：不得将本项目或其衍生内容用于商业目的。
- **相同方式共享（SA）**：发布衍生作品时，须以相同的 CC BY-NC-SA 协议授权。

本 README 仅为便于理解的摘要；完整且具有约束力的条款请以 [CC BY-NC-SA 4.0 正式许可文本](https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode.zh-hans) 为准。
