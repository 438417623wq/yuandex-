class LocalRuntimeStatusSnapshot {
  const LocalRuntimeStatusSnapshot({
    required this.supported,
    required this.isRunning,
    this.runtimeRoot = '',
    this.workspacesRoot = '',
    this.activeWorkspaceId = '',
    this.activeWorkspacePath = '',
    this.lastPreparedProjectPath = '',
    this.lastError = '',
    this.mirroredFileCount = 0,
    this.mirroredDirectoryCount = 0,
    this.shellRunning = false,
    this.shellWorkingDirectory = '',
    this.shellLastError = '',
  });

  const LocalRuntimeStatusSnapshot.unsupported()
    : supported = false,
      isRunning = false,
      runtimeRoot = '',
      workspacesRoot = '',
      activeWorkspaceId = '',
      activeWorkspacePath = '',
      lastPreparedProjectPath = '',
      lastError = '',
      mirroredFileCount = 0,
      mirroredDirectoryCount = 0,
      shellRunning = false,
      shellWorkingDirectory = '',
      shellLastError = '';

  final bool supported;
  final bool isRunning;
  final String runtimeRoot;
  final String workspacesRoot;
  final String activeWorkspaceId;
  final String activeWorkspacePath;
  final String lastPreparedProjectPath;
  final String lastError;
  final int mirroredFileCount;
  final int mirroredDirectoryCount;
  final bool shellRunning;
  final String shellWorkingDirectory;
  final String shellLastError;

  bool get hasWorkspace => activeWorkspacePath.trim().isNotEmpty;

  String get summary {
    if (!supported) return 'Local runtime is not supported on this platform.';
    if (!isRunning) return 'Local runtime is stopped.';
    if (!hasWorkspace) {
      return 'Local runtime is running. Workspace mirror not prepared.';
    }
    return 'Local runtime is running with a mirrored workspace.';
  }

  LocalRuntimeStatusSnapshot copyWith({
    bool? supported,
    bool? isRunning,
    String? runtimeRoot,
    String? workspacesRoot,
    String? activeWorkspaceId,
    String? activeWorkspacePath,
    String? lastPreparedProjectPath,
    String? lastError,
    int? mirroredFileCount,
    int? mirroredDirectoryCount,
    bool? shellRunning,
    String? shellWorkingDirectory,
    String? shellLastError,
  }) {
    return LocalRuntimeStatusSnapshot(
      supported: supported ?? this.supported,
      isRunning: isRunning ?? this.isRunning,
      runtimeRoot: runtimeRoot ?? this.runtimeRoot,
      workspacesRoot: workspacesRoot ?? this.workspacesRoot,
      activeWorkspaceId: activeWorkspaceId ?? this.activeWorkspaceId,
      activeWorkspacePath: activeWorkspacePath ?? this.activeWorkspacePath,
      lastPreparedProjectPath:
          lastPreparedProjectPath ?? this.lastPreparedProjectPath,
      lastError: lastError ?? this.lastError,
      mirroredFileCount: mirroredFileCount ?? this.mirroredFileCount,
      mirroredDirectoryCount:
          mirroredDirectoryCount ?? this.mirroredDirectoryCount,
      shellRunning: shellRunning ?? this.shellRunning,
      shellWorkingDirectory:
          shellWorkingDirectory ?? this.shellWorkingDirectory,
      shellLastError: shellLastError ?? this.shellLastError,
    );
  }

  static LocalRuntimeStatusSnapshot fromMap(Map<Object?, Object?> map) {
    int readInt(String key) {
      final value = map[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse('${value ?? ''}') ?? 0;
    }

    bool readBool(String key) {
      final value = map[key];
      if (value is bool) return value;
      final text = '${value ?? ''}'.trim().toLowerCase();
      return text == 'true' || text == '1';
    }

    String readString(String key) => '${map[key] ?? ''}'.trim();

    return LocalRuntimeStatusSnapshot(
      supported: readBool('supported'),
      isRunning: readBool('isRunning'),
      runtimeRoot: readString('runtimeRoot'),
      workspacesRoot: readString('workspacesRoot'),
      activeWorkspaceId: readString('activeWorkspaceId'),
      activeWorkspacePath: readString('activeWorkspacePath'),
      lastPreparedProjectPath: readString('lastPreparedProjectPath'),
      lastError: readString('lastError'),
      mirroredFileCount: readInt('mirroredFileCount'),
      mirroredDirectoryCount: readInt('mirroredDirectoryCount'),
      shellRunning: readBool('shellRunning'),
      shellWorkingDirectory: readString('shellWorkingDirectory'),
      shellLastError: readString('shellLastError'),
    );
  }
}

class LocalShellSnapshot {
  const LocalShellSnapshot({
    required this.supported,
    required this.isRunning,
    this.workingDirectory = '',
    this.lastError = '',
    this.lines = const <String>[],
  });

  const LocalShellSnapshot.empty()
    : supported = false,
      isRunning = false,
      workingDirectory = '',
      lastError = '',
      lines = const <String>[];

  final bool supported;
  final bool isRunning;
  final String workingDirectory;
  final String lastError;
  final List<String> lines;

  static LocalShellSnapshot fromMap(Map<Object?, Object?> map) {
    bool readBool(String key) {
      final value = map[key];
      if (value is bool) return value;
      final text = '${value ?? ''}'.trim().toLowerCase();
      return text == 'true' || text == '1';
    }

    String readString(String key) => '${map[key] ?? ''}'.trim();

    List<String> readLines(String key) {
      final value = map[key];
      if (value is List) {
        return value.map((item) => item.toString()).toList();
      }
      return const <String>[];
    }

    return LocalShellSnapshot(
      supported: readBool('supported'),
      isRunning: readBool('isRunning'),
      workingDirectory: readString('workingDirectory'),
      lastError: readString('lastError'),
      lines: readLines('lines'),
    );
  }
}
