# AI Mobile Coder UI

移动端 AI 编程助手（Flutter）。

## 功能

- 移动端聊天式编程助手 UI
- 项目文件读写工具集成（可选授权）
- 终端调试面板
- Godot MCP 网关接入能力

## Godot MCP 集成

已内置 `godot_*` 工具调用入口，链路如下：

- App（手机） -> `godot_mcp_bridge`（HTTP） -> `godot-mcp`（stdio） -> Godot CLI

桥接服务文档：

- [tools/godot_mcp_bridge/README.md](tools/godot_mcp_bridge/README.md)

## 本地开发

```bash
flutter pub get
flutter run
```

## 开源协作

欢迎提交 Issue 和 PR。提交前建议：

- 先描述复现步骤或需求背景
- 变更尽量小而清晰
- 提交前执行 `flutter analyze`

## License

本项目采用 [MIT License](LICENSE)。
