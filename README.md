# Nobig Agent

可安装的 Flutter Android 客户端骨架，连接 PC 上的单 Agent，提供原生会话列表、连接配置、聊天和设置页面。PC 执行任务，手机负责交互。

## v0.1.0

- 原生 Flutter 页面，无 WebView。
- PC 服务地址与连接 Token 配置；凭据使用系统安全存储。
- DSH rc.2 HTTP RPC / WebSocket 基础适配：会话列表、新建、文本发送、实时订阅、停止。
- 明确标注的本地演示：无需 PC 即可体验页面、模拟消息和停止操作。
- 浅色、深色和跟随系统主题。

第一步仅交付手机客户端。PC Agent 引擎和公网访问通道由外部服务提供。[连接说明](docs/connection.md)列出了兼容范围及限制。

## 在手机上体验

将生成的 `app-debug.apk` 传到 Android 手机上安装。打开「设置 → 体验本地演示」，即可查看会话、发送模拟消息和停止回复。

连接真实 PC 时，在「电脑」页填写 DSH 服务地址和连接 Token，再进入会话页。外出连接前需要先配置手机可访问的 HTTPS 地址或 VPN，详见[连接说明](docs/connection.md)。

## 开发与构建

环境：Flutter 3.47.8 stable / Dart 3.13.7、JDK 21、Android SDK 36；最低 Android API 24。

```sh
flutter pub get
flutter run
```

验证与生成 APK：

```sh
dart format lib test tool
flutter analyze
flutter test
flutter build apk --debug
```

APK：`build/app/outputs/flutter-apk/app-debug.apk`。CI 工作流也会生成同名 debug APK artifact。Debug 包用于开发验证，正式分发前需要自行配置稳定签名。

本次静态检查、16 项测试和 APK 构建均通过。安装包信息、本机工具链用法及尚未验证的项目见[验证记录](docs/verification.md)。

## 代码结构

```text
lib/
  main.dart                 应用启动
  app.dart                  原生导航与主题
  app_controller.dart       连接、会话、发送和生命周期状态
  domain/models.dart        不依赖 UI 的数据类型
  data/agent_gateway.dart   可替换的 PC Agent 接口
  data/dsh_gateway.dart     DSH 网络协议
  data/dsh_transcript.dart  会话事件归并
  data/demo_gateway.dart    显式本地模拟
  data/settings_store.dart  本机设置与凭据存储
  ui/                       会话、电脑、聊天和设置页面
```

参考了 shiyi-agent 的客户端/PC 服务分工与公开连接协议，当前客户端为独立实现。后续接入其他 PC 引擎时，实现 `AgentGateway` 即可沿用现有页面。
