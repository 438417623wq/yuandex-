# Local Android Runtime Plan

## Goal

Build a fully local Android coding agent on top of this Flutter project.
The app should feel close to Codex-style coding workflows while staying
inside the phone:

- local chat + tool loop
- local workspace mirror
- local terminal runtime
- local diff / patch / rollback flow
- optional local LLM backends

## Reference Direction

- `doge-code`: strong CLI and coding-agent interaction model
- `Operit`: strong Android-local runtime direction

This project should combine those ideas with a Flutter-first mobile UI.

## Product Shape

### UI Layer

Keep Flutter responsible for:

- conversations
- model/provider settings
- workspace browser
- runtime status
- diff preview
- command output
- patch approval

### Runtime Layer

Add an Android-local runtime responsible for:

- foreground service lifecycle
- private runtime storage
- mirrored workspaces
- PTY terminal sessions
- local tool execution
- local model bridge

### Workspace Strategy

Use a dual-workspace model:

1. external source folder selected by the user
2. internal mirrored workspace under app-private storage

The internal mirror becomes the default execution target for:

- shell commands
- git operations
- code search
- patch apply
- tests and builds

## Delivery Stages

### Stage 1

Establish the local-runtime foundation:

- runtime design doc
- Android foreground runtime service
- runtime status bridge to Flutter
- local mirrored workspace preparation

### Stage 2

Upgrade the fake terminal to a real local execution surface:

- PTY-backed shell sessions
- streamed stdout/stderr
- session lifecycle management

### Stage 3

Move coding actions into a true local agent loop:

- `run_command`
- `search_code`
- `git_status`
- `git_diff`
- `apply_patch`
- `run_tests`

### Stage 4

Add local intelligence backends:

- `llama.cpp`
- optional MNN-based mobile models
- model capability routing

## First Implementation Rules

- Android only for the local-runtime path
- keep Flutter as orchestration UI, not the runtime core
- keep workspace execution inside private app storage
- prefer explicit status reporting over hidden background work
- keep room for a future localhost daemon or Unix socket bridge

## Files Introduced In Stage 1

- `android/.../LocalRuntimeService.kt`
- `android/.../LocalRuntimeManager.kt`
- `lib/src/local_runtime.dart`
- runtime section in the settings drawer

## Near-Term Next Steps

1. Add PTY shell support.
2. Add streamed runtime logs in the bottom terminal panel.
3. Bind AI tool calls to the local runtime instead of the in-memory mock terminal.
4. Add diff preview before applying mirrored changes back to the source folder.
