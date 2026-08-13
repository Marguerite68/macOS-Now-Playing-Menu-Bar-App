# NowPlayingBar

原生 macOS 菜单栏媒体信息工具。当前版本完成 Phase 3 Scrolling UI，并实时读取正在运行的 Apple Music 或 Spotify。

## 当前实现

- 菜单栏最多显示字符数可配置（8–30 个字符）
- 使用 AppKit 字体度量测量文本实际宽度
- 可选择超出字符数后自动滚动，或使用省略号截断
- 支持首尾相接的无缝“循环”模式，以及在首尾停顿的“来回”模式
- 滚动速度可在 12–60 pt/s 之间调节
- 支持常规、中等、半粗和粗体四档菜单栏字体粗细
- 切换歌曲会移除旧动画并立即回到起点
- 左键状态栏打开详情页；右键显示带图标的“设置”和“退出”菜单
- 菜单栏使用原生 `NSStatusItem` 标题，确保歌名和歌手可靠显示
- 起点停留 1.4 秒、末尾停留 1 秒，默认速度 28 pt/s
- 播放器暂停时停止滚动并复位，恢复后从起点重新开始
- 每秒低频刷新 Music/Spotify 状态；只有媒体数据变化时才发布 UI 更新
- 独立偏好设置窗口，可选择显示内容并实时预览滚动效果
- 可设置未读取到媒体时隐藏菜单栏图标
- 左键详情页在右侧显示圆角歌曲封面；无法取得封面时显示占位图
- 显示设置通过 `UserDefaults` 持久化，并实时应用到菜单栏
- 可选的 Apple Music 音质识别，默认关闭；仅在 Music 当前播放控件提供可验证证据时显示 Lossless / Hi-Res 徽标
- 音质识别使用隔离的只读辅助功能 Provider，拒绝权限或无法验证时不会猜测音质，也不影响普通媒体信息显示
- Music 窗口关闭时会保留同一首已验证曲目的音质；后台切歌时，应用会通过 Music 的公开脚本接口维持一个最小化浏览器窗口，使辅助功能仍有当前播放控件可读
- 音质徽标优先在运行时读取本机 Music.app 的模板资源，不随应用分发；资源不可用或系统版本改名时自动使用自绘徽标

## 实时媒体来源

macOS 没有公开 API 可供第三方应用统一读取其他 App 的系统 Now Playing 信息。因此当前版本按照项目 spec 的优先级，使用 Apple Events/AppleScript：

1. 读取 Apple Music
2. 读取 Spotify
3. 如果两者均未播放，则显示空闲状态 `♫ —`

如果两个播放器都在运行，优先显示正在播放的一个；都暂停时优先 Music。Safari、YouTube 等来源需要后续经过验证的 Provider，当前版本不使用私有 MediaRemote。

首次读取 Music 或 Spotify 时，macOS 可能弹出“自动化”权限请求。拒绝权限不会导致应用崩溃，但对应播放器无法读取。

Apple Music 在线音质识别需在设置中主动开启，并在“系统设置 → 隐私与安全性 → 辅助功能”中授权 NowPlayingBar。该功能只读取 Music 播放控制区公开给辅助功能的文字属性；不会操作播放、读取音频内容或以输出设备格式推断源音质。当前 Music 若只公开通用 Lossless 标识而未公开 Hi-Res 或分辨率，应用也只显示能够验证的部分。

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

菜单栏尺寸和显示模式回归检查：

```bash
./scripts/test-menu-label-size.sh
```

## 工具链说明

当前构建脚本直接调用 Apple Swift 编译器，避免依赖完整 Xcode；`Package.swift` 可在安装 Xcode 后直接打开。

`SwiftToolchainOverlay.yaml` 只用于规避部分 Command Line Tools 安装中重复的 `SwiftBridging` module map，不会修改系统工具链。使用完整 Xcode 构建时不需要这个兼容层。
