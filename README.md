# yuandex

Local-first mobile AI coding agent built with Flutter.

## Features

- Mobile chat-first coding assistant UI
- Project file browsing and editing
- Local Android runtime foundation
- Bottom terminal/debug panel
- Godot MCP bridge support

## Local Runtime

The project now includes a first-stage local Android runtime foundation:

- foreground runtime service
- local workspace mirroring
- Flutter runtime status panel

See [docs/local_android_runtime_plan.md](docs/local_android_runtime_plan.md).

## Godot MCP

Built-in `godot_*` tool hooks are available through the HTTP bridge:

- App -> `godot_mcp_bridge` -> `godot-mcp` -> Godot CLI

Bridge setup documentation:

- [tools/godot_mcp_bridge/README.md](tools/godot_mcp_bridge/README.md)

## Development

```bash
flutter pub get
flutter run
```

## License

[MIT License](LICENSE)
