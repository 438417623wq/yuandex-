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
    if (!supported) return '当前平台不支持本地运行时。';
    if (!isRunning) return '本地运行时未启动。';
    if (!hasWorkspace) {
      return '本地运行时已启动，但还没有准备工作区镜像。';
    }
    return '本地运行时已启动，并且工作区镜像已就绪。';
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

class RuntimeBackendStatusSnapshot {
  const RuntimeBackendStatusSnapshot({
    required this.supported,
    this.nativeAvailable = false,
    this.termuxInstalled = false,
    this.termuxPermissionGranted = false,
    this.termuxLaunchable = false,
    this.rootAvailable = false,
    this.shizukuInstalled = false,
    this.shizukuLaunchable = false,
    this.systemLogcatAvailable = false,
    this.lastError = '',
  });

  const RuntimeBackendStatusSnapshot.empty()
    : supported = false,
      nativeAvailable = false,
      termuxInstalled = false,
      termuxPermissionGranted = false,
      termuxLaunchable = false,
      rootAvailable = false,
      shizukuInstalled = false,
      shizukuLaunchable = false,
      systemLogcatAvailable = false,
      lastError = '';

  final bool supported;
  final bool nativeAvailable;
  final bool termuxInstalled;
  final bool termuxPermissionGranted;
  final bool termuxLaunchable;
  final bool rootAvailable;
  final bool shizukuInstalled;
  final bool shizukuLaunchable;
  final bool systemLogcatAvailable;
  final String lastError;

  bool get termuxReady => termuxInstalled && termuxPermissionGranted;

  static RuntimeBackendStatusSnapshot fromMap(Map<Object?, Object?> map) {
    bool readBool(String key) {
      final value = map[key];
      if (value is bool) return value;
      final text = '${value ?? ''}'.trim().toLowerCase();
      return text == 'true' || text == '1';
    }

    String readString(String key) => '${map[key] ?? ''}'.trim();

    return RuntimeBackendStatusSnapshot(
      supported: readBool('supported'),
      nativeAvailable: readBool('nativeAvailable'),
      termuxInstalled: readBool('termuxInstalled'),
      termuxPermissionGranted: readBool('termuxPermissionGranted'),
      termuxLaunchable: readBool('termuxLaunchable'),
      rootAvailable: readBool('rootAvailable'),
      shizukuInstalled: readBool('shizukuInstalled'),
      shizukuLaunchable: readBool('shizukuLaunchable'),
      systemLogcatAvailable: readBool('systemLogcatAvailable'),
      lastError: readString('lastError'),
    );
  }
}

class EmbeddedDevToolkitStatusSnapshot {
  const EmbeddedDevToolkitStatusSnapshot({
    required this.supported,
    this.workspaceRoot = '',
    this.gitAvailable = false,
    this.jadxAvailable = false,
    this.apkSigAvailable = false,
    this.gitVersionLabel = '',
    this.jadxVersionLabel = '',
    this.apkSigVersionLabel = '',
    this.lastError = '',
  });

  const EmbeddedDevToolkitStatusSnapshot.empty()
    : supported = false,
      workspaceRoot = '',
      gitAvailable = false,
      jadxAvailable = false,
      apkSigAvailable = false,
      gitVersionLabel = '',
      jadxVersionLabel = '',
      apkSigVersionLabel = '',
      lastError = '';

  final bool supported;
  final String workspaceRoot;
  final bool gitAvailable;
  final bool jadxAvailable;
  final bool apkSigAvailable;
  final String gitVersionLabel;
  final String jadxVersionLabel;
  final String apkSigVersionLabel;
  final String lastError;

  bool get ready => supported && (gitAvailable || jadxAvailable || apkSigAvailable);

  static EmbeddedDevToolkitStatusSnapshot fromMap(Map<Object?, Object?> map) {
    bool readBool(String key) {
      final value = map[key];
      if (value is bool) return value;
      final text = '${value ?? ''}'.trim().toLowerCase();
      return text == 'true' || text == '1';
    }

    String readString(String key) => '${map[key] ?? ''}'.trim();

    return EmbeddedDevToolkitStatusSnapshot(
      supported: readBool('supported'),
      workspaceRoot: readString('workspaceRoot'),
      gitAvailable: readBool('gitAvailable'),
      jadxAvailable: readBool('jadxAvailable'),
      apkSigAvailable: readBool('apkSigAvailable'),
      gitVersionLabel: readString('gitVersionLabel'),
      jadxVersionLabel: readString('jadxVersionLabel'),
      apkSigVersionLabel: readString('apkSigVersionLabel'),
      lastError: readString('lastError'),
    );
  }
}
