# NowPlayingBar

原生 macOS 菜单栏媒体信息工具。当前版本完成 Phase 3 Scrolling UI，并实时读取正在运行的 Apple Music 或 Spotify。

## 当前实现

- 菜单栏文本最大可视宽度为 230 px
- 使用 AppKit 字体度量测量文本实际宽度
- 只有超出最大宽度的文本才自动滚动
- 切换歌曲和手动重置会立即回到起点
- 使用单个 Core Animation 图层平滑移动，不逐帧重建 SwiftUI 菜单栏标签
- 起点停留 1.4 秒、末尾停留 1 秒，速度 28 px/s
- 播放器暂停时冻结滚动位置，恢复后从原位置继续
- 每秒低频刷新 Music/Spotify 状态；只有媒体数据变化时才发布 UI 更新

## 实时媒体来源

macOS 没有公开 API 可供第三方应用统一读取其他 App 的系统 Now Playing 信息。因此当前版本按照项目 spec 的优先级，使用 Apple Events/AppleScript：

1. 读取 Apple Music
2. 读取 Spotify
3. 如果两者均未播放，则显示空闲状态 `♫ —`

如果两个播放器都在运行，优先显示正在播放的一个；都暂停时优先 Music。Safari、YouTube 等来源需要后续经过验证的 Provider，当前版本不使用私有 MediaRemote。

首次读取 Music 或 Spotify 时，macOS 可能弹出“自动化”权限请求。拒绝权限不会导致应用崩溃，但对应播放器无法读取。

## 运行

需要 macOS 13 或更高版本：

```bash
./scripts/run-poc.sh
```

脚本会构建并启动：

```text
build/debug/NowPlayingBar.app
```

仅构建 `.app`：

```bash
./scripts/build-app.sh debug
```

## 内存回归检查

```bash
./scripts/memory-smoke.sh
```

按提示点击、关闭并重新打开菜单栏面板。脚本会采样 15 秒 RSS；峰值超过 512 MB 或增长超过 100 MB 时失败。

## 工具链说明

当前构建脚本直接调用 Apple Swift 编译器，避免依赖完整 Xcode；`Package.swift` 可在安装 Xcode 后直接打开。

`SwiftToolchainOverlay.yaml` 只用于规避部分 Command Line Tools 安装中重复的 `SwiftBridging` module map，不会修改系统工具链。使用完整 Xcode 构建时不需要这个兼容层。
