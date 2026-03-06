# Godot MCP HTTP Bridge

这个目录提供一个轻量网关，把手机端 HTTP 请求转发到 `godot-mcp` 的 stdio MCP 服务。

## 适用场景

- 手机端 Flutter App 无法直接 `spawn` 本地 `godot --headless`
- 你希望在 PC/服务器上运行 Godot + `godot-mcp`，手机端远程调用

## 1) 准备 `godot-mcp`

```powershell
cd F:\ai\mmmmmmm\godot-mcp
npm install
npm run build
```

## 2) 启动桥接服务

```powershell
cd F:\ai\mmmmmmm\ai_mobile_coder_ui\tools\godot_mcp_bridge
npm install

$env:GODOT_MCP_ENTRY="F:\ai\mmmmmmm\godot-mcp\build\index.js"
$env:GODOT_PATH="C:\Program Files\Godot\Godot_v4.4-stable_win64.exe"
$env:PORT="8787"
$env:BRIDGE_TOKEN="replace_me_optional"

npm start
```

可选变量：

- `GODOT_MCP_COMMAND`：默认 `node`
- `GODOT_MCP_ARGS_JSON`：覆盖参数数组，例如 `["D:\\godot-mcp\\build\\index.js"]`
- `GODOT_MCP_ARGS`：空格分隔参数（不建议含空格路径时使用）

## 3) 健康检查

```powershell
curl -H "x-bridge-token: replace_me_optional" http://127.0.0.1:8787/health
```

## 4) 调用工具示例

```powershell
curl -X POST http://127.0.0.1:8787/tool `
  -H "Content-Type: application/json" `
  -H "x-bridge-token: replace_me_optional" `
  -d "{\"name\":\"get_godot_version\",\"arguments\":{}}"
```

## 5) 在 App 内配置

- 打开设置 -> 项目文件 -> `Godot MCP 网关`
- 打开“启用 Godot MCP 远程工具”
- 地址填 `http://<桥接机IP>:8787`
- Token 填 `BRIDGE_TOKEN`
- 点“检测网关连通性”

## 重要限制

- Android 上安装 Godot App 不等于可用 `godot --headless` CLI。
- `godot-mcp` 的项目路径是“桥接主机上的路径”，不是手机文件系统路径。
