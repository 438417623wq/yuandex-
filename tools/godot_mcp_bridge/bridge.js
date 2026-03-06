import express from 'express';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';

const BRIDGE_VERSION = '0.1.0';
const PORT = Number.parseInt(process.env.PORT ?? '8787', 10);
const BRIDGE_TOKEN = (process.env.BRIDGE_TOKEN ?? '').trim();

let client = null;
let transport = null;
let connectPromise = null;
let queue = Promise.resolve();

function splitArgs(raw) {
  const text = (raw ?? '').trim();
  if (!text) return [];
  return text.split(/\s+/).filter(Boolean);
}

function buildTransportConfig() {
  const command = (process.env.GODOT_MCP_COMMAND ?? 'node').trim();
  let args = [];
  const argsJson = (process.env.GODOT_MCP_ARGS_JSON ?? '').trim();
  if (argsJson) {
    try {
      const parsed = JSON.parse(argsJson);
      if (Array.isArray(parsed)) {
        args = parsed.map((item) => String(item));
      } else {
        throw new Error('GODOT_MCP_ARGS_JSON must be a JSON array');
      }
    } catch (error) {
      throw new Error(`Invalid GODOT_MCP_ARGS_JSON: ${error.message}`);
    }
  } else {
    args = splitArgs(process.env.GODOT_MCP_ARGS);
  }

  const entry = (process.env.GODOT_MCP_ENTRY ?? '').trim();
  if (entry && args.length === 0) {
    args = [entry];
  }

  if (command === 'node' && args.length === 0) {
    throw new Error(
      'Missing godot-mcp entrypoint. Set GODOT_MCP_ENTRY or GODOT_MCP_ARGS_JSON.',
    );
  }

  const env = {
    ...process.env,
  };
  return { command, args, env };
}

function enqueue(task) {
  const next = queue.then(task, task);
  queue = next.catch(() => {});
  return next;
}

async function ensureConnected() {
  if (client) return client;
  if (connectPromise) return connectPromise;

  connectPromise = (async () => {
    const transportConfig = buildTransportConfig();
    transport = new StdioClientTransport(transportConfig);
    client = new Client(
      {
        name: 'godot-mcp-http-bridge',
        version: BRIDGE_VERSION,
      },
      {
        capabilities: {},
      },
    );
    await client.connect(transport);
    return client;
  })();

  try {
    return await connectPromise;
  } catch (error) {
    client = null;
    transport = null;
    throw error;
  } finally {
    connectPromise = null;
  }
}

function normalizeError(error) {
  if (error instanceof Error) return error.message;
  return String(error);
}

async function closeClient() {
  const currentClient = client;
  client = null;
  transport = null;
  if (currentClient?.close) {
    try {
      await currentClient.close();
    } catch (_) {}
  }
}

function parseTokenFromRequest(req) {
  const direct = req.headers['x-bridge-token'];
  if (typeof direct === 'string' && direct.trim()) {
    return direct.trim();
  }
  const auth = req.headers.authorization;
  if (typeof auth === 'string' && auth.startsWith('Bearer ')) {
    return auth.slice(7).trim();
  }
  return '';
}

const app = express();
app.disable('x-powered-by');
app.use(express.json({ limit: '1mb' }));

app.use((req, res, next) => {
  if (!BRIDGE_TOKEN) {
    next();
    return;
  }
  const provided = parseTokenFromRequest(req);
  if (provided && provided === BRIDGE_TOKEN) {
    next();
    return;
  }
  res.status(401).json({
    ok: false,
    error: 'Unauthorized',
  });
});

app.get('/health', async (req, res) => {
  try {
    const toolsResult = await enqueue(async () => {
      const connected = await ensureConnected();
      return connected.listTools();
    });
    const tools = Array.isArray(toolsResult?.tools) ? toolsResult.tools : [];
    res.json({
      ok: true,
      bridge: `godot-mcp-http-bridge/${BRIDGE_VERSION}`,
      tool_count: tools.length,
      tools: tools.map((item) => item?.name).filter(Boolean),
    });
  } catch (error) {
    await closeClient();
    res.status(503).json({
      ok: false,
      bridge: `godot-mcp-http-bridge/${BRIDGE_VERSION}`,
      error: normalizeError(error),
    });
  }
});

app.get('/tools', async (req, res) => {
  try {
    const result = await enqueue(async () => {
      const connected = await ensureConnected();
      return connected.listTools();
    });
    res.json({
      ok: true,
      tools: result?.tools ?? [],
    });
  } catch (error) {
    await closeClient();
    res.status(500).json({
      ok: false,
      error: normalizeError(error),
    });
  }
});

app.post('/tool', async (req, res) => {
  const body = req.body ?? {};
  const name = typeof body.name === 'string' ? body.name.trim() : '';
  const args =
    body.arguments && typeof body.arguments === 'object' ? body.arguments : {};

  if (!name) {
    res.status(400).json({
      ok: false,
      error: 'Field "name" is required',
    });
    return;
  }

  try {
    const result = await enqueue(async () => {
      const connected = await ensureConnected();
      return connected.callTool({
        name,
        arguments: args,
      });
    });
    res.json({
      ok: true,
      result,
    });
  } catch (error) {
    await closeClient();
    res.status(500).json({
      ok: false,
      error: normalizeError(error),
      tool: name,
    });
  }
});

app.post('/reconnect', async (req, res) => {
  try {
    await closeClient();
    await ensureConnected();
    res.json({
      ok: true,
      message: 'Reconnected',
    });
  } catch (error) {
    res.status(500).json({
      ok: false,
      error: normalizeError(error),
    });
  }
});

const server = app.listen(PORT, '0.0.0.0', () => {
  // eslint-disable-next-line no-console
  console.log(`[bridge] listening on http://0.0.0.0:${PORT}`);
});

async function shutdown() {
  server.close();
  await closeClient();
}

process.on('SIGINT', async () => {
  await shutdown();
  process.exit(0);
});

process.on('SIGTERM', async () => {
  await shutdown();
  process.exit(0);
});
