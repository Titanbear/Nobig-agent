# v0.1.0 验证记录

日期：2026-10-26。环境：Windows、Flutter 3.47.8 stable、Dart 3.13.7、JDK 21、Android SDK 36。

## 已执行

| 检查 | 结果 |
| --- | --- |
| `dart format lib test tool` | 20 个文件，格式无变更 |
| `flutter analyze --no-pub` | No issues found |
| `flutter test --no-pub` | 16 项通过 |
| `flutter test --no-pub tool/preview_test.dart` | 1 项通过；连接页和聊天页截图已检查 |
| `flutter build apk --debug --no-pub --verbose` | BUILD SUCCESSFUL，APK 已生成 |
| `apksigner verify --verbose` | Verifies，v2 签名通过 |

测试覆盖原生页面导航、小屏和键盘布局、演示消息与停止、连接地址校验、连接切换、HTTP/Cookie 认证、RPC、WebSocket 会话事件归并及断线处理。协议测试使用本地服务夹具。

## 安装包

- 路径：`build/app/outputs/flutter-apk/app-debug.apk`
- 应用名：Nobig Agent
- 包名：`dev.nobig.nobig_agent`
- 版本：`0.1.0+1`
- 最低系统：Android 7.0 / API 24；目标 API 36
- 架构：arm64-v8a、armeabi-v7a、x86_64
- 文件大小：161,806,113 字节
- SHA-256：`A76B3387DC54CDDC65132BDF126E36F1FC687566FD60D0E5AF00C8636A9D53E1`

当前为开发调试包，使用 debug 签名。尚未执行 Android 真机安装测试，也未使用真实 PC 服务地址进行局域网或公网联调。CI 工作流已提供，未在 GitHub 上运行。

## 本机开发环境

工具链位于 `%LOCALAPPDATA%\NobigAgent\toolchains`，未修改全局 PATH。终端找不到 Flutter 时，可以在仓库目录执行：

```powershell
$toolsRoot = Join-Path $env:LOCALAPPDATA 'NobigAgent\toolchains'
$env:JAVA_HOME = Join-Path $toolsRoot 'jdk-21.0.13.0.2+1'
$env:ANDROID_HOME = Join-Path $toolsRoot 'android-sdk'
& (Join-Path $toolsRoot 'flutter-stable\bin\flutter.bat') build apk --debug
```

本机的 Dart 分析器在中文路径下出现工具崩溃，因此静态分析通过指向同一仓库的 `toolchains\nobig-client` 目录别名运行。测试和 Android 构建使用仓库原路径；Windows 目录别名会导致本机打包工具复制资源失败。
