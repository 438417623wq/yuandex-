import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_runtime.dart';
import 'models.dart';
import 'theme.dart';

class WorkbenchPage extends StatefulWidget {
  const WorkbenchPage({super.key});

  @override
  State<WorkbenchPage> createState() => _WorkbenchPageState();
}

class _WorkbenchPageState extends State<WorkbenchPage> {
  static const MethodChannel _storageChannel = MethodChannel(
    'ai_mobile_coder_ui/storage_access',
  );
  static const MethodChannel _backgroundGuardChannel = MethodChannel(
    'ai_mobile_coder_ui/background_guard',
  );
  static const MethodChannel _localRuntimeChannel = MethodChannel(
    'ai_mobile_coder_ui/local_runtime',
  );
  static const MethodChannel _runtimeBackendsChannel = MethodChannel(
    'ai_mobile_coder_ui/runtime_backends',
  );
  static const MethodChannel _embeddedDevToolkitChannel = MethodChannel(
    'ai_mobile_coder_ui/embedded_dev_toolkit',
  );
  static const String _defaultAssistantGreeting =
      '你好，我是你的移动端 AI 编程助手。先告诉我你想修改什么，我会给出补丁建议。';
  static const String _defaultConversationTitle = '新消息';
  static const String _prefsMessages = 'state.messages.v1';
  static const String _prefsTerminalLogs = 'state.terminal.logs.v1';
  static const String _prefsProjectRoot = 'state.project.root.v1';
  static const String _prefsProjectContext = 'state.project.context.v1';
  static const String _prefsAiFsGranted = 'state.project.fsGranted.v1';
  static const String _prefsShowTerminal = 'state.terminal.show.v1';
  static const String _prefsProviderConfigs = 'state.provider.configs.v1';
  static const String _prefsActiveProviderId = 'state.provider.activeId.v1';
  static const String _prefsApiConnections = 'state.api.connections.v1';
  static const String _prefsActiveConnectionId =
      'state.api.activeConnectionId.v1';
  static const String _prefsConversationTitle = 'state.chat.title.v1';
  static const String _prefsConversationHistory = 'state.chat.history.v1';
  static const String _prefsActiveConversationId = 'state.chat.activeId.v1';
  static const String _prefsActiveConversationPinned =
      'state.chat.activePinned.v1';
  static const String _prefsApiConnectionsCollapsed = 'state.api.collapsed.v1';
  static const String _prefsSettingsExpandedSections =
      'state.settings.expandedSections.v1';
  static const String _prefsReplyStructureSections =
      'state.reply.structure.sections.v1';
  static const String _prefsGodotMcpEnabled = 'state.godotMcp.enabled.v1';
  static const String _prefsGodotMcpBridgeUrl = 'state.godotMcp.bridgeUrl.v1';
  static const String _prefsGodotMcpBridgeToken =
      'state.godotMcp.bridgeToken.v1';
  static const String _prefsDownloadAssetMaxBytes =
      'state.download.asset.maxBytes.v1';
  static const String _prefsBackgroundGuardEnabled =
      'state.background.guard.enabled.v1';
  static const String _prefsAndroidToolkitApkPath =
      'state.androidToolkit.apkPath.v1';
  static const String _prefsAndroidToolkitReverseLabel =
      'state.androidToolkit.reverseLabel.v1';
  static const String _prefsAndroidToolkitJadxQuery =
      'state.androidToolkit.jadxQuery.v1';
  static const String _prefsAndroidToolkitGradleTask =
      'state.androidToolkit.gradleTask.v1';
  static const String _prefsAndroidToolkitInstallApkPath =
      'state.androidToolkit.installApkPath.v1';
  static const String _prefsAndroidToolkitLogcatFilter =
      'state.androidToolkit.logcatFilter.v1';
  static const String _prefsAndroidToolkitKeystorePath =
      'state.androidToolkit.keystorePath.v1';
  static const String _prefsAndroidToolkitKeystoreAlias =
      'state.androidToolkit.keystoreAlias.v1';
  static const String _prefsAndroidToolkitStorePassword =
      'state.androidToolkit.storePassword.v1';
  static const String _prefsAndroidToolkitKeyPassword =
      'state.androidToolkit.keyPassword.v1';
  static const String _prefsAndroidToolkitAdbCommand =
      'state.androidToolkit.adbCommand.v1';
  static const String _prefsAndroidToolkitApktoolCommand =
      'state.androidToolkit.apktoolCommand.v1';
  static const String _prefsAndroidToolkitJadxCommand =
      'state.androidToolkit.jadxCommand.v1';
  static const String _prefsAndroidToolkitApksignerCommand =
      'state.androidToolkit.apksignerCommand.v1';
  static const String _prefsAndroidToolkitZipalignCommand =
      'state.androidToolkit.zipalignCommand.v1';
  static const String _prefsAndroidToolkitGradleCommand =
      'state.androidToolkit.gradleCommand.v1';
  static const String _prefsPrimaryExecutionBackend =
      'state.runtimeBackends.primaryExecution.v1';
  static const String _prefsDeviceOperationsBackend =
      'state.runtimeBackends.deviceOperations.v1';
  static const String _prefsTermuxWorkdir =
      'state.runtimeBackends.termux.workdir.v1';
  static const String _prefsTermuxCommandTemplate =
      'state.runtimeBackends.termux.commandTemplate.v1';
  static const String _aboutAuthor = '开心小元';
  static const String _aboutBilibiliUrl = 'https://b23.tv/gJ3rHs3';
  static const int _maxRollbackRounds = 8;
  static const int _defaultDownloadMaxBytes = 134217728; // 128 MiB
  static const int _maxDownloadMaxBytes = 536870912; // 512 MiB
  static const String _drawerExplorerRootKey = '__drawer_explorer_root__';

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _chatScroll = ScrollController();
  final _terminalScroll = ScrollController();
  final _promptController = TextEditingController();
  final _messageEditController = TextEditingController();
  final _promptFocusNode = FocusNode();
  final _terminalController = TextEditingController();
  final _filePathController = TextEditingController();
  final _fileContentController = TextEditingController();
  final _godotBridgeUrlController = TextEditingController();
  final _godotBridgeTokenController = TextEditingController();
  final _androidToolkitApkPathController = TextEditingController();
  final _androidToolkitReverseLabelController = TextEditingController();
  final _androidToolkitJadxQueryController = TextEditingController();
  final _androidToolkitGradleTaskController = TextEditingController();
  final _androidToolkitInstallApkPathController = TextEditingController();
  final _androidToolkitLogcatFilterController = TextEditingController();
  final _androidToolkitKeystorePathController = TextEditingController();
  final _androidToolkitKeystoreAliasController = TextEditingController();
  final _androidToolkitStorePasswordController = TextEditingController();
  final _androidToolkitKeyPasswordController = TextEditingController();
  final _androidToolkitAdbCommandController = TextEditingController();
  final _androidToolkitApktoolCommandController = TextEditingController();
  final _androidToolkitJadxCommandController = TextEditingController();
  final _androidToolkitApksignerCommandController = TextEditingController();
  final _androidToolkitZipalignCommandController = TextEditingController();
  final _androidToolkitGradleCommandController = TextEditingController();
  final _termuxWorkdirController = TextEditingController();
  final _termuxCommandTemplateController = TextEditingController();

  final List<ChatMessage> _messages = [
    const ChatMessage(
      role: ChatRole.assistant,
      text: _defaultAssistantGreeting,
      time: '09:42',
    ),
  ];

  final List<String> _terminalLogs = [
    'Astra Terminal ready.',
    '输入 help 查看内置命令。',
  ];

  final Map<String, ProviderConfig> _providerConfigs = {};
  final List<ApiConnectionProfile> _apiConnections = [];
  final List<_ConversationSummary> _conversationHistory = [];
  final List<_ComposerAttachment> _composerAttachments = [];
  final Set<String> _drawerExplorerExpandedPaths = <String>{
    _drawerExplorerRootKey,
  };
  final Map<String, List<_DrawerExplorerEntry>> _drawerExplorerChildrenByPath =
      <String, List<_DrawerExplorerEntry>>{};
  final Set<String> _drawerExplorerLoadingPaths = <String>{};
  final Map<String, String> _drawerExplorerLoadErrors = <String, String>{};

  String _activeProviderId = 'openai';
  String? _activeConnectionId;
  String _activeConversationId = 'conv_bootstrap';
  bool _activeConversationPinned = false;
  String _conversationTitle = _defaultConversationTitle;
  String? _projectRootPath;
  List<ProjectFileSnippet> _projectFiles = const [];
  String _projectContext = '';
  bool _readingProject = false;
  bool _showTerminal = false;
  bool _aiFsGranted = false;
  String _fileOpsStatus = '等待操作';
  String _permissionAuditStatus = '未检查权限';
  bool _checkingPermissions = false;
  bool _sendingPrompt = false;
  bool _backgroundGuardEnabled = false;
  String? _sendingConversationId;
  bool _stopReplyRequested = false;
  bool _restoringState = false;
  bool _rollingBackRound = false;
  bool _apiConnectionsCollapsed = false;
  bool _godotMcpEnabled = false;
  String _godotMcpBridgeUrl = '';
  String _godotMcpBridgeToken = '';
  int _downloadAssetMaxBytes = _defaultDownloadMaxBytes;
  int? _editingMessageIndex;
  int? _rollingBackMessageIndex;
  String? _drawerExplorerSelectedPath;
  bool _drawerExplorerCollapsed = false;
  HttpClient? _activeChatClient;
  HttpClientRequest? _activeChatRequest;
  final List<_AiRoundRecord> _aiRoundHistory = [];
  Timer? _backgroundGuardTicker;
  Timer? _terminalPoller;
  Timer? _persistStateDebounce;
  int? _backgroundReplyStartedAtMs;
  String _backgroundReplyProgress = '';
  bool _backgroundGuardActive = false;
  LocalRuntimeStatusSnapshot _localRuntimeStatus =
      const LocalRuntimeStatusSnapshot.unsupported();
  LocalShellSnapshot _localShellSnapshot = const LocalShellSnapshot.empty();
  bool _loadingLocalRuntimeStatus = false;
  bool _preparingLocalWorkspace = false;
  bool _loadingShellSnapshot = false;
  bool _loadingMirrorPreview = false;
  bool _syncingMirrorToSource = false;
  bool _runningRuntimeWorkbenchCommand = false;
  String _runtimeWorkbenchOutput = '';
  String _mirrorPreviewSummary = '暂未生成镜像差异预览。';
  final List<_MirrorChangeEntry> _mirrorPreviewEntries = <_MirrorChangeEntry>[];
  RuntimeBackendStatusSnapshot _runtimeBackendStatus =
      const RuntimeBackendStatusSnapshot.empty();
  bool _loadingRuntimeBackendStatus = false;
  EmbeddedDevToolkitStatusSnapshot _embeddedDevToolkitStatus =
      const EmbeddedDevToolkitStatusSnapshot.empty();
  bool _loadingEmbeddedDevToolkitStatus = false;
  String _primaryExecutionBackend = 'native';
  String _deviceOperationsBackend = 'native';
  bool _runningAndroidToolkitAction = false;
  String _androidToolkitStatus = '安卓工具箱空闲中。';
  String _androidToolkitOutput = '';
  final List<_AgentProgressEntry> _agentProgressEntries =
      <_AgentProgressEntry>[];
  final List<_AgentToolEvent> _agentToolEvents = <_AgentToolEvent>[];
  String _agentLiveStatus = '空闲';
  String _agentPlanSummary = '';
  String _agentExecutionPhase = '待命';
  String _agentConvergenceSummary = '';
  String _agentConvergenceWarning = '';
  int _agentCurrentRound = 0;
  int _agentMaxRounds = 0;
  bool _agentSummaryMode = false;
  final Map<String, int> _agentToolFamilyCounts = <String, int>{};
  bool _agentProgressCollapsed = false;
  bool _agentToolsCollapsed = false;
  final Set<String> _expandedAgentToolEventIds = <String>{};
  final Set<String> _expandedStructuredMessageSections = <String>{};
  final Set<String> _expandedSettingsSections = <String>{
    'solution_overview',
    'components',
    'embedded_dev_stack',
    'project',
    'local_runtime',
  };
  final Set<String> _enabledReplyStructureSections = <String>{
    _replySectionReasoning,
    _replySectionContent,
    _replySectionToolCalls,
    _replySectionAgentProgress,
    _replySectionMetadata,
    _replySectionToolActivity,
  };
  int _selectedTabIndex = 0;

  static const Set<String> _chatCapableProviders = {
    'openai',
    'openai_responses',
    'deepseek',
    'siliconflow',
    'openrouter',
    'lmstudio',
    'groq',
    'xai',
    'mistral',
    'azure_openai',
    'custom',
    'perplexity',
  };

  static const Set<String> _providersMaySkipApiKey = {'lmstudio', 'custom'};
  static const List<String> _nonVisionModelTokens = [
    'embedding',
    'embed',
    'rerank',
    're-rank',
    'moderation',
    'whisper',
    'transcribe',
    'transcription',
    'tts',
    'speech',
    'audio',
  ];
  static const List<String> _reasoningEffortOrder = [
    'low',
    'medium',
    'high',
    'very_high',
  ];
  static const Set<String> _mirrorSyncIgnoredTopLevelDirs = {
    '.git',
    '.dart_tool',
    'build',
    '.gradle',
    '.idea',
    'node_modules',
  };
  static const String _browserLikeUserAgent =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36 AI-Mobile-Coder/1.0';
  static const String _replySectionReasoning = 'reasoning';
  static const String _replySectionContent = 'content';
  static const String _replySectionToolCalls = 'tool_calls';
  static const String _replySectionAgentProgress = 'agent_progress';
  static const String _replySectionMetadata = 'metadata';
  static const String _replySectionToolActivity = 'tool_activity';
  static const Map<String, String> _reasoningEffortLabelMap = {
    'low': '低',
    'medium': '中',
    'high': '高',
    'very_high': '超高',
  };

  @override
  void initState() {
    super.initState();
    _activeConversationId = _createConversationId();
    unawaited(_restoreState());
    unawaited(_refreshLocalRuntimeStatus());
    unawaited(_refreshRuntimeBackendStatus());
    unawaited(_refreshEmbeddedDevToolkitStatus());
  }

  @override
  void dispose() {
    for (final round in _aiRoundHistory) {
      unawaited(_cleanupBackupDir(round.backupDirPath));
    }
    _backgroundGuardTicker?.cancel();
    _terminalPoller?.cancel();
    _persistStateDebounce?.cancel();
    if (_backgroundGuardActive) {
      unawaited(_stopBackgroundReplyGuard(force: true));
    }
    try {
      _activeChatRequest?.abort();
    } catch (_) {}
    _activeChatClient?.close(force: true);
    _chatScroll.dispose();
    _terminalScroll.dispose();
    _promptController.dispose();
    _messageEditController.dispose();
    _promptFocusNode.dispose();
    _terminalController.dispose();
    _filePathController.dispose();
    _fileContentController.dispose();
    _godotBridgeUrlController.dispose();
    _godotBridgeTokenController.dispose();
    _androidToolkitApkPathController.dispose();
    _androidToolkitReverseLabelController.dispose();
    _androidToolkitJadxQueryController.dispose();
    _androidToolkitGradleTaskController.dispose();
    _androidToolkitInstallApkPathController.dispose();
    _androidToolkitLogcatFilterController.dispose();
    _androidToolkitKeystorePathController.dispose();
    _androidToolkitKeystoreAliasController.dispose();
    _androidToolkitStorePasswordController.dispose();
    _androidToolkitKeyPasswordController.dispose();
    _androidToolkitAdbCommandController.dispose();
    _androidToolkitApktoolCommandController.dispose();
    _androidToolkitJadxCommandController.dispose();
    _androidToolkitApksignerCommandController.dispose();
    _androidToolkitZipalignCommandController.dispose();
    _androidToolkitGradleCommandController.dispose();
    _termuxWorkdirController.dispose();
    _termuxCommandTemplateController.dispose();
    super.dispose();
  }

  void _setLocalRuntimeStatusFromRaw(dynamic raw, {bool withSetState = true}) {
    final mapped = raw is Map
        ? LocalRuntimeStatusSnapshot.fromMap(
            raw.map((key, value) => MapEntry(key, value)),
          )
        : const LocalRuntimeStatusSnapshot.unsupported();
    if (!mounted || !withSetState) {
      _localRuntimeStatus = mapped;
      return;
    }
    setState(() {
      _localRuntimeStatus = mapped;
    });
  }

  Future<void> _refreshLocalRuntimeStatus({
    bool showFailureSnackBar = false,
  }) async {
    if (!Platform.isAndroid) {
      if (!mounted) {
        _localRuntimeStatus = const LocalRuntimeStatusSnapshot.unsupported();
        return;
      }
      setState(() {
        _localRuntimeStatus = const LocalRuntimeStatusSnapshot.unsupported();
      });
      return;
    }

    if (mounted) {
      setState(() {
        _loadingLocalRuntimeStatus = true;
      });
    } else {
      _loadingLocalRuntimeStatus = true;
    }

    try {
      final raw = await _localRuntimeChannel.invokeMethod<dynamic>(
        'getRuntimeStatus',
      );
      _setLocalRuntimeStatusFromRaw(raw);
    } catch (error) {
      if (!mounted) {
        _localRuntimeStatus = _localRuntimeStatus.copyWith(
          supported: true,
          lastError: '$error',
        );
      } else {
        setState(() {
          _localRuntimeStatus = _localRuntimeStatus.copyWith(
            supported: true,
            lastError: '$error',
          );
        });
      }
      if (showFailureSnackBar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load local runtime status: $error'),
          ),
        );
      }
    } finally {
      if (!mounted) {
        _loadingLocalRuntimeStatus = false;
      } else {
        setState(() {
          _loadingLocalRuntimeStatus = false;
        });
      }
    }
  }

  String _primaryBackendLabel(String backend) {
    switch (backend) {
      case 'termux':
        return 'Termux / PRoot';
      case 'native':
      default:
        return '原生 Shell';
    }
  }

  String _deviceBackendLabel(String backend) {
    switch (backend) {
      case 'root':
        return 'Root / SU';
      case 'shizuku':
        return 'Shizuku / 系统';
      case 'native':
      default:
        return 'CLI / ADB';
    }
  }

  void _setRuntimeBackendStatusFromRaw(
    dynamic raw, {
    bool withSetState = true,
  }) {
    final mapped = raw is Map
        ? RuntimeBackendStatusSnapshot.fromMap(
            raw.map((key, value) => MapEntry(key, value)),
          )
        : const RuntimeBackendStatusSnapshot.empty();
    if (!mounted || !withSetState) {
      _runtimeBackendStatus = mapped;
      return;
    }
    setState(() {
      _runtimeBackendStatus = mapped;
    });
  }

  void _setEmbeddedDevToolkitStatusFromRaw(
    dynamic raw, {
    bool withSetState = true,
  }) {
    final mapped = raw is Map
        ? EmbeddedDevToolkitStatusSnapshot.fromMap(
            raw.map((key, value) => MapEntry(key, value)),
          )
        : const EmbeddedDevToolkitStatusSnapshot.empty();
    if (!mounted || !withSetState) {
      _embeddedDevToolkitStatus = mapped;
      return;
    }
    setState(() {
      _embeddedDevToolkitStatus = mapped;
    });
  }

  Future<void> _refreshRuntimeBackendStatus({
    bool showFailureSnackBar = false,
  }) async {
    if (!Platform.isAndroid) {
      if (!mounted) {
        _runtimeBackendStatus = const RuntimeBackendStatusSnapshot.empty();
        return;
      }
      setState(() {
        _runtimeBackendStatus = const RuntimeBackendStatusSnapshot.empty();
      });
      return;
    }

    if (mounted) {
      setState(() {
        _loadingRuntimeBackendStatus = true;
      });
    } else {
      _loadingRuntimeBackendStatus = true;
    }

    try {
      final raw = await _runtimeBackendsChannel.invokeMethod<dynamic>(
        'getBackendStatus',
      );
      _setRuntimeBackendStatusFromRaw(raw);
    } catch (error) {
      if (!mounted) {
        _runtimeBackendStatus = RuntimeBackendStatusSnapshot(
          supported: true,
          nativeAvailable: true,
          lastError: '$error',
        );
      } else {
        setState(() {
          _runtimeBackendStatus = RuntimeBackendStatusSnapshot(
            supported: true,
            nativeAvailable: true,
            lastError: '$error',
          );
        });
      }
      if (showFailureSnackBar && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载执行后端状态失败：$error')));
      }
    } finally {
      if (!mounted) {
        _loadingRuntimeBackendStatus = false;
      } else {
        setState(() {
          _loadingRuntimeBackendStatus = false;
        });
      }
    }
  }

  Future<void> _refreshEmbeddedDevToolkitStatus({
    bool showFailureSnackBar = false,
  }) async {
    if (!Platform.isAndroid) {
      if (!mounted) {
        _embeddedDevToolkitStatus =
            const EmbeddedDevToolkitStatusSnapshot.empty();
        return;
      }
      setState(() {
        _embeddedDevToolkitStatus =
            const EmbeddedDevToolkitStatusSnapshot.empty();
      });
      return;
    }

    if (mounted) {
      setState(() {
        _loadingEmbeddedDevToolkitStatus = true;
      });
    } else {
      _loadingEmbeddedDevToolkitStatus = true;
    }

    try {
      final raw = await _embeddedDevToolkitChannel.invokeMethod<dynamic>(
        'getToolkitStatus',
      );
      _setEmbeddedDevToolkitStatusFromRaw(raw);
    } catch (error) {
      if (!mounted) {
        _embeddedDevToolkitStatus = EmbeddedDevToolkitStatusSnapshot(
          supported: true,
          lastError: '$error',
        );
      } else {
        setState(() {
          _embeddedDevToolkitStatus = EmbeddedDevToolkitStatusSnapshot(
            supported: true,
            lastError: '$error',
          );
        });
      }
      if (showFailureSnackBar && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('加载内置开发栈失败：$error')));
      }
    } finally {
      if (!mounted) {
        _loadingEmbeddedDevToolkitStatus = false;
      } else {
        setState(() {
          _loadingEmbeddedDevToolkitStatus = false;
        });
      }
    }
  }

  Future<void> _openRuntimeBackendApp(String backend) async {
    if (!Platform.isAndroid) return;
    final backendLabel = backend == 'shizuku'
        ? _deviceBackendLabel(backend)
        : _primaryBackendLabel(backend);
    try {
      final opened = await _runtimeBackendsChannel.invokeMethod<bool>(
        'openBackendApp',
        <String, dynamic>{'backend': backend},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            opened == true ? '已打开 $backendLabel。' : '无法打开 $backendLabel。',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('打开后端应用失败：$error')));
    }
  }

  Future<void> _testCurrentExecutionBackend() async {
    try {
      final result = await _executePrimaryBackendCommand(
        command: 'pwd && echo BACKEND_OK',
        timeoutMs: 20000,
        maxOutputBytes: 65536,
        requireProjectWorkspace: false,
      );
      final output = _formatLocalCommandResult(
        'Backend Test',
        result,
        extra: <String, String>{
          'primary_backend': _primaryBackendLabel(_primaryExecutionBackend),
        },
      );
      if (!mounted) return;
      setState(() {
        _runtimeWorkbenchOutput = output;
        _androidToolkitOutput = output;
        _androidToolkitStatus = result['ok'] == true ? '后端测试已完成。' : '后端测试失败。';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('后端测试已完成。')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('后端测试失败：$error')));
    }
  }

  Future<void> _startLocalRuntime() async {
    if (!Platform.isAndroid) return;
    setState(() {
      _loadingLocalRuntimeStatus = true;
    });
    try {
      final raw = await _localRuntimeChannel.invokeMethod<dynamic>(
        'startRuntime',
      );
      _setLocalRuntimeStatusFromRaw(raw);
      _terminalLogs.add('[local-runtime] started');
      _persistState();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Local runtime started.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start local runtime: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingLocalRuntimeStatus = false;
        });
      }
    }
  }

  Future<void> _stopLocalRuntime() async {
    if (!Platform.isAndroid) return;
    setState(() {
      _loadingLocalRuntimeStatus = true;
    });
    try {
      final raw = await _localRuntimeChannel.invokeMethod<dynamic>(
        'stopRuntime',
      );
      _setLocalRuntimeStatusFromRaw(raw);
      _terminalLogs.add('[local-runtime] stopped');
      _persistState();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Local runtime stopped.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to stop local runtime: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingLocalRuntimeStatus = false;
        });
      }
    }
  }

  Future<void> _prepareLocalWorkspaceMirror() async {
    final projectRootPath = _projectRootPath;
    if (projectRootPath == null || projectRootPath.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a project folder first.')),
      );
      return;
    }
    if (!Platform.isAndroid) return;

    setState(() {
      _preparingLocalWorkspace = true;
    });
    try {
      if (!_localRuntimeStatus.isRunning) {
        await _startLocalRuntime();
      }
      if (_localShellSnapshot.isRunning) {
        await _stopShellSession();
      }
      final raw = await _localRuntimeChannel.invokeMethod<dynamic>(
        'prepareWorkspace',
        <String, dynamic>{'projectRootPath': projectRootPath},
      );
      _setLocalRuntimeStatusFromRaw(raw);
      _terminalLogs.add('[local-runtime] mirrored $projectRootPath');
      _persistState();
      if (mounted) {
        final workspacePath = _localRuntimeStatus.activeWorkspacePath;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              workspacePath.isEmpty
                  ? 'Workspace mirror prepared.'
                  : 'Workspace mirror ready: $workspacePath',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to prepare workspace mirror: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _preparingLocalWorkspace = false;
        });
      }
    }
  }

  void _startTerminalPolling() {
    _terminalPoller?.cancel();
    if (!Platform.isAndroid) return;
    _terminalPoller = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (!_showTerminal) return;
      unawaited(_refreshShellSnapshot());
    });
  }

  void _stopTerminalPolling() {
    _terminalPoller?.cancel();
    _terminalPoller = null;
  }

  void _applyShellSnapshot(dynamic raw, {bool autoScroll = false}) {
    final snapshot = raw is Map
        ? LocalShellSnapshot.fromMap(
            raw.map((key, value) => MapEntry(key, value)),
          )
        : const LocalShellSnapshot.empty();
    _localShellSnapshot = snapshot;
    final nextLogs = snapshot.lines.isEmpty
        ? <String>[
            if (snapshot.isRunning)
              '[local-shell] session running at ${snapshot.workingDirectory}'
            else if (snapshot.lastError.isNotEmpty)
              '[local-shell] ${snapshot.lastError}'
            else
              'Astra Terminal ready.',
          ]
        : snapshot.lines;
    _terminalLogs
      ..clear()
      ..addAll(nextLogs);
    if (!mounted) return;
    setState(() {});
    if (autoScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_terminalScroll.hasClients) {
          _terminalScroll.animateTo(
            _terminalScroll.position.maxScrollExtent + 120,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _refreshShellSnapshot({bool autoScroll = false}) async {
    if (!Platform.isAndroid) return;
    if (_loadingShellSnapshot) return;
    _loadingShellSnapshot = true;
    try {
      final raw = await _localRuntimeChannel.invokeMethod<dynamic>(
        'getShellSnapshot',
      );
      _applyShellSnapshot(raw, autoScroll: autoScroll);
    } catch (_) {
      // Ignore polling errors to keep the terminal usable.
    } finally {
      _loadingShellSnapshot = false;
    }
  }

  Future<void> _startShellSession() async {
    if (!Platform.isAndroid) return;
    try {
      final raw = await _localRuntimeChannel.invokeMethod<dynamic>(
        'startShellSession',
      );
      _applyShellSnapshot(raw, autoScroll: true);
      await _refreshLocalRuntimeStatus();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start local shell: $error')),
      );
    }
  }

  Future<void> _stopShellSession() async {
    if (!Platform.isAndroid) return;
    try {
      final raw = await _localRuntimeChannel.invokeMethod<dynamic>(
        'stopShellSession',
      );
      _applyShellSnapshot(raw, autoScroll: true);
      await _refreshLocalRuntimeStatus();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to stop local shell: $error')),
      );
    }
  }

  Future<void> _clearShellBuffer() async {
    if (!Platform.isAndroid) {
      setState(
        () => _terminalLogs
          ..clear()
          ..add('Astra Terminal ready.'),
      );
      _persistState();
      return;
    }
    try {
      final raw = await _localRuntimeChannel.invokeMethod<dynamic>(
        'clearShellBuffer',
      );
      _applyShellSnapshot(raw);
      _persistState();
    } catch (_) {
      setState(
        () => _terminalLogs
          ..clear()
          ..add('Astra Terminal ready.'),
      );
      _persistState();
    }
  }

  Future<void> _sendShellInput(String input) async {
    if (!Platform.isAndroid) return;
    try {
      if (!_localRuntimeStatus.isRunning) {
        await _startLocalRuntime();
      }
      if (!_localShellSnapshot.isRunning) {
        await _startShellSession();
      }
      final raw = await _localRuntimeChannel.invokeMethod<dynamic>(
        'sendShellInput',
        <String, dynamic>{'input': input},
      );
      _applyShellSnapshot(raw, autoScroll: true);
      _persistState();
      await _refreshLocalRuntimeStatus();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send shell input: $error')),
      );
    }
  }

  ModelProvider get _activeProvider {
    final activeConnection = _activeConnection;
    if (activeConnection != null) {
      return _providerById(activeConnection.providerId);
    }
    return _providerById(_activeProviderId);
  }

  ProviderConfig _configOf(String providerId) {
    return _providerConfigs[providerId] ?? const ProviderConfig();
  }

  ApiConnectionProfile? get _activeConnection {
    final activeId = _activeConnectionId;
    if (activeId == null || activeId.isEmpty) return null;
    for (final profile in _apiConnections) {
      if (profile.id == activeId) return profile;
    }
    return null;
  }

  ProviderConfig get _activeProviderConfig {
    final activeConnection = _activeConnection;
    if (activeConnection != null) return activeConnection.toConfig();
    return _configOf(_activeProviderId);
  }

  bool get _godotMcpReady =>
      _godotMcpEnabled && _godotMcpBridgeUrl.trim().isNotEmpty;

  ModelProvider _providerById(String providerId) {
    return kProviders.firstWhere(
      (provider) => provider.id == providerId,
      orElse: () => kProviders.first,
    );
  }

  String _providerName(String providerId) {
    return _providerById(providerId).name;
  }

  String _maskApiKey(String apiKey) {
    final text = apiKey.trim();
    if (text.isEmpty) return '未配置';
    if (text.length <= 8) return '****';
    return '${text.substring(0, 4)}...${text.substring(text.length - 4)}';
  }

  String _formatHeadersForEditor(Map<String, String> headers) {
    if (headers.isEmpty) return '';
    final entries = headers.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    return entries.map((entry) => '${entry.key}: ${entry.value}').join('\n');
  }

  Map<String, String> _parseHeadersFromEditor(String raw) {
    final headers = <String, String>{};
    for (final line in raw.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final splitIndex = trimmed.indexOf(':');
      if (splitIndex <= 0) continue;
      final key = trimmed.substring(0, splitIndex).trim();
      final value = trimmed.substring(splitIndex + 1).trim();
      if (key.isEmpty || value.isEmpty) continue;
      headers[key] = value;
    }
    return _cleanHeaderMap(headers);
  }

  String _defaultApiPathForProvider(String providerId) {
    if (providerId == 'openai_responses') {
      return '/responses';
    }
    if (providerId == 'azure_openai') {
      return '/openai/v1/chat/completions?api-version=preview';
    }
    if (providerId == 'gemini') {
      return '/models';
    }
    if (providerId == 'claude') {
      return '/v1/messages';
    }
    if (providerId == 'ollama') {
      return '/api/chat';
    }
    return '/chat/completions';
  }

  String _defaultModelListPathForProvider(String providerId) {
    switch (providerId) {
      case 'ollama':
        return '/api/tags';
      case 'azure_openai':
        return '/openai/v1/models?api-version=preview';
      case 'gemini':
        return '/models';
      case 'claude':
        return '/v1/models';
      default:
        return '/models';
    }
  }

  String _endpointPreview({
    required String providerId,
    required String baseUrl,
    required String apiPath,
  }) {
    final trimmedBaseUrl = baseUrl.trim();
    if (trimmedBaseUrl.isEmpty) return '';
    try {
      final uri = _buildChatCompletionEndpoint(
        providerId: providerId,
        baseUrl: trimmedBaseUrl,
        apiPath: apiPath.trim(),
      );
      return uri.toString();
    } catch (_) {
      return '';
    }
  }

  String _normalizeReasoningEffort(String raw) {
    final value = raw.trim().toLowerCase();
    if (_reasoningEffortLabelMap.containsKey(value)) {
      return value;
    }
    return 'very_high';
  }

  String _reasoningEffortLabel(String raw) {
    final key = _normalizeReasoningEffort(raw);
    return _reasoningEffortLabelMap[key] ?? '超高';
  }

  bool _isReplySectionEnabled(String sectionId) {
    return _enabledReplyStructureSections.contains(sectionId);
  }

  bool get _legacyStructuredAssistantSectionsEnabled => false;

  void _setReplySectionEnabled(String sectionId, bool enabled) {
    setState(() {
      if (enabled) {
        _enabledReplyStructureSections.add(sectionId);
      } else {
        _enabledReplyStructureSections.remove(sectionId);
      }
    });
    _persistState();
  }

  double _temperatureForReasoningEffort(String raw) {
    switch (_normalizeReasoningEffort(raw)) {
      case 'low':
        return 0.55;
      case 'medium':
        return 0.35;
      case 'high':
        return 0.2;
      case 'very_high':
        return 0.1;
    }
    return 0.2;
  }

  String _replyElapsedLabel() {
    final started = _backgroundReplyStartedAtMs;
    if (started == null) return '0s';
    final elapsedMs = DateTime.now().millisecondsSinceEpoch - started;
    final elapsed = max(0, elapsedMs ~/ 1000);
    final minute = elapsed ~/ 60;
    final second = elapsed % 60;
    if (minute <= 0) return '${second}s';
    return '${minute}m ${second}s';
  }

  Future<bool> _ensureNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final granted = await _backgroundGuardChannel.invokeMethod<bool>(
        'ensureNotificationPermission',
      );
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _startBackgroundReplyGuard({required String stage}) async {
    if (!Platform.isAndroid || !_backgroundGuardEnabled) return;
    final granted = await _ensureNotificationPermission();
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('后台防中断需要通知权限，请在系统设置中允许通知')),
        );
      }
      return;
    }
    final startedAt = DateTime.now().millisecondsSinceEpoch;
    _backgroundReplyStartedAtMs = startedAt;
    _backgroundReplyProgress = stage;
    try {
      await _backgroundGuardChannel.invokeMethod<bool>('startReplyGuard', {
        'title': 'AI 正在回复',
        'text': '$stage · 已进行 ${_replyElapsedLabel()}',
        'startedAtMs': startedAt,
      });
      _backgroundGuardActive = true;
      _backgroundGuardTicker?.cancel();
      _backgroundGuardTicker = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!_sendingPrompt || !_backgroundGuardActive) return;
        unawaited(_pushBackgroundReplyProgress(_backgroundReplyProgress));
      });
    } catch (_) {
      _backgroundGuardActive = false;
    }
  }

  Future<void> _pushBackgroundReplyProgress(String stage) async {
    _backgroundReplyProgress = stage;
    if (!Platform.isAndroid ||
        !_backgroundGuardEnabled ||
        !_backgroundGuardActive) {
      return;
    }
    final startedAt = _backgroundReplyStartedAtMs;
    if (startedAt == null) return;
    try {
      await _backgroundGuardChannel.invokeMethod<bool>('updateReplyGuard', {
        'title': 'AI 正在回复',
        'text': '$stage · 已进行 ${_replyElapsedLabel()}',
        'startedAtMs': startedAt,
      });
    } catch (_) {}
  }

  void _updateReplyProgress(String stage) {
    _backgroundReplyProgress = stage;
    if (!Platform.isAndroid || !_backgroundGuardEnabled || !_sendingPrompt) {
      return;
    }
    unawaited(_pushBackgroundReplyProgress(stage));
  }

  Future<void> _stopBackgroundReplyGuard({bool force = false}) async {
    _backgroundGuardTicker?.cancel();
    _backgroundGuardTicker = null;
    _backgroundReplyStartedAtMs = null;
    _backgroundReplyProgress = '';
    if (!Platform.isAndroid) {
      _backgroundGuardActive = false;
      return;
    }
    if (!_backgroundGuardActive && !force) return;
    _backgroundGuardActive = false;
    try {
      await _backgroundGuardChannel.invokeMethod<bool>('stopReplyGuard');
    } catch (_) {}
  }

  Future<void> _setBackgroundGuardEnabled(bool enabled) async {
    if (enabled && Platform.isAndroid) {
      final granted = await _ensureNotificationPermission();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('通知权限未开启，后台防中断模式可能无法显示通知')),
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _backgroundGuardEnabled = enabled;
    });
    _persistState();
    if (!enabled) {
      await _stopBackgroundReplyGuard(force: true);
      return;
    }
    if (_sendingPrompt) {
      await _startBackgroundReplyGuard(
        stage: _backgroundReplyProgress.isEmpty
            ? '正在继续回复'
            : _backgroundReplyProgress,
      );
    }
  }

  int _normalizeDownloadMaxBytes(int raw) {
    return raw.clamp(65536, _maxDownloadMaxBytes).toInt();
  }

  void _updateDownloadMaxBytes(int value) {
    final next = _normalizeDownloadMaxBytes(value);
    if (_downloadAssetMaxBytes == next) return;
    setState(() {
      _downloadAssetMaxBytes = next;
    });
    _persistState();
  }

  void _applyDownloadMaxBytesInput(String raw) {
    final parsed = int.tryParse(raw.trim());
    if (parsed == null || parsed <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入有效的字节数')));
      return;
    }
    final normalized = _normalizeDownloadMaxBytes(parsed);
    _updateDownloadMaxBytes(normalized);
    if (!mounted) return;
    if (normalized != parsed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已自动调整到允许范围: ${_formatBytes(normalized)} ($normalized bytes)',
          ),
        ),
      );
    }
  }

  void _resetAgentExecutionConsole() {
    void apply() {
      _agentProgressEntries.clear();
      _agentToolEvents.clear();
      _expandedAgentToolEventIds.clear();
      _agentLiveStatus = '准备请求模型';
      _agentPlanSummary = '';
      _agentExecutionPhase = '规划';
      _agentConvergenceSummary = '等待首次方案';
      _agentConvergenceWarning = '';
      _agentCurrentRound = 0;
      _agentMaxRounds = 0;
      _agentSummaryMode = false;
      _agentToolFamilyCounts.clear();
    }

    if (!mounted) {
      apply();
      return;
    }
    setState(apply);
  }

  void _updateAgentExecutionState({
    String? phase,
    String? convergenceSummary,
    String? convergenceWarning,
    int? currentRound,
    int? maxRounds,
    bool? summaryMode,
    Map<String, int>? toolFamilyCounts,
  }) {
    void apply() {
      if (phase != null) {
        _agentExecutionPhase = phase;
      }
      if (convergenceSummary != null) {
        _agentConvergenceSummary = convergenceSummary;
      }
      if (convergenceWarning != null) {
        _agentConvergenceWarning = convergenceWarning;
      }
      if (currentRound != null) {
        _agentCurrentRound = currentRound;
      }
      if (maxRounds != null) {
        _agentMaxRounds = maxRounds;
      }
      if (summaryMode != null) {
        _agentSummaryMode = summaryMode;
      }
      if (toolFamilyCounts != null) {
        _agentToolFamilyCounts
          ..clear()
          ..addAll(toolFamilyCounts);
      }
    }

    if (!mounted) {
      apply();
      return;
    }
    setState(apply);
  }

  void _recordAgentProgress(
    String title, {
    String detail = '',
    bool updateLiveStatus = true,
  }) {
    final entry = _AgentProgressEntry(
      title: title.trim(),
      detail: detail.trim(),
      time: _timeNow(),
    );
    void apply() {
      if (updateLiveStatus && entry.title.isNotEmpty) {
        _agentLiveStatus = entry.title;
      }
      _agentProgressEntries.add(entry);
      if (_agentProgressEntries.length > 24) {
        _agentProgressEntries.removeAt(0);
      }
    }

    if (!mounted) {
      apply();
      return;
    }
    setState(apply);
  }

  void _recordAgentToolStart(_ToolCall call) {
    final entry = _AgentToolEvent(
      id: call.id,
      name: call.name,
      status: 'running',
      argsPreview: _toolArgsPreview(call.argumentsJson),
      summary: '等待工具结果',
      time: _timeNow(),
      startedAtMs: DateTime.now().millisecondsSinceEpoch,
      durationMs: null,
      rawArgs: call.argumentsJson,
      commandText: _extractCommandPreview(call),
      stdout: '',
      stderr: '',
    );
    void apply() {
      _agentToolEvents.removeWhere((item) => item.id == call.id);
      _agentToolEvents.add(entry);
      if (_agentToolEvents.length > 20) {
        _agentToolEvents.removeAt(0);
      }
    }

    if (!mounted) {
      apply();
      return;
    }
    setState(apply);
  }

  void _recordAgentToolFinish(
    _ToolCall call,
    String toolResult, {
    required String status,
  }) {
    var summary = _summarizeForLog(toolResult);
    var stdout = '';
    var stderr = '';
    int? durationMs;
    try {
      final decoded = jsonDecode(toolResult);
      if (decoded is Map) {
        final errorText = decoded['error']?.toString().trim() ?? '';
        stdout = decoded['stdout']?.toString() ?? '';
        stderr = decoded['stderr']?.toString() ?? '';
        if (errorText.isNotEmpty) {
          summary = errorText;
        } else if (decoded['stdout'] is String &&
            (decoded['stdout'] as String).trim().isNotEmpty) {
          summary = _summarizeForLog(decoded['stdout'].toString());
        } else if (decoded['content'] is String &&
            (decoded['content'] as String).trim().isNotEmpty) {
          summary = _summarizeForLog(decoded['content'].toString());
        }
      }
    } catch (_) {}

    final entry = _AgentToolEvent(
      id: call.id,
      name: call.name,
      status: status,
      argsPreview: _toolArgsPreview(call.argumentsJson),
      summary: summary,
      time: _timeNow(),
      startedAtMs: DateTime.now().millisecondsSinceEpoch,
      durationMs: durationMs,
      rawArgs: call.argumentsJson,
      commandText: _extractCommandPreview(call),
      stdout: stdout,
      stderr: stderr,
    );
    void apply() {
      final index = _agentToolEvents.indexWhere((item) => item.id == call.id);
      final existing = index >= 0 ? _agentToolEvents[index] : null;
      final resolvedDurationMs =
          durationMs ??
          (existing == null
              ? null
              : DateTime.now().millisecondsSinceEpoch - existing.startedAtMs);
      final resolvedEntry = _AgentToolEvent(
        id: entry.id,
        name: entry.name,
        status: entry.status,
        argsPreview: entry.argsPreview,
        summary: entry.summary,
        time: entry.time,
        startedAtMs: existing?.startedAtMs ?? entry.startedAtMs,
        durationMs: resolvedDurationMs,
        rawArgs: entry.rawArgs,
        commandText: entry.commandText,
        stdout: entry.stdout,
        stderr: entry.stderr,
      );
      if (index >= 0) {
        _agentToolEvents[index] = resolvedEntry;
      } else {
        _agentToolEvents.add(resolvedEntry);
      }
      if (_agentToolEvents.length > 20) {
        _agentToolEvents.removeAt(0);
      }
    }

    if (!mounted) {
      apply();
      return;
    }
    setState(apply);
  }

  (String, String) _extractToolOutputStreams(String toolResult) {
    if (toolResult.trim().isEmpty) return ('', '');
    try {
      final decoded = jsonDecode(toolResult);
      if (decoded is Map) {
        return (
          decoded['stdout']?.toString() ?? '',
          decoded['stderr']?.toString() ?? '',
        );
      }
    } catch (_) {}
    return ('', '');
  }

  String _buildAssistantPlanMessage({
    required String content,
    required List<_ToolCall> toolCalls,
  }) {
    final trimmedContent = content.trim();
    if (trimmedContent.isNotEmpty) {
      return trimmedContent;
    }
    final phrases = <String>[];
    for (final call in toolCalls) {
      final phrase = _toolPlanPhrase(call.name);
      if (!phrases.contains(phrase)) {
        phrases.add(phrase);
      }
      if (phrases.length >= 3) break;
    }
    if (phrases.isEmpty) {
      return '我会先检查项目现状，再整理出最合适的处理方案。';
    }
    if (phrases.length == 1) {
      return '我先${phrases.first}，然后把我发现的问题和处理思路整理给你。';
    }
    if (phrases.length == 2) {
      return '我会先${phrases[0]}，再${phrases[1]}，最后给你一个明确结论。';
    }
    return '我会先${phrases[0]}，再${phrases[1]}，然后${phrases[2]}，最后给你一个明确结论。';
  }

  String _buildReasoningSummary({
    required String content,
    required List<_ToolCall> toolCalls,
    String rawReasoning = '',
  }) {
    final trimmed = rawReasoning.trim();
    if (trimmed.isNotEmpty) {
      return _summarizeForLog(trimmed);
    }
    return _buildAssistantPlanMessage(content: content, toolCalls: toolCalls);
  }

  String _toolPlanPhrase(String toolName) {
    switch (toolName) {
      case 'read_file':
      case 'read_file_part':
      case 'find_files':
      case 'file_exists':
        return '查看相关文件内容';
      case 'list_files':
      case 'list_dir':
        return '梳理项目目录结构';
      case 'grep_code':
        return '搜索相关代码位置';
      case 'replace_in_file':
      case 'write_file':
      case 'create_file':
      case 'create_dir':
      case 'delete_entry':
      case 'copy_file':
      case 'move_file':
      case 'apply_patch':
        return '应用所需的代码修改';
      case 'run_command':
      case 'android_gradle_build':
      case 'android_install_apk':
      case 'android_logcat':
      case 'android_decompile_apk':
      case 'android_run_jadx':
      case 'android_search_jadx':
      case 'android_rebuild_apk':
      case 'android_sign_apk':
      case 'git_status':
      case 'git_diff':
      case 'git_log':
      case 'git_show':
      case 'shell_session_start':
      case 'shell_session_stop':
      case 'shell_session_snapshot':
      case 'shell_session_input':
      case 'shell_session_clear':
        return '执行本地验证命令';
      case 'download_asset':
        return '下载需要的资源';
      case 'web_search':
        return '联网搜索最新参考信息';
      case 'fetch_webpage':
        return '读取目标网页内容';
      default:
        return '借助工具检查项目';
    }
  }

  String _toolProgressTitle(_ToolCall call) {
    switch (call.name) {
      case 'android_gradle_build':
        return 'Building Android project';
      case 'android_install_apk':
        return 'Installing APK';
      case 'android_logcat':
        return 'Collecting logcat';
      case 'android_decompile_apk':
        return 'Decoding APK with apktool';
      case 'android_run_jadx':
        return 'Running JADX';
      case 'android_search_jadx':
        return 'Searching JADX output';
      case 'android_rebuild_apk':
        return 'Rebuilding APK';
      case 'android_sign_apk':
        return 'Signing APK';
      default:
        break;
    }
    switch (call.name) {
      case 'read_file':
      case 'read_file_part':
        return '正在读取项目文件';
      case 'list_files':
      case 'list_dir':
        return '正在扫描目录';
      case 'grep_code':
        return '正在搜索代码';
      case 'replace_in_file':
      case 'write_file':
      case 'create_file':
      case 'create_dir':
      case 'delete_entry':
        return '正在修改文件';
      case 'run_command':
        return '正在执行本地命令';
      case 'download_asset':
        return '正在下载资源';
      case 'web_search':
        return '正在联网搜索';
      case 'fetch_webpage':
        return '正在读取网页';
      default:
        return '正在调用 ${call.name}';
    }
  }

  String _toolFinishStatus(String toolResult, {required bool cached}) {
    if (cached) return 'cached';
    try {
      final decoded = jsonDecode(toolResult);
      if (decoded is Map) {
        if (decoded['ok'] == false) return 'failed';
        if ((decoded['timedOut'] ?? false) == true) return 'failed';
      }
    } catch (_) {}
    return 'done';
  }

  String _extractCommandPreview(_ToolCall call) {
    try {
      final args = _decodeToolArguments(call.argumentsJson);
      if (call.name == 'run_command') {
        return args['command']?.toString().trim() ?? '';
      }
      if (call.name == 'android_gradle_build') {
        return args['task']?.toString().trim() ?? '';
      }
      if (call.name == 'android_install_apk' ||
          call.name == 'android_decompile_apk' ||
          call.name == 'android_run_jadx') {
        return args['apk_path']?.toString().trim() ?? '';
      }
      if (call.name == 'android_search_jadx') {
        return args['query']?.toString().trim() ?? '';
      }
      if (call.name == 'git_show') {
        return args['ref']?.toString().trim() ?? '';
      }
      if (call.name == 'git_diff' || call.name == 'find_files') {
        return args['path']?.toString().trim() ?? '';
      }
      if (call.name == 'shell_session_input') {
        return args['input']?.toString().trim() ?? '';
      }
      if (call.name == 'read_file' || call.name == 'read_file_part') {
        return args['path']?.toString().trim() ?? '';
      }
      if (call.name == 'list_dir' || call.name == 'file_info') {
        return args['path']?.toString().trim() ?? '';
      }
      if (call.name == 'grep_code') {
        return args['query']?.toString().trim() ?? '';
      }
    } catch (_) {}
    return '';
  }

  String _toolFamily(String toolName) {
    switch (toolName) {
      case 'list_files':
      case 'list_dir':
      case 'file_info':
      case 'find_files':
        return '目录探索';
      case 'read_file':
      case 'read_file_part':
      case 'file_exists':
        return '文件阅读';
      case 'grep_code':
        return '代码检索';
      case 'replace_in_file':
      case 'write_file':
      case 'create_file':
      case 'create_dir':
      case 'delete_entry':
      case 'copy_file':
      case 'move_file':
      case 'apply_patch':
        return '文件修改';
      case 'run_command':
      case 'android_gradle_build':
      case 'android_install_apk':
      case 'android_logcat':
      case 'android_decompile_apk':
      case 'android_run_jadx':
      case 'android_search_jadx':
      case 'android_rebuild_apk':
      case 'android_sign_apk':
      case 'shell_session_start':
      case 'shell_session_stop':
      case 'shell_session_snapshot':
      case 'shell_session_input':
      case 'shell_session_clear':
      case 'git_status':
      case 'git_diff':
      case 'git_log':
      case 'git_show':
        return '命令执行';
      case 'web_search':
        return '联网搜索';
      case 'fetch_webpage':
        return '网页读取';
      case 'download_asset':
        return '资源下载';
      default:
        return '其他工具';
    }
  }

  bool _isExplorationTool(String toolName) {
    switch (toolName) {
      case 'list_files':
      case 'list_dir':
      case 'file_info':
      case 'find_files':
      case 'read_file':
      case 'read_file_part':
      case 'file_exists':
      case 'grep_code':
      case 'web_search':
      case 'fetch_webpage':
        return true;
      default:
        return false;
    }
  }

  int _toolFamilyRoundLimit(String toolName) {
    switch (_toolFamily(toolName)) {
      case '目录探索':
        return 4;
      case '文件阅读':
        return 5;
      case '代码检索':
        return 4;
      case '联网搜索':
        return 3;
      case '网页读取':
        return 3;
      default:
        return 999;
    }
  }

  String _buildPlanningInstruction() {
    return '''
先不要调用任何工具，也不要直接给最终答案。
请先基于当前用户请求给出一段简洁执行方案，内容包括：
1. 你准备先检查什么
2. 预计会用到哪些工具
3. 可能的修改方向
要求：
- 用中文回答
- 控制在 4 句以内
- 像 Codex 一样先说方案，再进入执行
''';
  }

  String _buildExecutionInstruction() {
    return '''
你已经给出过执行方案，现在开始执行。
要求：
- 优先使用最少必要工具
- 先小范围定位，再读取关键文件，再修改或验证
- 不要重复扫描同一目录或重复读取同一片段
- 一旦信息足够，立即停止探索并输出结论
''';
  }

  String _buildSummaryModeInstruction({
    required int currentRound,
    required int maxRounds,
    required String convergenceReason,
  }) {
    return '''
你已进入总结模式（第 $currentRound / $maxRounds 轮）。
当前收敛提醒：$convergenceReason
除非缺少唯一关键文件，否则不要继续调用目录扫描、代码检索、文件阅读类工具。
请优先基于已有结果直接给出：
1. 你已经确认的事实
2. 需要修改的方案或补丁
3. 如果仍缺信息，只允许说明唯一缺少的关键点
''';
  }

  String _buildForcedFinalInstruction({
    required int currentRound,
    required int maxRounds,
    required String convergenceReason,
  }) {
    return '''
���������ܽ�غϣ��� $currentRound / $maxRounds �֣���
��Ҫ�ٵ����κι��ߣ�ֱ��������ս��ۡ�
�����ǰ̽��δ��ȫ����������ȷ˵����
- ��ȷ�ϵ���Ϣ
- ��δȷ�ϵ�����ܵ�ԭ��
- �����û���һ���ṩ����С������Ϣ
��ǰֹͣԭ��$convergenceReason
''';
  }

  String _buildConvergenceGuardResult({
    required _ToolCall call,
    required String reason,
    required int repeatedCount,
    required Map<String, int> toolFamilyCounts,
  }) {
    return jsonEncode(<String, dynamic>{
      'ok': false,
      'action': call.name,
      'error': reason,
      'repeat_count': repeatedCount,
      'next_step': '��ֹͣ������ɢʽ̽�������Ȼ������н���ܽ���ۣ���ֻ����Ψһ�ؼ��ļ���',
      'tool_family': _toolFamily(call.name),
      'family_stats': toolFamilyCounts,
    });
  }

  Future<void> _copyPlainText(String text, String successMessage) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: trimmed));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(successMessage)));
  }

  Future<void> _ensureLocalRuntimeReady({
    bool requireProjectWorkspace = false,
  }) async {
    if (!Platform.isAndroid || !_localRuntimeStatus.supported) {
      throw Exception('Android local runtime is not available on this device');
    }
    if (!_localRuntimeStatus.isRunning) {
      await _startLocalRuntime();
    }
    if (!requireProjectWorkspace) {
      return;
    }
    final projectRootPath = _projectRootPath;
    if (projectRootPath == null || projectRootPath.trim().isEmpty) {
      throw Exception('This action requires a selected project folder');
    }
    final activeProject = _localRuntimeStatus.lastPreparedProjectPath.trim();
    if (!_localRuntimeStatus.hasWorkspace || activeProject != projectRootPath) {
      await _prepareLocalWorkspaceMirror();
    }
  }

  Future<void> _ensureLocalRuntimeWorkspaceReadyForTools() async {
    await _ensureLocalRuntimeReady(requireProjectWorkspace: true);
  }

  Future<void> _ensureMirroredWorkspaceIfAvailable() async {
    if (!Platform.isAndroid || !_localRuntimeStatus.supported) {
      return;
    }
    if (_projectRootPath == null || _projectRootPath!.trim().isEmpty) {
      return;
    }
    await _ensureLocalRuntimeWorkspaceReadyForTools();
  }

  Future<Map<String, dynamic>> _executeLocalRuntimeCommand({
    required String command,
    int timeoutMs = 20000,
    int maxOutputBytes = 131072,
    bool requireProjectWorkspace = true,
  }) async {
    await _ensureLocalRuntimeReady(
      requireProjectWorkspace: requireProjectWorkspace,
    );
    final raw = await _localRuntimeChannel.invokeMethod<dynamic>(
      'executeCommand',
      <String, dynamic>{
        'command': command,
        'timeoutMs': timeoutMs,
        'maxOutputBytes': maxOutputBytes,
      },
    );
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    throw Exception('Local runtime returned an invalid executeCommand result');
  }

  String _renderTermuxCommandTemplate(String command) {
    final template = _termuxCommandTemplateController.text.trim();
    final quotedCommand = _quoteShellArg(command);
    if (template.isEmpty) {
      return command;
    }
    if (template.contains('{{command}}')) {
      return template.replaceAll('{{command}}', quotedCommand);
    }
    return '$template $quotedCommand';
  }

  String _termuxWorkingDirectory() {
    final configured = _termuxWorkdirController.text.trim();
    if (configured.isNotEmpty) {
      return configured;
    }
    final projectRoot = _projectRootPath?.trim() ?? '';
    if (projectRoot.isNotEmpty) {
      return projectRoot;
    }
    return '/data/data/com.termux/files/home';
  }

  Future<Map<String, dynamic>> _executeTermuxBackendCommand({
    required String command,
    int timeoutMs = 20000,
    int maxOutputBytes = 131072,
  }) async {
    await _refreshRuntimeBackendStatus();
    if (!_runtimeBackendStatus.termuxReady) {
      throw Exception('Termux backend is not ready');
    }
    final raw = await _runtimeBackendsChannel
        .invokeMethod<dynamic>('executeTermuxCommand', <String, dynamic>{
          'command': command,
          'workingDirectory': _termuxWorkingDirectory(),
          'commandTemplate': _renderTermuxCommandTemplate(command),
          'timeoutMs': timeoutMs,
          'maxOutputBytes': maxOutputBytes,
        });
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    throw Exception('Termux backend returned an invalid result');
  }

  Future<Map<String, dynamic>> _executePrimaryBackendCommand({
    required String command,
    int timeoutMs = 20000,
    int maxOutputBytes = 131072,
    bool requireProjectWorkspace = true,
  }) async {
    switch (_primaryExecutionBackend) {
      case 'termux':
        return _executeTermuxBackendCommand(
          command: command,
          timeoutMs: timeoutMs,
          maxOutputBytes: maxOutputBytes,
        );
      case 'native':
      default:
        return _executeLocalRuntimeCommand(
          command: command,
          timeoutMs: timeoutMs,
          maxOutputBytes: maxOutputBytes,
          requireProjectWorkspace: requireProjectWorkspace,
        );
    }
  }

  String _localRuntimeExecutionRoot() {
    final activeWorkspace = _localRuntimeStatus.activeWorkspacePath.trim();
    if (activeWorkspace.isNotEmpty) {
      return activeWorkspace;
    }
    final shellDirectory = _localShellSnapshot.workingDirectory.trim();
    if (shellDirectory.isNotEmpty) {
      return shellDirectory;
    }
    final runtimeRoot = _localRuntimeStatus.runtimeRoot.trim();
    if (runtimeRoot.isEmpty) {
      return '';
    }
    return '$runtimeRoot${Platform.pathSeparator}workspace_boot';
  }

  String _controllerValue(
    TextEditingController controller, {
    String fallback = '',
  }) {
    final text = controller.text.trim();
    return text.isEmpty ? fallback : text;
  }

  String _toolCommandValue(
    TextEditingController controller, {
    required String fallback,
  }) {
    return _controllerValue(controller, fallback: fallback);
  }

  String _shellWordArgs(String raw) {
    final parts = raw
        .trim()
        .split(RegExp(r'\s+'))
        .where((item) => item.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    return parts.map(_quoteShellArg).join(' ');
  }

  String _sanitizeWorkspaceSegment(String raw, {String fallback = 'android'}) {
    final cleaned = raw
        .trim()
        .replaceAll('\\', '/')
        .split('/')
        .last
        .replaceAll(RegExp(r'\.[^.]+$'), '')
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^[_\.]+|[_\.]+$'), '');
    return cleaned.isEmpty ? fallback : cleaned;
  }

  String _androidToolkitReverseLabel({String fallback = 'sample_apk'}) {
    final manual = _androidToolkitReverseLabelController.text.trim();
    if (manual.isNotEmpty) {
      return _sanitizeWorkspaceSegment(manual, fallback: fallback);
    }
    final apkPath = _androidToolkitApkPathController.text.trim();
    if (apkPath.isNotEmpty) {
      return _sanitizeWorkspaceSegment(apkPath, fallback: fallback);
    }
    return fallback;
  }

  String _androidToolkitReverseRoot([String? label]) {
    final effectiveLabel = _sanitizeWorkspaceSegment(
      label ?? _androidToolkitReverseLabel(),
      fallback: 'sample_apk',
    );
    return 'reverse/$effectiveLabel';
  }

  String _workspaceSegmentFromConversation([String? value]) {
    final source = (value ?? _conversationTitle).trim();
    if (source.isEmpty || source == _defaultConversationTitle) {
      return _sanitizeWorkspaceSegment(
        _activeConversationId,
        fallback: 'workspace',
      );
    }
    return _sanitizeWorkspaceSegment(source, fallback: 'workspace');
  }

  Future<Directory> _workspaceStoreRootDirectory() async {
    final base = await getApplicationSupportDirectory();
    final root = Directory('${base.path}${Platform.pathSeparator}workspaces');
    await root.create(recursive: true);
    return root;
  }

  Future<String> _createLocalWorkspaceRootPath({
    String? label,
    String? sourcePath,
  }) async {
    final root = await _workspaceStoreRootDirectory();
    final segment = _workspaceSegmentFromConversation(label);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final folderName = sourcePath == null || sourcePath.trim().isEmpty
        ? '${segment}_$stamp'
        : '${segment}_${_sanitizeWorkspaceSegment(sourcePath, fallback: 'source')}_$stamp';
    return '${root.path}${Platform.pathSeparator}$folderName';
  }

  Future<void> _createEmptyWorkspaceDirectory(String rootPath) async {
    final dir = Directory(rootPath);
    await dir.create(recursive: true);
    final marker = File(
      '${dir.path}${Platform.pathSeparator}.yuandex${Platform.pathSeparator}README.txt',
    );
    await marker.parent.create(recursive: true);
    if (!await marker.exists()) {
      await marker.writeAsString(
        'This workspace was created by yuandex for the active conversation.\n',
        flush: true,
      );
    }
  }

  Future<String> _bindWorkspacePath({
    required String path,
    required String statusText,
    bool grantFileAccess = true,
    bool silent = false,
  }) async {
    await _loadProjectFolder(path, silent: true);
    if (!mounted) return path;
    setState(() {
      if (grantFileAccess) {
        _aiFsGranted = true;
      }
      _fileOpsStatus = statusText;
    });
    _persistState();
    if (!silent) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(statusText)));
    }
    return path;
  }

  Future<void> _createAndBindEmptyWorkspace({
    String? label,
    bool silent = false,
  }) async {
    final path = await _createLocalWorkspaceRootPath(label: label);
    await _createEmptyWorkspaceDirectory(path);
    await _bindWorkspacePath(
      path: path,
      statusText: '已创建并绑定本地工作区: $path',
      grantFileAccess: true,
      silent: silent,
    );
  }

  Future<void> _unbindCurrentWorkspace() async {
    if (_projectRootPath == null) return;
    final projectName = _drawerExplorerProjectName();
    setState(() {
      _projectRootPath = null;
      _projectContext = '';
      _projectFiles = const [];
      _aiFsGranted = false;
      _fileOpsStatus = '已解绑工作区';
      _resetDrawerExplorerState();
    });
    _persistState();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已从当前对话解绑工作区: $projectName')));
  }

  bool _looksLikeAbsolutePath(String path) {
    final trimmed = path.trim();
    return trimmed.startsWith('/') ||
        RegExp(r'^[A-Za-z]:[\\/]').hasMatch(trimmed);
  }

  String _resolveAndroidToolkitPath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty || _looksLikeAbsolutePath(trimmed)) {
      return trimmed;
    }
    final projectRoot = _projectRootPath?.trim() ?? '';
    if (projectRoot.isEmpty) {
      return trimmed;
    }
    return '$projectRoot${Platform.pathSeparator}$trimmed';
  }

  String _formatLocalCommandResult(
    String title,
    Map<String, dynamic> result, {
    Map<String, String> extra = const <String, String>{},
  }) {
    final buffer = StringBuffer()
      ..writeln(title)
      ..writeln('ok: ${result['ok'] == true}')
      ..writeln('command: ${result['command'] ?? ''}');
    final workingDirectory = '${result['workingDirectory'] ?? ''}'.trim();
    if (workingDirectory.isNotEmpty) {
      buffer.writeln('cwd: $workingDirectory');
    }
    const extraKeys = <String>[
      'backend',
      'task',
      'apk_path',
      'filter_spec',
      'output_dir',
      'reverse_root',
      'project_dir',
      'input_apk',
      'output_apk',
      'search_dir',
    ];
    for (final key in extraKeys) {
      final value = '${result[key] ?? ''}'.trim();
      if (value.isEmpty) continue;
      buffer.writeln('$key: $value');
    }
    for (final entry in extra.entries) {
      if (entry.value.trim().isEmpty) continue;
      buffer.writeln('${entry.key}: ${entry.value}');
    }
    if (result.containsKey('exitCode')) {
      buffer.writeln('exit_code: ${result['exitCode']}');
    }
    if (result['timedOut'] == true) {
      buffer.writeln('timed_out: true');
    }
    final stdout = '${result['stdout'] ?? ''}'.trimRight();
    final stderr = '${result['stderr'] ?? ''}'.trimRight();
    if (stdout.isNotEmpty) {
      buffer
        ..writeln('')
        ..writeln('stdout:')
        ..writeln(stdout);
    }
    if (stderr.isNotEmpty) {
      buffer
        ..writeln('')
        ..writeln('stderr:')
        ..writeln(stderr);
    }
    return buffer.toString().trimRight();
  }

  Future<void> _pickAndroidToolkitFile(
    TextEditingController controller, {
    List<String>? allowedExtensions,
    bool updateReverseLabelFromApk = false,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: allowedExtensions == null ? FileType.any : FileType.custom,
        allowedExtensions: allowedExtensions,
        withData: false,
      );
      final path = result == null || result.files.isEmpty
          ? ''
          : (result.files.first.path?.trim() ?? '');
      if (path.isEmpty) return;
      controller.text = path;
      if (updateReverseLabelFromApk &&
          _androidToolkitReverseLabelController.text.trim().isEmpty) {
        _androidToolkitReverseLabelController.text = _sanitizeWorkspaceSegment(
          path,
          fallback: 'sample_apk',
        );
      }
      setState(() {});
      _persistState();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Selected: $path')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('File selection failed: $error')));
    }
  }

  Future<void> _runAndroidToolkitAction({
    required String title,
    required Future<Map<String, dynamic>> Function() action,
  }) async {
    if (_runningAndroidToolkitAction) return;
    setState(() {
      _runningAndroidToolkitAction = true;
      _androidToolkitStatus = 'Running $title...';
    });
    try {
      final result = await action();
      final ok = result['ok'] == true;
      final output = _formatLocalCommandResult(title, result);
      setState(() {
        _runningAndroidToolkitAction = false;
        _androidToolkitStatus = ok ? '$title completed.' : '$title failed.';
        _androidToolkitOutput = output;
        _runtimeWorkbenchOutput = output;
      });
    } catch (error) {
      final message = '$title failed: $error';
      setState(() {
        _runningAndroidToolkitAction = false;
        _androidToolkitStatus = message;
        _androidToolkitOutput = message;
        _runtimeWorkbenchOutput = message;
      });
    }
  }

  Future<Map<String, dynamic>> _runAndroidGradleBuildTool({
    String? task,
    int timeoutMs = 120000,
    int maxOutputBytes = 262144,
  }) async {
    final effectiveTask = (task ?? _androidToolkitGradleTaskController.text)
        .trim();
    if (effectiveTask.isEmpty) {
      throw Exception('Gradle task is required');
    }
    final gradleCommand = _toolCommandValue(
      _androidToolkitGradleCommandController,
      fallback: 'gradle',
    );
    final args = _shellWordArgs(effectiveTask);
    final command =
        "if [ -x ./gradlew ]; then ./gradlew $args; "
        "elif [ -f ./gradlew ]; then sh ./gradlew $args; "
        "else $gradleCommand $args; fi";
    final result = await _executePrimaryBackendCommand(
      command: command,
      timeoutMs: timeoutMs,
      maxOutputBytes: maxOutputBytes,
      requireProjectWorkspace: true,
    );
    return <String, dynamic>{
      'ok': result['ok'] == true,
      'action': 'android_gradle_build',
      'backend': _primaryExecutionBackend,
      'task': effectiveTask,
      ...result,
    };
  }

  Future<Map<String, dynamic>> _runAndroidInstallApkTool({
    String? apkPath,
    bool replace = true,
    bool grantAll = false,
    int timeoutMs = 60000,
    int maxOutputBytes = 196608,
  }) async {
    final effectiveApkPath =
        (apkPath ?? _androidToolkitInstallApkPathController.text).trim();
    if (effectiveApkPath.isEmpty) {
      throw Exception('APK path is required');
    }
    final adbCommand = _toolCommandValue(
      _androidToolkitAdbCommandController,
      fallback: 'adb',
    );
    final args = <String>[
      'install',
      if (replace) '-r',
      if (grantAll) '-g',
      effectiveApkPath,
    ].map(_quoteShellArg).join(' ');
    final needsProjectWorkspace =
        !_looksLikeAbsolutePath(effectiveApkPath) &&
        (_projectRootPath?.trim().isNotEmpty ?? false);
    if (_deviceOperationsBackend == 'shizuku') {
      final resolvedPath = _resolveAndroidToolkitPath(effectiveApkPath);
      final result = await _runtimeBackendsChannel.invokeMethod<dynamic>(
        'installApkWithSystem',
        <String, dynamic>{'apkPath': resolvedPath},
      );
      final mapped = result is Map
          ? result.map((key, value) => MapEntry(key.toString(), value))
          : <String, dynamic>{'ok': false};
      return <String, dynamic>{
        'ok': mapped['ok'] == true,
        'action': 'android_install_apk',
        'apk_path': resolvedPath,
        'backend': 'shizuku',
        ...mapped,
      };
    }
    if (_deviceOperationsBackend == 'root') {
      final resolvedPath = _resolveAndroidToolkitPath(effectiveApkPath);
      final result = await _runtimeBackendsChannel
          .invokeMethod<dynamic>('installApkWithRoot', <String, dynamic>{
            'apkPath': resolvedPath,
            'replace': replace,
            'grantAll': grantAll,
            'timeoutMs': timeoutMs,
            'maxOutputBytes': maxOutputBytes,
          });
      final mapped = result is Map
          ? result.map((key, value) => MapEntry(key.toString(), value))
          : <String, dynamic>{'ok': false};
      return <String, dynamic>{
        'ok': mapped['ok'] == true,
        'action': 'android_install_apk',
        'apk_path': resolvedPath,
        'backend': 'root',
        ...mapped,
      };
    }
    final result = await _executePrimaryBackendCommand(
      command: '$adbCommand $args',
      timeoutMs: timeoutMs,
      maxOutputBytes: maxOutputBytes,
      requireProjectWorkspace: needsProjectWorkspace,
    );
    return <String, dynamic>{
      'ok': result['ok'] == true,
      'action': 'android_install_apk',
      'apk_path': effectiveApkPath,
      'backend': _primaryExecutionBackend,
      ...result,
    };
  }

  Future<Map<String, dynamic>> _runAndroidLogcatTool({
    String? filterSpec,
    bool clearBefore = false,
    int timeoutMs = 20000,
    int maxOutputBytes = 262144,
  }) async {
    final adbCommand = _toolCommandValue(
      _androidToolkitAdbCommandController,
      fallback: 'adb',
    );
    final effectiveFilter =
        (filterSpec ?? _androidToolkitLogcatFilterController.text).trim();
    final filterArgs = _shellWordArgs(effectiveFilter);
    final clearPrefix = clearBefore ? '$adbCommand logcat -c && ' : '';
    final command =
        '$clearPrefix$adbCommand logcat -d${filterArgs.isEmpty ? '' : ' $filterArgs'}';
    if (_deviceOperationsBackend == 'shizuku') {
      final result = await _runtimeBackendsChannel.invokeMethod<dynamic>(
        'captureSystemLogcat',
        <String, dynamic>{
          'filterSpec': effectiveFilter,
          'clearBefore': clearBefore,
        },
      );
      final mapped = result is Map
          ? result.map((key, value) => MapEntry(key.toString(), value))
          : <String, dynamic>{'ok': false};
      return <String, dynamic>{
        'ok': mapped['ok'] == true,
        'action': 'android_logcat',
        'filter_spec': effectiveFilter,
        'backend': 'shizuku',
        ...mapped,
      };
    }
    if (_deviceOperationsBackend == 'root') {
      final result = await _runtimeBackendsChannel
          .invokeMethod<dynamic>('captureRootLogcat', <String, dynamic>{
            'filterSpec': effectiveFilter,
            'clearBefore': clearBefore,
            'timeoutMs': timeoutMs,
            'maxOutputBytes': maxOutputBytes,
          });
      final mapped = result is Map
          ? result.map((key, value) => MapEntry(key.toString(), value))
          : <String, dynamic>{'ok': false};
      return <String, dynamic>{
        'ok': mapped['ok'] == true,
        'action': 'android_logcat',
        'filter_spec': effectiveFilter,
        'backend': 'root',
        ...mapped,
      };
    }
    final result = await _executePrimaryBackendCommand(
      command: command,
      timeoutMs: timeoutMs,
      maxOutputBytes: maxOutputBytes,
      requireProjectWorkspace: false,
    );
    return <String, dynamic>{
      'ok': result['ok'] == true,
      'action': 'android_logcat',
      'filter_spec': effectiveFilter,
      'backend': _primaryExecutionBackend,
      ...result,
    };
  }

  Future<Map<String, dynamic>> _runAndroidApktoolDecodeTool({
    String? apkPath,
    String? reverseLabel,
    int timeoutMs = 120000,
    int maxOutputBytes = 262144,
  }) async {
    final effectiveApkPath = (apkPath ?? _androidToolkitApkPathController.text)
        .trim();
    if (effectiveApkPath.isEmpty) {
      throw Exception('APK path is required');
    }
    final label = _sanitizeWorkspaceSegment(
      reverseLabel ?? _androidToolkitReverseLabel(),
      fallback: 'sample_apk',
    );
    final root = _androidToolkitReverseRoot(label);
    final outputDir = '$root/apktool';
    final apktoolCommand = _toolCommandValue(
      _androidToolkitApktoolCommandController,
      fallback: 'apktool',
    );
    final command =
        'mkdir -p ${_quoteShellArg(root)} && '
        'rm -rf ${_quoteShellArg(outputDir)} && '
        '$apktoolCommand d -f ${_quoteShellArg(effectiveApkPath)} '
        '-o ${_quoteShellArg(outputDir)}';
    final result = await _executePrimaryBackendCommand(
      command: command,
      timeoutMs: timeoutMs,
      maxOutputBytes: maxOutputBytes,
      requireProjectWorkspace: false,
    );
    return <String, dynamic>{
      'ok': result['ok'] == true,
      'action': 'android_decompile_apk',
      'backend': _primaryExecutionBackend,
      'apk_path': effectiveApkPath,
      'output_dir': outputDir,
      'reverse_root': root,
      ...result,
    };
  }

  Future<Map<String, dynamic>> _runAndroidJadxTool({
    String? apkPath,
    String? reverseLabel,
    int timeoutMs = 120000,
    int maxOutputBytes = 262144,
  }) async {
    final effectiveApkPath = (apkPath ?? _androidToolkitApkPathController.text)
        .trim();
    if (effectiveApkPath.isEmpty) {
      throw Exception('APK path is required');
    }
    final label = _sanitizeWorkspaceSegment(
      reverseLabel ?? _androidToolkitReverseLabel(),
      fallback: 'sample_apk',
    );
    final root = _androidToolkitReverseRoot(label);
    final outputDir = '$root/jadx';
    final jadxCommand = _toolCommandValue(
      _androidToolkitJadxCommandController,
      fallback: 'jadx',
    );
    final command =
        'mkdir -p ${_quoteShellArg(root)} && '
        'rm -rf ${_quoteShellArg(outputDir)} && '
        '$jadxCommand -d ${_quoteShellArg(outputDir)} '
        '${_quoteShellArg(effectiveApkPath)}';
    final result = await _executePrimaryBackendCommand(
      command: command,
      timeoutMs: timeoutMs,
      maxOutputBytes: maxOutputBytes,
      requireProjectWorkspace: false,
    );
    return <String, dynamic>{
      'ok': result['ok'] == true,
      'action': 'android_run_jadx',
      'backend': _primaryExecutionBackend,
      'apk_path': effectiveApkPath,
      'output_dir': outputDir,
      'reverse_root': root,
      ...result,
    };
  }

  Future<Map<String, dynamic>> _runAndroidJadxSearchTool({
    String? query,
    String? reverseLabel,
    int maxResults = 40,
    bool caseSensitive = false,
    int timeoutMs = 20000,
    int maxOutputBytes = 196608,
  }) async {
    final effectiveQuery = (query ?? _androidToolkitJadxQueryController.text)
        .trim();
    if (effectiveQuery.isEmpty) {
      throw Exception('Search query is required');
    }
    final label = _sanitizeWorkspaceSegment(
      reverseLabel ?? _androidToolkitReverseLabel(),
      fallback: 'sample_apk',
    );
    final searchDir = '${_androidToolkitReverseRoot(label)}/jadx';
    final caseFlag = caseSensitive ? '' : '-i ';
    final command =
        'if command -v rg >/dev/null 2>&1; then '
        'rg -n ${caseSensitive ? '' : '-i '}'
        '--max-count ${maxResults.clamp(1, 200)} '
        '${_quoteShellArg(effectiveQuery)} ${_quoteShellArg(searchDir)}; '
        'else '
        'grep -RIn $caseFlag${_quoteShellArg(effectiveQuery)} '
        '${_quoteShellArg(searchDir)} | head -n ${maxResults.clamp(1, 200)}; '
        'fi';
    final result = await _executePrimaryBackendCommand(
      command: command,
      timeoutMs: timeoutMs,
      maxOutputBytes: maxOutputBytes,
      requireProjectWorkspace: false,
    );
    return <String, dynamic>{
      'ok': result['ok'] == true,
      'action': 'android_search_jadx',
      'backend': _primaryExecutionBackend,
      'query': effectiveQuery,
      'search_dir': searchDir,
      ...result,
    };
  }

  Future<Map<String, dynamic>> _runAndroidApktoolBuildTool({
    String? reverseLabel,
    int timeoutMs = 120000,
    int maxOutputBytes = 262144,
  }) async {
    final label = _sanitizeWorkspaceSegment(
      reverseLabel ?? _androidToolkitReverseLabel(),
      fallback: 'sample_apk',
    );
    final root = _androidToolkitReverseRoot(label);
    final decodeDir = '$root/apktool';
    final outputApk = '$root/dist/${label}_unsigned.apk';
    final apktoolCommand = _toolCommandValue(
      _androidToolkitApktoolCommandController,
      fallback: 'apktool',
    );
    final command =
        'mkdir -p ${_quoteShellArg('$root/dist')} && '
        '$apktoolCommand b ${_quoteShellArg(decodeDir)} '
        '-o ${_quoteShellArg(outputApk)}';
    final result = await _executePrimaryBackendCommand(
      command: command,
      timeoutMs: timeoutMs,
      maxOutputBytes: maxOutputBytes,
      requireProjectWorkspace: false,
    );
    return <String, dynamic>{
      'ok': result['ok'] == true,
      'action': 'android_rebuild_apk',
      'backend': _primaryExecutionBackend,
      'project_dir': decodeDir,
      'output_apk': outputApk,
      ...result,
    };
  }

  Future<Map<String, dynamic>> _runAndroidSignApkTool({
    String? reverseLabel,
    int timeoutMs = 120000,
    int maxOutputBytes = 196608,
  }) async {
    final keystorePath = _androidToolkitKeystorePathController.text.trim();
    final alias = _androidToolkitKeystoreAliasController.text.trim();
    final storePassword = _androidToolkitStorePasswordController.text;
    if (keystorePath.isEmpty || alias.isEmpty || storePassword.isEmpty) {
      throw Exception('Keystore path, alias, and store password are required');
    }
    final label = _sanitizeWorkspaceSegment(
      reverseLabel ?? _androidToolkitReverseLabel(),
      fallback: 'sample_apk',
    );
    final root = _androidToolkitReverseRoot(label);
    final unsignedApk = '$root/dist/${label}_unsigned.apk';
    final alignedApk = '$root/dist/${label}_aligned.apk';
    final signedApk = '$root/dist/${label}_signed.apk';
    final apksignerCommand = _toolCommandValue(
      _androidToolkitApksignerCommandController,
      fallback: 'apksigner',
    );
    final zipalignCommand = _toolCommandValue(
      _androidToolkitZipalignCommandController,
      fallback: 'zipalign',
    );
    final keyPassword = _androidToolkitKeyPasswordController.text;
    final keyPassArg = keyPassword.isEmpty
        ? ''
        : ' --key-pass ${_quoteShellArg('pass:$keyPassword')}';
    final command =
        'mkdir -p ${_quoteShellArg('$root/dist')} && '
        '$zipalignCommand -f 4 ${_quoteShellArg(unsignedApk)} '
        '${_quoteShellArg(alignedApk)} && '
        '$apksignerCommand sign '
        '--ks ${_quoteShellArg(keystorePath)} '
        '--ks-key-alias ${_quoteShellArg(alias)} '
        '--ks-pass ${_quoteShellArg('pass:$storePassword')}'
        '$keyPassArg '
        '--out ${_quoteShellArg(signedApk)} '
        '${_quoteShellArg(alignedApk)}';
    final result = await _executePrimaryBackendCommand(
      command: command,
      timeoutMs: timeoutMs,
      maxOutputBytes: maxOutputBytes,
      requireProjectWorkspace: false,
    );
    return <String, dynamic>{
      'ok': result['ok'] == true,
      'action': 'android_sign_apk',
      'backend': _primaryExecutionBackend,
      'input_apk': unsignedApk,
      'output_apk': signedApk,
      ...result,
    };
  }

  String _activeReasoningEffort() {
    final activeConnection = _activeConnection;
    if (activeConnection != null) {
      return _normalizeReasoningEffort(activeConnection.reasoningEffort);
    }
    return _normalizeReasoningEffort(_activeProviderConfig.reasoningEffort);
  }

  List<String> _composerModelOptions() {
    final output = <String>[];
    final dedup = <String>{};

    void addOption(String value) {
      final item = value.trim();
      if (item.isEmpty) return;
      if (!dedup.add(item)) return;
      output.add(item);
    }

    final activeConfig = _activeProviderConfig;
    addOption(activeConfig.model);
    for (final item in activeConfig.availableModels) {
      addOption(item);
    }

    final activeConnection = _activeConnection;
    if (activeConnection != null) {
      for (final item in activeConnection.availableModels) {
        addOption(item);
      }
    }

    return output;
  }

  Future<void> _switchComposerModel(String model) async {
    final targetModel = model.trim();
    if (targetModel.isEmpty) return;

    setState(() {
      final activeConnection = _activeConnection;
      if (activeConnection != null) {
        final index = _apiConnections.indexWhere(
          (item) => item.id == activeConnection.id,
        );
        if (index >= 0) {
          final options = {
            ..._apiConnections[index].availableModels,
            targetModel,
          }.toList();
          final updated = _apiConnections[index].copyWith(
            model: targetModel,
            availableModels: options,
          );
          _apiConnections[index] = updated;
          _providerConfigs[updated.providerId] = updated.toConfig();
          _activeProviderId = updated.providerId;
        }
      } else {
        final providerId = _activeProviderId;
        final previous = _configOf(providerId);
        final nextOptions = {...previous.availableModels, targetModel}.toList();
        _providerConfigs[providerId] = previous.copyWith(
          model: targetModel,
          availableModels: nextOptions,
        );
      }
    });
    _persistState();
  }

  Future<void> _switchComposerReasoningEffort(String effort) async {
    final normalized = _normalizeReasoningEffort(effort);
    setState(() {
      final activeConnection = _activeConnection;
      if (activeConnection != null) {
        final index = _apiConnections.indexWhere(
          (item) => item.id == activeConnection.id,
        );
        if (index >= 0) {
          final updated = _apiConnections[index].copyWith(
            reasoningEffort: normalized,
          );
          _apiConnections[index] = updated;
          _providerConfigs[updated.providerId] = updated.toConfig();
        }
      } else {
        final providerId = _activeProviderId;
        final previous = _configOf(providerId);
        _providerConfigs[providerId] = previous.copyWith(
          reasoningEffort: normalized,
        );
      }
    });
    _persistState();
  }

  void _stopCurrentReply() {
    if (!_sendingPrompt) return;
    _stopReplyRequested = true;
    _updateReplyProgress('正在停止回复');
    try {
      _activeChatRequest?.abort();
    } catch (_) {}
    try {
      _activeChatClient?.close(force: true);
    } catch (_) {}
  }

  String _normalizeModelIdentity(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower.startsWith('models/')) {
      return lower.substring('models/'.length);
    }
    return lower;
  }

  bool _containsAnyToken(String source, List<String> tokens) {
    for (final token in tokens) {
      if (source.contains(token)) return true;
    }
    return false;
  }

  String _suggestModelDisplayName(String modelName) {
    final trimmed = modelName.trim();
    if (trimmed.isEmpty) return '';
    final slashIndex = trimmed.lastIndexOf('/');
    final colonIndex = trimmed.lastIndexOf(':');
    final cutIndex = max(slashIndex, colonIndex);
    final core = cutIndex >= 0 ? trimmed.substring(cutIndex + 1) : trimmed;
    final words = core
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .split(RegExp(r'\s+'))
        .where((item) => item.trim().isNotEmpty)
        .map((item) {
          final value = item.trim();
          if (RegExp(r'^\d+(\.\d+)?$').hasMatch(value)) return value;
          if (value.toUpperCase() == value) return value;
          return '${value[0].toUpperCase()}${value.substring(1)}';
        })
        .toList();
    if (words.isEmpty) return trimmed;
    return words.join(' ');
  }

  Future<_ModelCapabilityDetection> _detectModelCapabilities({
    required ModelProvider provider,
    required String baseUrl,
    required String apiKey,
    required String modelName,
    required bool improveNetworkCompatibility,
    String modelListPath = '',
    Map<String, String> extraHeaders = const <String, String>{},
  }) async {
    final model = modelName.trim();
    if (model.isEmpty) {
      throw Exception('请先填写模型名称');
    }

    var fetchedModels = const <String>[];
    var remoteCatalog = const _ModelCatalog();
    String? remoteDetectIssue;
    final guide = kProviderGuides[provider.id];
    if (baseUrl.trim().isNotEmpty && (guide?.supportsAutoFetch ?? false)) {
      try {
        remoteCatalog = await _requestModelCatalog(
          provider: provider,
          baseUrl: baseUrl,
          apiKey: apiKey,
          modelListPath: modelListPath,
          extraHeaders: extraHeaders,
          improveNetworkCompatibility: improveNetworkCompatibility,
        );
        fetchedModels = remoteCatalog.modelIds;
      } catch (error) {
        remoteDetectIssue = error.toString();
      }
    }

    final lower = model.toLowerCase();
    final normalizedModel = _normalizeModelIdentity(model);
    final inputModes = <String>{'text'};
    final outputModes = <String>{'text'};
    var modelType = 'chat';

    final embeddingLike = _containsAnyToken(lower, const [
      'embedding',
      'embed',
      'text-embedding',
      'bge-',
      'e5-',
      'm3e',
      'rerank',
    ]);
    final imageGenerationLike = _containsAnyToken(lower, const [
      'gpt-image',
      'image-gen',
      'imagegen',
      'stable-diffusion',
      'sdxl',
      'flux',
      'midjourney',
      'kandinsky',
      'hunyuan-image',
      'wanx',
      'seedream',
      'imagen',
    ]);
    final visionLike = _containsAnyToken(lower, const [
      'vision',
      '-vl',
      '/vl',
      'multimodal',
      '4o',
      'omni',
      'gemini',
      'pixtral',
      'llava',
      'glm-4v',
      'qwen-vl',
      'internvl',
      'grok-vision',
      'claude-3',
      'claude-sonnet-4',
      'gemma3',
      'smolvlm',
      'minicpm-v',
      'mllama',
      'molmo',
      'phi-4-multimodal',
      'idefics',
      'fuyu',
      'janus',
      'vision-instruct',
    ]);
    final remoteSignal = remoteCatalog.signalsByNormalizedId[normalizedModel];

    if (remoteSignal?.isEmbedding == true || embeddingLike) {
      modelType = 'embedding';
      inputModes
        ..clear()
        ..add('text');
      outputModes
        ..clear()
        ..add('text');
    } else if (remoteSignal?.isImageGeneration == true || imageGenerationLike) {
      modelType = 'image';
      inputModes
        ..clear()
        ..add('text');
      outputModes
        ..clear()
        ..add('image');
      if (_containsAnyToken(lower, const ['img2img', 'edit', 'variation'])) {
        inputModes.add('image');
      }
    } else {
      modelType = 'chat';
      if (visionLike) {
        inputModes.add('image');
      }
      if (_containsAnyToken(lower, const ['img2img', 'image-edit'])) {
        outputModes.add('image');
      }
    }

    if (remoteSignal != null && modelType == 'chat') {
      if (remoteSignal.supportsImageInput) {
        inputModes.add('image');
      }
      if (remoteSignal.supportsImageOutput) {
        outputModes.add('image');
      }
    }

    var capabilityTools =
        modelType == 'chat' &&
        (_chatCapableProviders.contains(provider.id) ||
            _containsAnyToken(lower, const [
              'tool',
              'function',
              'gpt-4',
              'gpt-5',
              'deepseek',
              'qwen',
              'llama',
              'claude',
              'gemini',
              'mistral',
              'grok',
            ]));

    var capabilityReasoning =
        modelType == 'chat' &&
        _containsAnyToken(lower, const [
          'reason',
          'reasoning',
          'think',
          'thinking',
          'deepseek-r1',
          'r1',
          'qwq',
          'o1',
          'o3',
          'o4',
        ]);

    if (modelType != 'chat') {
      capabilityTools = false;
      capabilityReasoning = false;
    }

    final remoteMatched =
        fetchedModels.isNotEmpty &&
        fetchedModels.map(_normalizeModelIdentity).contains(normalizedModel);
    final mayHaveVisionButUndetected =
        modelType == 'chat' &&
        !inputModes.contains('image') &&
        remoteMatched &&
        _chatCapableProviders.contains(provider.id) &&
        !_containsAnyToken(lower, _nonVisionModelTokens);
    if (mayHaveVisionButUndetected) {
      // Prefer non-restrictive defaults to avoid suppressing model potential.
      inputModes.add('image');
    }

    String statusText;
    if (remoteMatched) {
      statusText = '检测完成：连接可用，模型已在返回列表中匹配';
    } else if (fetchedModels.isNotEmpty) {
      statusText = '检测完成：连接可用，能力已推断（模型未在返回列表中精确匹配）';
    } else if (remoteDetectIssue != null && remoteDetectIssue.isNotEmpty) {
      statusText = '已按模型名完成能力推断（远程检测未完成）';
    } else {
      statusText = '已按模型名完成能力推断';
    }

    return _ModelCapabilityDetection(
      modelDisplayName: _suggestModelDisplayName(model),
      modelType: modelType,
      inputModes: inputModes,
      outputModes: outputModes,
      capabilityTools: capabilityTools,
      capabilityReasoning: capabilityReasoning,
      statusText: statusText,
      availableModels: fetchedModels,
    );
  }

  Future<void> _restoreState() async {
    _restoringState = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final providerConfigsRaw = prefs.getString(_prefsProviderConfigs);
      final messagesRaw = prefs.getString(_prefsMessages);
      final terminalLogsRaw = prefs.getString(_prefsTerminalLogs);
      final apiConnectionsRaw = prefs.getString(_prefsApiConnections);
      final conversationHistoryRaw = prefs.getString(_prefsConversationHistory);
      final savedExpandedSettingsSections =
          prefs.getStringList(_prefsSettingsExpandedSections) ??
          const <String>[];
      final hasSavedReplyStructureSections = prefs.containsKey(
        _prefsReplyStructureSections,
      );
      final savedReplyStructureSections =
          prefs.getStringList(_prefsReplyStructureSections) ?? const <String>[];

      final restoredProviderConfigs = <String, ProviderConfig>{};
      if (providerConfigsRaw != null && providerConfigsRaw.isNotEmpty) {
        final decoded = jsonDecode(providerConfigsRaw);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            if (entry.value is Map<String, dynamic>) {
              restoredProviderConfigs[entry.key.toString()] =
                  ProviderConfig.fromJson(entry.value as Map<String, dynamic>);
            } else if (entry.value is Map) {
              restoredProviderConfigs[entry.key
                  .toString()] = ProviderConfig.fromJson(
                (entry.value as Map).map(
                  (key, value) => MapEntry(key.toString(), value),
                ),
              );
            }
          }
        }
      }

      final restoredMessages = <ChatMessage>[];
      if (messagesRaw != null && messagesRaw.isNotEmpty) {
        final decoded = jsonDecode(messagesRaw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              restoredMessages.add(ChatMessage.fromJson(item));
            } else if (item is Map) {
              restoredMessages.add(
                ChatMessage.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              );
            }
          }
        }
      }

      final restoredTerminal = <String>[];
      if (terminalLogsRaw != null && terminalLogsRaw.isNotEmpty) {
        final decoded = jsonDecode(terminalLogsRaw);
        if (decoded is List) {
          restoredTerminal.addAll(decoded.map((item) => item.toString()));
        }
      }

      final restoredConnections = <ApiConnectionProfile>[];
      if (apiConnectionsRaw != null && apiConnectionsRaw.isNotEmpty) {
        final decoded = jsonDecode(apiConnectionsRaw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              restoredConnections.add(ApiConnectionProfile.fromJson(item));
            } else if (item is Map) {
              restoredConnections.add(
                ApiConnectionProfile.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              );
            }
          }
        }
      }

      final restoredConversationHistory = <_ConversationSummary>[];
      if (conversationHistoryRaw != null && conversationHistoryRaw.isNotEmpty) {
        final decoded = jsonDecode(conversationHistoryRaw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              restoredConversationHistory.add(
                _ConversationSummary.fromJson(item),
              );
            } else if (item is Map) {
              restoredConversationHistory.add(
                _ConversationSummary.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
              );
            }
          }
        }
      }

      if (restoredConnections.isEmpty && restoredProviderConfigs.isNotEmpty) {
        for (final entry in restoredProviderConfigs.entries) {
          final cfg = entry.value;
          if (cfg.baseUrl.trim().isEmpty &&
              cfg.apiKey.trim().isEmpty &&
              cfg.model.trim().isEmpty) {
            continue;
          }
          final providerName = _providerName(entry.key);
          restoredConnections.add(
            ApiConnectionProfile(
              id: 'migrate_${entry.key}',
              name: '$providerName API',
              providerId: entry.key,
              baseUrl: cfg.baseUrl,
              apiPath: cfg.apiPath,
              modelListPath: cfg.modelListPath,
              apiKey: cfg.apiKey,
              extraHeaders: cfg.extraHeaders,
              model: cfg.model,
              availableModels: cfg.availableModels,
              improveNetworkCompatibility: cfg.improveNetworkCompatibility,
              reasoningEffort: _normalizeReasoningEffort(cfg.reasoningEffort),
            ),
          );
        }
      }

      final savedActiveProviderId =
          prefs.getString(_prefsActiveProviderId) ?? 'openai';
      final savedProjectRootRaw = prefs.getString(_prefsProjectRoot);
      final savedProjectRoot =
          (savedProjectRootRaw == null || savedProjectRootRaw.trim().isEmpty)
          ? null
          : savedProjectRootRaw;
      final savedProjectContext = prefs.getString(_prefsProjectContext) ?? '';
      final savedAiFsGranted = prefs.getBool(_prefsAiFsGranted) ?? false;
      final savedShowTerminal = prefs.getBool(_prefsShowTerminal) ?? false;
      final savedConversationTitleRaw = prefs.getString(
        _prefsConversationTitle,
      );
      final savedConversationTitle =
          (savedConversationTitleRaw == null ||
              savedConversationTitleRaw.trim().isEmpty)
          ? _defaultConversationTitle
          : savedConversationTitleRaw.trim();
      final savedActiveConnectionIdRaw = prefs.getString(
        _prefsActiveConnectionId,
      );
      final savedActiveConnectionId =
          (savedActiveConnectionIdRaw == null ||
              savedActiveConnectionIdRaw.trim().isEmpty)
          ? null
          : savedActiveConnectionIdRaw;
      final savedActiveConversationIdRaw = prefs.getString(
        _prefsActiveConversationId,
      );
      final savedActiveConversationId =
          (savedActiveConversationIdRaw == null ||
              savedActiveConversationIdRaw.trim().isEmpty)
          ? 'conv_${DateTime.now().microsecondsSinceEpoch}'
          : savedActiveConversationIdRaw.trim();
      final savedActiveConversationPinned =
          prefs.getBool(_prefsActiveConversationPinned) ?? false;
      final savedApiConnectionsCollapsed =
          prefs.getBool(_prefsApiConnectionsCollapsed) ?? false;
      final savedGodotMcpEnabled =
          prefs.getBool(_prefsGodotMcpEnabled) ?? false;
      final savedGodotMcpBridgeUrl =
          prefs.getString(_prefsGodotMcpBridgeUrl) ?? '';
      final savedGodotMcpBridgeToken =
          prefs.getString(_prefsGodotMcpBridgeToken) ?? '';
      final savedDownloadAssetMaxBytes = _normalizeDownloadMaxBytes(
        prefs.getInt(_prefsDownloadAssetMaxBytes) ?? _defaultDownloadMaxBytes,
      );
      final savedBackgroundGuardEnabled =
          prefs.getBool(_prefsBackgroundGuardEnabled) ?? false;
      final savedAndroidToolkitApkPath =
          prefs.getString(_prefsAndroidToolkitApkPath) ?? '';
      final savedAndroidToolkitReverseLabel =
          prefs.getString(_prefsAndroidToolkitReverseLabel) ?? '';
      final savedAndroidToolkitJadxQuery =
          prefs.getString(_prefsAndroidToolkitJadxQuery) ?? '';
      final savedAndroidToolkitGradleTask =
          prefs.getString(_prefsAndroidToolkitGradleTask) ?? 'assembleDebug';
      final savedAndroidToolkitInstallApkPath =
          prefs.getString(_prefsAndroidToolkitInstallApkPath) ??
          'app/build/outputs/apk/debug/app-debug.apk';
      final savedAndroidToolkitLogcatFilter =
          prefs.getString(_prefsAndroidToolkitLogcatFilter) ?? '';
      final savedAndroidToolkitKeystorePath =
          prefs.getString(_prefsAndroidToolkitKeystorePath) ?? '';
      final savedAndroidToolkitKeystoreAlias =
          prefs.getString(_prefsAndroidToolkitKeystoreAlias) ?? '';
      final savedAndroidToolkitStorePassword =
          prefs.getString(_prefsAndroidToolkitStorePassword) ?? '';
      final savedAndroidToolkitKeyPassword =
          prefs.getString(_prefsAndroidToolkitKeyPassword) ?? '';
      final savedAndroidToolkitAdbCommand =
          prefs.getString(_prefsAndroidToolkitAdbCommand) ?? 'adb';
      final savedAndroidToolkitApktoolCommand =
          prefs.getString(_prefsAndroidToolkitApktoolCommand) ?? 'apktool';
      final savedAndroidToolkitJadxCommand =
          prefs.getString(_prefsAndroidToolkitJadxCommand) ?? 'jadx';
      final savedAndroidToolkitApksignerCommand =
          prefs.getString(_prefsAndroidToolkitApksignerCommand) ?? 'apksigner';
      final savedAndroidToolkitZipalignCommand =
          prefs.getString(_prefsAndroidToolkitZipalignCommand) ?? 'zipalign';
      final savedAndroidToolkitGradleCommand =
          prefs.getString(_prefsAndroidToolkitGradleCommand) ?? 'gradle';
      final savedPrimaryExecutionBackend =
          prefs.getString(_prefsPrimaryExecutionBackend) ?? 'native';
      final savedDeviceOperationsBackend =
          prefs.getString(_prefsDeviceOperationsBackend) ?? 'native';
      final savedTermuxWorkdir = prefs.getString(_prefsTermuxWorkdir) ?? '';
      final savedTermuxCommandTemplate =
          prefs.getString(_prefsTermuxCommandTemplate) ?? '';

      if (!mounted) return;
      setState(() {
        _providerConfigs
          ..clear()
          ..addAll(restoredProviderConfigs);

        _apiConnections
          ..clear()
          ..addAll(restoredConnections);

        _activeConnectionId = savedActiveConnectionId;
        _activeProviderId = savedActiveProviderId;
        _activeConversationId = savedActiveConversationId;
        _activeConversationPinned = savedActiveConversationPinned;
        _conversationTitle = savedConversationTitle;
        _projectRootPath = savedProjectRoot;
        _projectContext = savedProjectContext;
        _aiFsGranted = savedAiFsGranted;
        _showTerminal = savedShowTerminal;
        _apiConnectionsCollapsed = savedApiConnectionsCollapsed;
        _godotMcpEnabled = savedGodotMcpEnabled;
        _godotMcpBridgeUrl = savedGodotMcpBridgeUrl.trim();
        _godotMcpBridgeToken = savedGodotMcpBridgeToken.trim();
        _downloadAssetMaxBytes = savedDownloadAssetMaxBytes;
        _backgroundGuardEnabled = savedBackgroundGuardEnabled;
        _primaryExecutionBackend = savedPrimaryExecutionBackend == 'termux'
            ? 'termux'
            : 'native';
        _deviceOperationsBackend =
            savedDeviceOperationsBackend == 'shizuku' ||
                savedDeviceOperationsBackend == 'root'
            ? savedDeviceOperationsBackend
            : 'native';

        _messages
          ..clear()
          ..addAll(
            restoredMessages.isEmpty
                ? [_buildWelcomeMessage()]
                : restoredMessages,
          );

        _terminalLogs
          ..clear()
          ..addAll(
            restoredTerminal.isEmpty
                ? const ['Astra Terminal ready.', '输入 help 查看内置命令。']
                : restoredTerminal,
          );

        _conversationHistory
          ..clear()
          ..addAll(restoredConversationHistory);
        _conversationHistory.removeWhere(
          (item) => item.id == _activeConversationId,
        );
        if (savedExpandedSettingsSections.isNotEmpty) {
          _expandedSettingsSections
            ..clear()
            ..addAll(
              savedExpandedSettingsSections.where(
                (item) => item.trim().isNotEmpty,
              ),
            );
        }
        if (hasSavedReplyStructureSections) {
          _enabledReplyStructureSections
            ..clear()
            ..addAll(
              savedReplyStructureSections.where(
                (item) => item.trim().isNotEmpty,
              ),
            );
        }
      });

      final activeConnection = _activeConnection;
      if (activeConnection != null) {
        _activeProviderId = activeConnection.providerId;
        _providerConfigs[activeConnection.providerId] = activeConnection
            .toConfig();
      } else if (_apiConnections.isNotEmpty) {
        await _activateConnection(_apiConnections.first.id, silent: true);
      }

      if (savedProjectRoot != null && savedProjectRoot.isNotEmpty) {
        await _loadProjectFolder(savedProjectRoot, silent: true);
      }
      _godotBridgeUrlController.text = _godotMcpBridgeUrl;
      _godotBridgeTokenController.text = _godotMcpBridgeToken;
      _androidToolkitApkPathController.text = savedAndroidToolkitApkPath.trim();
      _androidToolkitReverseLabelController.text =
          savedAndroidToolkitReverseLabel.trim();
      _androidToolkitJadxQueryController.text = savedAndroidToolkitJadxQuery
          .trim();
      _androidToolkitGradleTaskController.text = savedAndroidToolkitGradleTask
          .trim();
      _androidToolkitInstallApkPathController.text =
          savedAndroidToolkitInstallApkPath.trim();
      _androidToolkitLogcatFilterController.text =
          savedAndroidToolkitLogcatFilter.trim();
      _androidToolkitKeystorePathController.text =
          savedAndroidToolkitKeystorePath.trim();
      _androidToolkitKeystoreAliasController.text =
          savedAndroidToolkitKeystoreAlias.trim();
      _androidToolkitStorePasswordController.text =
          savedAndroidToolkitStorePassword;
      _androidToolkitKeyPasswordController.text =
          savedAndroidToolkitKeyPassword;
      _androidToolkitAdbCommandController.text = savedAndroidToolkitAdbCommand
          .trim();
      _androidToolkitApktoolCommandController.text =
          savedAndroidToolkitApktoolCommand.trim();
      _androidToolkitJadxCommandController.text = savedAndroidToolkitJadxCommand
          .trim();
      _androidToolkitApksignerCommandController.text =
          savedAndroidToolkitApksignerCommand.trim();
      _androidToolkitZipalignCommandController.text =
          savedAndroidToolkitZipalignCommand.trim();
      _androidToolkitGradleCommandController.text =
          savedAndroidToolkitGradleCommand.trim();
      _termuxWorkdirController.text = savedTermuxWorkdir.trim();
      _termuxCommandTemplateController.text = savedTermuxCommandTemplate.trim();
      _applyRecommendedMobileDevPreset(force: false, persist: false);
    } catch (_) {
      // Ignore restore failures and continue with in-memory defaults.
    } finally {
      _restoringState = false;
    }
  }

  Future<void> _saveState() async {
    if (_restoringState) return;
    _godotMcpBridgeUrl = _godotBridgeUrlController.text.trim();
    _godotMcpBridgeToken = _godotBridgeTokenController.text.trim();
    final prefs = await SharedPreferences.getInstance();
    final providerJson = <String, dynamic>{};
    for (final entry in _providerConfigs.entries) {
      providerJson[entry.key] = entry.value.toJson();
    }

    await prefs.setString(
      _prefsMessages,
      jsonEncode(_messages.map((item) => item.toJson()).toList()),
    );
    await prefs.setString(_prefsTerminalLogs, jsonEncode(_terminalLogs));
    await prefs.setString(_prefsProjectRoot, _projectRootPath ?? '');
    await prefs.setString(_prefsProjectContext, _projectContext);
    await prefs.setBool(_prefsAiFsGranted, _aiFsGranted);
    await prefs.setBool(_prefsShowTerminal, _showTerminal);
    await prefs.setString(_prefsConversationTitle, _conversationTitle.trim());
    await prefs.setString(_prefsActiveConversationId, _activeConversationId);
    await prefs.setBool(
      _prefsActiveConversationPinned,
      _activeConversationPinned,
    );
    await prefs.setString(
      _prefsConversationHistory,
      jsonEncode(_conversationHistory.map((item) => item.toJson()).toList()),
    );
    await prefs.setBool(
      _prefsApiConnectionsCollapsed,
      _apiConnectionsCollapsed,
    );
    await prefs.setString(_prefsProviderConfigs, jsonEncode(providerJson));
    await prefs.setString(_prefsActiveProviderId, _activeProviderId);
    await prefs.setString(
      _prefsApiConnections,
      jsonEncode(_apiConnections.map((item) => item.toJson()).toList()),
    );
    await prefs.setString(_prefsActiveConnectionId, _activeConnectionId ?? '');
    await prefs.setBool(_prefsGodotMcpEnabled, _godotMcpEnabled);
    await prefs.setString(_prefsGodotMcpBridgeUrl, _godotMcpBridgeUrl.trim());
    await prefs.setString(
      _prefsGodotMcpBridgeToken,
      _godotMcpBridgeToken.trim(),
    );
    await prefs.setInt(_prefsDownloadAssetMaxBytes, _downloadAssetMaxBytes);
    await prefs.setBool(_prefsBackgroundGuardEnabled, _backgroundGuardEnabled);
    await prefs.setString(
      _prefsAndroidToolkitApkPath,
      _androidToolkitApkPathController.text.trim(),
    );
    await prefs.setString(
      _prefsAndroidToolkitReverseLabel,
      _androidToolkitReverseLabelController.text.trim(),
    );
    await prefs.setString(
      _prefsAndroidToolkitJadxQuery,
      _androidToolkitJadxQueryController.text.trim(),
    );
    await prefs.setString(
      _prefsAndroidToolkitGradleTask,
      _androidToolkitGradleTaskController.text.trim(),
    );
    await prefs.setString(
      _prefsAndroidToolkitInstallApkPath,
      _androidToolkitInstallApkPathController.text.trim(),
    );
    await prefs.setString(
      _prefsAndroidToolkitLogcatFilter,
      _androidToolkitLogcatFilterController.text.trim(),
    );
    await prefs.setString(
      _prefsAndroidToolkitKeystorePath,
      _androidToolkitKeystorePathController.text.trim(),
    );
    await prefs.setString(
      _prefsAndroidToolkitKeystoreAlias,
      _androidToolkitKeystoreAliasController.text.trim(),
    );
    await prefs.setString(
      _prefsAndroidToolkitStorePassword,
      _androidToolkitStorePasswordController.text,
    );
    await prefs.setString(
      _prefsAndroidToolkitKeyPassword,
      _androidToolkitKeyPasswordController.text,
    );
    await prefs.setString(
      _prefsAndroidToolkitAdbCommand,
      _androidToolkitAdbCommandController.text.trim(),
    );
    await prefs.setString(
      _prefsAndroidToolkitApktoolCommand,
      _androidToolkitApktoolCommandController.text.trim(),
    );
    await prefs.setString(
      _prefsAndroidToolkitJadxCommand,
      _androidToolkitJadxCommandController.text.trim(),
    );
    await prefs.setString(
      _prefsAndroidToolkitApksignerCommand,
      _androidToolkitApksignerCommandController.text.trim(),
    );
    await prefs.setString(
      _prefsAndroidToolkitZipalignCommand,
      _androidToolkitZipalignCommandController.text.trim(),
    );
    await prefs.setString(
      _prefsAndroidToolkitGradleCommand,
      _androidToolkitGradleCommandController.text.trim(),
    );
    await prefs.setString(
      _prefsPrimaryExecutionBackend,
      _primaryExecutionBackend,
    );
    await prefs.setString(
      _prefsDeviceOperationsBackend,
      _deviceOperationsBackend,
    );
    await prefs.setString(
      _prefsTermuxWorkdir,
      _termuxWorkdirController.text.trim(),
    );
    await prefs.setString(
      _prefsTermuxCommandTemplate,
      _termuxCommandTemplateController.text.trim(),
    );
    await prefs.setStringList(
      _prefsSettingsExpandedSections,
      _expandedSettingsSections.toList(),
    );
    await prefs.setStringList(
      _prefsReplyStructureSections,
      _enabledReplyStructureSections.toList(),
    );
  }

  void _persistState() {
    if (_restoringState) return;
    _persistStateDebounce?.cancel();
    _persistStateDebounce = Timer(const Duration(milliseconds: 220), () {
      unawaited(_saveState());
    });
  }

  void _toggleSettingsSection(String id) {
    setState(() {
      if (_expandedSettingsSections.contains(id)) {
        _expandedSettingsSections.remove(id);
      } else {
        _expandedSettingsSections.add(id);
      }
    });
    _persistState();
  }

  Future<void> _refreshWorkbenchOverview({bool showFeedback = false}) async {
    await _refreshLocalRuntimeStatus(showFailureSnackBar: showFeedback);
    await _refreshRuntimeBackendStatus(showFailureSnackBar: showFeedback);
    await _refreshEmbeddedDevToolkitStatus(showFailureSnackBar: showFeedback);
    await _refreshShellSnapshot();
    if (showFeedback && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('方案状态已刷新')));
    }
  }

  Future<Map<String, dynamic>> _inspectEmbeddedGitRepository() async {
    final repoPath = (_projectRootPath ?? '').trim();
    if (repoPath.isEmpty) {
      throw Exception('请先选择项目目录');
    }
    final raw = await _embeddedDevToolkitChannel.invokeMethod<dynamic>(
      'inspectGitRepository',
      <String, dynamic>{'repoPath': repoPath},
    );
    final mapped = raw is Map
        ? raw.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{'ok': false};
    return mapped;
  }

  Future<Map<String, dynamic>> _runEmbeddedJadxTool() async {
    final apkPath = _androidToolkitApkPathController.text.trim();
    if (apkPath.isEmpty) {
      throw Exception('请先填写 APK 路径');
    }
    final raw = await _embeddedDevToolkitChannel.invokeMethod<dynamic>(
      'decompileApkWithEmbeddedJadx',
      <String, dynamic>{
        'apkPath': apkPath,
        'outputLabel': _androidToolkitReverseLabel(),
      },
    );
    final mapped = raw is Map
        ? raw.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{'ok': false};
    return mapped;
  }

  Future<Map<String, dynamic>> _verifyEmbeddedApkSignature() async {
    final apkPath = _androidToolkitApkPathController.text.trim();
    if (apkPath.isEmpty) {
      throw Exception('请先填写 APK 路径');
    }
    final raw = await _embeddedDevToolkitChannel.invokeMethod<dynamic>(
      'verifyApkSignature',
      <String, dynamic>{'apkPath': apkPath},
    );
    final mapped = raw is Map
        ? raw.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{'ok': false};
    return mapped;
  }

  void _applyRecommendedMobileDevPreset({
    bool force = true,
    bool persist = true,
  }) {
    final projectRoot = _projectRootPath?.trim() ?? '';
    final recommendedWorkdir = projectRoot.isNotEmpty
        ? projectRoot
        : '/data/data/com.termux/files/home';
    const recommendedTemplate =
        'proot-distro login ubuntu --shared-tmp -- /bin/bash -lc {{command}}';

    if (force || _termuxWorkdirController.text.trim().isEmpty) {
      _termuxWorkdirController.text = recommendedWorkdir;
    }
    if (force || _termuxCommandTemplateController.text.trim().isEmpty) {
      _termuxCommandTemplateController.text = recommendedTemplate;
    }
    if (force || _androidToolkitGradleTaskController.text.trim().isEmpty) {
      _androidToolkitGradleTaskController.text = 'assembleDebug';
    }
    if (force || _androidToolkitInstallApkPathController.text.trim().isEmpty) {
      _androidToolkitInstallApkPathController.text =
          'build/app/outputs/flutter-apk/app-debug.apk';
    }
    if (force || _androidToolkitGradleCommandController.text.trim().isEmpty) {
      _androidToolkitGradleCommandController.text = 'gradle';
    }
    if (force || _androidToolkitAdbCommandController.text.trim().isEmpty) {
      _androidToolkitAdbCommandController.text = 'adb';
    }
    if (force || _androidToolkitApktoolCommandController.text.trim().isEmpty) {
      _androidToolkitApktoolCommandController.text = 'apktool';
    }
    if (force || _androidToolkitJadxCommandController.text.trim().isEmpty) {
      _androidToolkitJadxCommandController.text = 'jadx';
    }
    if (force ||
        _androidToolkitApksignerCommandController.text.trim().isEmpty) {
      _androidToolkitApksignerCommandController.text = 'apksigner';
    }
    if (force || _androidToolkitZipalignCommandController.text.trim().isEmpty) {
      _androidToolkitZipalignCommandController.text = 'zipalign';
    }
    if (force || _androidToolkitLogcatFilterController.text.trim().isEmpty) {
      _androidToolkitLogcatFilterController.text = '*:I';
    }

    setState(() {
      if (force) {
        if (_runtimeBackendStatus.termuxInstalled) {
          _primaryExecutionBackend = 'termux';
        } else {
          _primaryExecutionBackend = 'native';
        }
        if (_runtimeBackendStatus.shizukuInstalled) {
          _deviceOperationsBackend = 'shizuku';
        } else if (_runtimeBackendStatus.rootAvailable) {
          _deviceOperationsBackend = 'root';
        } else {
          _deviceOperationsBackend = 'native';
        }
      }
      _expandedSettingsSections
        ..add('solution_overview')
        ..add('components')
        ..add('project')
        ..add('local_runtime')
        ..add('execution_backends');
      _androidToolkitStatus = '已写入推荐配置，可直接开始联调 Android/Flutter 项目。';
      _runtimeWorkbenchOutput = [
        '移动端方案推荐配置已写入：',
        '- Termux 工作目录：${_termuxWorkdirController.text.trim()}',
        '- Termux 命令模板：${_termuxCommandTemplateController.text.trim()}',
        '- Gradle 默认任务：${_androidToolkitGradleTaskController.text.trim()}',
        '- APK 安装路径：${_androidToolkitInstallApkPathController.text.trim()}',
      ].join('\n');
    });

    if (persist) {
      _persistState();
    }
    if (force && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已写入移动端开发推荐配置')));
    }
  }

  Widget _buildSolutionOverviewSection() {
    final hasProject = _projectRootPath?.trim().isNotEmpty == true;
    final runtimeReady = Platform.isAndroid && _localRuntimeStatus.supported;
    final runtimeRunning = runtimeReady && _localRuntimeStatus.isRunning;
    final embeddedReady = Platform.isAndroid && _embeddedDevToolkitStatus.ready;
    final termuxReady = _runtimeBackendStatus.termuxReady;
    final termuxInstalled = _runtimeBackendStatus.termuxInstalled;
    final agentReady = _activeConnection != null;
    final shellReady = _localShellSnapshot.isRunning;
    final perfMode = _expandedSettingsSections.length <= 4;

    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '已按“Flutter 手机端 AI 编程工作台 + Android 本地运行时 + Termux 工具链 + 可扩展 Agent 内核”方案补齐，并将重点能力集中到右侧抽屉中。',
            style: TextStyle(
              fontSize: 12,
              color: AppPalette.muted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SolutionStatusCard(
                icon: Icons.phone_android_rounded,
                title: 'Flutter 工作台',
                subtitle: hasProject ? '项目已绑定，可直接浏览与编辑' : '待绑定项目目录',
                statusLabel: hasProject ? '就绪' : '待配置',
                active: hasProject,
              ),
              _SolutionStatusCard(
                icon: Icons.memory_rounded,
                title: 'Android 本地运行时',
                subtitle: runtimeRunning ? '前台服务与镜像工作区已启用' : '可一键启动本地运行时',
                statusLabel: runtimeRunning
                    ? '运行中'
                    : (runtimeReady ? '可用' : '不可用'),
                active: runtimeReady,
              ),
              _SolutionStatusCard(
                icon: Icons.inventory_2_rounded,
                title: '内置开发栈',
                subtitle: embeddedReady
                    ? 'Git、JADX 与签名校验已可直接使用'
                    : '正在准备 APK 内置开发能力',
                statusLabel: embeddedReady ? '已启用' : '准备中',
                active: embeddedReady,
              ),
              _SolutionStatusCard(
                icon: Icons.terminal_rounded,
                title: '外部增强后端',
                subtitle: termuxReady
                    ? 'Termux 已接入，可承接更重的 CLI 工作流'
                    : (termuxInstalled
                          ? 'Termux 已安装，等待授权后可启用增强能力'
                          : '可选安装 Termux 作为增强后端'),
                statusLabel: termuxReady ? '增强就绪' : '可选增强',
                active: termuxReady,
              ),
              _SolutionStatusCard(
                icon: Icons.auto_awesome_rounded,
                title: 'Agent 内核',
                subtitle: agentReady ? '模型连接已可用，可执行规划与工具调用' : '请先配置模型连接',
                statusLabel: agentReady ? '可用' : '待配置',
                active: agentReady,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppPalette.border),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _AgentMetricChip(
                  label:
                      '主后端 ${_primaryBackendLabel(_primaryExecutionBackend)}',
                ),
                _AgentMetricChip(
                  label:
                      '设备后端 ${_deviceBackendLabel(_deviceOperationsBackend)}',
                ),
                _AgentMetricChip(label: shellReady ? 'Shell 已启动' : 'Shell 未启动'),
                _AgentMetricChip(label: perfMode ? '抽屉性能模式' : '可继续折叠板块'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _applyRecommendedMobileDevPreset(),
                icon: const Icon(Icons.auto_fix_high_rounded),
                label: const Text('写入推荐配置'),
              ),
              OutlinedButton.icon(
                onPressed: () => _refreshWorkbenchOverview(showFeedback: true),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('刷新方案状态'),
              ),
              OutlinedButton.icon(
                onPressed: _testCurrentExecutionBackend,
                icon: const Icon(Icons.play_circle_outline_rounded),
                label: const Text('测试当前后端'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '性能优化说明：右侧抽屉已改为手风琴式按需展开，只在展开时构建对应板块内容，避免所有重型面板同时渲染。',
            style: TextStyle(
              fontSize: 11,
              color: AppPalette.muted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuiltInComponentsSection() {
    final componentRows = <Widget>[
      _SolutionComponentRow(
        icon: Icons.design_services_rounded,
        title: 'Flutter 手机工作台',
        subtitle: '聊天、项目文件、补丁审批、终端面板与工作区状态面板。',
        badge: '已内置',
        tone: const Color(0xFF0B6E4F),
      ),
      _SolutionComponentRow(
        icon: Icons.storage_rounded,
        title: 'Android 本地运行时',
        subtitle: '前台服务、本地镜像工作区、本地 Shell、命令执行与状态回传。',
        badge: '已内置',
        tone: const Color(0xFF2563EB),
      ),
      _SolutionComponentRow(
        icon: Icons.developer_mode_rounded,
        title: 'Android 开发工具箱',
        subtitle: 'Gradle、APK 安装、Logcat 以及内置/外接反编译与签名能力统一放在这里。',
        badge: '已内置',
        tone: const Color(0xFF7C3AED),
      ),
      _SolutionComponentRow(
        icon: Icons.inventory_2_rounded,
        title: '内置开发栈',
        subtitle: 'JGit、jadx-core、apksig 已打进 APK，可直接完成仓库检测、反编译与签名校验。',
        badge: _embeddedDevToolkitStatus.ready ? '已启用' : '加载中',
        tone: _embeddedDevToolkitStatus.ready
            ? const Color(0xFF0B6E4F)
            : const Color(0xFFB45309),
      ),
      _SolutionComponentRow(
        icon: Icons.terminal_rounded,
        title: 'Termux 桥接层',
        subtitle: '命令模板、工作目录与权限桥接已内置；Termux 现作为增强后端，不再是硬依赖。',
        badge: _runtimeBackendStatus.termuxInstalled ? '增强已就绪' : '可选增强',
        tone: _runtimeBackendStatus.termuxInstalled
            ? const Color(0xFF0B6E4F)
            : const Color(0xFFB45309),
      ),
      _SolutionComponentRow(
        icon: Icons.account_tree_rounded,
        title: '可扩展 Agent 内核',
        subtitle: '规划、工具调用、进度追踪、回滚与补丁执行面板已接入。',
        badge: _activeConnection == null ? '待接模型' : '可用',
        tone: _activeConnection == null
            ? const Color(0xFFB45309)
            : const Color(0xFF0B6E4F),
      ),
    ];

    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '为了减少切换成本，新能力已统一收拢到右侧抽屉。重型板块默认折叠，点击后再加载内容。',
            style: TextStyle(
              fontSize: 12,
              color: AppPalette.muted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          ...componentRows,
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _runtimeBackendStatus.termuxLaunchable
                    ? () => _openRuntimeBackendApp('termux')
                    : null,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('打开 Termux'),
              ),
              OutlinedButton.icon(
                onPressed: _runtimeBackendStatus.shizukuLaunchable
                    ? () => _openRuntimeBackendApp('shizuku')
                    : null,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('打开 Shizuku'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmbeddedDevStackSection() {
    final supported = Platform.isAndroid && _embeddedDevToolkitStatus.supported;
    final busy =
        _runningAndroidToolkitAction || _loadingEmbeddedDevToolkitStatus;
    final lastError = _embeddedDevToolkitStatus.lastError.trim();

    Future<void> runAction(
      String title,
      Future<Map<String, dynamic>> Function() action,
    ) {
      return _runAndroidToolkitAction(title: title, action: action);
    }

    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '这部分能力直接内置在 APK 中，适合作为手机端开发与逆向分析的基础栈。外部工具链现在属于增强项，不再是必需项。',
            style: TextStyle(
              fontSize: 12,
              color: AppPalette.muted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppPalette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '内置开发栈状态',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.ink,
                        ),
                      ),
                    ),
                    if (_loadingEmbeddedDevToolkitStatus)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  supported ? '状态：可用' : '状态：当前不可用',
                  style: const TextStyle(fontSize: 11, color: AppPalette.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  '工作目录：${_embeddedDevToolkitStatus.workspaceRoot.isEmpty ? '未就绪' : _embeddedDevToolkitStatus.workspaceRoot}',
                  style: const TextStyle(fontSize: 11, color: AppPalette.muted),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _AgentMetricChip(
                      label: _embeddedDevToolkitStatus.gitAvailable
                          ? 'JGit 已内置'
                          : 'JGit 未就绪',
                    ),
                    _AgentMetricChip(
                      label: _embeddedDevToolkitStatus.jadxAvailable
                          ? 'JADX 已内置'
                          : 'JADX 未就绪',
                    ),
                    _AgentMetricChip(
                      label: _embeddedDevToolkitStatus.apkSigAvailable
                          ? 'APK 签名校验已内置'
                          : 'APK 签名校验未就绪',
                    ),
                  ],
                ),
                if (lastError.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '最近错误：$lastError',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: !supported || busy
                    ? null
                    : () {
                        unawaited(
                          runAction('检查 Git 仓库', _inspectEmbeddedGitRepository),
                        );
                      },
                icon: const Icon(Icons.account_tree_rounded),
                label: const Text('检查 Git 仓库'),
              ),
              OutlinedButton.icon(
                onPressed: !supported || busy
                    ? null
                    : () {
                        unawaited(
                          runAction('内置 JADX 反编译', _runEmbeddedJadxTool),
                        );
                      },
                icon: const Icon(Icons.code_rounded),
                label: const Text('内置 JADX'),
              ),
              OutlinedButton.icon(
                onPressed: !supported || busy
                    ? null
                    : () {
                        unawaited(
                          runAction('校验 APK 签名', _verifyEmbeddedApkSignature),
                        );
                      },
                icon: const Icon(Icons.verified_rounded),
                label: const Text('校验签名'),
              ),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => _refreshEmbeddedDevToolkitStatus(
                        showFailureSnackBar: true,
                      ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('刷新状态'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '当前策略：内置开发栈负责基础开发与分析，Termux/PRoot、Root、Shizuku 负责更重或更开放的外部能力。',
            style: TextStyle(
              fontSize: 11,
              color: AppPalette.muted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSectionCard(_SettingsSectionEntry section) {
    final expanded = _expandedSettingsSections.contains(section.id);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE1E8F0)),
          boxShadow: [
            BoxShadow(
              blurRadius: 14,
              offset: const Offset(0, 6),
              color: Colors.black.withValues(alpha: 0.04),
            ),
          ],
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () => _toggleSettingsSection(section.id),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
                bottom: Radius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F7FD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(section.icon, color: AppPalette.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.ink,
                            ),
                          ),
                          if (section.summary.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              section.summary,
                              maxLines: expanded ? 3 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppPalette.muted,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: const Color(0xFF6F8296),
                    ),
                  ],
                ),
              ),
            ),
            if (expanded) ...[
              const Divider(height: 1, thickness: 1, color: Color(0xFFE8EEF5)),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                child: section.builder(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _upsertConnection(
    ApiConnectionProfile profile, {
    bool activate = false,
  }) async {
    final index = _apiConnections.indexWhere((item) => item.id == profile.id);
    setState(() {
      if (index >= 0) {
        _apiConnections[index] = profile;
      } else {
        _apiConnections.add(profile);
      }
      _providerConfigs[profile.providerId] = profile.toConfig();
      if (activate || _apiConnections.length == 1) {
        _activeConnectionId = profile.id;
        _activeProviderId = profile.providerId;
      }
    });
    _persistState();
    if (activate || _apiConnections.length == 1) {
      _appendMessage(
        ChatMessage(
          role: ChatRole.system,
          text:
              '已启用 API 连接: ${profile.name} (${_providerName(profile.providerId)})',
          time: _timeNow(),
        ),
      );
    }
  }

  Future<void> _activateConnection(
    String profileId, {
    bool silent = false,
  }) async {
    ApiConnectionProfile? profile;
    for (final item in _apiConnections) {
      if (item.id == profileId) {
        profile = item;
        break;
      }
    }
    final selected = profile;
    if (selected == null) return;
    setState(() {
      _activeConnectionId = selected.id;
      _activeProviderId = selected.providerId;
      _providerConfigs[selected.providerId] = selected.toConfig();
    });
    _persistState();
    if (!silent) {
      _appendMessage(
        ChatMessage(
          role: ChatRole.system,
          text: '已启用 API 连接: ${selected.name}',
          time: _timeNow(),
        ),
      );
    }
  }

  Future<bool> _confirmDeleteConnection(ApiConnectionProfile profile) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除 API 连接'),
          content: Text('确认删除连接「${profile.name}」吗？此操作不可撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<void> _deleteConnection(
    ApiConnectionProfile profile, {
    bool silent = false,
  }) async {
    if (!_apiConnections.any((item) => item.id == profile.id)) return;
    var removedActive = false;
    ApiConnectionProfile? fallback;

    setState(() {
      removedActive = _activeConnectionId == profile.id;
      _apiConnections.removeWhere((item) => item.id == profile.id);

      final hasSameProvider = _apiConnections.any(
        (item) => item.providerId == profile.providerId,
      );
      if (!hasSameProvider) {
        _providerConfigs.remove(profile.providerId);
      }

      final activeStillExists = _apiConnections.any(
        (item) => item.id == _activeConnectionId,
      );
      if (removedActive || !activeStillExists) {
        if (_apiConnections.isEmpty) {
          _activeConnectionId = null;
          if (_activeProviderId == profile.providerId) {
            _activeProviderId = 'openai';
          }
        } else {
          fallback = _apiConnections.first;
          _activeConnectionId = fallback!.id;
          _activeProviderId = fallback!.providerId;
          _providerConfigs[fallback!.providerId] = fallback!.toConfig();
        }
      }
    });

    _persistState();
    if (silent) return;

    if (removedActive && fallback != null) {
      _appendMessage(
        ChatMessage(
          role: ChatRole.system,
          text: '已删除连接: ${profile.name}，已切换到 ${fallback!.name}',
          time: _timeNow(),
        ),
      );
      return;
    }
    if (removedActive) {
      _appendMessage(
        ChatMessage(
          role: ChatRole.system,
          text: '已删除连接: ${profile.name}，当前无已启用连接',
          time: _timeNow(),
        ),
      );
      return;
    }
    _appendMessage(
      ChatMessage(
        role: ChatRole.system,
        text: '已删除连接: ${profile.name}',
        time: _timeNow(),
      ),
    );
  }

  Future<void> _showApiConnectionEditor({
    ApiConnectionProfile? editing,
    bool activateOnSave = false,
  }) async {
    var selectedProviderId = editing?.providerId ?? _activeProviderId;
    if (!kProviders.any((item) => item.id == selectedProviderId)) {
      selectedProviderId = 'openai';
    }

    final selectedGuide =
        kProviderGuides[selectedProviderId] ?? kProviderGuides['custom']!;
    final nameController = TextEditingController(
      text: editing?.name ?? 'New API',
    );
    final baseUrlController = TextEditingController(
      text:
          editing?.baseUrl ??
          (selectedGuide.baseUrl.isEmpty ? '' : selectedGuide.baseUrl),
    );
    final apiPathController = TextEditingController(
      text: editing?.apiPath ?? '',
    );
    final modelListPathController = TextEditingController(
      text: editing?.modelListPath ?? '',
    );
    final apiKeyController = TextEditingController(text: editing?.apiKey ?? '');
    final headersController = TextEditingController(
      text: _formatHeadersForEditor(editing?.extraHeaders ?? const {}),
    );
    final modelController = TextEditingController(text: editing?.model ?? '');
    var modelOptions = List<String>.from(editing?.availableModels ?? const []);
    var improveNetworkCompatibility =
        editing?.improveNetworkCompatibility ?? false;
    final displayNameController = TextEditingController(
      text: editing?.modelDisplayName ?? '',
    );
    var modelType = editing?.modelType ?? 'chat';
    final inputModes = <String>{
      ...(editing?.inputModes ?? const ['text']),
    };
    final outputModes = <String>{
      ...(editing?.outputModes ?? const ['text']),
    };
    var capabilityTools = editing?.capabilityTools ?? false;
    var capabilityReasoning = editing?.capabilityReasoning ?? false;
    var advancedOpen =
        editing != null &&
        (editing.apiPath.trim().isNotEmpty ||
            editing.modelListPath.trim().isNotEmpty ||
            editing.extraHeaders.isNotEmpty);
    if (editing == null) {
      apiPathController.text = _defaultApiPathForProvider(selectedProviderId);
      modelListPathController.text = _defaultModelListPathForProvider(
        selectedProviderId,
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        bool obscure = true;
        bool loadingModels = false;
        bool detectingModel = false;
        String? fetchError;
        String? detectStatus;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final provider = _providerById(selectedProviderId);
            final guide =
                kProviderGuides[selectedProviderId] ??
                kProviderGuides['custom']!;
            void applyModelTypePreset(String value) {
              modelType = value;
              if (value == 'embedding') {
                inputModes
                  ..clear()
                  ..add('text');
                outputModes
                  ..clear()
                  ..add('text');
                capabilityTools = false;
                capabilityReasoning = false;
                return;
              }
              if (value == 'image') {
                inputModes
                  ..clear()
                  ..add('text');
                outputModes
                  ..clear()
                  ..add('image');
                capabilityTools = false;
                capabilityReasoning = false;
                return;
              }
              if (inputModes.isEmpty) {
                inputModes.add('text');
              }
              if (outputModes.isEmpty) {
                outputModes.add('text');
              }
            }

            void toggleMode(Set<String> target, String mode, bool selected) {
              if (selected) {
                target.add(mode);
              } else if (target.length > 1) {
                target.remove(mode);
              }
            }

            Widget buildSegmentGroup({
              required String title,
              required Map<String, String> options,
              required Set<String> selectedValues,
              required bool singleSelect,
              required void Function(String value, bool selected) onToggle,
            }) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: options.entries.map((entry) {
                      final selected = selectedValues.contains(entry.key);
                      return FilterChip(
                        label: Text(entry.value),
                        selected: selected,
                        showCheckmark: false,
                        side: BorderSide(
                          color: selected
                              ? AppPalette.primary
                              : AppPalette.border,
                        ),
                        backgroundColor: const Color(0xFFF8FAFD),
                        selectedColor: const Color(0x1A0B6E4F),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? AppPalette.primary
                              : AppPalette.muted,
                        ),
                        onSelected: (next) {
                          if (singleSelect && !next) return;
                          onToggle(entry.key, next);
                        },
                      );
                    }).toList(),
                  ),
                ],
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 12,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                    decoration: BoxDecoration(
                      color: AppPalette.card,
                      border: Border.all(color: AppPalette.border),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _ProviderLogo(provider: provider, size: 34),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  editing == null ? '新建 API 连接' : '编辑 API 连接',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppPalette.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _InputField(
                            label: '名称',
                            controller: nameController,
                            hintText: '例如: DeepSeek Pro',
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: selectedProviderId,
                            decoration: const InputDecoration(
                              labelText: '模型平台',
                              border: OutlineInputBorder(),
                            ),
                            items: kProviders
                                .map(
                                  (item) => DropdownMenuItem<String>(
                                    value: item.id,
                                    child: Text(item.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setModalState(() {
                                if (value == selectedProviderId) {
                                  return;
                                }
                                selectedProviderId = value;
                                final nextGuide =
                                    kProviderGuides[selectedProviderId] ??
                                    kProviderGuides['custom']!;
                                if (nextGuide.baseUrl.isNotEmpty) {
                                  baseUrlController.text = nextGuide.baseUrl;
                                } else {
                                  baseUrlController.clear();
                                }
                                apiPathController.text =
                                    _defaultApiPathForProvider(
                                      selectedProviderId,
                                    );
                                modelListPathController.text =
                                    _defaultModelListPathForProvider(
                                      selectedProviderId,
                                    );
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          _InputField(
                            label: 'API 接口地址',
                            controller: baseUrlController,
                            hintText: guide.baseUrl.isEmpty
                                ? 'https://api.example.com/v1'
                                : guide.baseUrl,
                            onChanged: (_) => setModalState(() {}),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () {
                                  setModalState(() {
                                    if (guide.baseUrl.isNotEmpty) {
                                      baseUrlController.text = guide.baseUrl;
                                    }
                                    apiPathController.text =
                                        _defaultApiPathForProvider(
                                          selectedProviderId,
                                        );
                                    modelListPathController.text =
                                        _defaultModelListPathForProvider(
                                          selectedProviderId,
                                        );
                                  });
                                },
                                icon: const Icon(Icons.auto_fix_high_rounded),
                                label: const Text('填入推荐地址'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () {
                                  setModalState(() {
                                    advancedOpen = !advancedOpen;
                                  });
                                },
                                icon: Icon(
                                  advancedOpen
                                      ? Icons.expand_less_rounded
                                      : Icons.tune_rounded,
                                ),
                                label: const Text('高级连接设置'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Builder(
                            builder: (_) {
                              final preview = _endpointPreview(
                                providerId: selectedProviderId,
                                baseUrl: baseUrlController.text,
                                apiPath: apiPathController.text,
                              );
                              if (preview.isEmpty) {
                                return const Text(
                                  '聊天接口预览: 请填写 API 地址',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppPalette.muted,
                                  ),
                                );
                              }
                              return Text(
                                '聊天接口预览: $preview',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppPalette.muted,
                                ),
                              );
                            },
                          ),
                          if (advancedOpen) ...[
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _InputField(
                                    label: 'API Path (可选)',
                                    controller: apiPathController,
                                    hintText: '/chat/completions',
                                    onChanged: (_) => setModalState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _InputField(
                                    label: '模型列表 Path (可选)',
                                    controller: modelListPathController,
                                    hintText: '/models',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '自定义请求头（每行 Header: Value）',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppPalette.muted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: headersController,
                              minLines: 2,
                              maxLines: 4,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppPalette.ink,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    'HTTP-Referer: https://example.com\\nX-Title: My App',
                                hintStyle: const TextStyle(
                                  color: AppPalette.muted,
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppPalette.border,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppPalette.border,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: AppPalette.primary,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          _InputField(
                            label: 'API 密钥',
                            controller: apiKeyController,
                            hintText: 'sk-xxxx',
                            obscureText: obscure,
                            suffix: IconButton(
                              onPressed: () =>
                                  setModalState(() => obscure = !obscure),
                              icon: Icon(
                                obscure
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _InputField(
                                  label: '模型名称',
                                  controller: modelController,
                                  hintText: 'gpt-4.1 / deepseek-chat / ...',
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.tonal(
                                onPressed:
                                    (!guide.supportsAutoFetch || loadingModels)
                                    ? null
                                    : () async {
                                        setModalState(() {
                                          loadingModels = true;
                                          fetchError = null;
                                          detectStatus = null;
                                        });
                                        try {
                                          final fetched = await _requestModels(
                                            provider: provider,
                                            baseUrl: baseUrlController.text
                                                .trim(),
                                            apiKey: apiKeyController.text
                                                .trim(),
                                            modelListPath:
                                                modelListPathController.text
                                                    .trim(),
                                            extraHeaders:
                                                _parseHeadersFromEditor(
                                                  headersController.text,
                                                ),
                                            improveNetworkCompatibility:
                                                improveNetworkCompatibility,
                                          );
                                          setModalState(() {
                                            modelOptions = fetched;
                                            if (modelController.text
                                                    .trim()
                                                    .isEmpty &&
                                                fetched.isNotEmpty) {
                                              modelController.text =
                                                  fetched.first;
                                            }
                                            detectStatus = fetched.isEmpty
                                                ? null
                                                : '已获取模型列表';
                                          });
                                        } catch (error) {
                                          setModalState(() {
                                            fetchError = '获取模型失败: $error';
                                          });
                                        } finally {
                                          setModalState(() {
                                            loadingModels = false;
                                          });
                                        }
                                      },
                                child: loadingModels
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('测试/获取'),
                              ),
                            ],
                          ),
                          if (modelOptions.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue:
                                  modelOptions.contains(
                                    modelController.text.trim(),
                                  )
                                  ? modelController.text.trim()
                                  : null,
                              decoration: const InputDecoration(
                                labelText: '可选模型',
                                border: OutlineInputBorder(),
                              ),
                              items: modelOptions
                                  .map(
                                    (model) => DropdownMenuItem<String>(
                                      value: model,
                                      child: Text(model),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setModalState(() {
                                  modelController.text = value;
                                });
                              },
                            ),
                          ],
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFD),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppPalette.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        '模型能力检测',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: AppPalette.ink,
                                        ),
                                      ),
                                    ),
                                    FilledButton.tonalIcon(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppPalette.primary,
                                        foregroundColor: Colors.white,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: detectingModel
                                          ? null
                                          : () async {
                                              var currentModel = modelController
                                                  .text
                                                  .trim();
                                              if (currentModel.isEmpty &&
                                                  modelOptions.isNotEmpty) {
                                                modelController.text =
                                                    modelOptions.first;
                                                currentModel =
                                                    modelOptions.first;
                                              }
                                              if (currentModel.isEmpty) {
                                                setModalState(() {
                                                  fetchError = '请先填写模型名称再检测';
                                                });
                                                return;
                                              }
                                              setModalState(() {
                                                detectingModel = true;
                                                fetchError = null;
                                                detectStatus = null;
                                              });
                                              try {
                                                final detected =
                                                    await _detectModelCapabilities(
                                                      provider: provider,
                                                      baseUrl: baseUrlController
                                                          .text
                                                          .trim(),
                                                      apiKey: apiKeyController
                                                          .text
                                                          .trim(),
                                                      modelName: currentModel,
                                                      modelListPath:
                                                          modelListPathController
                                                              .text
                                                              .trim(),
                                                      extraHeaders:
                                                          _parseHeadersFromEditor(
                                                            headersController
                                                                .text,
                                                          ),
                                                      improveNetworkCompatibility:
                                                          improveNetworkCompatibility,
                                                    );
                                                if (!mounted) return;
                                                setModalState(() {
                                                  if (detected
                                                      .availableModels
                                                      .isNotEmpty) {
                                                    modelOptions = detected
                                                        .availableModels;
                                                  }
                                                  displayNameController.text =
                                                      detected.modelDisplayName;
                                                  modelType =
                                                      detected.modelType;
                                                  inputModes
                                                    ..clear()
                                                    ..addAll(
                                                      detected.inputModes,
                                                    );
                                                  outputModes
                                                    ..clear()
                                                    ..addAll(
                                                      detected.outputModes,
                                                    );
                                                  capabilityTools =
                                                      detected.capabilityTools;
                                                  capabilityReasoning = detected
                                                      .capabilityReasoning;
                                                  detectStatus =
                                                      detected.statusText;
                                                });
                                              } catch (error) {
                                                setModalState(() {
                                                  fetchError = '检测失败: $error';
                                                });
                                              } finally {
                                                if (mounted) {
                                                  setModalState(() {
                                                    detectingModel = false;
                                                  });
                                                }
                                              }
                                            },
                                      icon: detectingModel
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.radar_rounded,
                                              size: 16,
                                            ),
                                      label: Text(
                                        detectingModel ? '检测中' : '检测',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  '模型显示名称',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppPalette.muted,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: displayNameController,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppPalette.ink,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '用于展示，例如 GPT-4.1',
                                    hintStyle: const TextStyle(
                                      color: AppPalette.muted,
                                    ),
                                    isDense: true,
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: AppPalette.border,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: AppPalette.border,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: AppPalette.primary,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                buildSegmentGroup(
                                  title: '模型类型',
                                  options: const {
                                    'chat': '聊天',
                                    'image': '图像',
                                    'embedding': '嵌入',
                                  },
                                  selectedValues: {modelType},
                                  singleSelect: true,
                                  onToggle: (value, selected) {
                                    if (!selected) return;
                                    setModalState(() {
                                      applyModelTypePreset(value);
                                    });
                                  },
                                ),
                                const SizedBox(height: 10),
                                buildSegmentGroup(
                                  title: '输入模式',
                                  options: const {'text': '文本', 'image': '图片'},
                                  selectedValues: inputModes,
                                  singleSelect: false,
                                  onToggle: (value, selected) {
                                    setModalState(() {
                                      toggleMode(inputModes, value, selected);
                                    });
                                  },
                                ),
                                const SizedBox(height: 10),
                                buildSegmentGroup(
                                  title: '输出模式',
                                  options: const {'text': '文本', 'image': '图片'},
                                  selectedValues: outputModes,
                                  singleSelect: false,
                                  onToggle: (value, selected) {
                                    setModalState(() {
                                      toggleMode(outputModes, value, selected);
                                    });
                                  },
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  '能力',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppPalette.muted,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    FilterChip(
                                      label: const Text('工具调用'),
                                      selected: capabilityTools,
                                      showCheckmark: false,
                                      side: BorderSide(
                                        color: capabilityTools
                                            ? AppPalette.primary
                                            : AppPalette.border,
                                      ),
                                      backgroundColor: const Color(0xFFF8FAFD),
                                      selectedColor: const Color(0x1A0B6E4F),
                                      labelStyle: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: capabilityTools
                                            ? AppPalette.primary
                                            : AppPalette.muted,
                                      ),
                                      onSelected: modelType == 'chat'
                                          ? (selected) {
                                              setModalState(() {
                                                capabilityTools = selected;
                                              });
                                            }
                                          : null,
                                    ),
                                    FilterChip(
                                      label: const Text('推理增强'),
                                      selected: capabilityReasoning,
                                      showCheckmark: false,
                                      side: BorderSide(
                                        color: capabilityReasoning
                                            ? AppPalette.primary
                                            : AppPalette.border,
                                      ),
                                      backgroundColor: const Color(0xFFF8FAFD),
                                      selectedColor: const Color(0x1A0B6E4F),
                                      labelStyle: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: capabilityReasoning
                                            ? AppPalette.primary
                                            : AppPalette.muted,
                                      ),
                                      onSelected: modelType == 'chat'
                                          ? (selected) {
                                              setModalState(() {
                                                capabilityReasoning = selected;
                                              });
                                            }
                                          : null,
                                    ),
                                  ],
                                ),
                                if (detectStatus != null) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    detectStatus!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppPalette.primary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (fetchError != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              fetchError!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          SwitchListTile(
                            value: improveNetworkCompatibility,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('改善网络兼容性'),
                            subtitle: const Text('开启后将使用更保守的网络参数（更长超时/兼容请求头）。'),
                            onChanged: (value) {
                              setModalState(() {
                                improveNetworkCompatibility = value;
                              });
                            },
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('取消'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppPalette.primary,
                                  ),
                                  onPressed: () async {
                                    final name = nameController.text.trim();
                                    final baseUrl = baseUrlController.text
                                        .trim();
                                    final apiPath = apiPathController.text
                                        .trim();
                                    final modelListPath =
                                        modelListPathController.text.trim();
                                    final model = modelController.text.trim();
                                    final extraHeaders =
                                        _parseHeadersFromEditor(
                                          headersController.text,
                                        );
                                    if (name.isEmpty) {
                                      setModalState(() {
                                        fetchError = '名称不能为空';
                                      });
                                      return;
                                    }
                                    if (baseUrl.isEmpty) {
                                      setModalState(() {
                                        fetchError = 'API 接口地址不能为空';
                                      });
                                      return;
                                    }
                                    if (model.isEmpty) {
                                      setModalState(() {
                                        fetchError = '模型名称不能为空';
                                      });
                                      return;
                                    }
                                    if (inputModes.isEmpty) {
                                      inputModes.add('text');
                                    }
                                    if (outputModes.isEmpty) {
                                      outputModes.add('text');
                                    }

                                    final sortedInputModes =
                                        inputModes
                                            .map((item) => item.trim())
                                            .where((item) => item.isNotEmpty)
                                            .toSet()
                                            .toList()
                                          ..sort();
                                    final sortedOutputModes =
                                        outputModes
                                            .map((item) => item.trim())
                                            .where((item) => item.isNotEmpty)
                                            .toSet()
                                            .toList()
                                          ..sort();
                                    final displayName =
                                        displayNameController.text
                                            .trim()
                                            .isEmpty
                                        ? _suggestModelDisplayName(model)
                                        : displayNameController.text.trim();
                                    final resolvedType =
                                        modelType.trim().isEmpty
                                        ? 'chat'
                                        : modelType.trim();
                                    final resolvedCapabilityTools =
                                        resolvedType == 'chat'
                                        ? capabilityTools
                                        : false;
                                    final resolvedCapabilityReasoning =
                                        resolvedType == 'chat'
                                        ? capabilityReasoning
                                        : false;

                                    final profile = ApiConnectionProfile(
                                      id:
                                          editing?.id ??
                                          'api_${DateTime.now().microsecondsSinceEpoch}',
                                      name: name,
                                      providerId: selectedProviderId,
                                      baseUrl: baseUrl,
                                      apiPath: apiPath,
                                      modelListPath: modelListPath,
                                      apiKey: apiKeyController.text.trim(),
                                      extraHeaders: extraHeaders,
                                      model: model,
                                      availableModels: modelOptions,
                                      improveNetworkCompatibility:
                                          improveNetworkCompatibility,
                                      modelDisplayName: displayName,
                                      modelType: resolvedType,
                                      inputModes: sortedInputModes,
                                      outputModes: sortedOutputModes,
                                      capabilityTools: resolvedCapabilityTools,
                                      capabilityReasoning:
                                          resolvedCapabilityReasoning,
                                      reasoningEffort:
                                          editing?.reasoningEffort ??
                                          _activeReasoningEffort(),
                                    );
                                    await _upsertConnection(
                                      profile,
                                      activate:
                                          activateOnSave || editing == null,
                                    );
                                    if (!context.mounted) return;
                                    Navigator.of(context).pop();
                                  },
                                  child: Text(editing == null ? '保存并启用' : '保存'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    baseUrlController.dispose();
    apiPathController.dispose();
    modelListPathController.dispose();
    apiKeyController.dispose();
    headersController.dispose();
    modelController.dispose();
    displayNameController.dispose();
  }

  Future<void> _showApiConnectionManager() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final sorted = [..._apiConnections]
              ..sort((a, b) {
                if (a.id == _activeConnectionId) return -1;
                if (b.id == _activeConnectionId) return 1;
                return a.name.compareTo(b.name);
              });

            return Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 12,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppPalette.card,
                      border: Border.all(color: AppPalette.border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'API 连接管理',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppPalette.ink,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  await _showApiConnectionEditor(
                                    activateOnSave: false,
                                  );
                                  setModalState(() {});
                                },
                                icon: const Icon(Icons.add_rounded),
                                tooltip: '新建',
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Flexible(
                          child: sorted.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                    '暂无 API 连接，点击右上角 + 新建。',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppPalette.muted,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: sorted.length,
                                  separatorBuilder: (_, _) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final item = sorted[index];
                                    final provider = _providerById(
                                      item.providerId,
                                    );
                                    final enabled =
                                        item.id == _activeConnectionId;
                                    final typeLabel = switch (item.modelType) {
                                      'image' => '图像',
                                      'embedding' => '嵌入',
                                      _ => '聊天',
                                    };
                                    final inputLabel = item.inputModes
                                        .map(
                                          (mode) =>
                                              mode == 'image' ? '图片' : '文本',
                                        )
                                        .toSet()
                                        .join('/');
                                    final outputLabel = item.outputModes
                                        .map(
                                          (mode) =>
                                              mode == 'image' ? '图片' : '文本',
                                        )
                                        .toSet()
                                        .join('/');
                                    final displayModel =
                                        item.modelDisplayName.trim().isEmpty
                                        ? item.model
                                        : '${item.modelDisplayName} (${item.model})';
                                    final apiPathLabel =
                                        item.apiPath.trim().isEmpty
                                        ? '默认'
                                        : item.apiPath.trim();
                                    final modelListPathLabel =
                                        item.modelListPath.trim().isEmpty
                                        ? '默认'
                                        : item.modelListPath.trim();
                                    return ListTile(
                                      leading: _ProviderLogo(
                                        provider: provider,
                                        size: 36,
                                      ),
                                      title: Text(item.name),
                                      subtitle: Text(
                                        '${provider.name} | $displayModel\n类型: $typeLabel  输入: $inputLabel  输出: $outputLabel\n能力: ${item.capabilityTools ? '工具' : '-'} ${item.capabilityReasoning ? '推理' : '-'}\n网络兼容: ${item.improveNetworkCompatibility ? '开启' : '关闭'}  |  ${_maskApiKey(item.apiKey)}'
                                        '${item.extraHeaders.isEmpty ? '' : '  |  Header:${item.extraHeaders.length}'}\nAPI Path: $apiPathLabel  |  Models Path: $modelListPathLabel',
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: Wrap(
                                        spacing: 4,
                                        children: [
                                          TextButton(
                                            onPressed: enabled
                                                ? null
                                                : () async {
                                                    await _activateConnection(
                                                      item.id,
                                                    );
                                                    setModalState(() {});
                                                  },
                                            child: Text(enabled ? '已启用' : '启用'),
                                          ),
                                          IconButton(
                                            onPressed: () async {
                                              await _showApiConnectionEditor(
                                                editing: item,
                                              );
                                              setModalState(() {});
                                            },
                                            icon: const Icon(
                                              Icons.edit_rounded,
                                            ),
                                            tooltip: '编辑',
                                          ),
                                          IconButton(
                                            onPressed: () async {
                                              final confirmed =
                                                  await _confirmDeleteConnection(
                                                    item,
                                                  );
                                              if (!confirmed) return;
                                              await _deleteConnection(item);
                                              setModalState(() {});
                                            },
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                            ),
                                            tooltip: '删除',
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _timeNow() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  ChatMessage _buildWelcomeMessage() {
    return ChatMessage(
      role: ChatRole.assistant,
      text: _defaultAssistantGreeting,
      time: _timeNow(),
    );
  }

  String _normalizedConversationTitle([String? raw]) {
    final title = (raw ?? _conversationTitle).trim();
    if (title.isEmpty) return _defaultConversationTitle;
    return title;
  }

  String? _normalizeWorkspaceBindingPath(String? raw) {
    final normalized = raw?.trim() ?? '';
    if (normalized.isEmpty) return null;
    return normalized;
  }

  String? _workspaceBindingLabel(String? projectRootPath) {
    final normalized = _normalizeWorkspaceBindingPath(projectRootPath);
    if (normalized == null) return null;
    return '工作区：$normalized';
  }

  String _singleLinePreview(String raw, {int maxLength = 24}) {
    final normalized = raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isEmpty) return _defaultConversationTitle;
    if (normalized.length <= maxLength) return normalized;
    return '${normalized.substring(0, maxLength)}...';
  }

  bool get _hasMeaningfulConversation {
    if ((_projectRootPath?.trim().isNotEmpty ?? false) ||
        _projectContext.trim().isNotEmpty) {
      return true;
    }
    if (_messages.isEmpty) {
      return _conversationTitle.trim().isNotEmpty &&
          _conversationTitle.trim() != _defaultConversationTitle;
    }
    if (_messages.length > 1) return true;
    final only = _messages.first;
    final isDefaultWelcome =
        only.role == ChatRole.assistant &&
        only.text.trim() == _defaultAssistantGreeting;
    if (!isDefaultWelcome) return true;
    return _conversationTitle.trim().isNotEmpty &&
        _conversationTitle.trim() != _defaultConversationTitle;
  }

  String _buildConversationPreview() {
    return _buildConversationPreviewFromMessages(_messages);
  }

  String _buildConversationPreviewFromMessages(List<ChatMessage> messages) {
    for (final item in messages.reversed) {
      final text = _messageDisplayText(item).trim();
      if (text.isEmpty) continue;
      if (item.role == ChatRole.system) continue;
      return _singleLinePreview(text, maxLength: 26);
    }
    return _singleLinePreview(_defaultAssistantGreeting, maxLength: 26);
  }

  bool _isToolLogMessage(ChatMessage message) {
    if (message.role != ChatRole.system) return false;
    if (_isReplySectionEnabled(_replySectionToolActivity)) return false;
    final text = message.text.trim();
    return text.startsWith('AI ') ||
        text.startsWith('工具结果(') ||
        text.startsWith('AI 调用工具:');
  }

  String _createConversationId() {
    return 'conv_${DateTime.now().microsecondsSinceEpoch}';
  }

  List<ChatMessage> _cloneMessages(List<ChatMessage> source) {
    return source
        .map(
          (message) => ChatMessage(
            role: message.role,
            text: message.text,
            time: message.time,
            parts: message.parts,
            metadata: message.metadata,
          ),
        )
        .toList(growable: false);
  }

  String _messageDisplayText(ChatMessage message) {
    if (message.text.trim().isNotEmpty) {
      return message.text;
    }
    for (final part in message.parts) {
      if (part is ContentPart && part.markdown.trim().isNotEmpty) {
        return part.markdown;
      }
      if (part is ReasoningPart && part.summary.trim().isNotEmpty) {
        return part.summary;
      }
    }
    return '';
  }

  String _messageConversationText(ChatMessage message) {
    if (message.text.trim().isNotEmpty) {
      return message.text;
    }
    for (final part in message.parts) {
      if (part is ContentPart && part.markdown.trim().isNotEmpty) {
        return part.markdown;
      }
    }
    return '';
  }

  List<AgentProgressSnapshot> _snapshotAgentProgressEntries() {
    return _agentProgressEntries
        .map(
          (entry) => AgentProgressSnapshot(
            title: entry.title,
            detail: entry.detail,
            time: entry.time,
          ),
        )
        .toList(growable: false);
  }

  List<ToolActivitySnapshot> _snapshotToolActivityEntries() {
    return _agentToolEvents
        .map(
          (entry) => ToolActivitySnapshot(
            toolName: entry.name,
            status: entry.status,
            summary: entry.summary,
            argsPreview: entry.argsPreview,
            time: entry.time,
            durationMs: entry.durationMs,
          ),
        )
        .toList(growable: false);
  }

  ChatMessage _buildStructuredAssistantMessage({
    required String text,
    required String time,
    String reasoningSummary = '',
    List<_ToolCall> toolCalls = const <_ToolCall>[],
    String toolCallStatus = 'done',
    Map<String, String> toolOutputsById = const <String, String>{},
    List<CitationPart> citations = const <CitationPart>[],
    ResponseMetadata? metadata,
    List<AgentProgressSnapshot> progressEntries =
        const <AgentProgressSnapshot>[],
    List<ToolActivitySnapshot> toolActivityEntries =
        const <ToolActivitySnapshot>[],
  }) {
    final parts = <ResponsePart>[];
    final trimmedReasoning = reasoningSummary.trim();
    final trimmedText = text.trim();

    if (trimmedReasoning.isNotEmpty) {
      parts.add(
        ReasoningPart(summary: trimmedReasoning, collapsedByDefault: true),
      );
    }
    if (trimmedText.isNotEmpty) {
      parts.add(ContentPart(markdown: trimmedText));
    }
    for (final call in toolCalls) {
      final rawOutput = toolOutputsById[call.id] ?? '';
      final preview = _summarizeForLog(rawOutput);
      final outputStreams = _extractToolOutputStreams(rawOutput);
      parts.add(
        ToolCallPart(
          id: call.id,
          toolName: call.name,
          argumentsJson: call.argumentsJson,
          reason: _toolPlanPhrase(call.name),
          status: toolCallStatus,
          outputPreview: preview,
          commandText: _extractCommandPreview(call),
          stdout: outputStreams.$1,
          stderr: outputStreams.$2,
        ),
      );
    }
    if (progressEntries.isNotEmpty) {
      parts.add(
        AgentProgressPart(
          summary: _agentPlanSummary.trim().isEmpty
              ? _singleLinePreview(trimmedText, maxLength: 80)
              : _agentPlanSummary.trim(),
          entries: progressEntries,
        ),
      );
    }
    if (toolActivityEntries.isNotEmpty) {
      parts.add(ToolActivityPart(entries: toolActivityEntries));
    }
    parts.addAll(citations);
    if (metadata != null && metadata.hasAnyValue) {
      parts.add(MetadataPart(metadata: metadata));
    }

    return ChatMessage(
      role: ChatRole.assistant,
      text: trimmedText,
      time: time,
      parts: parts,
      metadata: metadata,
    );
  }

  ChatMessage _buildToolRunMessage({
    required _ToolCall call,
    required String time,
    String toolResult = '',
    String status = 'running',
  }) {
    final outputStreams = _extractToolOutputStreams(toolResult);
    return ChatMessage(
      role: ChatRole.assistant,
      text: '',
      time: time,
      parts: [
        ToolCallPart(
          id: call.id,
          toolName: call.name,
          argumentsJson: call.argumentsJson,
          reason: _toolPlanPhrase(call.name),
          status: status,
          outputPreview: _summarizeForLog(toolResult),
          commandText: _extractCommandPreview(call),
          stdout: outputStreams.$1,
          stderr: outputStreams.$2,
        ),
      ],
    );
  }

  List<CitationPart> _collectCitationPartsFromToolResults(
    Iterable<String> toolResults,
  ) {
    final citations = <CitationPart>[];
    final dedup = <String>{};

    for (final raw in toolResults) {
      dynamic decoded;
      try {
        decoded = jsonDecode(raw);
      } catch (_) {
        decoded = null;
      }
      if (decoded is! Map) continue;

      final action = '${decoded['action'] ?? ''}'.trim();
      if (action == 'web_search') {
        final results = decoded['results'];
        if (results is List) {
          for (final item in results) {
            if (item is! Map) continue;
            final uri = '${item['url'] ?? ''}'.trim();
            if (uri.isEmpty || !dedup.add('web:$uri')) continue;
            citations.add(
              CitationPart(
                title: '${item['title'] ?? uri}'.trim(),
                uri: uri,
                snippet: '${item['snippet'] ?? ''}'.trim(),
                sourceType: 'web',
              ),
            );
            if (citations.length >= 6) return citations;
          }
        }
      } else if (action == 'fetch_webpage') {
        final uri = '${decoded['url'] ?? ''}'.trim();
        if (uri.isEmpty || !dedup.add('page:$uri')) continue;
        citations.add(
          CitationPart(
            title: '${decoded['title'] ?? uri}'.trim(),
            uri: uri,
            snippet: _summarizeForLog('${decoded['content'] ?? ''}'),
            sourceType: 'web',
          ),
        );
        if (citations.length >= 6) return citations;
      } else if (action == 'read_file' || action == 'read_file_part') {
        final path = '${decoded['path'] ?? ''}'.trim();
        if (path.isEmpty || !dedup.add('file:$path')) continue;
        citations.add(
          CitationPart(
            title: path,
            uri: path,
            snippet: _summarizeForLog('${decoded['content'] ?? ''}'),
            sourceType: 'file',
          ),
        );
        if (citations.length >= 6) return citations;
      }
    }

    return citations;
  }

  int _historyIndexByConversationId(String id) {
    return _conversationHistory.indexWhere((item) => item.id == id);
  }

  void _upsertConversationHistory(
    _ConversationSummary summary, {
    bool moveToTop = true,
  }) {
    final index = _historyIndexByConversationId(summary.id);
    final preservedPin = index >= 0
        ? _conversationHistory[index].isPinned
        : null;
    final merged = summary.copyWith(
      isPinned: preservedPin ?? summary.isPinned,
      preview: _singleLinePreview(summary.preview, maxLength: 26),
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      clearProjectRootPath: summary.projectRootPath == null,
      clearProjectContext: summary.projectRootPath == null,
    );

    if (index >= 0) {
      _conversationHistory[index] = merged;
      if (moveToTop && !merged.isPinned) {
        final updated = _conversationHistory.removeAt(index);
        _conversationHistory.insert(0, updated);
      }
    } else if (moveToTop && !merged.isPinned) {
      _conversationHistory.insert(0, merged);
    } else {
      _conversationHistory.add(merged);
    }

    while (_conversationHistory.length > 60) {
      var removeIndex = _conversationHistory.lastIndexWhere(
        (item) => !item.isPinned,
      );
      if (removeIndex < 0) {
        removeIndex = _conversationHistory.length - 1;
      }
      _conversationHistory.removeAt(removeIndex);
    }
  }

  void _archiveCurrentConversation({bool moveToTop = true}) {
    if (!_hasMeaningfulConversation) return;
    _upsertConversationHistory(
      _ConversationSummary(
        id: _activeConversationId,
        title: _normalizedConversationTitle(),
        preview: _buildConversationPreview(),
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        messages: _cloneMessages(_messages),
        isPinned: _activeConversationPinned,
        projectRootPath: _normalizeWorkspaceBindingPath(_projectRootPath),
        projectContext: _projectContext,
      ),
      moveToTop: moveToTop,
    );
  }

  Future<void> _restoreConversationFromHistory(
    _ConversationSummary item, {
    bool closeDrawer = true,
  }) async {
    if (_rollingBackRound) return;
    if (item.messages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('该历史会话未包含完整内容')));
      return;
    }

    if (closeDrawer) {
      Navigator.of(context).pop();
    }
    final restoredProjectRoot = _normalizeWorkspaceBindingPath(
      item.projectRootPath,
    );
    final restoredProjectContext = restoredProjectRoot == null
        ? ''
        : item.projectContext;
    final staleRounds = List<_AiRoundRecord>.from(_aiRoundHistory);
    setState(() {
      _archiveCurrentConversation();
      _activeConversationId = item.id;
      _activeConversationPinned = item.isPinned;
      _conversationTitle = _normalizedConversationTitle(item.title);
      _messages
        ..clear()
        ..addAll(_cloneMessages(item.messages));
      if (_messages.isEmpty) {
        _messages.add(_buildWelcomeMessage());
      }
      _projectRootPath = restoredProjectRoot;
      _projectContext = restoredProjectContext;
      _projectFiles = const [];
      if (restoredProjectRoot == null) {
        _aiFsGranted = false;
      }
      _resetDrawerExplorerState();
      _aiRoundHistory.clear();
      _fileOpsStatus = '已恢复历史对话';
      _conversationHistory.removeWhere((entry) => entry.id == item.id);
    });
    _promptController.clear();

    if (restoredProjectRoot != null) {
      await _loadProjectFolder(restoredProjectRoot, silent: true);
      if (mounted) {
        setState(() {
          _projectContext = restoredProjectContext;
        });
      }
    }
    _persistState();

    for (final round in staleRounds) {
      await _cleanupBackupDir(round.backupDirPath);
    }

    if (!mounted) return;
    _promptFocusNode.requestFocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_sendingPrompt ? '已切换会话，原会话回复仍在后台继续' : '已恢复完整历史对话'),
      ),
    );
  }

  Future<void> _startNewConversation() async {
    final staleRounds = List<_AiRoundRecord>.from(_aiRoundHistory);
    setState(() {
      _archiveCurrentConversation();
      _activeConversationId = _createConversationId();
      _activeConversationPinned = false;
      _conversationTitle = _defaultConversationTitle;
      _messages
        ..clear()
        ..add(_buildWelcomeMessage());
      _projectRootPath = null;
      _projectContext = '';
      _projectFiles = const [];
      _aiFsGranted = false;
      _resetDrawerExplorerState();
      _aiRoundHistory.clear();
      _fileOpsStatus = '等待操作';
    });
    _promptController.clear();
    _persistState();
    _promptFocusNode.requestFocus();

    for (final round in staleRounds) {
      await _cleanupBackupDir(round.backupDirPath);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_sendingPrompt ? '已切换到新对话，原会话回复仍在后台继续' : '已开始新的对话'),
      ),
    );
  }

  Future<void> _showConversationHistoryActions(
    _ConversationSummary item,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final pinLabel = item.isPinned ? '取消置顶' : '置顶会话';
        final pinIcon = item.isPinned
            ? Icons.push_pin_outlined
            : Icons.push_pin_rounded;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(pinIcon),
                title: Text(pinLabel),
                onTap: () => Navigator.of(context).pop('pin'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: const Text('删除会话'),
                onTap: () => Navigator.of(context).pop('delete'),
              ),
            ],
          ),
        );
      },
    );
    if (action == null) return;
    if (!mounted) return;

    if (action == 'pin') {
      setState(() {
        final index = _historyIndexByConversationId(item.id);
        if (index < 0) return;
        final target = _conversationHistory[index];
        final updated = target.copyWith(
          isPinned: !target.isPinned,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        );
        _conversationHistory[index] = updated;
        if (updated.isPinned) {
          final moved = _conversationHistory.removeAt(index);
          _conversationHistory.insert(0, moved);
        }
      });
      _persistState();
      return;
    }

    if (action == 'delete') {
      if (_sendingConversationId == item.id) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('该会话正在回复中，暂时不能删除')));
        return;
      }
      setState(() {
        _conversationHistory.removeWhere((entry) => entry.id == item.id);
      });
      _persistState();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已删除历史会话')));
    }
  }

  List<_ConversationSearchHit> _searchConversationHits(
    String rawQuery, {
    int limit = 80,
  }) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return const [];
    final hits = <_ConversationSearchHit>[];

    void collectFromConversation({
      required String conversationId,
      required String title,
      required String preview,
      required int timestampMs,
      required bool isCurrent,
      required bool isPinned,
      required List<ChatMessage> messages,
    }) {
      final titleMatch = title.toLowerCase().contains(query);
      final previewMatch = preview.toLowerCase().contains(query);
      var matchedIndex = -1;
      for (var i = messages.length - 1; i >= 0; i--) {
        final text = messages[i].text.trim().toLowerCase();
        if (text.isEmpty) continue;
        if (text.contains(query)) {
          matchedIndex = i;
          break;
        }
      }
      if (!titleMatch && !previewMatch && matchedIndex < 0) return;

      final matchedMessageText = matchedIndex >= 0
          ? _singleLinePreview(messages[matchedIndex].text, maxLength: 64)
          : '';
      final snippet = matchedMessageText.isNotEmpty
          ? matchedMessageText
          : (preview.trim().isNotEmpty
                ? _singleLinePreview(preview, maxLength: 64)
                : _singleLinePreview(title, maxLength: 64));
      final score =
          (titleMatch ? 5 : 0) +
          (previewMatch ? 3 : 0) +
          (matchedIndex >= 0 ? 4 : 0);
      hits.add(
        _ConversationSearchHit(
          conversationId: conversationId,
          title: title,
          snippet: snippet,
          timestampMs: timestampMs,
          isCurrent: isCurrent,
          isPinned: isPinned,
          messageIndex: matchedIndex >= 0 ? matchedIndex : null,
          score: score,
        ),
      );
    }

    collectFromConversation(
      conversationId: _activeConversationId,
      title: _normalizedConversationTitle(),
      preview: _buildConversationPreview(),
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      isCurrent: true,
      isPinned: _activeConversationPinned,
      messages: _messages,
    );

    for (final item in _conversationHistory) {
      collectFromConversation(
        conversationId: item.id,
        title: _normalizedConversationTitle(item.title),
        preview: item.preview,
        timestampMs: item.timestampMs,
        isCurrent: false,
        isPinned: item.isPinned,
        messages: item.messages,
      );
    }

    hits.sort((a, b) {
      if (a.score != b.score) {
        return b.score.compareTo(a.score);
      }
      if (a.isCurrent != b.isCurrent) {
        return a.isCurrent ? -1 : 1;
      }
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      return b.timestampMs.compareTo(a.timestampMs);
    });
    if (hits.length <= limit) return hits;
    return hits.take(limit).toList(growable: false);
  }

  void _scrollToChatMessageIndex(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_chatScroll.hasClients) return;
      final total = _messages.length;
      if (total <= 1) {
        _chatScroll.animateTo(
          _chatScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
        return;
      }
      final clamped = index.clamp(0, total - 1);
      final ratio = clamped / (total - 1);
      final target = _chatScroll.position.maxScrollExtent * ratio;
      _chatScroll.animateTo(
        target.clamp(0, _chatScroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _showConversationSearch() async {
    final controller = TextEditingController();
    var keyword = '';
    final selected = await showModalBottomSheet<_ConversationSearchHit>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final results = _searchConversationHits(keyword);
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 14,
                  right: 14,
                  top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      onChanged: (value) {
                        setModalState(() {
                          keyword = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: '输入关键词搜索会话内容',
                        prefixIcon: const Icon(Icons.search_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.52,
                      child: results.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              child: Text(
                                keyword.trim().isEmpty
                                    ? '输入关键词后开始搜索'
                                    : '没有找到匹配内容',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppPalette.muted,
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: results.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final item = results[index];
                                return InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => Navigator.of(context).pop(item),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFD),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppPalette.border,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppPalette.ink,
                                                ),
                                              ),
                                            ),
                                            if (item.isCurrent)
                                              const Padding(
                                                padding: EdgeInsets.only(
                                                  left: 6,
                                                ),
                                                child: Text(
                                                  '当前',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: AppPalette.primary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          item.snippet,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppPalette.muted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    controller.dispose();

    if (!mounted || selected == null) return;
    if (selected.isCurrent) {
      if (selected.messageIndex != null) {
        _scrollToChatMessageIndex(selected.messageIndex!);
      }
      return;
    }

    final targetIndex = _historyIndexByConversationId(selected.conversationId);
    if (targetIndex < 0) return;
    final target = _conversationHistory[targetIndex];
    await _restoreConversationFromHistory(target, closeDrawer: false);
    if (selected.messageIndex != null) {
      _scrollToChatMessageIndex(selected.messageIndex!);
    }
  }

  Future<void> _showConversationTitleEditor() async {
    final nextTitle = await showDialog<String>(
      context: context,
      builder: (_) => _TextEditingAlertDialog(
        title: '自定义对话标题',
        initialValue: _normalizedConversationTitle(),
        hintText: '例如：登录页按钮样式调整',
        maxLength: 24,
        submitLabel: '保存',
      ),
    );
    if (!mounted || nextTitle == null) return;
    final normalized = _singleLinePreview(
      _normalizedConversationTitle(nextTitle),
      maxLength: 24,
    );
    if (normalized == _conversationTitle) return;
    setState(() {
      _conversationTitle = normalized;
    });
    _persistState();
  }

  String _historyGroupTitle(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final diff = today.difference(target).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    return '${dateTime.month}月${dateTime.day}日';
  }

  String _greetingByTime() {
    final hour = DateTime.now().hour;
    if (hour < 6) return '夜深了，注意休息';
    if (hour < 12) return '早上好';
    if (hour < 18) return '下午好';
    return '晚上好';
  }

  bool _isLikelyTextFile(String name) {
    final lower = name.toLowerCase();
    const textExtensions = <String>{
      '.txt',
      '.md',
      '.markdown',
      '.json',
      '.yaml',
      '.yml',
      '.xml',
      '.csv',
      '.log',
      '.ini',
      '.cfg',
      '.conf',
      '.toml',
      '.dart',
      '.java',
      '.kt',
      '.kts',
      '.py',
      '.js',
      '.ts',
      '.jsx',
      '.tsx',
      '.c',
      '.cc',
      '.cpp',
      '.h',
      '.hpp',
      '.go',
      '.rs',
      '.swift',
      '.m',
      '.mm',
      '.php',
      '.rb',
      '.sql',
      '.html',
      '.css',
      '.scss',
      '.vue',
      '.sh',
      '.bat',
      '.ps1',
      '.gradle',
      '.pbxproj',
      '.gitignore',
      '.env',
    };
    for (final ext in textExtensions) {
      if (lower.endsWith(ext)) return true;
    }
    return false;
  }

  bool _isLikelyImageFile(String name) {
    final lower = name.toLowerCase();
    const imageExtensions = <String>{
      '.jpg',
      '.jpeg',
      '.png',
      '.webp',
      '.gif',
      '.bmp',
      '.heic',
      '.heif',
      '.tif',
      '.tiff',
    };
    for (final ext in imageExtensions) {
      if (lower.endsWith(ext)) return true;
    }
    return false;
  }

  String _guessImageMimeType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.bmp')) return 'image/bmp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.heif')) return 'image/heif';
    if (lower.endsWith('.tif') || lower.endsWith('.tiff')) return 'image/tiff';
    return 'image/jpeg';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _displayPathForAttachment(String fullPath) {
    final normalizedPath = fullPath.replaceAll('\\', '/');
    final root = _projectRootPath;
    if (root != null && root.trim().isNotEmpty) {
      final normalizedRoot = root.replaceAll('\\', '/');
      if (normalizedPath.startsWith(normalizedRoot)) {
        final relative = _relativePath(normalizedPath, normalizedRoot);
        return relative.isEmpty ? normalizedPath : relative;
      }
    }
    return normalizedPath;
  }

  Future<_PreparedAttachments> _prepareOutgoingAttachments() async {
    if (_composerAttachments.isEmpty) {
      return const _PreparedAttachments();
    }
    const maxTextBytes = 196608;
    const maxPreviewChars = 1200;
    const maxTotalChars = 5200;
    const maxImageBytes = 3145728;
    const maxImageCount = 3;
    final buffer = StringBuffer()..writeln('【上传文件】');
    final outgoingImages = <_OutgoingImageAttachment>[];
    var totalChars = 0;

    for (var i = 0; i < _composerAttachments.length; i++) {
      final item = _composerAttachments[i];
      buffer.writeln(
        '${i + 1}. ${item.name} (${_formatBytes(item.sizeBytes)}) 路径: ${item.displayPath}',
      );
      if (item.isImageLike) {
        if (item.path == null) {
          buffer.writeln('图片处理: 缺少本地路径，无法附带图片内容');
          continue;
        }
        if (outgoingImages.length >= maxImageCount) {
          buffer.writeln('图片处理: 最多附带 $maxImageCount 张，后续已跳过');
          continue;
        }
        if (item.sizeBytes > maxImageBytes) {
          buffer.writeln('图片处理: 文件超过 ${_formatBytes(maxImageBytes)}，已跳过图片注入');
          continue;
        }
        try {
          final file = File(item.path!);
          if (!await file.exists()) {
            buffer.writeln('图片处理: 文件不存在，已跳过');
            continue;
          }
          final bytes = await file.readAsBytes();
          if (bytes.isEmpty) {
            buffer.writeln('图片处理: 文件为空，已跳过');
            continue;
          }
          final mime = _guessImageMimeType(item.name);
          final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
          outgoingImages.add(
            _OutgoingImageAttachment(
              name: item.name,
              mime: mime,
              sizeBytes: item.sizeBytes,
              dataUrl: dataUrl,
            ),
          );
          buffer.writeln('图片处理: 已作为图片输入附带给模型');
        } catch (_) {
          buffer.writeln('图片处理: 读取失败，已跳过');
        }
        continue;
      }
      if (item.path == null || !item.isTextLike) {
        continue;
      }
      try {
        final file = File(item.path!);
        if (!await file.exists()) continue;
        if (item.sizeBytes > maxTextBytes) {
          buffer.writeln('内容预览: 文件较大，已跳过正文注入');
          continue;
        }
        final content = await file.readAsString();
        if (content.trim().isEmpty) continue;
        final clipped = content.length <= maxPreviewChars
            ? content
            : '${content.substring(0, maxPreviewChars)}...';
        totalChars += clipped.length;
        if (totalChars > maxTotalChars) {
          buffer.writeln('内容预览: 文件较多，后续正文已省略');
          break;
        }
        buffer
          ..writeln('内容预览:')
          ..writeln('```')
          ..writeln(clipped)
          ..writeln('```');
      } catch (_) {
        buffer.writeln('内容预览: 读取失败，保留文件信息');
      }
    }
    return _PreparedAttachments(
      promptBlock: buffer.toString().trim(),
      images: outgoingImages,
    );
  }

  bool _maySupportImageInput() {
    final activeConnection = _activeConnection;
    if (activeConnection != null) {
      if (activeConnection.inputModes.contains('image')) {
        return true;
      }
      // Keep chat models permissive to avoid accidental capability suppression.
      return activeConnection.modelType == 'chat';
    }
    return true;
  }

  Future<void> _pickComposerFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;

      final next = List<_ComposerAttachment>.from(_composerAttachments);
      for (final file in result.files) {
        final name = file.name.trim().isEmpty ? '未命名文件' : file.name.trim();
        final path = file.path;
        final sizeBytes = file.size;
        final displayPath = path == null || path.trim().isEmpty
            ? name
            : _displayPathForAttachment(path);
        final id = '${DateTime.now().microsecondsSinceEpoch}_${next.length}';
        next.add(
          _ComposerAttachment(
            id: id,
            name: name,
            path: path,
            displayPath: displayPath,
            sizeBytes: sizeBytes,
            isTextLike: _isLikelyTextFile(name),
            isImageLike: _isLikelyImageFile(name),
          ),
        );
      }
      if (next.length > 10) {
        next.removeRange(10, next.length);
      }
      setState(() {
        _composerAttachments
          ..clear()
          ..addAll(next);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已选择 ${result.files.length} 个文件')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('选择文件失败: $error')));
    }
  }

  void _removeComposerAttachment(String id) {
    setState(() {
      _composerAttachments.removeWhere((item) => item.id == id);
    });
  }

  int _messageCountForConversation(String conversationId) {
    if (conversationId == _activeConversationId) {
      return _messages.length;
    }
    final index = _historyIndexByConversationId(conversationId);
    if (index < 0) return 0;
    return _conversationHistory[index].messages.length;
  }

  void _appendMessage(ChatMessage message, {String? conversationId}) {
    final targetConversationId = conversationId ?? _activeConversationId;
    var shouldScroll = false;
    setState(() {
      if (targetConversationId == _activeConversationId) {
        _messages.add(message);
        shouldScroll = true;
        return;
      }

      final index = _historyIndexByConversationId(targetConversationId);
      if (index >= 0) {
        final item = _conversationHistory[index];
        final nextMessages = List<ChatMessage>.from(item.messages)
          ..add(message);
        final updated = item.copyWith(
          messages: nextMessages,
          preview: _buildConversationPreviewFromMessages(nextMessages),
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        );
        _conversationHistory[index] = updated;
        if (!updated.isPinned) {
          final moved = _conversationHistory.removeAt(index);
          _conversationHistory.insert(0, moved);
        }
        return;
      }

      _upsertConversationHistory(
        _ConversationSummary(
          id: targetConversationId,
          title: _defaultConversationTitle,
          preview: _singleLinePreview(message.text, maxLength: 26),
          timestampMs: DateTime.now().millisecondsSinceEpoch,
          messages: [message],
        ),
      );
    });
    _persistState();
    if (!shouldScroll) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(
          _chatScroll.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scheduleChatScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(
          _chatScroll.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  int? _appendLiveAssistantPlaceholder({
    required String conversationId,
    required String time,
  }) {
    if (conversationId != _activeConversationId) return null;
    late int index;
    setState(() {
      index = _messages.length;
      _messages.add(
        ChatMessage(role: ChatRole.assistant, text: '', time: time),
      );
    });
    _scheduleChatScrollToBottom();
    return index;
  }

  void _updateLiveAssistantMessage({
    required String conversationId,
    required int? messageIndex,
    required ChatMessage message,
    bool persist = false,
  }) {
    if (conversationId != _activeConversationId ||
        messageIndex == null ||
        messageIndex < 0 ||
        messageIndex >= _messages.length) {
      if (persist) {
        _appendMessage(message, conversationId: conversationId);
      }
      return;
    }

    setState(() {
      _messages[messageIndex] = message;
    });
    if (persist) {
      _persistState();
    }
    _scheduleChatScrollToBottom();
  }

  bool _looksLikeWorkspaceCreationRequest(String text) {
    final normalized = text.toLowerCase();
    if (normalized.startsWith('@fs create-file') ||
        normalized.startsWith('@fs create-dir') ||
        normalized.startsWith('@fs write')) {
      return true;
    }
    const markers = <String>[
      '创建项目',
      '新建项目',
      '创建文件',
      '新建文件',
      '创建目录',
      '新建目录',
      '写一个demo',
      '写一个 demo',
      '做一个demo',
      '做一个 demo',
      '生成项目',
      'generate a project',
      'create a project',
      'create file',
      'new file',
      'make a demo',
      'build a demo',
    ];
    return markers.any(normalized.contains);
  }

  Future<void> _ensureWorkspaceForCreationPrompt({
    required String text,
    required String conversationId,
  }) async {
    if (_projectRootPath != null) return;
    if (!_looksLikeWorkspaceCreationRequest(text)) return;
    await _createAndBindEmptyWorkspace(label: _singleLinePreview(text));
    _appendMessage(
      ChatMessage(
        role: ChatRole.system,
        text: '已为当前对话创建并绑定一个本地工作区。后续 AI 文件读写只会发生在这个工作区内。',
        time: _timeNow(),
      ),
      conversationId: conversationId,
    );
  }

  Future<void> _sendPrompt() async {
    if (_sendingPrompt) return;
    _cancelInlineMessageEdit();
    _stopReplyRequested = false;
    final conversationId = _activeConversationId;
    final rawText = _promptController.text.trim();
    if (rawText.isEmpty && _composerAttachments.isEmpty) return;
    final preparedAttachments = await _prepareOutgoingAttachments();
    final attachmentBlock = preparedAttachments.promptBlock;
    final attachedImages = preparedAttachments.images;
    final text = attachmentBlock.isEmpty
        ? rawText
        : '${rawText.isEmpty ? '请处理我上传的文件。' : rawText}\n\n$attachmentBlock';

    if (attachedImages.isNotEmpty && !_maySupportImageInput()) {
      _appendMessage(
        ChatMessage(
          role: ChatRole.system,
          text: '当前连接标记为文本输入模型，已尝试附带图片；若识图失败请切换支持视觉输入的模型。',
          time: _timeNow(),
        ),
        conversationId: conversationId,
      );
    }

    _promptController.clear();
    if (_composerAttachments.isNotEmpty) {
      setState(() {
        _composerAttachments.clear();
      });
    }

    _appendMessage(
      ChatMessage(role: ChatRole.user, text: text, time: _timeNow()),
      conversationId: conversationId,
    );

    await _ensureWorkspaceForCreationPrompt(
      text: text,
      conversationId: conversationId,
    );

    if (_aiFsGranted) {
      final fsRoundDraft = _AiRoundDraft(
        id: 'round_${DateTime.now().microsecondsSinceEpoch}',
        prompt: text,
        messageStartIndex: _messageCountForConversation(conversationId),
        projectRootPath: _projectRootPath,
      );
      final handled = await _maybeHandleFsToolCommand(
        text,
        roundDraft: fsRoundDraft,
        conversationId: conversationId,
      );
      if (handled) {
        await _finalizeAiRound(fsRoundDraft, conversationId: conversationId);
        return;
      }
    }

    final roundDraft = _AiRoundDraft(
      id: 'round_${DateTime.now().microsecondsSinceEpoch}',
      prompt: text,
      messageStartIndex: _messageCountForConversation(conversationId),
      projectRootPath: _projectRootPath,
    );

    setState(() {
      _sendingPrompt = true;
      _sendingConversationId = conversationId;
    });
    _updateReplyProgress('准备请求模型');
    await _startBackgroundReplyGuard(stage: '准备请求模型');
    try {
      await _replyWithModelOrchestrated(
        roundDraft: roundDraft,
        conversationId: conversationId,
        attachedImages: attachedImages,
      );
    } catch (error) {
      if (error is _ModelRequestCancelledException) {
        _recordAgentProgress('已停止回复', detail: '这次回复已被手动停止。');
        _updateReplyProgress('已手动停止回复');
        _appendMessage(
          ChatMessage(
            role: ChatRole.system,
            text: '已手动停止接收回复',
            time: _timeNow(),
          ),
          conversationId: conversationId,
        );
      } else {
        _recordAgentProgress('回复失败', detail: error.toString());
        _updateReplyProgress('回复失败');
        _appendMessage(
          ChatMessage(
            role: ChatRole.system,
            text: '调用模型失败: $error',
            time: _timeNow(),
          ),
          conversationId: conversationId,
        );
      }
    } finally {
      await _stopBackgroundReplyGuard();
      await _finalizeAiRound(roundDraft, conversationId: conversationId);
      _stopReplyRequested = false;
      _activeChatRequest = null;
      _activeChatClient = null;
      if (mounted) {
        setState(() {
          _sendingPrompt = false;
          if (_sendingConversationId == conversationId) {
            _sendingConversationId = null;
          }
        });
      } else if (_sendingConversationId == conversationId) {
        _sendingConversationId = null;
      }
    }
  }

  void _editMessageAt(int index) {
    if (index < 0 || index >= _messages.length) return;
    final message = _messages[index];
    if (message.role == ChatRole.system) return;
    final text = _messages[index].text.trim();
    if (text.isEmpty) return;
    setState(() {
      _editingMessageIndex = index;
      _messageEditController.text = text;
      _messageEditController.selection = TextSelection.collapsed(
        offset: text.length,
      );
    });
  }

  void _cancelInlineMessageEdit() {
    if (_editingMessageIndex == null) return;
    setState(() {
      _editingMessageIndex = null;
      _messageEditController.clear();
    });
  }

  Future<void> _saveInlineMessageEdit(int index) async {
    if (_editingMessageIndex != index) return;
    if (index < 0 || index >= _messages.length) return;
    final nextText = _messageEditController.text.trim();
    if (nextText.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('消息内容不能为空')));
      return;
    }

    final original = _messages[index];
    setState(() {
      _messages[index] = ChatMessage(
        role: original.role,
        text: nextText,
        time: original.time,
      );
      _editingMessageIndex = null;
      _messageEditController.clear();
    });
    _persistState();
  }

  Future<void> _copyMessageAt(int index) async {
    if (index < 0 || index >= _messages.length) return;
    final text = _messages[index].text;
    if (text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('消息已复制')));
  }

  String get _aboutCopyText =>
      '作者     $_aboutAuthor\n开心哔站      $_aboutBilibiliUrl';

  Future<void> _showAboutAppDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('关于应用'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '作者     $_aboutAuthor',
                style: TextStyle(fontSize: 15, color: AppPalette.ink),
              ),
              const SizedBox(height: 10),
              const SelectableText(
                '开心哔站      $_aboutBilibiliUrl',
                style: TextStyle(fontSize: 15, color: AppPalette.ink),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _aboutCopyText));
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已复制应用信息')));
              },
              child: const Text('复制'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  String? _resolveRetryPromptFromIndex(int index) {
    if (index < 0 || index >= _messages.length) return null;
    final current = _messages[index];
    if (current.role == ChatRole.user) {
      final selfText = current.text.trim();
      return selfText.isEmpty ? null : selfText;
    }
    for (var i = index - 1; i >= 0; i--) {
      final message = _messages[i];
      if (message.role == ChatRole.user && message.text.trim().isNotEmpty) {
        return message.text.trim();
      }
    }
    for (var i = _messages.length - 1; i >= 0; i--) {
      final message = _messages[i];
      if (message.role == ChatRole.user && message.text.trim().isNotEmpty) {
        return message.text.trim();
      }
    }
    return null;
  }

  Future<void> _retryMessageAt(int index) async {
    if (_sendingPrompt) return;
    final prompt = _resolveRetryPromptFromIndex(index);
    if (prompt == null || prompt.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('未找到可重试的问题')));
      return;
    }
    _promptController.text = prompt;
    _promptController.selection = TextSelection.collapsed(
      offset: prompt.length,
    );
    _promptFocusNode.requestFocus();
    await _sendPrompt();
  }

  Widget _buildMessageActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Colors.white.withValues(alpha: 0.52),
          border: Border.all(color: AppPalette.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppPalette.muted),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppPalette.muted),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _finalizeAiRound(
    _AiRoundDraft roundDraft, {
    required String conversationId,
  }) async {
    final messageCount = _messageCountForConversation(conversationId);
    final hasRoundMessages = messageCount > roundDraft.messageStartIndex;
    if (!hasRoundMessages && roundDraft.snapshots.isEmpty) {
      await _cleanupBackupDir(roundDraft.backupDir?.path);
      return;
    }

    if (conversationId != _activeConversationId) {
      await _cleanupBackupDir(roundDraft.backupDir?.path);
      return;
    }

    _aiRoundHistory.add(
      _AiRoundRecord(
        id: roundDraft.id,
        prompt: roundDraft.prompt,
        messageStartIndex: roundDraft.messageStartIndex,
        messageEndIndex: messageCount,
        projectRootPath: roundDraft.projectRootPath,
        snapshots: List<_PathUndoSnapshot>.unmodifiable(roundDraft.snapshots),
        backupDirPath: roundDraft.backupDir?.path,
      ),
    );
    await _trimAiRoundHistory();
  }

  Future<void> _trimAiRoundHistory() async {
    while (_aiRoundHistory.length > _maxRollbackRounds) {
      final removed = _aiRoundHistory.removeAt(0);
      await _cleanupBackupDir(removed.backupDirPath);
    }
  }

  Future<void> _captureUndoSnapshotIfNeeded(
    _AiRoundDraft roundDraft,
    String relativePath,
  ) async {
    final normalized = _normalizeInputPath(relativePath);
    if (normalized.isEmpty) return;
    if (!roundDraft.capturedPaths.add(normalized)) return;

    final targetPath = _resolveWithinProject(normalized);
    final targetFile = File(targetPath);
    if (await targetFile.exists()) {
      final backupDir = await _ensureRoundBackupDir(roundDraft);
      final entryName =
          'f_${roundDraft.snapshots.length}_${DateTime.now().microsecondsSinceEpoch}';
      final backupFile = File(
        '${backupDir.path}${Platform.pathSeparator}$entryName',
      );
      await backupFile.parent.create(recursive: true);
      await targetFile.copy(backupFile.path);
      roundDraft.snapshots.add(
        _PathUndoSnapshot(
          relativePath: normalized,
          beforeType: _PathSnapshotType.file,
          backupEntryName: entryName,
        ),
      );
      return;
    }

    final targetDir = Directory(targetPath);
    if (await targetDir.exists()) {
      final backupDir = await _ensureRoundBackupDir(roundDraft);
      final entryName =
          'd_${roundDraft.snapshots.length}_${DateTime.now().microsecondsSinceEpoch}';
      final backupPath = Directory(
        '${backupDir.path}${Platform.pathSeparator}$entryName',
      );
      await _copyDirectoryRecursively(targetDir, backupPath);
      roundDraft.snapshots.add(
        _PathUndoSnapshot(
          relativePath: normalized,
          beforeType: _PathSnapshotType.directory,
          backupEntryName: entryName,
        ),
      );
      return;
    }

    roundDraft.snapshots.add(
      _PathUndoSnapshot(
        relativePath: normalized,
        beforeType: _PathSnapshotType.missing,
      ),
    );
  }

  Future<Directory> _ensureRoundBackupDir(_AiRoundDraft roundDraft) async {
    final existing = roundDraft.backupDir;
    if (existing != null) return existing;
    final created = await Directory.systemTemp.createTemp(
      'astra_ai_undo_${roundDraft.id}_',
    );
    roundDraft.backupDir = created;
    return created;
  }

  Future<void> _copyDirectoryRecursively(
    Directory source,
    Directory target,
  ) async {
    await target.create(recursive: true);
    await for (final entity in source.list(
      recursive: true,
      followLinks: false,
    )) {
      final relative = _relativePath(entity.path, source.path);
      final nextPath = '${target.path}${Platform.pathSeparator}$relative';
      if (entity is Directory) {
        await Directory(nextPath).create(recursive: true);
      } else if (entity is File) {
        final outFile = File(nextPath);
        await outFile.parent.create(recursive: true);
        await entity.copy(outFile.path);
      }
    }
  }

  Future<void> _restoreSnapshot(
    _PathUndoSnapshot snapshot, {
    required String? backupDirPath,
  }) async {
    final targetPath = _resolveWithinProject(snapshot.relativePath);
    final targetFile = File(targetPath);
    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    final targetDir = Directory(targetPath);
    if (await targetDir.exists()) {
      await targetDir.delete(recursive: true);
    }

    if (snapshot.beforeType == _PathSnapshotType.missing) {
      return;
    }

    final entryName = snapshot.backupEntryName;
    if (backupDirPath == null || entryName == null || entryName.isEmpty) {
      throw Exception('缺少回退备份: ${snapshot.relativePath}');
    }

    final backupPath = '$backupDirPath${Platform.pathSeparator}$entryName';
    if (snapshot.beforeType == _PathSnapshotType.file) {
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        throw Exception('回退备份文件不存在: ${snapshot.relativePath}');
      }
      await targetFile.parent.create(recursive: true);
      await backupFile.copy(targetFile.path);
      return;
    }

    final backupDir = Directory(backupPath);
    if (!await backupDir.exists()) {
      throw Exception('回退备份目录不存在: ${snapshot.relativePath}');
    }
    await _copyDirectoryRecursively(backupDir, targetDir);
  }

  Future<void> _cleanupBackupDir(String? backupDirPath) async {
    if (backupDirPath == null || backupDirPath.isEmpty) return;
    final dir = Directory(backupDirPath);
    try {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }

  List<_AiRoundRecord> _collectRollbackRoundsFromUserMessageIndex(int index) {
    if (index < 0 || index >= _messages.length) return const [];
    if (_messages[index].role != ChatRole.user) return const [];
    final rounds = <_AiRoundRecord>[];
    for (var i = _aiRoundHistory.length - 1; i >= 0; i--) {
      final round = _aiRoundHistory[i];
      if (round.messageStartIndex >= index + 1) {
        rounds.add(round);
      }
    }
    return rounds;
  }

  bool _isSnapshotMetadataReady(_AiRoundRecord round) {
    if (round.snapshots.isEmpty) return false;
    for (final snapshot in round.snapshots) {
      if (snapshot.beforeType == _PathSnapshotType.missing) continue;
      final backupDirPath = round.backupDirPath;
      final entryName = snapshot.backupEntryName;
      if (backupDirPath == null || backupDirPath.isEmpty) return false;
      if (entryName == null || entryName.isEmpty) return false;
    }
    return true;
  }

  bool _canRollbackFromUserMessage(int index) {
    if (_sendingPrompt || _rollingBackRound) return false;
    final rounds = _collectRollbackRoundsFromUserMessageIndex(index);
    if (rounds.isEmpty) return false;
    var hasRollbackableChanges = false;
    for (final round in rounds) {
      if (round.snapshots.isEmpty) continue;
      if (!_isSnapshotMetadataReady(round)) return false;
      hasRollbackableChanges = true;
    }
    return hasRollbackableChanges;
  }

  Future<void> _rollbackFromUserMessage(int index) async {
    if (_sendingPrompt || _rollingBackRound) return;
    if (index < 0 || index >= _messages.length) return;
    final selected = _messages[index];
    if (selected.role != ChatRole.user) return;
    final userText = selected.text.trim();
    if (userText.isEmpty) return;

    final roundsToRollback = _collectRollbackRoundsFromUserMessageIndex(index);
    if (!_canRollbackFromUserMessage(index)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前消息没有可回退的文件修改记录')));
      return;
    }
    final roundIds = roundsToRollback.map((round) => round.id).toSet();

    setState(() {
      _rollingBackRound = true;
      _rollingBackMessageIndex = index;
      _aiRoundHistory.removeWhere((round) => roundIds.contains(round.id));
    });

    try {
      for (final round in roundsToRollback) {
        final roundRoot = round.projectRootPath;
        if (roundRoot != null && roundRoot != _projectRootPath) {
          await _loadProjectFolder(roundRoot, silent: true);
        }
        if (roundRoot != null && roundRoot != _projectRootPath) {
          throw Exception('无法切回原始项目目录: $roundRoot');
        }
        for (final snapshot in round.snapshots.reversed) {
          await _restoreSnapshot(snapshot, backupDirPath: round.backupDirPath);
        }
      }
      if (_projectRootPath != null) {
        await _loadProjectFolder(_projectRootPath!, silent: true);
      }

      if (mounted) {
        setState(() {
          if (index < _messages.length) {
            _messages.removeRange(index, _messages.length);
          }
          _fileOpsStatus = '已回退消息到输入栏';
        });
        _promptController.text = userText;
        _promptController.selection = TextSelection.collapsed(
          offset: userText.length,
        );
        _persistState();
        _promptFocusNode.requestFocus();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已回退消息并恢复到输入栏')));
      }
      for (final round in roundsToRollback) {
        await _cleanupBackupDir(round.backupDirPath);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _aiRoundHistory.addAll(roundsToRollback.reversed);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('回退失败: $error')));
      } else {
        _aiRoundHistory.addAll(roundsToRollback.reversed);
      }
    } finally {
      if (mounted) {
        setState(() {
          _rollingBackRound = false;
          _rollingBackMessageIndex = null;
        });
      } else {
        _rollingBackRound = false;
        _rollingBackMessageIndex = null;
      }
    }
  }

  String _relativePath(String path, String rootPath) {
    final p = path.replaceAll('\\', '/');
    final root = rootPath.replaceAll('\\', '/');
    if (p.startsWith(root)) {
      return p.substring(root.length).replaceFirst(RegExp(r'^/'), '');
    }
    return p;
  }

  String _previewText(String content) {
    final text = content.replaceAll('\r\n', '\n').trim();
    if (text.length <= 240) return text;
    return '${text.substring(0, 240)}...';
  }

  bool _looksBinary(List<int> bytes) {
    if (bytes.isEmpty) return false;
    var controlCount = 0;
    for (final b in bytes.take(256)) {
      if (b == 0) return true;
      if (b < 9 || (b > 13 && b < 32)) {
        controlCount++;
      }
    }
    return controlCount > 20;
  }

  Future<(String, bool)> _readPreview(File file) async {
    final bytes = await file.openRead(0, 32768).fold<List<int>>(<int>[], (
      acc,
      chunk,
    ) {
      acc.addAll(chunk);
      return acc;
    });
    final stat = await file.stat();
    final size = stat.size;
    if (_looksBinary(bytes)) {
      return ('<binary: $size bytes>', true);
    }
    final text = utf8.decode(bytes, allowMalformed: true);
    return (_previewText(text), false);
  }

  String _normalizeInputPath(String value) {
    return value.trim().replaceAll('\\', '/').replaceFirst(RegExp(r'^/'), '');
  }

  bool get _hasActiveMirrorWorkspace {
    final projectRoot = _projectRootPath?.trim();
    final preparedProject = _localRuntimeStatus.lastPreparedProjectPath.trim();
    if (projectRoot == null || projectRoot.isEmpty) return false;
    if (!_localRuntimeStatus.hasWorkspace) return false;
    return preparedProject == projectRoot;
  }

  String? _effectiveProjectAccessRootPath() {
    final projectRoot = _projectRootPath?.trim();
    if (projectRoot == null || projectRoot.isEmpty) {
      return null;
    }
    return projectRoot;
  }

  String _requireEffectiveProjectAccessRootPath() {
    final root = _effectiveProjectAccessRootPath();
    if (root == null || root.isEmpty) {
      throw Exception('Project root is not available.');
    }
    return root;
  }

  String _displayProjectAccessRootPath() {
    return _effectiveProjectAccessRootPath() ?? '';
  }

  String _relativeProjectAccessPath(String absolutePath) {
    final root = _requireEffectiveProjectAccessRootPath();
    return _normalizeInputPath(_relativePath(absolutePath, root));
  }

  bool _isWithinRoot(String path, String rootPath) {
    var normalizedPath = path.replaceAll('\\', '/');
    var normalizedRoot = rootPath.replaceAll('\\', '/');
    if (!normalizedRoot.endsWith('/')) {
      normalizedRoot = '$normalizedRoot/';
    }
    if (Platform.isWindows) {
      normalizedPath = normalizedPath.toLowerCase();
      normalizedRoot = normalizedRoot.toLowerCase();
    }
    return normalizedPath.startsWith(normalizedRoot);
  }

  String _resolveWithinProject(String relativePath) {
    if (_projectRootPath == null) {
      throw Exception('请先选择项目文件夹');
    }
    final normalized = _normalizeInputPath(relativePath);
    if (normalized.isEmpty) {
      throw Exception('请输入相对路径');
    }
    final root = Directory(
      _requireEffectiveProjectAccessRootPath(),
    ).absolute.path;
    final target = File(
      '$root${Platform.pathSeparator}$normalized',
    ).absolute.path;
    if (!_isWithinRoot(target, root)) {
      throw Exception('路径越界，禁止访问项目目录之外的文件');
    }
    return target;
  }

  Future<String?> _manualFolderDialog() async {
    return showDialog<String>(
      context: context,
      builder: (_) => _TextEditingAlertDialog(
        title: '手动输入目录',
        initialValue: _projectRootPath ?? '',
        hintText: r'例如: /storage/emulated/0/Download/project',
        submitLabel: '确定',
        trimOnSubmit: true,
      ),
    );
  }

  bool _isSharedStoragePath(String path) {
    if (!Platform.isAndroid) return false;
    final normalized = path.replaceAll('\\', '/').toLowerCase();
    return normalized.startsWith('/storage/emulated/0/') ||
        normalized.startsWith('/sdcard/');
  }

  Future<bool> _hasExternalStorageAccess() async {
    if (!Platform.isAndroid) return true;
    try {
      final allowed = await _storageChannel.invokeMethod<bool>(
        'hasExternalStorageAccess',
      );
      return allowed ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _hasManifestPermission(String permission) async {
    if (!Platform.isAndroid) return true;
    try {
      final granted = await _storageChannel.invokeMethod<bool>(
        'hasManifestPermission',
        <String, dynamic>{'permission': permission},
      );
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _hasNetworkConnectivity() async {
    if (!Platform.isAndroid) return true;
    var channelConnected = false;
    try {
      final connected = await _storageChannel.invokeMethod<bool>(
        'hasNetworkConnectivity',
      );
      channelConnected = connected ?? false;
    } catch (_) {}
    if (channelConnected) return true;

    Future<bool> dnsProbe(String host) async {
      try {
        final entries = await InternetAddress.lookup(
          host,
        ).timeout(const Duration(seconds: 4));
        return entries.isNotEmpty && entries.first.rawAddress.isNotEmpty;
      } catch (_) {
        return false;
      }
    }

    if (await dnsProbe('one.one.one.one')) return true;
    if (await dnsProbe('www.bing.com')) return true;
    if (await dnsProbe('duckduckgo.com')) return true;
    return false;
  }

  Future<void> _openExternalStorageSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _storageChannel.invokeMethod<bool>('openExternalStorageSettings');
    } catch (_) {}
  }

  Future<void> _openAppSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _storageChannel.invokeMethod<bool>('openAppSettings');
    } catch (_) {}
  }

  Future<void> _auditAndRequestPermissions() async {
    if (_checkingPermissions) return;
    setState(() {
      _checkingPermissions = true;
      _permissionAuditStatus = '正在检查权限...';
    });

    try {
      final internetPermission = await _hasManifestPermission(
        'android.permission.INTERNET',
      );
      final networkStatePermission = await _hasManifestPermission(
        'android.permission.ACCESS_NETWORK_STATE',
      );
      var storageAccess = await _hasExternalStorageAccess();
      var networkConnected = await _hasNetworkConnectivity();

      if (!storageAccess) {
        await _showStoragePermissionDialog();
        storageAccess = await _hasExternalStorageAccess();
      }
      if (!internetPermission || !networkStatePermission) {
        await _openAppSettings();
      }
      networkConnected = await _hasNetworkConnectivity();

      final lines = <String>[
        '联网权限(INTERNET): ${internetPermission ? '已就绪' : '缺失'}',
        '网络状态权限(ACCESS_NETWORK_STATE): ${networkStatePermission ? '已就绪' : '缺失'}',
        '外部存储访问(所有文件): ${storageAccess ? '已授权' : '未授权'}',
        '当前网络连通性: ${networkConnected ? '正常' : '不可用'}',
      ];

      final actionHints = <String>[];
      if (!storageAccess) {
        actionHints.add('请在系统设置中打开“所有文件访问权限”');
      }
      if (!internetPermission || !networkStatePermission) {
        actionHints.add('��ǰ��װ��Ȩ���쳣������װ���°汾 App');
      }
      if (!networkConnected) {
        actionHints.add('请检查系统网络、DNS 或代理设置');
      }

      setState(() {
        _permissionAuditStatus = actionHints.isEmpty
            ? '${lines.join(' | ')} | 权限检查通过'
            : '${lines.join(' | ')} | ${actionHints.join('；')}';
        _fileOpsStatus = _permissionAuditStatus;
      });
    } catch (error) {
      setState(() {
        _permissionAuditStatus = '权限检查失败: $error';
        _fileOpsStatus = _permissionAuditStatus;
      });
    } finally {
      if (mounted) {
        setState(() {
          _checkingPermissions = false;
        });
      }
    }
  }

  Future<void> _showStoragePermissionDialog() async {
    if (!mounted) return;
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('需要存储访问权限'),
          content: const Text(
            '当前目录位于手机共享存储（如 Download）。请在系统设置中为本应用开启“所有文件访问权限”，然后回到应用点刷新。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('去设置'),
            ),
          ],
        );
      },
    );
    if (shouldOpen == true) {
      await _openExternalStorageSettings();
    }
  }

  Future<bool> _ensureStorageAccessIfNeeded(
    String path, {
    bool interactive = true,
  }) async {
    if (!_isSharedStoragePath(path)) return true;
    final granted = await _hasExternalStorageAccess();
    if (granted) return true;
    if (interactive) {
      await _showStoragePermissionDialog();
    }
    return await _hasExternalStorageAccess();
  }

  Future<
    ({
      List<ProjectFileSnippet> snippets,
      int scannedDirs,
      int scannedEntries,
      String? readError,
    })
  >
  _scanProjectSnippets(String folderPath) async {
    final snippets = <ProjectFileSnippet>[];
    var scannedDirs = 0;
    var scannedEntries = 0;
    String? readError;

    try {
      final dir = Directory(folderPath);
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        scannedEntries++;
        if (entity is Directory) {
          scannedDirs++;
          continue;
        }
        if (entity is! File) continue;
        final stat = await entity.stat();
        late final (String preview, bool isBinary) previewInfo;
        try {
          previewInfo = await _readPreview(entity);
        } catch (_) {
          previewInfo = ('<unreadable file>', true);
        }

        snippets.add(
          ProjectFileSnippet(
            path: _relativePath(entity.path, folderPath),
            absolutePath: entity.absolute.path,
            preview: previewInfo.$1,
            sizeBytes: stat.size,
            isBinary: previewInfo.$2,
          ),
        );
      }
    } on FileSystemException catch (error) {
      readError = error.message;
    } catch (error) {
      readError = error.toString();
    }

    return (
      snippets: snippets,
      scannedDirs: scannedDirs,
      scannedEntries: scannedEntries,
      readError: readError,
    );
  }

  String? _drawerExplorerAbsoluteDirectory(String path) {
    final rootPath = _effectiveProjectAccessRootPath();
    if (rootPath == null || rootPath.trim().isEmpty) return null;
    final root = Directory(rootPath).absolute.path;
    if (path == _drawerExplorerRootKey) {
      return root;
    }
    final normalized = _normalizeInputPath(path);
    if (normalized.isEmpty) {
      return root;
    }
    final target = Directory(
      '$root${Platform.pathSeparator}$normalized',
    ).absolute.path;
    if (!_isWithinRoot(target, root)) {
      return null;
    }
    return target;
  }

  Future<void> _loadDrawerExplorerChildren(
    String path, {
    bool force = false,
  }) async {
    final rootPath = _effectiveProjectAccessRootPath();
    if (rootPath == null || rootPath.trim().isEmpty) {
      return;
    }
    if (!force && _drawerExplorerChildrenByPath.containsKey(path)) {
      return;
    }
    if (_drawerExplorerLoadingPaths.contains(path)) {
      return;
    }
    final absolutePath = _drawerExplorerAbsoluteDirectory(path);
    if (absolutePath == null) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _drawerExplorerLoadingPaths.add(path);
      _drawerExplorerLoadErrors.remove(path);
    });

    List<_DrawerExplorerEntry> entries = const [];
    String? readError;
    try {
      final targetDir = Directory(absolutePath);
      if (!await targetDir.exists()) {
        readError = '目录不存在';
      } else {
        final root = Directory(rootPath).absolute.path;
        final children = <_DrawerExplorerEntry>[];
        await for (final entity in targetDir.list(
          recursive: false,
          followLinks: false,
        )) {
          final relative = _normalizeInputPath(
            _relativePath(entity.path, root),
          );
          if (relative.isEmpty) continue;
          final segments = relative.split('/');
          final name = segments.isEmpty ? relative : segments.last;
          if (name.isEmpty) continue;
          if (entity is Directory) {
            children.add(
              _DrawerExplorerEntry.directory(
                name: name,
                path: relative,
                absolutePath: entity.absolute.path,
              ),
            );
            continue;
          }
          if (entity is! File) continue;
          var sizeBytes = 0;
          try {
            sizeBytes = (await entity.stat()).size;
          } catch (_) {}
          children.add(
            _DrawerExplorerEntry.file(
              name: name,
              path: relative,
              absolutePath: entity.absolute.path,
              sizeBytes: sizeBytes,
            ),
          );
        }
        children.sort((a, b) {
          if (a.isDirectory != b.isDirectory) {
            return a.isDirectory ? -1 : 1;
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
        entries = children;
      }
    } on FileSystemException catch (error) {
      readError = error.message;
    } catch (error) {
      readError = error.toString();
    }

    if (!mounted || _effectiveProjectAccessRootPath() != rootPath) return;
    setState(() {
      _drawerExplorerLoadingPaths.remove(path);
      if (readError == null) {
        _drawerExplorerChildrenByPath[path] = entries;
        _drawerExplorerLoadErrors.remove(path);
      } else {
        _drawerExplorerChildrenByPath.remove(path);
        _drawerExplorerLoadErrors[path] = readError;
      }
    });
  }

  Future<void> _loadProjectFolder(
    String folderPath, {
    bool silent = false,
  }) async {
    final normalizedPath = folderPath.trim();
    final previousRoot = _projectRootPath;
    final rootChanged =
        previousRoot == null || previousRoot.trim() != normalizedPath;
    final hasPermission = await _ensureStorageAccessIfNeeded(
      normalizedPath,
      interactive: !silent,
    );
    if (!hasPermission) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('未授予存储权限，无法读取该目录')));
      }
      return;
    }

    final dir = Directory(normalizedPath);
    if (!await dir.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('目录不存在')));
      return;
    }

    setState(() {
      _readingProject = true;
      _projectRootPath = normalizedPath;
      if (rootChanged) {
        _projectFiles = const [];
        _projectContext = '';
      }
      _resetDrawerExplorerState();
    });

    await _loadDrawerExplorerChildren(_drawerExplorerRootKey, force: true);

    if (!mounted) return;
    setState(() {
      _readingProject = false;
    });
    _persistState();

    if (!silent) {
      final rootError = _drawerExplorerLoadErrors[_drawerExplorerRootKey];
      if (rootError != null) {
        final hint = _isSharedStoragePath(normalizedPath)
            ? '读取目录失败，可能缺少“所有文件访问权限”'
            : '读取目录失败';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$hint: $rootError')));
        return;
      }
      final rootEntries =
          _drawerExplorerChildrenByPath[_drawerExplorerRootKey] ??
          const <_DrawerExplorerEntry>[];
      final dirCount = rootEntries.where((item) => item.isDirectory).length;
      final fileCount = rootEntries.length - dirCount;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已加载根目录：$fileCount 个文件，$dirCount 个目录')),
      );
    }
  }

  void _resetDrawerExplorerState() {
    _drawerExplorerSelectedPath = null;
    _drawerExplorerExpandedPaths
      ..clear()
      ..add(_drawerExplorerRootKey);
    _drawerExplorerChildrenByPath.clear();
    _drawerExplorerLoadingPaths.clear();
    _drawerExplorerLoadErrors.clear();
  }

  Future<void> _pickProjectFolder() async {
    final path = await _manualFolderDialog();
    if (path == null || path.isEmpty) return;
    await _bindWorkspacePath(
      path: path,
      statusText: '已绑定当前对话工作区: $path',
      grantFileAccess: true,
    );
  }

  void _injectProjectContext() {
    unawaited(_injectProjectContextAsync());
  }

  Future<void> _injectProjectContextAsync() async {
    final root = _projectRootPath;
    if (root == null || root.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先读取项目文件夹')));
      return;
    }
    setState(() {
      _readingProject = true;
    });
    final scan = await _scanProjectSnippets(root);
    if (!mounted) return;
    setState(() {
      _readingProject = false;
      _projectFiles = scan.snippets;
    });
    if (scan.readError != null) {
      final hint = _isSharedStoragePath(root)
          ? '读取目录失败，可能缺少“所有文件访问权限”'
          : '读取目录失败';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$hint: ${scan.readError}')));
      return;
    }
    if (_projectFiles.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('目录内没有可用文件')));
      return;
    }
    _projectContext = _projectFiles
        .take(20)
        .map((f) => '[${f.path}]\n${f.preview}')
        .join('\n\n');
    final topFiles = _projectFiles.take(8).map((f) => '- ${f.path}').join('\n');
    _appendMessage(
      ChatMessage(
        role: ChatRole.system,
        text: '已将项目上下文注入 AI（${_projectFiles.length} 个文件）\n$topFiles',
        time: _timeNow(),
      ),
    );
  }

  Future<String> _readFileText(String relativePath) async {
    final targetPath = _resolveWithinProject(relativePath);
    final file = File(targetPath);
    if (!await file.exists()) {
      throw Exception('文件不存在: $relativePath');
    }
    final bytes = await file.readAsBytes();
    if (_looksBinary(bytes)) {
      return '<binary file: ${bytes.length} bytes>';
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  Future<Map<String, dynamic>> _readFilePart(
    String relativePath, {
    required int startLine,
    required int maxLines,
  }) async {
    final content = await _readFileText(relativePath);
    if (content.startsWith('<binary file:')) {
      throw Exception('read_file_part does not support binary files');
    }
    final lines = const LineSplitter().convert(content);
    final normalizedStartLine = startLine < 1 ? 1 : startLine;
    final normalizedMaxLines = maxLines.clamp(1, 400);
    final startIndex = normalizedStartLine - 1;
    if (startIndex >= lines.length) {
      return <String, dynamic>{
        'ok': true,
        'path': relativePath,
        'start_line': normalizedStartLine,
        'end_line': normalizedStartLine - 1,
        'total_lines': lines.length,
        'content': '',
      };
    }
    final endIndexExclusive = min(
      lines.length,
      startIndex + normalizedMaxLines,
    );
    final slice = lines.sublist(startIndex, endIndexExclusive).join('\n');
    return <String, dynamic>{
      'ok': true,
      'path': relativePath,
      'start_line': normalizedStartLine,
      'end_line': endIndexExclusive,
      'total_lines': lines.length,
      'content': slice,
    };
  }

  Future<void> _writeFileText(String relativePath, String content) async {
    final targetPath = _resolveWithinProject(relativePath);
    final file = File(targetPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  Future<Map<String, dynamic>> _replaceTextInFile({
    required String relativePath,
    required String oldText,
    required String newText,
    required bool replaceAll,
  }) async {
    final targetPath = _resolveWithinProject(relativePath);
    final file = File(targetPath);
    if (!await file.exists()) {
      throw Exception('文件不存�? $relativePath');
    }
    final bytes = await file.readAsBytes();
    if (_looksBinary(bytes)) {
      throw Exception('replace_in_file does not support binary files');
    }
    final content = utf8.decode(bytes, allowMalformed: true);
    if (oldText.isEmpty) {
      throw Exception('replace_in_file requires a non-empty old_text value');
    }
    if (!content.contains(oldText)) {
      throw Exception('Target text was not found in $relativePath');
    }
    final updated = replaceAll
        ? content.replaceAll(oldText, newText)
        : content.replaceFirst(oldText, newText);
    await file.writeAsString(updated);
    final replacedCount = replaceAll ? oldText.allMatches(content).length : 1;
    return <String, dynamic>{
      'ok': true,
      'path': relativePath,
      'replaced_count': replacedCount,
      'bytes': utf8.encode(updated).length,
    };
  }

  Future<void> _createDirectory(String relativePath) async {
    final targetPath = _resolveWithinProject(relativePath);
    final dir = Directory(targetPath);
    await dir.create(recursive: true);
  }

  Future<Map<String, dynamic>> _listDirectoryEntries(
    String relativePath, {
    required int limit,
  }) async {
    final normalized = relativePath.trim().isEmpty ? '.' : relativePath;
    final targetPath = _resolveWithinProject(normalized);
    final directory = Directory(targetPath);
    if (!await directory.exists()) {
      throw Exception('目录不存�? $normalized');
    }
    final entries = <Map<String, dynamic>>[];
    final listed = await directory.list(followLinks: false).toList();
    listed.sort((a, b) {
      final aDir = a is Directory ? 0 : 1;
      final bDir = b is Directory ? 0 : 1;
      if (aDir != bDir) return aDir.compareTo(bDir);
      return a.path.toLowerCase().compareTo(b.path.toLowerCase());
    });
    for (final entity in listed.take(limit)) {
      final stat = await entity.stat();
      final relative = _relativeProjectAccessPath(entity.path);
      entries.add(<String, dynamic>{
        'path': relative,
        'name': relative.split('/').last,
        'is_directory': entity is Directory,
        'size_bytes': entity is File ? stat.size : 0,
      });
    }
    return <String, dynamic>{
      'ok': true,
      'path': normalized == '.' ? '' : _normalizeInputPath(normalized),
      'count': entries.length,
      'entries': entries,
    };
  }

  Future<Map<String, dynamic>> _readFileInfo(String relativePath) async {
    final targetPath = _resolveWithinProject(relativePath);
    final file = File(targetPath);
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      return <String, dynamic>{
        'ok': true,
        'path': _normalizeInputPath(relativePath),
        'exists': true,
        'type': 'file',
        'size_bytes': bytes.length,
        'binary': _looksBinary(bytes),
      };
    }
    final dir = Directory(targetPath);
    if (await dir.exists()) {
      final childCount = await dir.list(followLinks: false).length;
      return <String, dynamic>{
        'ok': true,
        'path': _normalizeInputPath(relativePath),
        'exists': true,
        'type': 'directory',
        'child_count': childCount,
      };
    }
    return <String, dynamic>{
      'ok': true,
      'path': _normalizeInputPath(relativePath),
      'exists': false,
      'type': 'missing',
    };
  }

  Future<Map<String, dynamic>> _grepProjectCode({
    required String query,
    required String relativePath,
    required int limit,
    required bool caseSensitive,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      throw Exception('grep_code query cannot be empty');
    }
    final normalizedRoot = relativePath.trim().isEmpty ? '.' : relativePath;
    final targetPath = _resolveWithinProject(normalizedRoot);
    final rootDir = Directory(targetPath);
    if (!await rootDir.exists()) {
      throw Exception('目录不存�? $normalizedRoot');
    }
    final matches = <Map<String, dynamic>>[];
    final needle = caseSensitive
        ? normalizedQuery
        : normalizedQuery.toLowerCase();
    await for (final entity in rootDir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (matches.length >= limit) break;
      if (entity is! File) continue;
      final bytes = await entity.readAsBytes();
      if (_looksBinary(bytes)) continue;
      final content = utf8.decode(bytes, allowMalformed: true);
      final lines = const LineSplitter().convert(content);
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final haystack = caseSensitive ? line : line.toLowerCase();
        if (!haystack.contains(needle)) continue;
        matches.add(<String, dynamic>{
          'path': _relativeProjectAccessPath(entity.path),
          'line': i + 1,
          'content': line.trim(),
        });
        if (matches.length >= limit) break;
      }
    }
    return <String, dynamic>{
      'ok': true,
      'query': normalizedQuery,
      'path': normalizedRoot == '.' ? '' : _normalizeInputPath(normalizedRoot),
      'count': matches.length,
      'matches': matches,
    };
  }

  Future<void> _deleteEntry(String relativePath) async {
    final targetPath = _resolveWithinProject(relativePath);
    final file = File(targetPath);
    if (await file.exists()) {
      await file.delete();
      return;
    }
    final dir = Directory(targetPath);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      return;
    }
    throw Exception('目标不存在: $relativePath');
  }

  RegExp _globToRegExp(String pattern, {required bool caseSensitive}) {
    final normalized = pattern.trim().isEmpty ? '*' : pattern.trim();
    final buffer = StringBuffer('^');
    for (var i = 0; i < normalized.length; i++) {
      final char = normalized[i];
      if (char == '*') {
        final nextIsStar =
            i + 1 < normalized.length && normalized[i + 1] == '*';
        if (nextIsStar) {
          buffer.write('.*');
          i++;
        } else {
          buffer.write('[^/]*');
        }
        continue;
      }
      if (char == '?') {
        buffer.write('[^/]');
        continue;
      }
      if (r'\.[]{}()+-^$|'.contains(char)) {
        buffer.write('\\$char');
      } else {
        buffer.write(char);
      }
    }
    buffer.write(r'$');
    return RegExp(buffer.toString(), caseSensitive: caseSensitive);
  }

  bool _shouldIgnoreMirrorRelativePath(String relativePath) {
    final normalized = _normalizeInputPath(relativePath);
    if (normalized.isEmpty) return false;
    final segments = normalized.split('/');
    if (segments.isEmpty) return false;
    return _mirrorSyncIgnoredTopLevelDirs.contains(segments.first);
  }

  String _basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    final segments = normalized.split('/');
    return segments.isEmpty ? normalized : segments.last;
  }

  Future<Map<String, dynamic>> _findProjectFiles({
    required String pattern,
    required String relativePath,
    required int limit,
    required bool caseSensitive,
  }) async {
    final normalizedRoot = relativePath.trim().isEmpty ? '.' : relativePath;
    final targetPath = _resolveWithinProject(normalizedRoot);
    final rootDir = Directory(targetPath);
    if (!await rootDir.exists()) {
      throw Exception('Directory does not exist: $normalizedRoot');
    }
    final matcher = _globToRegExp(pattern, caseSensitive: caseSensitive);
    final matches = <Map<String, dynamic>>[];
    await for (final entity in rootDir.list(
      recursive: true,
      followLinks: false,
    )) {
      if (matches.length >= limit) break;
      final relative = _relativeProjectAccessPath(entity.path);
      final name = relative.split('/').last;
      if (!matcher.hasMatch(relative) && !matcher.hasMatch(name)) {
        continue;
      }
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      var sizeBytes = 0;
      if (type == FileSystemEntityType.file) {
        try {
          sizeBytes = (await File(entity.path).stat()).size;
        } catch (_) {}
      }
      matches.add(<String, dynamic>{
        'path': relative,
        'name': name,
        'type': type == FileSystemEntityType.directory ? 'directory' : 'file',
        if (sizeBytes > 0) 'size_bytes': sizeBytes,
      });
    }
    return <String, dynamic>{
      'ok': true,
      'action': 'find_files',
      'pattern': pattern,
      'path': normalizedRoot == '.' ? '' : _normalizeInputPath(normalizedRoot),
      'count': matches.length,
      'matches': matches,
    };
  }

  Future<Map<String, dynamic>> _readFileExists(String relativePath) async {
    final targetPath = _resolveWithinProject(relativePath);
    final file = File(targetPath);
    final dir = Directory(targetPath);
    final fileExists = await file.exists();
    final dirExists = await dir.exists();
    return <String, dynamic>{
      'ok': true,
      'action': 'file_exists',
      'path': _normalizeInputPath(relativePath),
      'exists': fileExists || dirExists,
      'type': fileExists ? 'file' : (dirExists ? 'directory' : 'missing'),
    };
  }

  Future<void> _copyEntityToResolvedPath(
    FileSystemEntity source,
    String targetPath,
  ) async {
    if (source is File) {
      final targetFile = File(targetPath);
      await targetFile.parent.create(recursive: true);
      await source.copy(targetFile.path);
      return;
    }
    if (source is Directory) {
      final targetDir = Directory(targetPath);
      await targetDir.create(recursive: true);
      await for (final entity in source.list(
        recursive: false,
        followLinks: false,
      )) {
        final childTarget =
            '$targetPath${Platform.pathSeparator}${_basename(entity.path)}';
        await _copyEntityToResolvedPath(entity, childTarget);
      }
      return;
    }
    throw Exception('Unsupported entity type: ${source.path}');
  }

  Future<Map<String, dynamic>> _copyProjectEntry(
    String fromPath,
    String toPath,
  ) async {
    final sourcePath = _resolveWithinProject(fromPath);
    final targetPath = _resolveWithinProject(toPath);
    if (sourcePath == targetPath) {
      throw Exception('copy_file source and destination must be different');
    }
    final sourceFile = File(sourcePath);
    if (await sourceFile.exists()) {
      await _copyEntityToResolvedPath(sourceFile, targetPath);
      return <String, dynamic>{
        'ok': true,
        'action': 'copy_file',
        'from_path': _normalizeInputPath(fromPath),
        'to_path': _normalizeInputPath(toPath),
        'type': 'file',
      };
    }
    final sourceDir = Directory(sourcePath);
    if (await sourceDir.exists()) {
      await _copyEntityToResolvedPath(sourceDir, targetPath);
      return <String, dynamic>{
        'ok': true,
        'action': 'copy_file',
        'from_path': _normalizeInputPath(fromPath),
        'to_path': _normalizeInputPath(toPath),
        'type': 'directory',
      };
    }
    throw Exception('Source path does not exist: $fromPath');
  }

  Future<Map<String, dynamic>> _moveProjectEntry(
    String fromPath,
    String toPath,
  ) async {
    final sourcePath = _resolveWithinProject(fromPath);
    final targetPath = _resolveWithinProject(toPath);
    if (sourcePath == targetPath) {
      throw Exception('move_file source and destination must be different');
    }
    final sourceFile = File(sourcePath);
    if (await sourceFile.exists()) {
      final targetFile = File(targetPath);
      await targetFile.parent.create(recursive: true);
      try {
        await sourceFile.rename(targetPath);
      } on FileSystemException {
        await sourceFile.copy(targetPath);
        await sourceFile.delete();
      }
      return <String, dynamic>{
        'ok': true,
        'action': 'move_file',
        'from_path': _normalizeInputPath(fromPath),
        'to_path': _normalizeInputPath(toPath),
        'type': 'file',
      };
    }
    final sourceDir = Directory(sourcePath);
    if (await sourceDir.exists()) {
      final targetDir = Directory(targetPath);
      await targetDir.parent.create(recursive: true);
      try {
        await sourceDir.rename(targetPath);
      } on FileSystemException {
        await _copyEntityToResolvedPath(sourceDir, targetPath);
        await sourceDir.delete(recursive: true);
      }
      return <String, dynamic>{
        'ok': true,
        'action': 'move_file',
        'from_path': _normalizeInputPath(fromPath),
        'to_path': _normalizeInputPath(toPath),
        'type': 'directory',
      };
    }
    throw Exception('Source path does not exist: $fromPath');
  }

  Future<Map<String, dynamic>> _applyStructuredPatch({
    required _AiRoundDraft roundDraft,
    required List<dynamic> operations,
  }) async {
    final results = <Map<String, dynamic>>[];
    for (final item in operations) {
      if (item is! Map) {
        throw Exception('apply_patch operations must be objects');
      }
      final op = item.map((key, value) => MapEntry(key.toString(), value));
      final type = _readArgString(op, 'type').trim();
      switch (type) {
        case 'write':
        case 'create_file':
          final path = _readArgString(op, 'path');
          final content = _readArgString(op, 'content', fallback: '');
          await _captureUndoSnapshotIfNeeded(roundDraft, path);
          await _writeFileText(path, content);
          results.add(<String, dynamic>{
            'type': type,
            'path': _normalizeInputPath(path),
            'bytes': utf8.encode(content).length,
          });
          break;
        case 'replace':
          final path = _readArgString(op, 'path');
          await _captureUndoSnapshotIfNeeded(roundDraft, path);
          results.add(
            await _replaceTextInFile(
              relativePath: path,
              oldText: _readArgString(op, 'old_text'),
              newText: _readArgString(op, 'new_text', fallback: ''),
              replaceAll: _readArgBool(op, 'replace_all', fallback: false),
            ),
          );
          break;
        case 'create_dir':
          final path = _readArgString(op, 'path');
          await _captureUndoSnapshotIfNeeded(roundDraft, path);
          await _createDirectory(path);
          results.add(<String, dynamic>{
            'type': type,
            'path': _normalizeInputPath(path),
          });
          break;
        case 'delete':
        case 'delete_entry':
          final path = _readArgString(op, 'path');
          await _captureUndoSnapshotIfNeeded(roundDraft, path);
          await _deleteEntry(path);
          results.add(<String, dynamic>{
            'type': type,
            'path': _normalizeInputPath(path),
          });
          break;
        case 'move':
          final fromPath = _readArgString(op, 'from_path');
          final toPath = _readArgString(op, 'to_path');
          await _captureUndoSnapshotIfNeeded(roundDraft, fromPath);
          await _captureUndoSnapshotIfNeeded(roundDraft, toPath);
          results.add(await _moveProjectEntry(fromPath, toPath));
          break;
        case 'copy':
          final fromPath = _readArgString(op, 'from_path');
          final toPath = _readArgString(op, 'to_path');
          await _captureUndoSnapshotIfNeeded(roundDraft, toPath);
          results.add(await _copyProjectEntry(fromPath, toPath));
          break;
        default:
          throw Exception('Unsupported apply_patch operation: $type');
      }
    }
    return <String, dynamic>{
      'ok': true,
      'action': 'apply_patch',
      'count': results.length,
      'results': results,
    };
  }

  String _quoteShellArg(String value) {
    if (value.isEmpty) return "''";
    return "'${value.replaceAll("'", "'\"'\"'")}'";
  }

  Future<Map<String, dynamic>> _runGitCommand(
    List<String> args, {
    int timeoutMs = 20000,
    int maxOutputBytes = 131072,
  }) async {
    final command = 'git ${args.map(_quoteShellArg).join(' ')}';
    final result = await _executePrimaryBackendCommand(
      command: command,
      timeoutMs: timeoutMs,
      maxOutputBytes: maxOutputBytes,
    );
    return <String, dynamic>{
      'ok': result['ok'] == true,
      'action': 'git',
      'command': command,
      ...result,
    };
  }

  Future<Map<String, dynamic>> _runGitStatusTool({
    int timeoutMs = 20000,
    int maxOutputBytes = 131072,
  }) {
    return _runGitCommand(
      const <String>['status', '--short', '--branch'],
      timeoutMs: timeoutMs,
      maxOutputBytes: maxOutputBytes,
    );
  }

  Future<Map<String, dynamic>> _runGitDiffTool({
    String path = '',
    bool staged = false,
    int timeoutMs = 20000,
    int maxOutputBytes = 131072,
  }) {
    final args = <String>['diff'];
    if (staged) {
      args.add('--staged');
    }
    final normalizedPath = _normalizeInputPath(path);
    if (normalizedPath.isNotEmpty) {
      args
        ..add('--')
        ..add(normalizedPath);
    }
    return _runGitCommand(
      args,
      timeoutMs: timeoutMs,
      maxOutputBytes: maxOutputBytes,
    );
  }

  Future<Map<String, dynamic>> _runGitLogTool({
    int limit = 20,
    int timeoutMs = 20000,
    int maxOutputBytes = 131072,
  }) {
    return _runGitCommand(
      <String>[
        'log',
        '--oneline',
        '--decorate',
        '-n',
        limit.clamp(1, 80).toString(),
      ],
      timeoutMs: timeoutMs,
      maxOutputBytes: maxOutputBytes,
    );
  }

  Future<Map<String, dynamic>> _runGitShowTool({
    required String ref,
    String path = '',
    int timeoutMs = 20000,
    int maxOutputBytes = 131072,
  }) {
    final args = <String>['show', ref];
    final normalizedPath = _normalizeInputPath(path);
    if (normalizedPath.isNotEmpty) {
      args
        ..add('--')
        ..add(normalizedPath);
    }
    return _runGitCommand(
      args,
      timeoutMs: timeoutMs,
      maxOutputBytes: maxOutputBytes,
    );
  }

  Future<Map<String, String>> _collectProjectFileMap(String rootPath) async {
    final files = <String, String>{};
    final root = Directory(rootPath);
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      final relative = _normalizeInputPath(
        _relativePath(entity.path, rootPath),
      );
      if (relative.isEmpty || _shouldIgnoreMirrorRelativePath(relative)) {
        continue;
      }
      if (entity is File) {
        files[relative] = entity.path;
      }
    }
    return files;
  }

  Future<Map<String, bool>> _collectProjectDirectoryMap(String rootPath) async {
    final directories = <String, bool>{};
    final root = Directory(rootPath);
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      final relative = _normalizeInputPath(
        _relativePath(entity.path, rootPath),
      );
      if (relative.isEmpty || _shouldIgnoreMirrorRelativePath(relative)) {
        continue;
      }
      if (entity is Directory) {
        directories[relative] = true;
      }
    }
    return directories;
  }

  Future<bool> _filesHaveSameContent(String leftPath, String rightPath) async {
    final leftFile = File(leftPath);
    final rightFile = File(rightPath);
    final leftStat = await leftFile.stat();
    final rightStat = await rightFile.stat();
    if (leftStat.size != rightStat.size) {
      return false;
    }
    final leftBytes = await leftFile.readAsBytes();
    final rightBytes = await rightFile.readAsBytes();
    return listEquals(leftBytes, rightBytes);
  }

  Future<List<_MirrorChangeEntry>> _computeMirrorChangeEntries({
    required String sourceRoot,
    required String mirrorRoot,
  }) async {
    final sourceFiles = await _collectProjectFileMap(sourceRoot);
    final mirrorFiles = await _collectProjectFileMap(mirrorRoot);
    final sourceDirs = await _collectProjectDirectoryMap(sourceRoot);
    final mirrorDirs = await _collectProjectDirectoryMap(mirrorRoot);
    final allPaths = <String>{
      ...sourceFiles.keys,
      ...mirrorFiles.keys,
      ...sourceDirs.keys,
      ...mirrorDirs.keys,
    }.toList()..sort();
    final entries = <_MirrorChangeEntry>[];
    for (final path in allPaths) {
      final sourceFile = sourceFiles[path];
      final mirrorFile = mirrorFiles[path];
      final sourceDir = sourceDirs[path] == true;
      final mirrorDir = mirrorDirs[path] == true;
      final sourceExists = sourceFile != null || sourceDir;
      final mirrorExists = mirrorFile != null || mirrorDir;
      if (sourceExists && !mirrorExists) {
        entries.add(
          _MirrorChangeEntry(
            path: path,
            changeType: 'deleted',
            entityType: sourceDir ? 'directory' : 'file',
          ),
        );
        continue;
      }
      if (!sourceExists && mirrorExists) {
        entries.add(
          _MirrorChangeEntry(
            path: path,
            changeType: 'added',
            entityType: mirrorDir ? 'directory' : 'file',
          ),
        );
        continue;
      }
      if (sourceDir != mirrorDir) {
        entries.add(
          _MirrorChangeEntry(
            path: path,
            changeType: 'type_changed',
            entityType: mirrorDir ? 'directory' : 'file',
          ),
        );
        continue;
      }
      if (sourceFile != null &&
          mirrorFile != null &&
          !await _filesHaveSameContent(sourceFile, mirrorFile)) {
        entries.add(
          _MirrorChangeEntry(
            path: path,
            changeType: 'modified',
            entityType: 'file',
          ),
        );
      }
    }
    return entries;
  }

  String _buildMirrorPreviewSummary(List<_MirrorChangeEntry> entries) {
    if (entries.isEmpty) {
      return '镜像工作区和源目录当前一致。';
    }
    var added = 0;
    var modified = 0;
    var deleted = 0;
    var typeChanged = 0;
    for (final entry in entries) {
      switch (entry.changeType) {
        case 'added':
          added++;
          break;
        case 'modified':
          modified++;
          break;
        case 'deleted':
          deleted++;
          break;
        case 'type_changed':
          typeChanged++;
          break;
      }
    }
    return '检测到 ${entries.length} 项变更：新增 $added，修改 $modified，删除 $deleted，类型变化 $typeChanged。';
  }

  Future<void> _previewMirrorWorkspaceChanges() async {
    if (_loadingMirrorPreview) return;
    final sourceRoot = _projectRootPath?.trim();
    if (sourceRoot == null || sourceRoot.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先选择项目目录')));
      return;
    }
    if (!_hasActiveMirrorWorkspace) {
      await _ensureMirroredWorkspaceIfAvailable();
    }
    final mirrorRoot = _localRuntimeStatus.activeWorkspacePath.trim();
    if (mirrorRoot.isEmpty) {
      throw Exception('Mirror workspace is not ready.');
    }
    setState(() {
      _loadingMirrorPreview = true;
      _runtimeWorkbenchOutput = '正在比较镜像工作区与源目录...';
    });
    try {
      final entries = await _computeMirrorChangeEntries(
        sourceRoot: sourceRoot,
        mirrorRoot: mirrorRoot,
      );
      if (!mounted) return;
      setState(() {
        _mirrorPreviewEntries
          ..clear()
          ..addAll(entries);
        _mirrorPreviewSummary = _buildMirrorPreviewSummary(entries);
        _runtimeWorkbenchOutput = _mirrorPreviewSummary;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingMirrorPreview = false;
        });
      }
    }
  }

  Future<void> _syncMirrorWorkspaceBackToSource() async {
    if (_syncingMirrorToSource) return;
    final sourceRoot = _projectRootPath?.trim();
    final mirrorRoot = _localRuntimeStatus.activeWorkspacePath.trim();
    if (sourceRoot == null || sourceRoot.isEmpty) {
      throw Exception('Project root is not selected.');
    }
    if (mirrorRoot.isEmpty) {
      throw Exception('Mirror workspace is not ready.');
    }
    setState(() {
      _syncingMirrorToSource = true;
      _runtimeWorkbenchOutput = '正在把镜像工作区同步回源目录...';
    });
    try {
      final entries = await _computeMirrorChangeEntries(
        sourceRoot: sourceRoot,
        mirrorRoot: mirrorRoot,
      );
      for (final entry in entries) {
        final sourcePath =
            '$sourceRoot${Platform.pathSeparator}${entry.path.replaceAll('/', Platform.pathSeparator)}';
        final mirrorPath =
            '$mirrorRoot${Platform.pathSeparator}${entry.path.replaceAll('/', Platform.pathSeparator)}';
        if (entry.changeType == 'deleted') {
          final sourceFile = File(sourcePath);
          if (await sourceFile.exists()) {
            await sourceFile.delete();
          } else {
            final sourceDir = Directory(sourcePath);
            if (await sourceDir.exists()) {
              await sourceDir.delete(recursive: true);
            }
          }
          continue;
        }
        final sourceFile = File(sourcePath);
        if (await sourceFile.exists()) {
          await sourceFile.delete();
        }
        final sourceDir = Directory(sourcePath);
        if (await sourceDir.exists()) {
          await sourceDir.delete(recursive: true);
        }
        if (entry.entityType == 'directory') {
          await Directory(sourcePath).create(recursive: true);
        } else {
          await _copyEntityToResolvedPath(File(mirrorPath), sourcePath);
        }
      }
      await _loadProjectFolder(sourceRoot, silent: true);
      await _previewMirrorWorkspaceChanges();
      if (!mounted) return;
      setState(() {
        _runtimeWorkbenchOutput = '同步完成，共处理 ${entries.length} 项镜像差异。';
      });
    } finally {
      if (mounted) {
        setState(() {
          _syncingMirrorToSource = false;
        });
      }
    }
  }

  Future<void> _runRuntimeWorkbenchCommand({
    required String title,
    required Future<Map<String, dynamic>> Function() action,
  }) async {
    if (_runningRuntimeWorkbenchCommand) return;
    setState(() {
      _runningRuntimeWorkbenchCommand = true;
      _runtimeWorkbenchOutput = '$title...';
    });
    try {
      final result = await action();
      final stdout = result['stdout']?.toString().trim() ?? '';
      final stderr = result['stderr']?.toString().trim() ?? '';
      final error = result['error']?.toString().trim() ?? '';
      final parts = <String>[
        title,
        if (result['command'] != null) '命令: ${result['command']}',
        if (stdout.isNotEmpty) 'stdout:\n$stdout',
        if (stderr.isNotEmpty) 'stderr:\n$stderr',
        if (error.isNotEmpty) 'error:\n$error',
      ];
      if (mounted) {
        setState(() {
          _runtimeWorkbenchOutput = parts.join('\n\n');
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _runtimeWorkbenchOutput = '$title 失败\n\n$error';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _runningRuntimeWorkbenchCommand = false;
        });
      }
    }
  }

  Future<bool> _maybeHandleFsToolCommand(
    String raw, {
    _AiRoundDraft? roundDraft,
    required String conversationId,
  }) async {
    final text = raw.trim();
    if (!text.startsWith('@fs ')) return false;
    if (!_aiFsGranted) {
      _appendMessage(
        ChatMessage(
          role: ChatRole.system,
          text: '当前未授予 AI 文件读写权限，请在“设置 > 项目文件”中开启。',
          time: _timeNow(),
        ),
        conversationId: conversationId,
      );
      return true;
    }

    final body = text.substring(4).trim();
    try {
      if (body.startsWith('read ')) {
        final path = body.substring(5).trim();
        final content = await _readFileText(path);
        _appendMessage(
          ChatMessage(
            role: ChatRole.system,
            text: '读取成功: $path\n$content',
            time: _timeNow(),
          ),
          conversationId: conversationId,
        );
        return true;
      }

      if (body.startsWith('write ')) {
        final payload = body.substring(6);
        final split = payload.split(':::');
        if (split.length < 2) {
          throw Exception('write 命令格式: @fs write 路径 ::: 内容');
        }
        final path = split.first.trim();
        final content = split.sublist(1).join(':::').trim();
        if (roundDraft != null) {
          await _captureUndoSnapshotIfNeeded(roundDraft, path);
        }
        await _writeFileText(path, content);
        await _loadProjectFolder(_projectRootPath!, silent: true);
        _appendMessage(
          ChatMessage(
            role: ChatRole.system,
            text: '写入成功: $path',
            time: _timeNow(),
          ),
          conversationId: conversationId,
        );
        return true;
      }

      if (body.startsWith('create-file ')) {
        final payload = body.substring(12);
        final split = payload.split(':::');
        final path = split.first.trim();
        final content = split.length > 1
            ? split.sublist(1).join(':::').trim()
            : '';
        if (roundDraft != null) {
          await _captureUndoSnapshotIfNeeded(roundDraft, path);
        }
        await _writeFileText(path, content);
        await _loadProjectFolder(_projectRootPath!, silent: true);
        _appendMessage(
          ChatMessage(
            role: ChatRole.system,
            text: '新建文件成功: $path',
            time: _timeNow(),
          ),
          conversationId: conversationId,
        );
        return true;
      }

      if (body.startsWith('create-dir ')) {
        final path = body.substring(11).trim();
        if (roundDraft != null) {
          await _captureUndoSnapshotIfNeeded(roundDraft, path);
        }
        await _createDirectory(path);
        await _loadProjectFolder(_projectRootPath!, silent: true);
        _appendMessage(
          ChatMessage(
            role: ChatRole.system,
            text: '新建目录成功: $path',
            time: _timeNow(),
          ),
          conversationId: conversationId,
        );
        return true;
      }

      if (body.startsWith('delete ')) {
        final path = body.substring(7).trim();
        if (roundDraft != null) {
          await _captureUndoSnapshotIfNeeded(roundDraft, path);
        }
        await _deleteEntry(path);
        await _loadProjectFolder(_projectRootPath!, silent: true);
        _appendMessage(
          ChatMessage(
            role: ChatRole.system,
            text: '删除成功: $path',
            time: _timeNow(),
          ),
          conversationId: conversationId,
        );
        return true;
      }

      if (body.startsWith('download ')) {
        final payload = body.substring(9);
        final split = payload.split(':::');
        if (split.length < 2) {
          throw Exception('download 命令格式: @fs download URL ::: 相对路径');
        }
        final url = split.first.trim();
        final path = split.sublist(1).join(':::').trim();
        if (roundDraft != null) {
          await _captureUndoSnapshotIfNeeded(roundDraft, path);
        }
        final downloaded = await _downloadUrlToProject(
          url: url,
          relativePath: path,
          overwrite: true,
          maxBytes: _downloadAssetMaxBytes,
        );
        await _loadProjectFolder(_projectRootPath!, silent: true);
        _appendMessage(
          ChatMessage(
            role: ChatRole.system,
            text: '下载成功: $path (${downloaded['bytes']} bytes)',
            time: _timeNow(),
          ),
          conversationId: conversationId,
        );
        return true;
      }

      throw Exception(
        '支持命令: read / write / create-file / create-dir / delete / download',
      );
    } catch (error) {
      _appendMessage(
        ChatMessage(
          role: ChatRole.system,
          text: '文件操作失败: $error',
          time: _timeNow(),
        ),
        conversationId: conversationId,
      );
      return true;
    }
  }

  // ignore: unused_element
  Future<void> _replyWithModel({
    required _AiRoundDraft roundDraft,
    required String conversationId,
    List<_OutgoingImageAttachment> attachedImages = const [],
  }) async {
    _resetAgentExecutionConsole();
    _recordAgentProgress('准备请求模型', detail: '正在检查连接配置、项目上下文和可用工具。');
    _updateReplyProgress('校验连接配置');
    final config = _activeProviderConfig;
    final baseUrl = config.baseUrl.trim();
    final apiPath = config.apiPath.trim();
    final apiKey = config.apiKey.trim();
    final model = config.model.trim();
    final extraHeaders = config.extraHeaders;

    if (baseUrl.isEmpty) {
      throw Exception('请先在设置中填写 Base URL');
    }
    if (model.isEmpty) {
      throw Exception('请先在设置中填写模型名');
    }
    if (apiKey.isEmpty &&
        !_providersMaySkipApiKey.contains(_activeProviderId)) {
      throw Exception('请先在设置中填写 API Key');
    }
    if (!_chatCapableProviders.contains(_activeProviderId)) {
      throw Exception(
        '当前提供方尚未接入聊天协议。请先切换到 OpenAI/DeepSeek/硅基流动/OpenRouter/LM Studio/Groq/Mistral/Azure OpenAI/自定义(OpenAI兼容)。',
      );
    }

    final uri = _buildChatCompletionEndpoint(
      providerId: _activeProviderId,
      baseUrl: baseUrl,
      apiPath: apiPath,
    );
    final headers = _buildChatHeaders(
      providerId: _activeProviderId,
      apiKey: apiKey,
      extraHeaders: extraHeaders,
    );
    final tools = _buildActiveTools();
    final reasoningEffort = _normalizeReasoningEffort(config.reasoningEffort);
    final temperature = _temperatureForReasoningEffort(reasoningEffort);
    final conversation = _buildConversationMessages(
      reasoningEffort: reasoningEffort,
      attachedImages: attachedImages,
    );
    final toolResultCache = <String, String>{};
    final repeatedToolCalls = <String, int>{};
    var webSearchCount = 0;
    var fetchWebpageCount = 0;
    var downloadAssetCount = 0;
    var emittedToolPlanMessage = false;
    final collectedToolOutputs = <String, String>{};
    const maxToolRounds = 12;

    for (var round = 0; round < maxToolRounds; round++) {
      _recordAgentProgress(
        '模型思考中',
        detail: '第 ${round + 1} / $maxToolRounds 轮推理。',
      );
      _updateReplyProgress('模型推理中（第${round + 1}轮）');
      if (_stopReplyRequested) {
        throw const _ModelRequestCancelledException();
      }
      final payload = <String, dynamic>{
        'model': model,
        'messages': conversation,
        'temperature': temperature,
      };
      if (tools.isNotEmpty) {
        payload['tools'] = tools;
        payload['tool_choice'] = 'auto';
      }

      int? liveMessageIndex;
      final liveMessageTime = _timeNow();
      void handleReplyStream(_ChatCompletionStreamSnapshot snapshot) {
        if (!snapshot.hasVisibleOutput) return;
        liveMessageIndex ??= _appendLiveAssistantPlaceholder(
          conversationId: conversationId,
          time: liveMessageTime,
        );
        _updateLiveAssistantMessage(
          conversationId: conversationId,
          messageIndex: liveMessageIndex,
          message: _buildStructuredAssistantMessage(
            text: snapshot.content,
            time: liveMessageTime,
            reasoningSummary: snapshot.reasoningSummary,
            toolCalls: snapshot.toolCalls,
            toolCallStatus: 'streaming',
            metadata: snapshot.metadata,
          ),
        );
      }

      final result = await _requestChatCompletion(
        uri: uri,
        headers: headers,
        payload: payload,
        improveNetworkCompatibility: config.improveNetworkCompatibility,
        onStreamSnapshot: handleReplyStream,
      );

      conversation.add(<String, dynamic>{
        'role': 'assistant',
        'content': result.content,
        if (result.toolCalls.isNotEmpty)
          'tool_calls': result.toolCalls.map((call) => call.toMap()).toList(),
      });

      if (result.toolCalls.isEmpty) {
        _recordAgentProgress('整理最终回复', detail: '工具调用已结束，正在组织最终回答。');
        _updateReplyProgress('整理回复内容');
        final replyText = result.content.trim();
        if (replyText.isEmpty) {
          throw Exception('模型返回了空内容，请重试或切换模型。');
        }
        final finalMessage = _buildStructuredAssistantMessage(
          text: replyText,
          time: liveMessageIndex == null ? _timeNow() : liveMessageTime,
          reasoningSummary: _buildReasoningSummary(
            content: result.content,
            toolCalls: result.toolCalls,
            rawReasoning: result.reasoningSummary,
          ),
          toolOutputsById: collectedToolOutputs,
          citations: _collectCitationPartsFromToolResults(
            collectedToolOutputs.values,
          ),
          metadata: result.metadata,
          progressEntries: _snapshotAgentProgressEntries(),
          toolActivityEntries: _snapshotToolActivityEntries(),
        );
        if (liveMessageIndex == null) {
          _appendMessage(finalMessage, conversationId: conversationId);
        } else {
          _updateLiveAssistantMessage(
            conversationId: conversationId,
            messageIndex: liveMessageIndex,
            message: finalMessage,
            persist: true,
          );
        }
        _updateReplyProgress('回复完成');
        return;
      }

      if (!emittedToolPlanMessage) {
        final planText = _buildAssistantPlanMessage(
          content: result.content,
          toolCalls: result.toolCalls,
        );
        emittedToolPlanMessage = true;
        _agentPlanSummary = _singleLinePreview(planText, maxLength: 120);
        if (_isReplySectionEnabled(_replySectionAgentProgress)) {
          _appendMessage(
            ChatMessage(
              role: ChatRole.assistant,
              text: planText,
              time: _timeNow(),
            ),
            conversationId: conversationId,
          );
        }
        _recordAgentProgress('已给出执行方案', detail: _agentPlanSummary);
      }

      for (final call in result.toolCalls) {
        _recordAgentProgress(
          _toolProgressTitle(call),
          detail: _toolArgsPreview(call.argumentsJson),
        );
        _updateReplyProgress('执行工具 ${call.name}');
        if (_stopReplyRequested) {
          throw const _ModelRequestCancelledException();
        }
        _recordAgentToolStart(call);
        final toolLiveTime = _timeNow();
        final toolLiveMessageIndex = _appendLiveAssistantPlaceholder(
          conversationId: conversationId,
          time: toolLiveTime,
        );
        _updateLiveAssistantMessage(
          conversationId: conversationId,
          messageIndex: toolLiveMessageIndex,
          message: _buildToolRunMessage(call: call, time: toolLiveTime),
        );
        _appendMessage(
          ChatMessage(
            role: ChatRole.system,
            text:
                'AI 调用工具: ${call.name} ${_toolArgsPreview(call.argumentsJson)}',
            time: _timeNow(),
          ),
          conversationId: conversationId,
        );

        var toolResult = '';
        var toolStatus = 'done';
        final signature = _toolCallSignature(call);
        final repeatedCount = (repeatedToolCalls[signature] ?? 0) + 1;
        repeatedToolCalls[signature] = repeatedCount;
        if (call.name == 'web_search') {
          webSearchCount++;
        } else if (call.name == 'fetch_webpage') {
          fetchWebpageCount++;
        } else if (call.name == 'download_asset') {
          downloadAssetCount++;
        }

        if (toolResultCache.containsKey(signature)) {
          if ((call.name == 'web_search' || call.name == 'fetch_webpage') &&
              repeatedCount >= 3) {
            toolResult = _buildToolLoopGuardResult(
              call: call,
              repeatedCount: repeatedCount,
              reason: '检测到重复调用同一工具参数，已阻止继续重复联网请求。',
              webSearchCount: webSearchCount,
              fetchWebpageCount: fetchWebpageCount,
              downloadAssetCount: downloadAssetCount,
            );
            toolStatus = 'failed';
          } else {
            toolResult = toolResultCache[signature]!;
            toolStatus = 'cached';
          }
        } else if (call.name == 'web_search' &&
            webSearchCount > 3 &&
            fetchWebpageCount == 0 &&
            downloadAssetCount == 0) {
          toolResult = _buildToolLoopGuardResult(
            call: call,
            repeatedCount: repeatedCount,
            reason: '搜索次数已超过上限(3次)。请改为 fetch_webpage 读取候选链接，随后下载资源。',
            webSearchCount: webSearchCount,
            fetchWebpageCount: fetchWebpageCount,
            downloadAssetCount: downloadAssetCount,
          );
          toolStatus = 'failed';
        } else {
          try {
            toolResult = await _executeFsTool(call, roundDraft: roundDraft);
          } catch (error) {
            toolResult = jsonEncode({'ok': false, 'error': error.toString()});
          }
          toolStatus = _toolFinishStatus(toolResult, cached: false);
          if (_shouldCacheToolResult(call.name)) {
            toolResultCache[signature] = toolResult;
          }
        }

        conversation.add(<String, dynamic>{
          'role': 'tool',
          'tool_call_id': call.id,
          'content': toolResult,
        });
        collectedToolOutputs[call.id] = toolResult;
        _recordAgentToolFinish(call, toolResult, status: toolStatus);
        _updateLiveAssistantMessage(
          conversationId: conversationId,
          messageIndex: toolLiveMessageIndex,
          message: _buildToolRunMessage(
            call: call,
            time: toolLiveTime,
            toolResult: toolResult,
            status: toolStatus,
          ),
          persist: true,
        );

        _appendMessage(
          ChatMessage(
            role: ChatRole.system,
            text: '工具结果(${call.name}): ${_summarizeForLog(toolResult)}',
            time: _timeNow(),
          ),
          conversationId: conversationId,
        );
      }
    }

    throw Exception('工具调用轮次超过上限(12次)。请先指定更明确的下载链接或目标文件。');
  }

  Future<void> _replyWithModelOrchestrated({
    required _AiRoundDraft roundDraft,
    required String conversationId,
    List<_OutgoingImageAttachment> attachedImages = const [],
  }) async {
    _resetAgentExecutionConsole();
    _recordAgentProgress('准备请求模型', detail: '正在检查连接配置、项目上下文和可用工具。');
    _updateReplyProgress('校验连接配置');
    final config = _activeProviderConfig;
    final baseUrl = config.baseUrl.trim();
    final apiPath = config.apiPath.trim();
    final apiKey = config.apiKey.trim();
    final model = config.model.trim();
    final extraHeaders = config.extraHeaders;

    if (baseUrl.isEmpty) {
      throw Exception('请先在设置中填写 Base URL');
    }
    if (model.isEmpty) {
      throw Exception('请先在设置中填写模型名');
    }
    if (apiKey.isEmpty &&
        !_providersMaySkipApiKey.contains(_activeProviderId)) {
      throw Exception('请先在设置中填写 API Key');
    }
    if (!_chatCapableProviders.contains(_activeProviderId)) {
      throw Exception(
        '当前提供方尚未接入聊天协议。请先切换到 OpenAI / DeepSeek / OpenRouter / LM Studio / Groq / Mistral / Azure OpenAI / 自定义 OpenAI 兼容接口。',
      );
    }

    final uri = _buildChatCompletionEndpoint(
      providerId: _activeProviderId,
      baseUrl: baseUrl,
      apiPath: apiPath,
    );
    final headers = _buildChatHeaders(
      providerId: _activeProviderId,
      apiKey: apiKey,
      extraHeaders: extraHeaders,
    );
    final tools = _buildActiveTools();
    final reasoningEffort = _normalizeReasoningEffort(config.reasoningEffort);
    final temperature = _temperatureForReasoningEffort(reasoningEffort);
    final conversation = _buildConversationMessages(
      reasoningEffort: reasoningEffort,
      attachedImages: attachedImages,
    );
    final toolResultCache = <String, String>{};
    final repeatedToolCalls = <String, int>{};
    final toolFamilyCounts = <String, int>{};
    var webSearchCount = 0;
    var fetchWebpageCount = 0;
    var downloadAssetCount = 0;
    var readFileCount = 0;
    var grepCodeCount = 0;
    var runCommandCount = 0;
    var blockedExplorationCount = 0;
    var emittedToolPlanMessage = false;
    final collectedToolOutputs = <String, String>{};
    const maxToolRounds = 12;
    const softToolRoundLimit = 8;

    String buildConvergenceSummary({
      required int roundNumber,
      required bool summaryMode,
    }) {
      final parts = <String>[
        '第 $roundNumber / $maxToolRounds 轮',
        summaryMode ? '已切换总结模式' : '正常执行',
      ];
      if (readFileCount > 0) {
        parts.add('读文件 $readFileCount');
      }
      if (grepCodeCount > 0) {
        parts.add('代码检索 $grepCodeCount');
      }
      if (runCommandCount > 0) {
        parts.add('命令执行 $runCommandCount');
      }
      if (blockedExplorationCount > 0) {
        parts.add('已阻止扩散探索 $blockedExplorationCount');
      }
      final hotFamilies =
          toolFamilyCounts.entries.where((entry) => entry.value > 0).toList()
            ..sort((a, b) => b.value.compareTo(a.value));
      if (hotFamilies.isNotEmpty) {
        parts.add(
          hotFamilies
              .take(2)
              .map((entry) => '${entry.key} ${entry.value}')
              .join(' / '),
        );
      }
      return parts.join(' · ');
    }

    _updateAgentExecutionState(
      phase: tools.isEmpty ? '回复' : '规划',
      currentRound: 0,
      maxRounds: maxToolRounds,
      summaryMode: false,
      convergenceSummary: tools.isEmpty
          ? '当前无工具可用，将直接生成回复。'
          : '先输出执行方案，再进入工具执行。',
      convergenceWarning: '',
      toolFamilyCounts: toolFamilyCounts,
    );

    if (tools.isNotEmpty) {
      _recordAgentProgress('生成执行方案', detail: '先给出方案，再开始工具执行。');
      _updateReplyProgress('生成执行方案');
      final planningPayload = <String, dynamic>{
        'model': model,
        'messages': <Map<String, dynamic>>[
          ...conversation,
          <String, dynamic>{
            'role': 'system',
            'content': _buildPlanningInstruction(),
          },
        ],
        'temperature': temperature,
      };
      int? planningLiveMessageIndex;
      final planningLiveTime = _timeNow();
      void handlePlanningStream(_ChatCompletionStreamSnapshot snapshot) {
        if (!snapshot.hasVisibleOutput) return;
        planningLiveMessageIndex ??= _appendLiveAssistantPlaceholder(
          conversationId: conversationId,
          time: planningLiveTime,
        );
        _updateLiveAssistantMessage(
          conversationId: conversationId,
          messageIndex: planningLiveMessageIndex,
          message: _buildStructuredAssistantMessage(
            text: snapshot.content,
            time: planningLiveTime,
            reasoningSummary: snapshot.reasoningSummary,
            toolCalls: snapshot.toolCalls,
            toolCallStatus: 'streaming',
            metadata: snapshot.metadata,
          ),
        );
      }

      final planningResult = await _requestChatCompletion(
        uri: uri,
        headers: headers,
        payload: planningPayload,
        improveNetworkCompatibility: config.improveNetworkCompatibility,
        onStreamSnapshot: handlePlanningStream,
      );
      final planText = planningResult.content.trim().isEmpty
          ? '我会先定位相关目录和关键文件，再做必要修改与验证，最后给你一个明确结论。'
          : planningResult.content.trim();
      conversation.add(<String, dynamic>{
        'role': 'assistant',
        'content': planText,
      });
      conversation.add(<String, dynamic>{
        'role': 'system',
        'content': _buildExecutionInstruction(),
      });
      emittedToolPlanMessage = true;
      _updateAgentExecutionState(
        phase: '执行',
        convergenceSummary: '执行前方案已生成，准备进入工具回合。',
      );
      if (mounted) {
        setState(() {
          _agentPlanSummary = _singleLinePreview(planText, maxLength: 120);
        });
      } else {
        _agentPlanSummary = _singleLinePreview(planText, maxLength: 120);
      }
      if (_isReplySectionEnabled(_replySectionAgentProgress)) {
        final planMessage = _buildStructuredAssistantMessage(
          text: planText,
          time: planningLiveMessageIndex == null
              ? _timeNow()
              : planningLiveTime,
          reasoningSummary: planningResult.reasoningSummary,
          metadata: planningResult.metadata,
        );
        if (planningLiveMessageIndex == null) {
          _appendMessage(planMessage, conversationId: conversationId);
        } else {
          _updateLiveAssistantMessage(
            conversationId: conversationId,
            messageIndex: planningLiveMessageIndex,
            message: planMessage,
            persist: true,
          );
        }
      }
      _recordAgentProgress('已给出执行方案', detail: _agentPlanSummary);
    }

    for (var round = 0; round < maxToolRounds; round++) {
      final roundNumber = round + 1;
      final summaryMode =
          roundNumber > softToolRoundLimit || blockedExplorationCount >= 2;
      final forceFinalAnswer = roundNumber >= maxToolRounds - 1;
      final convergenceSummary = buildConvergenceSummary(
        roundNumber: roundNumber,
        summaryMode: summaryMode,
      );
      _updateAgentExecutionState(
        phase: forceFinalAnswer
            ? '最终总结'
            : summaryMode
            ? '总结收敛'
            : '执行',
        currentRound: roundNumber,
        maxRounds: maxToolRounds,
        summaryMode: summaryMode,
        convergenceSummary: convergenceSummary,
        toolFamilyCounts: toolFamilyCounts,
      );
      _recordAgentProgress(
        forceFinalAnswer
            ? '模型正在输出最终结论'
            : summaryMode
            ? '模型进入总结模式'
            : '模型思考中',
        detail: convergenceSummary,
      );
      _updateReplyProgress(
        forceFinalAnswer
            ? '整理最终结论'
            : summaryMode
            ? '总结现有结果'
            : '模型推理中（第 $roundNumber 轮）',
      );
      if (_stopReplyRequested) {
        throw const _ModelRequestCancelledException();
      }

      final requestMessages = <Map<String, dynamic>>[...conversation];
      if (forceFinalAnswer) {
        requestMessages.add(<String, dynamic>{
          'role': 'system',
          'content': _buildForcedFinalInstruction(
            currentRound: roundNumber,
            maxRounds: maxToolRounds,
            convergenceReason: _agentConvergenceWarning.isNotEmpty
                ? _agentConvergenceWarning
                : convergenceSummary,
          ),
        });
      } else if (summaryMode) {
        requestMessages.add(<String, dynamic>{
          'role': 'system',
          'content': _buildSummaryModeInstruction(
            currentRound: roundNumber,
            maxRounds: maxToolRounds,
            convergenceReason: _agentConvergenceWarning.isNotEmpty
                ? _agentConvergenceWarning
                : convergenceSummary,
          ),
        });
      }

      final payload = <String, dynamic>{
        'model': model,
        'messages': requestMessages,
        'temperature': temperature,
      };
      if (tools.isNotEmpty && !forceFinalAnswer) {
        payload['tools'] = tools;
        payload['tool_choice'] = 'auto';
      }

      int? liveMessageIndex;
      final liveMessageTime = _timeNow();
      void handleReplyStream(_ChatCompletionStreamSnapshot snapshot) {
        if (!snapshot.hasVisibleOutput) return;
        liveMessageIndex ??= _appendLiveAssistantPlaceholder(
          conversationId: conversationId,
          time: liveMessageTime,
        );
        _updateLiveAssistantMessage(
          conversationId: conversationId,
          messageIndex: liveMessageIndex,
          message: _buildStructuredAssistantMessage(
            text: snapshot.content,
            time: liveMessageTime,
            reasoningSummary: snapshot.reasoningSummary,
            toolCalls: snapshot.toolCalls,
            toolCallStatus: 'streaming',
            metadata: snapshot.metadata,
          ),
        );
      }

      final result = await _requestChatCompletion(
        uri: uri,
        headers: headers,
        payload: payload,
        improveNetworkCompatibility: config.improveNetworkCompatibility,
        onStreamSnapshot: handleReplyStream,
      );

      conversation.add(<String, dynamic>{
        'role': 'assistant',
        'content': result.content,
        if (result.toolCalls.isNotEmpty)
          'tool_calls': result.toolCalls.map((call) => call.toMap()).toList(),
      });

      if (result.toolCalls.isEmpty) {
        _recordAgentProgress('整理最终回复', detail: '工具调用已结束，正在组织最终回答。');
        _updateAgentExecutionState(
          phase: '完成',
          convergenceSummary: '工具执行已结束，模型正在输出最终答复。',
        );
        _updateReplyProgress('整理回复内容');
        final replyText = result.content.trim();
        if (replyText.isEmpty) {
          throw Exception('模型返回了空内容，请重试或切换模型。');
        }
        final finalMessage = _buildStructuredAssistantMessage(
          text: replyText,
          time: liveMessageIndex == null ? _timeNow() : liveMessageTime,
          reasoningSummary: _buildReasoningSummary(
            content: result.content,
            toolCalls: result.toolCalls,
            rawReasoning: result.reasoningSummary,
          ),
          toolOutputsById: collectedToolOutputs,
          citations: _collectCitationPartsFromToolResults(
            collectedToolOutputs.values,
          ),
          metadata: result.metadata,
          progressEntries: _snapshotAgentProgressEntries(),
          toolActivityEntries: _snapshotToolActivityEntries(),
        );
        if (liveMessageIndex == null) {
          _appendMessage(finalMessage, conversationId: conversationId);
        } else {
          _updateLiveAssistantMessage(
            conversationId: conversationId,
            messageIndex: liveMessageIndex,
            message: finalMessage,
            persist: true,
          );
        }
        _updateReplyProgress('回复完成');
        return;
      }

      if (!emittedToolPlanMessage) {
        final planText = _buildAssistantPlanMessage(
          content: result.content,
          toolCalls: result.toolCalls,
        );
        emittedToolPlanMessage = true;
        if (mounted) {
          setState(() {
            _agentPlanSummary = _singleLinePreview(planText, maxLength: 120);
          });
        } else {
          _agentPlanSummary = _singleLinePreview(planText, maxLength: 120);
        }
        if (_isReplySectionEnabled(_replySectionAgentProgress)) {
          final planMessage = _buildStructuredAssistantMessage(
            text: planText,
            time: liveMessageIndex == null ? _timeNow() : liveMessageTime,
            reasoningSummary: result.reasoningSummary,
            toolCalls: result.toolCalls,
            metadata: result.metadata,
          );
          if (liveMessageIndex == null) {
            _appendMessage(planMessage, conversationId: conversationId);
          } else {
            _updateLiveAssistantMessage(
              conversationId: conversationId,
              messageIndex: liveMessageIndex,
              message: planMessage,
              persist: true,
            );
          }
        }
        _recordAgentProgress('已给出执行方案', detail: _agentPlanSummary);
      }

      for (final call in result.toolCalls) {
        final family = _toolFamily(call.name);
        final familyCount = (toolFamilyCounts[family] ?? 0) + 1;
        toolFamilyCounts[family] = familyCount;
        if (call.name == 'read_file' || call.name == 'read_file_part') {
          readFileCount++;
        } else if (call.name == 'grep_code') {
          grepCodeCount++;
        } else if (call.name == 'run_command') {
          runCommandCount++;
        }
        _updateAgentExecutionState(
          toolFamilyCounts: toolFamilyCounts,
          convergenceSummary: buildConvergenceSummary(
            roundNumber: roundNumber,
            summaryMode: summaryMode,
          ),
        );
        _recordAgentProgress(
          _toolProgressTitle(call),
          detail: _toolArgsPreview(call.argumentsJson),
        );
        _updateReplyProgress('执行工具 ${call.name}');
        if (_stopReplyRequested) {
          throw const _ModelRequestCancelledException();
        }
        _recordAgentToolStart(call);
        final toolLiveTime = _timeNow();
        final toolLiveMessageIndex = _appendLiveAssistantPlaceholder(
          conversationId: conversationId,
          time: toolLiveTime,
        );
        _updateLiveAssistantMessage(
          conversationId: conversationId,
          messageIndex: toolLiveMessageIndex,
          message: _buildToolRunMessage(call: call, time: toolLiveTime),
        );
        _appendMessage(
          ChatMessage(
            role: ChatRole.system,
            text:
                'AI 调用工具: ${call.name} ${_toolArgsPreview(call.argumentsJson)}',
            time: _timeNow(),
          ),
          conversationId: conversationId,
        );

        var toolResult = '';
        var toolStatus = 'done';
        final signature = _toolCallSignature(call);
        final repeatedCount = (repeatedToolCalls[signature] ?? 0) + 1;
        repeatedToolCalls[signature] = repeatedCount;
        if (call.name == 'web_search') {
          webSearchCount++;
        } else if (call.name == 'fetch_webpage') {
          fetchWebpageCount++;
        } else if (call.name == 'download_asset') {
          downloadAssetCount++;
        }

        String? convergenceBlockReason;
        if (toolResultCache.containsKey(signature)) {
          if (_isExplorationTool(call.name) && repeatedCount >= 3) {
            convergenceBlockReason = '检测到重复调用同一组工具参数，继续$family很可能不会收敛。';
          } else {
            toolResult = toolResultCache[signature]!;
            toolStatus = 'cached';
          }
        } else if (_isExplorationTool(call.name) &&
            familyCount > _toolFamilyRoundLimit(call.name)) {
          convergenceBlockReason =
              '$family 已达到本轮上限（${_toolFamilyRoundLimit(call.name)} 次），继续探索收益很低。';
        } else if (summaryMode &&
            _isExplorationTool(call.name) &&
            (readFileCount >= 3 ||
                grepCodeCount >= 2 ||
                runCommandCount > 0 ||
                blockedExplorationCount > 0)) {
          convergenceBlockReason = '已进入总结模式，当前信息已基本足够，停止继续$family。';
        } else if (call.name == 'web_search' &&
            webSearchCount > 3 &&
            fetchWebpageCount == 0 &&
            downloadAssetCount == 0) {
          toolResult = _buildToolLoopGuardResult(
            call: call,
            repeatedCount: repeatedCount,
            reason: '搜索次数已超过上限 3 次。请改为 fetch_webpage 读取候选链接，随后再下载资源。',
            webSearchCount: webSearchCount,
            fetchWebpageCount: fetchWebpageCount,
            downloadAssetCount: downloadAssetCount,
          );
          toolStatus = 'failed';
        } else if (forceFinalAnswer && _isExplorationTool(call.name)) {
          convergenceBlockReason = '已进入最后总结回合，不再执行新的探索工具。';
        }

        if (convergenceBlockReason != null) {
          blockedExplorationCount++;
          _updateAgentExecutionState(
            convergenceWarning: convergenceBlockReason,
            convergenceSummary: buildConvergenceSummary(
              roundNumber: roundNumber,
              summaryMode: true,
            ),
          );
          _recordAgentProgress(
            '探索未收敛，停止继续扩散',
            detail: convergenceBlockReason,
            updateLiveStatus: false,
          );
          toolResult = _buildConvergenceGuardResult(
            call: call,
            reason: convergenceBlockReason,
            repeatedCount: repeatedCount,
            toolFamilyCounts: toolFamilyCounts,
          );
          toolStatus = 'failed';
        } else if (toolStatus != 'cached') {
          try {
            toolResult = await _executeFsTool(call, roundDraft: roundDraft);
          } catch (error) {
            toolResult = jsonEncode({'ok': false, 'error': error.toString()});
          }
          toolStatus = _toolFinishStatus(toolResult, cached: false);
          if (_shouldCacheToolResult(call.name)) {
            toolResultCache[signature] = toolResult;
          }
        }

        conversation.add(<String, dynamic>{
          'role': 'tool',
          'tool_call_id': call.id,
          'content': toolResult,
        });
        collectedToolOutputs[call.id] = toolResult;
        _recordAgentToolFinish(call, toolResult, status: toolStatus);
        _updateLiveAssistantMessage(
          conversationId: conversationId,
          messageIndex: toolLiveMessageIndex,
          message: _buildToolRunMessage(
            call: call,
            time: toolLiveTime,
            toolResult: toolResult,
            status: toolStatus,
          ),
          persist: true,
        );

        _appendMessage(
          ChatMessage(
            role: ChatRole.system,
            text: '工具结果(${call.name}): ${_summarizeForLog(toolResult)}',
            time: _timeNow(),
          ),
          conversationId: conversationId,
        );
      }
    }

    final stopReason = _agentConvergenceWarning.isNotEmpty
        ? _agentConvergenceWarning
        : '模型连续调用工具但未收敛，已停止自动探索。';
    _updateAgentExecutionState(
      phase: '已停止',
      convergenceSummary: '自动工具探索未收敛，已中止本次会话。',
      convergenceWarning: stopReason,
    );
    throw Exception(
      '模型连续调用工具未收敛，已停止自动探索。建议缩小范围，例如指定具体文件、目录或报错信息。当前原因：$stopReason',
    );
  }

  List<Map<String, dynamic>> _buildConversationMessages({
    required String reasoningEffort,
    List<_OutgoingImageAttachment> attachedImages = const [],
  }) {
    var history = _messages
        .where((message) => message.role != ChatRole.system)
        .where(
          (message) =>
              message.role == ChatRole.user ||
              _messageConversationText(message).trim().isNotEmpty,
        )
        .toList();
    if (history.isNotEmpty &&
        history.first.role == ChatRole.assistant &&
        history.first.text.startsWith('你好，我是你的移动端 AI 编程助手')) {
      history = history.sublist(1);
    }
    if (history.length > 16) {
      history = history.sublist(history.length - 16);
    }

    final messages = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content': _buildSystemInstruction(reasoningEffort: reasoningEffort),
      },
    ];
    for (var i = 0; i < history.length; i++) {
      final item = history[i];
      dynamic content = _messageConversationText(item);
      final isLastUserMessage =
          i == history.length - 1 && item.role == ChatRole.user;
      if (isLastUserMessage && attachedImages.isNotEmpty) {
        content = _buildUserMessageContentWithImages(
          text: item.text,
          images: attachedImages,
        );
      }
      messages.add(<String, dynamic>{
        'role': item.role == ChatRole.user ? 'user' : 'assistant',
        'content': content,
      });
    }
    return messages;
  }

  List<Map<String, dynamic>> _buildUserMessageContentWithImages({
    required String text,
    required List<_OutgoingImageAttachment> images,
  }) {
    final parts = <Map<String, dynamic>>[
      <String, dynamic>{
        'type': 'text',
        'text': text.trim().isEmpty ? '请分析我上传的图片。' : text,
      },
    ];
    for (final image in images) {
      parts.add(<String, dynamic>{
        'type': 'image_url',
        'image_url': <String, dynamic>{'url': image.dataUrl},
      });
    }
    return parts;
  }

  String _buildSystemInstruction({required String reasoningEffort}) {
    final buffer = StringBuffer()
      ..writeln('你是移动端编程助手，目标是帮助用户完成项目修改并给出可执行步骤。')
      ..writeln('必须基于事实回答，不要编造已执行的文件操作。')
      ..writeln('需要读写项目文件时，优先调用工具函数。')
      ..writeln('如需联网检索网页内容，调用 web_search。')
      ..writeln('如需读取网页正文，调用 fetch_webpage。')
      ..writeln('如需把网络资源保存到项目，调用 download_asset。')
      ..writeln(
        'download_asset 默认下载上限: ${_formatBytes(_downloadAssetMaxBytes)} ($_downloadAssetMaxBytes bytes)。',
      )
      ..writeln(
        '下载任务建议流程：web_search 最多2次 -> fetch_webpage 验证链接 -> download_asset 保存。',
      )
      ..writeln('禁止重复调用相同工具和参数；如果已有结果，直接进入下一步。')
      ..writeln('当用户消息包含图片输入时，直接分析图片内容，不要说“无法读取二进制图片”。')
      ..writeln('不要说“不能联网搜索”；你可以通过工具联网。')
      ..writeln('所有文件路径都使用相对项目根目录路径。')
      ..writeln('当前推理强度设置: ${_reasoningEffortLabel(reasoningEffort)}。')
      ..writeln('完成工具调用后，再给出最终说明。');

    buffer
      ..writeln(
        'Before large tool sequences, prefer a short natural-language progress note.',
      )
      ..writeln(
        'For project exploration, prefer list_dir, grep_code, and read_file_part before reading entire large files.',
      )
      ..writeln(
        'Use replace_in_file for targeted edits and run_command for verification inside the mirrored Android runtime workspace.',
      )
      ..writeln(
        'You can also use find_files, file_exists, copy_file, move_file, apply_patch, git_status, git_diff, git_log, git_show, shell_session_*, and android_* tools when they are a better fit.',
      );

    if (_projectRootPath != null) {
      buffer.writeln('项目根目录: $_projectRootPath');
    }
    if (_projectFiles.isNotEmpty) {
      final index = _projectFiles
          .take(80)
          .map((file) => '- ${file.path}')
          .join('\n');
      buffer.writeln('项目文件索引(最多80条):\n$index');
    }
    if (_projectContext.isNotEmpty) {
      buffer.writeln(
        '项目上下文摘要:\n${_truncateModelOutput(_projectContext, 4200)}',
      );
    }
    if (!_aiFsGranted || _projectRootPath == null) {
      buffer.writeln('当前未授予文件系统工具权限，不能执行真实文件修改与下载落盘。');
    }
    if (_godotMcpReady) {
      buffer.writeln('已启用 Godot MCP 远程工具，可调用 godot_get_* / godot_run_* 等函数。');
      buffer.writeln('注意：Godot 路径与项目路径均以网关主机文件系统为准。');
    } else {
      buffer.writeln('当前未启用 Godot MCP 远程工具。');
    }
    return buffer.toString().trim();
  }

  Uri _buildChatCompletionEndpoint({
    required String providerId,
    required String baseUrl,
    String apiPath = '',
  }) {
    final endpoint = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final pathOverride = apiPath.trim();
    if (providerId == 'azure_openai') {
      Uri uri;
      if (pathOverride.isNotEmpty) {
        uri = _resolveEndpointByCustomPath(
          baseUrl: endpoint,
          customPath: pathOverride,
        );
      } else if (_endsWithPath(endpoint, 'openai/v1/chat/completions')) {
        uri = Uri.parse(endpoint);
      } else if (_endsWithPath(endpoint, 'openai/v1')) {
        uri = _joinBase(endpoint, 'chat/completions');
      } else {
        uri = _joinBase(endpoint, 'openai/v1/chat/completions');
      }
      if (!uri.queryParameters.containsKey('api-version')) {
        uri = uri.replace(
          queryParameters: <String, String>{
            ...uri.queryParameters,
            'api-version': 'preview',
          },
        );
      }
      return uri;
    }

    if (pathOverride.isNotEmpty) {
      return _resolveEndpointByCustomPath(
        baseUrl: endpoint,
        customPath: pathOverride,
      );
    }

    if (_endsWithPath(endpoint, 'chat/completions')) {
      return Uri.parse(endpoint);
    }
    if (_endsWithPath(endpoint, 'v1') || _endsWithPath(endpoint, 'openai/v1')) {
      return _joinBase(endpoint, 'chat/completions');
    }
    return _joinBase(endpoint, 'v1/chat/completions');
  }

  Map<String, String> _buildChatHeaders({
    required String providerId,
    required String apiKey,
    Map<String, String> extraHeaders = const <String, String>{},
  }) {
    final headers = <String, String>{
      HttpHeaders.acceptHeader: 'application/json',
      HttpHeaders.contentTypeHeader: 'application/json',
    };

    if (providerId == 'azure_openai') {
      if (apiKey.isNotEmpty) {
        headers['api-key'] = apiKey;
      }
    } else if (apiKey.isNotEmpty) {
      headers[HttpHeaders.authorizationHeader] = 'Bearer $apiKey';
    }

    if (providerId == 'openrouter') {
      headers['HTTP-Referer'] = 'https://localhost';
      headers['X-Title'] = 'yuandex';
    }
    for (final entry in _cleanHeaderMap(extraHeaders).entries) {
      headers[entry.key] = entry.value;
    }
    return headers;
  }

  HttpClient _createHttpClient({required bool improveNetworkCompatibility}) {
    return HttpClient()
      ..connectionTimeout = Duration(
        seconds: improveNetworkCompatibility ? 45 : 25,
      )
      ..idleTimeout = Duration(seconds: improveNetworkCompatibility ? 45 : 15);
  }

  void _applyRequestNetworkProfile(
    HttpClientRequest request, {
    required bool improveNetworkCompatibility,
  }) {
    request.followRedirects = true;
    request.maxRedirects = 5;
    request.persistentConnection = true;
    request.headers.set(HttpHeaders.userAgentHeader, _browserLikeUserAgent);
    request.headers.set(HttpHeaders.connectionHeader, 'keep-alive');
    request.headers.set(HttpHeaders.acceptLanguageHeader, 'zh-CN,zh;q=0.9');
    // Avoid brotli responses because dart:io does not transparently decode br.
    request.headers.set(HttpHeaders.acceptEncodingHeader, 'gzip, deflate');
    if (improveNetworkCompatibility) {
      request.headers.set('Pragma', 'no-cache');
      request.headers.set('Cache-Control', 'no-cache');
    }
  }

  bool _isTransientNetworkError(Object error) {
    if (error is TimeoutException ||
        error is SocketException ||
        error is HandshakeException ||
        error is HttpException) {
      return true;
    }
    final text = error.toString().toLowerCase();
    return text.contains('timed out') ||
        text.contains('connection reset') ||
        text.contains('connection closed') ||
        text.contains('temporarily unavailable') ||
        text.contains('network is unreachable') ||
        text.contains('connection aborted');
  }

  Future<_ChatCompletionResult> _requestChatCompletionStream({
    required Uri uri,
    required Map<String, String> headers,
    required Map<String, dynamic> payload,
    required bool improveNetworkCompatibility,
    required void Function(_ChatCompletionStreamSnapshot snapshot)
    onStreamSnapshot,
  }) async {
    final client = _createHttpClient(
      improveNetworkCompatibility: improveNetworkCompatibility,
    );
    HttpClientRequest? request;
    _activeChatClient = client;
    final startedAtMs = DateTime.now().millisecondsSinceEpoch;
    final streamPayload = <String, dynamic>{...payload, 'stream': true};
    final content = StringBuffer();
    final reasoning = StringBuffer();
    final toolCallAccumulators = <String, _StreamingToolCallAccumulator>{};
    final responseToolKeysByItemId = <String, String>{};
    final responseToolKeysByOutputIndex = <String, String>{};
    dynamic usage;
    var modelName = '${payload['model'] ?? ''}'.trim();
    var finishReason = '';
    var lastEmitMs = 0;
    var emittedAnySnapshot = false;
    var processedSseData = false;

    List<_ToolCall> currentToolCalls() {
      return toolCallAccumulators.values
          .map((item) => item.toToolCall())
          .where((item) => item.name.trim().isNotEmpty)
          .toList(growable: false);
    }

    ResponseMetadata currentMetadata() {
      final elapsedMs = DateTime.now().millisecondsSinceEpoch - startedAtMs;
      return _buildResponseMetadataFromUsage(
        model: modelName,
        finishReason: finishReason,
        usage: usage,
      ).copyWith(elapsedMs: elapsedMs);
    }

    void emitSnapshot({bool force = false}) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (!force && now - lastEmitMs < 80) return;
      final snapshot = _ChatCompletionStreamSnapshot(
        content: content.toString(),
        reasoningSummary: reasoning.toString(),
        toolCalls: currentToolCalls(),
        metadata: currentMetadata(),
      );
      if (!snapshot.hasVisibleOutput && !force) return;
      emittedAnySnapshot = true;
      lastEmitMs = now;
      onStreamSnapshot(snapshot);
    }

    _StreamingToolCallAccumulator accumulatorFor(String key) {
      return toolCallAccumulators.putIfAbsent(
        key,
        () => _StreamingToolCallAccumulator(fallbackId: key),
      );
    }

    String responseToolKeyFor({
      required Map<String, dynamic> event,
      Map? item,
    }) {
      final outputIndex = '${event['output_index'] ?? ''}'.trim();
      final itemId =
          '${event['item_id'] ?? item?['id'] ?? item?['call_id'] ?? ''}'.trim();
      if (itemId.isNotEmpty && responseToolKeysByItemId[itemId] != null) {
        return responseToolKeysByItemId[itemId]!;
      }
      if (outputIndex.isNotEmpty &&
          responseToolKeysByOutputIndex[outputIndex] != null) {
        return responseToolKeysByOutputIndex[outputIndex]!;
      }

      final seed = itemId.isNotEmpty
          ? itemId
          : outputIndex.isNotEmpty
          ? 'index_$outputIndex'
          : 'call_${toolCallAccumulators.length}';
      final key = 'responses:$seed';
      if (itemId.isNotEmpty) {
        responseToolKeysByItemId[itemId] = key;
      }
      if (outputIndex.isNotEmpty) {
        responseToolKeysByOutputIndex[outputIndex] = key;
      }
      return key;
    }

    void appendStreamingText(StringBuffer target, dynamic raw) {
      final text = _extractStreamingText(raw);
      if (text.isNotEmpty) {
        target.write(text);
      }
    }

    void applyChatCompletionChunk(Map<String, dynamic> decoded) {
      final chunkModel = '${decoded['model'] ?? ''}'.trim();
      if (chunkModel.isNotEmpty) {
        modelName = chunkModel;
      }
      if (decoded.containsKey('usage')) {
        usage = decoded['usage'];
      }
      final choices = decoded['choices'];
      if (choices is! List) return;
      for (var choiceIndex = 0; choiceIndex < choices.length; choiceIndex++) {
        final choice = choices[choiceIndex];
        if (choice is! Map) continue;
        final finish = '${choice['finish_reason'] ?? ''}'.trim();
        if (finish.isNotEmpty) {
          finishReason = finish;
        }
        final delta = choice['delta'];
        if (delta is Map) {
          appendStreamingText(content, delta['content']);
          appendStreamingText(content, delta['text']);
          appendStreamingText(reasoning, delta['reasoning']);
          appendStreamingText(reasoning, delta['reasoning_content']);
          appendStreamingText(reasoning, delta['reasoning_text']);
          final toolCalls = delta['tool_calls'];
          if (toolCalls is List) {
            for (var i = 0; i < toolCalls.length; i++) {
              final item = toolCalls[i];
              if (item is! Map) continue;
              final index = item['index'] ?? i;
              final key = 'chat:$choiceIndex:$index';
              final accumulator = accumulatorFor(key);
              final id = '${item['id'] ?? ''}'.trim();
              if (id.isNotEmpty) accumulator.id = id;
              final function = item['function'];
              if (function is Map) {
                final name = '${function['name'] ?? ''}'.trim();
                if (name.isNotEmpty) accumulator.name = name;
                final args = function['arguments'];
                if (args != null) {
                  accumulator.arguments.write(args.toString());
                }
              }
            }
          }
        }
        final message = choice['message'];
        if (message is Map) {
          appendStreamingText(content, message['content']);
          appendStreamingText(reasoning, message['reasoning']);
          appendStreamingText(reasoning, message['reasoning_content']);
          for (final call in _extractToolCalls(message['tool_calls'])) {
            final key = 'message:${call.id}';
            final accumulator = accumulatorFor(key);
            accumulator.id = call.id;
            accumulator.name = call.name;
            accumulator.arguments
              ..clear()
              ..write(call.argumentsJson);
          }
        }
      }
    }

    void applyResponsesChunk(Map<String, dynamic> decoded) {
      final type = '${decoded['type'] ?? ''}'.trim();
      final response = decoded['response'];
      if (response is Map) {
        final responseModel = '${response['model'] ?? ''}'.trim();
        if (responseModel.isNotEmpty) {
          modelName = responseModel;
        }
        if (response.containsKey('usage')) {
          usage = response['usage'];
        }
        final status = '${response['status'] ?? ''}'.trim();
        if (status.isNotEmpty) {
          finishReason = status;
        }
      }
      if (type == 'response.output_text.delta' ||
          type == 'response.refusal.delta') {
        appendStreamingText(content, decoded['delta']);
      } else if (type == 'response.reasoning_summary_text.delta' ||
          type == 'response.reasoning_text.delta' ||
          type.contains('reasoning') && type.endsWith('.delta')) {
        appendStreamingText(reasoning, decoded['delta'] ?? decoded['text']);
      } else if (type == 'response.function_call_arguments.delta') {
        final key = responseToolKeyFor(event: decoded);
        accumulatorFor(key).arguments.write('${decoded['delta'] ?? ''}');
      } else if (type == 'response.function_call_arguments.done') {
        final key = responseToolKeyFor(event: decoded);
        final argumentsText =
            decoded['arguments'] ?? decoded['delta'] ?? decoded['text'];
        if (argumentsText != null) {
          accumulatorFor(key).arguments
            ..clear()
            ..write(argumentsText.toString());
        }
      } else if (type == 'response.output_item.added' ||
          type == 'response.output_item.done') {
        final item = decoded['item'];
        if (item is Map && '${item['type'] ?? ''}' == 'function_call') {
          final key = responseToolKeyFor(event: decoded, item: item);
          final accumulator = accumulatorFor(key);
          final id = '${item['call_id'] ?? item['id'] ?? ''}'.trim();
          if (id.isNotEmpty) accumulator.id = id;
          final name = '${item['name'] ?? ''}'.trim();
          if (name.isNotEmpty) accumulator.name = name;
          if (item.containsKey('arguments')) {
            accumulator.arguments
              ..clear()
              ..write('${item['arguments'] ?? '{}'}');
          }
        }
      }
    }

    void applySseData(String data) {
      final trimmed = data.trim();
      if (trimmed.isEmpty || trimmed == '[DONE]') return;
      processedSseData = true;
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map<String, dynamic>) return;
      if (decoded.containsKey('choices')) {
        applyChatCompletionChunk(decoded);
      } else {
        applyResponsesChunk(decoded);
      }
      emitSnapshot();
    }

    try {
      if (_stopReplyRequested) {
        throw const _ModelRequestCancelledException();
      }
      request = await client.postUrl(uri);
      _activeChatRequest = request;
      _applyRequestNetworkProfile(
        request,
        improveNetworkCompatibility: improveNetworkCompatibility,
      );
      for (final entry in headers.entries) {
        final value = entry.value.trim();
        if (value.isEmpty) continue;
        request.headers.set(entry.key, value);
      }
      request.headers.set(
        HttpHeaders.acceptHeader,
        'text/event-stream, application/json',
      );
      request.add(utf8.encode(jsonEncode(streamPayload)));
      final response = await request.close();
      if (_stopReplyRequested) {
        throw const _ModelRequestCancelledException();
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await utf8.decoder.bind(response).join();
        final snippet = _condenseErrorBody(body);
        final suffix = snippet.isEmpty ? '' : ' - $snippet';
        throw Exception('HTTP ${response.statusCode}$suffix');
      }

      var pending = '';
      final rawResponse = StringBuffer();
      await for (final chunk in utf8.decoder.bind(response)) {
        if (_stopReplyRequested) {
          throw const _ModelRequestCancelledException();
        }
        rawResponse.write(chunk);
        pending += chunk.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
        while (true) {
          final eventEnd = pending.indexOf('\n\n');
          if (eventEnd < 0) break;
          final rawEvent = pending.substring(0, eventEnd);
          pending = pending.substring(eventEnd + 2);
          final dataLines = rawEvent
              .split('\n')
              .where((line) => line.startsWith('data:'))
              .map((line) => line.substring(5).trimLeft())
              .toList();
          if (dataLines.isEmpty) continue;
          applySseData(dataLines.join('\n'));
        }
      }
      if (pending.trim().isNotEmpty) {
        final dataLines = pending
            .split('\n')
            .where((line) => line.startsWith('data:'))
            .map((line) => line.substring(5).trimLeft())
            .toList();
        if (dataLines.isNotEmpty) {
          applySseData(dataLines.join('\n'));
        }
      }
      if (!processedSseData) {
        final rawBody = rawResponse.toString().trim();
        if (rawBody.isNotEmpty) {
          final decoded = jsonDecode(rawBody);
          if (decoded is! Map<String, dynamic>) {
            throw Exception('Streaming response format was not a JSON object');
          }
          if (decoded.containsKey('output')) {
            return _parseResponsesApiResult(decoded, payload: payload);
          }
          final choices = decoded['choices'];
          if (choices is! List || choices.isEmpty) {
            throw Exception('Streaming response did not contain SSE data');
          }
          final first = choices.first;
          if (first is! Map<String, dynamic>) {
            throw Exception('Streaming choices[0] format was invalid');
          }
          final message = first['message'];
          if (message is! Map<String, dynamic>) {
            throw Exception('Streaming response did not contain message');
          }
          return _ChatCompletionResult(
            content: _extractAssistantText(message['content']),
            toolCalls: _extractToolCalls(message['tool_calls']),
            reasoningSummary: _extractReasoningText(message),
            metadata: _buildResponseMetadataFromUsage(
              model: '${decoded['model'] ?? payload['model'] ?? ''}',
              finishReason: '${first['finish_reason'] ?? ''}'.trim(),
              usage: decoded['usage'],
            ),
          );
        }
      }
      emitSnapshot(force: true);
      return _ChatCompletionResult(
        content: content.toString().trim(),
        toolCalls: currentToolCalls(),
        reasoningSummary: reasoning.toString().trim(),
        metadata: currentMetadata(),
      );
    } catch (error) {
      if (_stopReplyRequested) {
        throw const _ModelRequestCancelledException();
      }
      if (emittedAnySnapshot) {
        emitSnapshot(force: true);
      }
      rethrow;
    } finally {
      if (identical(_activeChatRequest, request)) {
        _activeChatRequest = null;
      }
      if (identical(_activeChatClient, client)) {
        _activeChatClient = null;
      }
      client.close(force: true);
    }
  }

  Future<_ChatCompletionResult> _requestChatCompletion({
    required Uri uri,
    required Map<String, String> headers,
    required Map<String, dynamic> payload,
    required bool improveNetworkCompatibility,
    void Function(_ChatCompletionStreamSnapshot snapshot)? onStreamSnapshot,
  }) async {
    if (onStreamSnapshot != null) {
      try {
        return await _requestChatCompletionStream(
          uri: uri,
          headers: headers,
          payload: payload,
          improveNetworkCompatibility: improveNetworkCompatibility,
          onStreamSnapshot: onStreamSnapshot,
        );
      } catch (error) {
        if (_stopReplyRequested) {
          throw const _ModelRequestCancelledException();
        }
        _recordAgentProgress(
          'Streaming fallback',
          detail: error.toString(),
          updateLiveStatus: false,
        );
      }
    }

    final client = _createHttpClient(
      improveNetworkCompatibility: improveNetworkCompatibility,
    );
    HttpClientRequest? request;
    _activeChatClient = client;
    try {
      if (_stopReplyRequested) {
        throw const _ModelRequestCancelledException();
      }
      request = await client.postUrl(uri);
      _activeChatRequest = request;
      _applyRequestNetworkProfile(
        request,
        improveNetworkCompatibility: improveNetworkCompatibility,
      );
      for (final entry in headers.entries) {
        final value = entry.value.trim();
        if (value.isEmpty) continue;
        request.headers.set(entry.key, value);
      }
      if (_stopReplyRequested) {
        throw const _ModelRequestCancelledException();
      }
      request.add(utf8.encode(jsonEncode(payload)));
      final response = await request.close();
      if (_stopReplyRequested) {
        throw const _ModelRequestCancelledException();
      }
      final body = await utf8.decoder.bind(response).join();
      if (_stopReplyRequested) {
        throw const _ModelRequestCancelledException();
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final snippet = _condenseErrorBody(body);
        final suffix = snippet.isEmpty ? '' : ' - $snippet';
        throw Exception('HTTP ${response.statusCode}$suffix');
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('响应格式异常: 非 JSON 对象');
      }
      if (decoded.containsKey('output')) {
        return _parseResponsesApiResult(decoded, payload: payload);
      }
      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) {
        throw Exception('响应缺少 choices');
      }
      final first = choices.first;
      if (first is! Map<String, dynamic>) {
        throw Exception('响应 choices[0] 格式异常');
      }
      final message = first['message'];
      if (message is! Map<String, dynamic>) {
        throw Exception('响应缺少 message');
      }

      final content = _extractAssistantText(message['content']);
      final toolCalls = _extractToolCalls(message['tool_calls']);
      return _ChatCompletionResult(
        content: content,
        toolCalls: toolCalls,
        reasoningSummary: _extractReasoningText(message),
        metadata: _buildResponseMetadataFromUsage(
          model: '${decoded['model'] ?? payload['model'] ?? ''}',
          finishReason: '${first['finish_reason'] ?? ''}'.trim(),
          usage: decoded['usage'],
        ),
      );
    } catch (error) {
      if (_stopReplyRequested) {
        throw const _ModelRequestCancelledException();
      }
      rethrow;
    } finally {
      if (identical(_activeChatRequest, request)) {
        _activeChatRequest = null;
      }
      if (identical(_activeChatClient, client)) {
        _activeChatClient = null;
      }
      client.close(force: true);
    }
  }

  String _extractAssistantText(dynamic content) {
    if (content == null) return '';
    if (content is String) return content;
    if (content is List) {
      final parts = <String>[];
      for (final item in content) {
        if (item is String && item.trim().isNotEmpty) {
          parts.add(item.trim());
        } else if (item is Map<String, dynamic>) {
          final text = item['text']?.toString().trim() ?? '';
          if (text.isNotEmpty) {
            parts.add(text);
          }
        }
      }
      return parts.join('\n').trim();
    }
    if (content is Map<String, dynamic>) {
      return content['text']?.toString().trim() ?? '';
    }
    return content.toString();
  }

  String _extractStreamingText(dynamic content) {
    if (content == null) return '';
    if (content is String) return content;
    if (content is List) {
      final buffer = StringBuffer();
      for (final item in content) {
        buffer.write(_extractStreamingText(item));
      }
      return buffer.toString();
    }
    if (content is Map) {
      return _extractStreamingText(
        content['text'] ?? content['delta'] ?? content['content'],
      );
    }
    return content.toString();
  }

  String _extractReasoningText(Map<String, dynamic> message) {
    final parts = <String>[];
    void add(dynamic raw) {
      final text = _extractAssistantText(raw).trim();
      if (text.isNotEmpty) parts.add(text);
    }

    add(message['reasoning']);
    add(message['reasoning_content']);
    add(message['reasoning_text']);
    final reasoningDetails = message['reasoning_details'];
    if (reasoningDetails is List) {
      for (final item in reasoningDetails) {
        add(item);
      }
    }
    return parts.join('\n').trim();
  }

  _ChatCompletionResult _parseResponsesApiResult(
    Map<String, dynamic> decoded, {
    required Map<String, dynamic> payload,
  }) {
    final output = decoded['output'];
    final toolCalls = <_ToolCall>[];
    final contentBlocks = <String>[];
    final reasoningBlocks = <String>[];

    if (output is List) {
      for (var i = 0; i < output.length; i++) {
        final item = output[i];
        if (item is! Map) continue;
        final type = '${item['type'] ?? ''}'.trim();
        if (type == 'message') {
          contentBlocks.add(_extractAssistantText(item['content']));
          continue;
        }
        if (type == 'reasoning') {
          final summary = item['summary'];
          if (summary is List) {
            for (final entry in summary) {
              if (entry is Map) {
                final text = '${entry['text'] ?? ''}'.trim();
                if (text.isNotEmpty) {
                  reasoningBlocks.add(text);
                }
              }
            }
          }
          final text = '${item['text'] ?? ''}'.trim();
          if (text.isNotEmpty) {
            reasoningBlocks.add(text);
          }
          continue;
        }
        if (type == 'function_call') {
          final name = '${item['name'] ?? ''}'.trim();
          if (name.isEmpty) continue;
          final argsText = '${item['arguments'] ?? '{}'}';
          final idRaw = '${item['call_id'] ?? item['id'] ?? ''}'.trim();
          toolCalls.add(
            _ToolCall(
              id: idRaw.isEmpty
                  ? 'call_${DateTime.now().microsecondsSinceEpoch}_$i'
                  : idRaw,
              name: name,
              argumentsJson: argsText,
            ),
          );
        }
      }
    }

    return _ChatCompletionResult(
      content: contentBlocks
          .where((item) => item.trim().isNotEmpty)
          .join('\n\n')
          .trim(),
      toolCalls: toolCalls,
      reasoningSummary: reasoningBlocks.join('\n').trim(),
      metadata: _buildResponseMetadataFromUsage(
        model: '${decoded['model'] ?? payload['model'] ?? ''}',
        finishReason: '${decoded['status'] ?? ''}'.trim(),
        usage: decoded['usage'],
      ),
    );
  }

  ResponseMetadata _buildResponseMetadataFromUsage({
    required String model,
    required String finishReason,
    required dynamic usage,
  }) {
    int? readNestedInt(dynamic source, List<String> path) {
      dynamic current = source;
      for (final key in path) {
        if (current is Map) {
          current = current[key];
        } else {
          return null;
        }
      }
      if (current is int) return current;
      if (current is num) return current.toInt();
      return int.tryParse('${current ?? ''}');
    }

    return ResponseMetadata(
      model: model,
      inputTokens:
          readNestedInt(usage, const ['prompt_tokens']) ??
          readNestedInt(usage, const ['input_tokens']),
      outputTokens:
          readNestedInt(usage, const ['completion_tokens']) ??
          readNestedInt(usage, const ['output_tokens']),
      reasoningTokens:
          readNestedInt(usage, const [
            'completion_tokens_details',
            'reasoning_tokens',
          ]) ??
          readNestedInt(usage, const [
            'output_tokens_details',
            'reasoning_tokens',
          ]),
      finishReason: finishReason,
    );
  }

  List<_ToolCall> _extractToolCalls(dynamic raw) {
    if (raw is! List) return const [];
    final calls = <_ToolCall>[];
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      if (item is! Map<String, dynamic>) continue;
      final function = item['function'];
      if (function is! Map<String, dynamic>) continue;
      final name = function['name']?.toString().trim() ?? '';
      if (name.isEmpty) continue;
      final args = function['arguments'];
      final argsText = args is String ? args : jsonEncode(args ?? const {});
      final idRaw = item['id']?.toString().trim() ?? '';
      final callId = idRaw.isEmpty
          ? 'call_${DateTime.now().microsecondsSinceEpoch}_$i'
          : idRaw;
      calls.add(_ToolCall(id: callId, name: name, argumentsJson: argsText));
    }
    return calls;
  }

  List<Map<String, dynamic>> _buildActiveTools() {
    final tools = <Map<String, dynamic>>[];
    if (_aiFsGranted && _projectRootPath != null) {
      tools.addAll(_buildFsTools());
    } else {
      tools.addAll(_buildWebTools(includeDownloadAsset: false));
    }
    if (_godotMcpReady) {
      tools.addAll(_buildGodotMcpTools());
    }
    return tools;
  }

  // ignore: unused_element
  List<Map<String, dynamic>> _buildAndroidRuntimeTools() {
    const allowedNames = <String>{
      'run_command',
      'android_gradle_build',
      'android_install_apk',
      'android_logcat',
      'android_decompile_apk',
      'android_run_jadx',
      'android_search_jadx',
      'android_rebuild_apk',
      'android_sign_apk',
      'git_status',
      'git_diff',
      'git_log',
      'git_show',
      'shell_session_start',
      'shell_session_stop',
      'shell_session_snapshot',
      'shell_session_input',
      'shell_session_clear',
    };
    return _buildFsTools().where((tool) {
      final function = tool['function'];
      if (function is! Map) return false;
      final name = function['name']?.toString() ?? '';
      return allowedNames.contains(name);
    }).toList();
  }

  List<Map<String, dynamic>> _buildFsTools() {
    return [
      {
        'type': 'function',
        'function': {
          'name': 'read_file',
          'description': 'Read a text file from project root by relative path.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {'type': 'string', 'description': 'Relative file path'},
            },
            'required': ['path'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'read_file_part',
          'description':
              'Read only part of a text file by line range for faster code inspection.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {'type': 'string', 'description': 'Relative file path'},
              'start_line': {
                'type': 'integer',
                'description': '1-based starting line number',
                'default': 1,
              },
              'max_lines': {
                'type': 'integer',
                'description': 'Maximum number of lines to read',
                'default': 160,
              },
            },
            'required': ['path'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'find_files',
          'description':
              'Find files or directories by glob pattern relative to the project root or a subdirectory.',
          'parameters': {
            'type': 'object',
            'properties': {
              'pattern': {
                'type': 'string',
                'description': 'Glob pattern such as **/*.dart or *.md',
              },
              'path': {
                'type': 'string',
                'description': 'Relative directory path to search in',
                'default': '.',
              },
              'limit': {
                'type': 'integer',
                'description': 'Maximum number of matches to return',
                'default': 80,
              },
              'case_sensitive': {
                'type': 'boolean',
                'description': 'Whether matching should be case-sensitive',
                'default': false,
              },
            },
            'required': ['pattern'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'file_exists',
          'description':
              'Check whether a project file or directory exists and return its type.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {'type': 'string', 'description': 'Relative path'},
            },
            'required': ['path'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'write_file',
          'description': 'Write text content to an existing file or create it.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {'type': 'string', 'description': 'Relative file path'},
              'content': {'type': 'string', 'description': 'File content'},
            },
            'required': ['path', 'content'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'replace_in_file',
          'description':
              'Replace text inside an existing text file without rewriting the entire file manually.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {'type': 'string', 'description': 'Relative file path'},
              'old_text': {
                'type': 'string',
                'description': 'The text to replace',
              },
              'new_text': {'type': 'string', 'description': 'Replacement text'},
              'replace_all': {
                'type': 'boolean',
                'description': 'Replace all matches instead of only the first',
                'default': false,
              },
            },
            'required': ['path', 'old_text', 'new_text'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'create_file',
          'description': 'Create a new file with optional content.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {'type': 'string', 'description': 'Relative file path'},
              'content': {
                'type': 'string',
                'description': 'Initial content',
                'default': '',
              },
            },
            'required': ['path'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'create_dir',
          'description': 'Create a directory recursively by relative path.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {
                'type': 'string',
                'description': 'Relative directory path',
              },
            },
            'required': ['path'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'delete_entry',
          'description': 'Delete file or directory by relative path.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {'type': 'string', 'description': 'Relative path'},
            },
            'required': ['path'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'copy_file',
          'description':
              'Copy a file or directory to another relative project path.',
          'parameters': {
            'type': 'object',
            'properties': {
              'from_path': {'type': 'string', 'description': 'Source path'},
              'to_path': {'type': 'string', 'description': 'Destination path'},
            },
            'required': ['from_path', 'to_path'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'move_file',
          'description':
              'Move or rename a file or directory to another relative project path.',
          'parameters': {
            'type': 'object',
            'properties': {
              'from_path': {'type': 'string', 'description': 'Source path'},
              'to_path': {'type': 'string', 'description': 'Destination path'},
            },
            'required': ['from_path', 'to_path'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'apply_patch',
          'description':
              'Apply a structured multi-step patch with write, replace, create_dir, delete, move, or copy operations.',
          'parameters': {
            'type': 'object',
            'properties': {
              'operations': {
                'type': 'array',
                'description': 'Ordered patch operations to apply',
                'items': {
                  'type': 'object',
                  'properties': {
                    'type': {'type': 'string'},
                    'path': {'type': 'string'},
                    'content': {'type': 'string'},
                    'old_text': {'type': 'string'},
                    'new_text': {'type': 'string'},
                    'replace_all': {'type': 'boolean'},
                    'from_path': {'type': 'string'},
                    'to_path': {'type': 'string'},
                  },
                  'required': ['type'],
                },
              },
            },
            'required': ['operations'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'list_files',
          'description': 'List project files for code navigation.',
          'parameters': {
            'type': 'object',
            'properties': {
              'limit': {
                'type': 'integer',
                'description': 'Max number of files to return',
                'default': 80,
              },
            },
            'required': [],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'list_dir',
          'description':
              'List files and directories inside a relative directory path.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {
                'type': 'string',
                'description': 'Relative directory path',
                'default': '.',
              },
              'limit': {
                'type': 'integer',
                'description': 'Maximum number of entries to return',
                'default': 120,
              },
            },
            'required': [],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'file_info',
          'description':
              'Return metadata about a project file or directory path.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {'type': 'string', 'description': 'Relative path'},
            },
            'required': ['path'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'grep_code',
          'description':
              'Search for text in project files and return matching lines.',
          'parameters': {
            'type': 'object',
            'properties': {
              'query': {'type': 'string', 'description': 'Text to search for'},
              'path': {
                'type': 'string',
                'description': 'Relative directory path to search in',
                'default': '.',
              },
              'limit': {
                'type': 'integer',
                'description': 'Maximum number of matches to return',
                'default': 40,
              },
              'case_sensitive': {
                'type': 'boolean',
                'description': 'Use case-sensitive matching',
                'default': false,
              },
            },
            'required': ['query'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'create_project',
          'description':
              'Create a project subdirectory under root and initialize README.',
          'parameters': {
            'type': 'object',
            'properties': {
              'name': {'type': 'string', 'description': 'Project folder name'},
              'readme': {'type': 'string', 'description': 'README content'},
            },
            'required': ['name'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'run_command',
          'description':
              'Execute a one-shot shell command inside the mirrored Android local runtime workspace for checks, tests, and builds.',
          'parameters': {
            'type': 'object',
            'properties': {
              'command': {'type': 'string', 'description': 'Shell command'},
              'timeout_ms': {
                'type': 'integer',
                'description': 'Timeout in milliseconds',
                'default': 20000,
              },
              'max_output_bytes': {
                'type': 'integer',
                'description': 'Maximum bytes to capture from stdout or stderr',
                'default': 131072,
              },
            },
            'required': ['command'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'android_gradle_build',
          'description':
              'Build the current Android project with Gradle inside the mirrored workspace.',
          'parameters': {
            'type': 'object',
            'properties': {
              'task': {
                'type': 'string',
                'description': 'Gradle task, for example assembleDebug',
              },
              'timeout_ms': {
                'type': 'integer',
                'description': 'Timeout in milliseconds',
                'default': 120000,
              },
              'max_output_bytes': {
                'type': 'integer',
                'description': 'Maximum bytes to capture',
                'default': 262144,
              },
            },
            'required': ['task'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'android_install_apk',
          'description':
              'Install an APK with adb. The path can be absolute or relative to the mirrored workspace.',
          'parameters': {
            'type': 'object',
            'properties': {
              'apk_path': {
                'type': 'string',
                'description': 'APK path to install',
              },
              'replace': {
                'type': 'boolean',
                'description': 'Replace existing app if already installed',
                'default': true,
              },
              'grant_all': {
                'type': 'boolean',
                'description': 'Grant all runtime permissions on install',
                'default': false,
              },
              'timeout_ms': {
                'type': 'integer',
                'description': 'Timeout in milliseconds',
                'default': 60000,
              },
              'max_output_bytes': {
                'type': 'integer',
                'description': 'Maximum bytes to capture',
                'default': 196608,
              },
            },
            'required': ['apk_path'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'android_logcat',
          'description': 'Capture logcat output through adb.',
          'parameters': {
            'type': 'object',
            'properties': {
              'filter_spec': {
                'type': 'string',
                'description':
                    'Optional logcat filter spec, for example MyApp:D *:S',
                'default': '',
              },
              'clear_before': {
                'type': 'boolean',
                'description': 'Clear logcat buffer before dumping',
                'default': false,
              },
              'timeout_ms': {
                'type': 'integer',
                'description': 'Timeout in milliseconds',
                'default': 20000,
              },
              'max_output_bytes': {
                'type': 'integer',
                'description': 'Maximum bytes to capture',
                'default': 262144,
              },
            },
            'required': [],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'android_decompile_apk',
          'description':
              'Decode an APK with apktool into the runtime reverse workspace.',
          'parameters': {
            'type': 'object',
            'properties': {
              'apk_path': {
                'type': 'string',
                'description': 'APK path to decode',
              },
              'reverse_label': {
                'type': 'string',
                'description': 'Workspace label under reverse/',
                'default': '',
              },
              'timeout_ms': {
                'type': 'integer',
                'description': 'Timeout in milliseconds',
                'default': 120000,
              },
              'max_output_bytes': {
                'type': 'integer',
                'description': 'Maximum bytes to capture',
                'default': 262144,
              },
            },
            'required': ['apk_path'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'android_run_jadx',
          'description':
              'Run jadx on an APK and write Java sources into the runtime reverse workspace.',
          'parameters': {
            'type': 'object',
            'properties': {
              'apk_path': {
                'type': 'string',
                'description': 'APK path to decompile with jadx',
              },
              'reverse_label': {
                'type': 'string',
                'description': 'Workspace label under reverse/',
                'default': '',
              },
              'timeout_ms': {
                'type': 'integer',
                'description': 'Timeout in milliseconds',
                'default': 120000,
              },
              'max_output_bytes': {
                'type': 'integer',
                'description': 'Maximum bytes to capture',
                'default': 262144,
              },
            },
            'required': ['apk_path'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'android_search_jadx',
          'description':
              'Search the generated jadx output directory inside the reverse workspace.',
          'parameters': {
            'type': 'object',
            'properties': {
              'query': {'type': 'string', 'description': 'Search string'},
              'reverse_label': {
                'type': 'string',
                'description': 'Workspace label under reverse/',
                'default': '',
              },
              'case_sensitive': {
                'type': 'boolean',
                'description': 'Use case-sensitive search',
                'default': false,
              },
              'max_results': {
                'type': 'integer',
                'description': 'Maximum number of matches',
                'default': 40,
              },
              'timeout_ms': {
                'type': 'integer',
                'description': 'Timeout in milliseconds',
                'default': 20000,
              },
              'max_output_bytes': {
                'type': 'integer',
                'description': 'Maximum bytes to capture',
                'default': 196608,
              },
            },
            'required': ['query'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'android_rebuild_apk',
          'description':
              'Rebuild an apktool reverse workspace into an unsigned APK.',
          'parameters': {
            'type': 'object',
            'properties': {
              'reverse_label': {
                'type': 'string',
                'description': 'Workspace label under reverse/',
                'default': '',
              },
              'timeout_ms': {
                'type': 'integer',
                'description': 'Timeout in milliseconds',
                'default': 120000,
              },
              'max_output_bytes': {
                'type': 'integer',
                'description': 'Maximum bytes to capture',
                'default': 262144,
              },
            },
            'required': [],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'android_sign_apk',
          'description':
              'Zipalign and sign the rebuilt APK using the configured keystore fields.',
          'parameters': {
            'type': 'object',
            'properties': {
              'reverse_label': {
                'type': 'string',
                'description': 'Workspace label under reverse/',
                'default': '',
              },
              'timeout_ms': {
                'type': 'integer',
                'description': 'Timeout in milliseconds',
                'default': 120000,
              },
              'max_output_bytes': {
                'type': 'integer',
                'description': 'Maximum bytes to capture',
                'default': 196608,
              },
            },
            'required': [],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'git_status',
          'description':
              'Run git status in the mirrored Android runtime workspace.',
          'parameters': {
            'type': 'object',
            'properties': {
              'timeout_ms': {
                'type': 'integer',
                'description': 'Timeout in milliseconds',
                'default': 20000,
              },
              'max_output_bytes': {
                'type': 'integer',
                'description': 'Maximum bytes to capture',
                'default': 131072,
              },
            },
            'required': [],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'git_diff',
          'description':
              'Run git diff in the mirrored Android runtime workspace.',
          'parameters': {
            'type': 'object',
            'properties': {
              'path': {
                'type': 'string',
                'description': 'Optional relative path to limit diff scope',
                'default': '',
              },
              'staged': {
                'type': 'boolean',
                'description': 'Whether to diff staged changes',
                'default': false,
              },
              'timeout_ms': {
                'type': 'integer',
                'description': 'Timeout in milliseconds',
                'default': 20000,
              },
              'max_output_bytes': {
                'type': 'integer',
                'description': 'Maximum bytes to capture',
                'default': 131072,
              },
            },
            'required': [],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'git_log',
          'description':
              'Read recent git history in the mirrored Android runtime workspace.',
          'parameters': {
            'type': 'object',
            'properties': {
              'limit': {
                'type': 'integer',
                'description': 'Maximum number of commits to show',
                'default': 20,
              },
              'timeout_ms': {
                'type': 'integer',
                'description': 'Timeout in milliseconds',
                'default': 20000,
              },
              'max_output_bytes': {
                'type': 'integer',
                'description': 'Maximum bytes to capture',
                'default': 131072,
              },
            },
            'required': [],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'git_show',
          'description':
              'Show a specific git ref, commit, or file revision in the mirrored Android runtime workspace.',
          'parameters': {
            'type': 'object',
            'properties': {
              'ref': {
                'type': 'string',
                'description': 'Commit, ref name, or revision to show',
              },
              'path': {
                'type': 'string',
                'description': 'Optional relative path for a single file view',
                'default': '',
              },
              'timeout_ms': {
                'type': 'integer',
                'description': 'Timeout in milliseconds',
                'default': 20000,
              },
              'max_output_bytes': {
                'type': 'integer',
                'description': 'Maximum bytes to capture',
                'default': 131072,
              },
            },
            'required': ['ref'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'shell_session_start',
          'description':
              'Start the persistent local shell session in the Android runtime workspace.',
          'parameters': {'type': 'object', 'properties': {}, 'required': []},
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'shell_session_stop',
          'description':
              'Stop the persistent local shell session in the Android runtime workspace.',
          'parameters': {'type': 'object', 'properties': {}, 'required': []},
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'shell_session_snapshot',
          'description':
              'Read the current shell session state and buffered output.',
          'parameters': {'type': 'object', 'properties': {}, 'required': []},
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'shell_session_input',
          'description':
              'Send one command or line of input to the persistent shell session.',
          'parameters': {
            'type': 'object',
            'properties': {
              'input': {'type': 'string', 'description': 'Shell input text'},
            },
            'required': ['input'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'shell_session_clear',
          'description': 'Clear the buffered shell session output.',
          'parameters': {'type': 'object', 'properties': {}, 'required': []},
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'download_asset',
          'description':
              'Download a remote file from http/https URL and save it to project path.',
          'parameters': {
            'type': 'object',
            'properties': {
              'url': {'type': 'string', 'description': 'Remote file URL'},
              'path': {
                'type': 'string',
                'description': 'Relative destination path in project',
              },
              'overwrite': {
                'type': 'boolean',
                'description': 'Whether to overwrite existing file',
                'default': true,
              },
              'max_bytes': {
                'type': 'integer',
                'description': 'Max allowed download size in bytes',
                'default': _downloadAssetMaxBytes,
              },
            },
            'required': ['url', 'path'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'web_search',
          'description':
              'Search the web and return candidate URLs with title/snippet.',
          'parameters': {
            'type': 'object',
            'properties': {
              'query': {'type': 'string', 'description': 'Search keywords'},
              'max_results': {
                'type': 'integer',
                'description': 'Maximum number of results',
                'default': 6,
              },
            },
            'required': ['query'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'fetch_webpage',
          'description':
              'Fetch webpage content from URL and return readable plain text.',
          'parameters': {
            'type': 'object',
            'properties': {
              'url': {'type': 'string', 'description': 'http/https page URL'},
              'max_chars': {
                'type': 'integer',
                'description': 'Max characters of extracted text',
                'default': 6000,
              },
            },
            'required': ['url'],
          },
        },
      },
    ];
  }

  List<Map<String, dynamic>> _buildWebTools({
    bool includeDownloadAsset = true,
  }) {
    final tools = <Map<String, dynamic>>[
      {
        'type': 'function',
        'function': {
          'name': 'web_search',
          'description':
              'Search the web and return candidate URLs with title/snippet.',
          'parameters': {
            'type': 'object',
            'properties': {
              'query': {'type': 'string', 'description': 'Search keywords'},
              'max_results': {
                'type': 'integer',
                'description': 'Maximum number of results',
                'default': 6,
              },
            },
            'required': ['query'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'fetch_webpage',
          'description':
              'Fetch webpage content from URL and return readable plain text.',
          'parameters': {
            'type': 'object',
            'properties': {
              'url': {'type': 'string', 'description': 'http/https page URL'},
              'max_chars': {
                'type': 'integer',
                'description': 'Max characters of extracted text',
                'default': 6000,
              },
            },
            'required': ['url'],
          },
        },
      },
    ];
    if (includeDownloadAsset) {
      tools.add({
        'type': 'function',
        'function': {
          'name': 'download_asset',
          'description':
              'Download a remote file to project path (requires file-system permission and project folder).',
          'parameters': {
            'type': 'object',
            'properties': {
              'url': {'type': 'string', 'description': 'Remote file URL'},
              'path': {
                'type': 'string',
                'description': 'Relative destination path in project',
              },
              'overwrite': {
                'type': 'boolean',
                'description': 'Whether to overwrite existing file',
                'default': true,
              },
              'max_bytes': {
                'type': 'integer',
                'description': 'Max allowed download size in bytes',
                'default': _downloadAssetMaxBytes,
              },
            },
            'required': ['url', 'path'],
          },
        },
      });
    }
    return tools;
  }

  List<Map<String, dynamic>> _buildGodotMcpTools() {
    return const [
      {
        'type': 'function',
        'function': {
          'name': 'godot_get_version',
          'description': 'Get Godot version from remote godot-mcp bridge.',
          'parameters': {'type': 'object', 'properties': {}, 'required': []},
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'godot_list_projects',
          'description':
              'List Godot projects on bridge host under a directory.',
          'parameters': {
            'type': 'object',
            'properties': {
              'directory': {
                'type': 'string',
                'description': 'Directory on bridge host',
              },
              'recursive': {
                'type': 'boolean',
                'description': 'Search recursively',
                'default': false,
              },
            },
            'required': ['directory'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'godot_get_project_info',
          'description': 'Get project metadata by project path on bridge host.',
          'parameters': {
            'type': 'object',
            'properties': {
              'project_path': {
                'type': 'string',
                'description': 'Project directory on bridge host',
              },
            },
            'required': ['project_path'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'godot_launch_editor',
          'description': 'Launch Godot editor for project on bridge host.',
          'parameters': {
            'type': 'object',
            'properties': {
              'project_path': {
                'type': 'string',
                'description': 'Project directory on bridge host',
              },
            },
            'required': ['project_path'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'godot_run_project',
          'description': 'Run project in debug mode on bridge host.',
          'parameters': {
            'type': 'object',
            'properties': {
              'project_path': {
                'type': 'string',
                'description': 'Project directory on bridge host',
              },
              'scene': {
                'type': 'string',
                'description': 'Optional scene path to run',
              },
            },
            'required': ['project_path'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'godot_get_debug_output',
          'description': 'Read latest debug output from active run.',
          'parameters': {'type': 'object', 'properties': {}, 'required': []},
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'godot_stop_project',
          'description': 'Stop currently running Godot project.',
          'parameters': {'type': 'object', 'properties': {}, 'required': []},
        },
      },
    ];
  }

  Future<String> _executeFsTool(
    _ToolCall call, {
    required _AiRoundDraft roundDraft,
  }) async {
    final args = _decodeToolArguments(call.argumentsJson);
    final name = call.name;

    if (name == 'web_search') {
      final query = _readArgString(args, 'query');
      final maxResults = _readArgInt(
        args,
        'max_results',
        fallback: 6,
      ).clamp(1, 12);
      final results = await _searchWeb(
        query: query,
        maxResults: maxResults.toInt(),
      );
      setState(() {
        _fileOpsStatus = 'AI 联网搜索完成: $query (${results.length}条)';
      });
      return jsonEncode(<String, dynamic>{
        'ok': true,
        'action': 'web_search',
        'query': query,
        'count': results.length,
        'results': results,
      });
    }

    if (name == 'fetch_webpage') {
      final url = _readArgString(args, 'url');
      final maxChars = _readArgInt(
        args,
        'max_chars',
        fallback: 6000,
      ).clamp(800, 20000);
      final result = await _fetchWebpage(url: url, maxChars: maxChars.toInt());
      setState(() {
        _fileOpsStatus = 'AI 已抓取网页内容';
      });
      return jsonEncode(<String, dynamic>{
        'ok': true,
        'action': 'fetch_webpage',
        ...result,
      });
    }

    if (_isGodotMcpTool(name)) {
      return _executeGodotMcpTool(name, args);
    }

    if (name == 'run_command') {
      final command = _readArgString(args, 'command');
      final timeoutMs = _readArgInt(args, 'timeout_ms', fallback: 20000);
      final maxOutputBytes = _readArgInt(
        args,
        'max_output_bytes',
        fallback: 131072,
      );
      final result = await _executePrimaryBackendCommand(
        command: command,
        timeoutMs: timeoutMs,
        maxOutputBytes: maxOutputBytes,
      );
      setState(() {
        _fileOpsStatus = 'AI executed local command: $command';
      });
      return jsonEncode(<String, dynamic>{
        'ok': result['ok'] == true,
        'action': 'run_command',
        ...result,
      });
    }

    if (name == 'android_gradle_build') {
      final task = _readArgString(args, 'task');
      final timeoutMs = _readArgInt(args, 'timeout_ms', fallback: 120000);
      final maxOutputBytes = _readArgInt(
        args,
        'max_output_bytes',
        fallback: 262144,
      );
      final result = await _runAndroidGradleBuildTool(
        task: task,
        timeoutMs: timeoutMs,
        maxOutputBytes: maxOutputBytes,
      );
      setState(() {
        _fileOpsStatus = 'AI built Android project: $task';
      });
      return jsonEncode(result);
    }

    if (name == 'android_install_apk') {
      final apkPath = _readArgString(args, 'apk_path');
      final replace = _readArgBool(args, 'replace', fallback: true);
      final grantAll = _readArgBool(args, 'grant_all', fallback: false);
      final timeoutMs = _readArgInt(args, 'timeout_ms', fallback: 60000);
      final maxOutputBytes = _readArgInt(
        args,
        'max_output_bytes',
        fallback: 196608,
      );
      final result = await _runAndroidInstallApkTool(
        apkPath: apkPath,
        replace: replace,
        grantAll: grantAll,
        timeoutMs: timeoutMs,
        maxOutputBytes: maxOutputBytes,
      );
      setState(() {
        _fileOpsStatus = 'AI installed APK: $apkPath';
      });
      return jsonEncode(result);
    }

    if (name == 'android_logcat') {
      final filterSpec = _readArgString(args, 'filter_spec', fallback: '');
      final clearBefore = _readArgBool(args, 'clear_before', fallback: false);
      final timeoutMs = _readArgInt(args, 'timeout_ms', fallback: 20000);
      final maxOutputBytes = _readArgInt(
        args,
        'max_output_bytes',
        fallback: 262144,
      );
      final result = await _runAndroidLogcatTool(
        filterSpec: filterSpec,
        clearBefore: clearBefore,
        timeoutMs: timeoutMs,
        maxOutputBytes: maxOutputBytes,
      );
      setState(() {
        _fileOpsStatus = 'AI captured logcat';
      });
      return jsonEncode(result);
    }

    if (name == 'android_decompile_apk') {
      final apkPath = _readArgString(args, 'apk_path');
      final reverseLabel = _readArgString(args, 'reverse_label', fallback: '');
      final timeoutMs = _readArgInt(args, 'timeout_ms', fallback: 120000);
      final maxOutputBytes = _readArgInt(
        args,
        'max_output_bytes',
        fallback: 262144,
      );
      final result = await _runAndroidApktoolDecodeTool(
        apkPath: apkPath,
        reverseLabel: reverseLabel,
        timeoutMs: timeoutMs,
        maxOutputBytes: maxOutputBytes,
      );
      setState(() {
        _fileOpsStatus = 'AI decoded APK: $apkPath';
      });
      return jsonEncode(result);
    }

    if (name == 'android_run_jadx') {
      final apkPath = _readArgString(args, 'apk_path');
      final reverseLabel = _readArgString(args, 'reverse_label', fallback: '');
      final timeoutMs = _readArgInt(args, 'timeout_ms', fallback: 120000);
      final maxOutputBytes = _readArgInt(
        args,
        'max_output_bytes',
        fallback: 262144,
      );
      final result = await _runAndroidJadxTool(
        apkPath: apkPath,
        reverseLabel: reverseLabel,
        timeoutMs: timeoutMs,
        maxOutputBytes: maxOutputBytes,
      );
      setState(() {
        _fileOpsStatus = 'AI ran JADX: $apkPath';
      });
      return jsonEncode(result);
    }

    if (name == 'android_search_jadx') {
      final query = _readArgString(args, 'query');
      final reverseLabel = _readArgString(args, 'reverse_label', fallback: '');
      final caseSensitive = _readArgBool(
        args,
        'case_sensitive',
        fallback: false,
      );
      final maxResults = _readArgInt(args, 'max_results', fallback: 40);
      final timeoutMs = _readArgInt(args, 'timeout_ms', fallback: 20000);
      final maxOutputBytes = _readArgInt(
        args,
        'max_output_bytes',
        fallback: 196608,
      );
      final result = await _runAndroidJadxSearchTool(
        query: query,
        reverseLabel: reverseLabel,
        caseSensitive: caseSensitive,
        maxResults: maxResults,
        timeoutMs: timeoutMs,
        maxOutputBytes: maxOutputBytes,
      );
      setState(() {
        _fileOpsStatus = 'AI searched JADX output: $query';
      });
      return jsonEncode(result);
    }

    if (name == 'android_rebuild_apk') {
      final reverseLabel = _readArgString(args, 'reverse_label', fallback: '');
      final timeoutMs = _readArgInt(args, 'timeout_ms', fallback: 120000);
      final maxOutputBytes = _readArgInt(
        args,
        'max_output_bytes',
        fallback: 262144,
      );
      final result = await _runAndroidApktoolBuildTool(
        reverseLabel: reverseLabel,
        timeoutMs: timeoutMs,
        maxOutputBytes: maxOutputBytes,
      );
      setState(() {
        _fileOpsStatus = 'AI rebuilt reverse APK';
      });
      return jsonEncode(result);
    }

    if (name == 'android_sign_apk') {
      final reverseLabel = _readArgString(args, 'reverse_label', fallback: '');
      final timeoutMs = _readArgInt(args, 'timeout_ms', fallback: 120000);
      final maxOutputBytes = _readArgInt(
        args,
        'max_output_bytes',
        fallback: 196608,
      );
      final result = await _runAndroidSignApkTool(
        reverseLabel: reverseLabel,
        timeoutMs: timeoutMs,
        maxOutputBytes: maxOutputBytes,
      );
      setState(() {
        _fileOpsStatus = 'AI signed rebuilt APK';
      });
      return jsonEncode(result);
    }

    if (name == 'shell_session_start') {
      await _ensureMirroredWorkspaceIfAvailable();
      await _startShellSession();
      await _refreshShellSnapshot(autoScroll: true);
      return jsonEncode(<String, dynamic>{
        'ok': true,
        'action': 'shell_session_start',
        'is_running': _localShellSnapshot.isRunning,
        'working_directory': _localShellSnapshot.workingDirectory,
        'lines': _localShellSnapshot.lines,
      });
    }

    if (name == 'shell_session_stop') {
      await _stopShellSession();
      await _refreshShellSnapshot(autoScroll: true);
      return jsonEncode(<String, dynamic>{
        'ok': true,
        'action': 'shell_session_stop',
        'is_running': _localShellSnapshot.isRunning,
        'working_directory': _localShellSnapshot.workingDirectory,
        'lines': _localShellSnapshot.lines,
      });
    }

    if (name == 'shell_session_snapshot') {
      await _refreshShellSnapshot();
      return jsonEncode(<String, dynamic>{
        'ok': true,
        'action': 'shell_session_snapshot',
        'is_running': _localShellSnapshot.isRunning,
        'working_directory': _localShellSnapshot.workingDirectory,
        'last_error': _localShellSnapshot.lastError,
        'lines': _localShellSnapshot.lines,
      });
    }

    if (name == 'shell_session_input') {
      await _ensureMirroredWorkspaceIfAvailable();
      final input = _readArgString(args, 'input');
      await _sendShellInput(input);
      await _refreshShellSnapshot(autoScroll: true);
      return jsonEncode(<String, dynamic>{
        'ok': true,
        'action': 'shell_session_input',
        'input': input,
        'is_running': _localShellSnapshot.isRunning,
        'working_directory': _localShellSnapshot.workingDirectory,
        'lines': _localShellSnapshot.lines,
      });
    }

    if (name == 'shell_session_clear') {
      await _clearShellBuffer();
      await _refreshShellSnapshot();
      return jsonEncode(<String, dynamic>{
        'ok': true,
        'action': 'shell_session_clear',
        'is_running': _localShellSnapshot.isRunning,
        'working_directory': _localShellSnapshot.workingDirectory,
        'lines': _localShellSnapshot.lines,
      });
    }

    if (name == 'download_asset' && !_aiFsGranted) {
      throw Exception('download_asset 需要先在设置中开启 AI 文件夹读写权限');
    }
    if (name == 'download_asset' && _projectRootPath == null) {
      throw Exception('download_asset 需要先选择项目文件夹');
    }

    if (!_aiFsGranted) {
      throw Exception('未授予 AI 文件读写权限');
    }
    if (_projectRootPath == null) {
      throw Exception('未选择项目文件夹');
    }

    await _ensureMirroredWorkspaceIfAvailable();

    if (name == 'read_file') {
      final path = _readArgString(args, 'path');
      final content = await _readFileText(path);
      _filePathController.text = path;
      _fileContentController.text = _truncateModelOutput(content, 12000);
      setState(() {
        _fileOpsStatus = 'AI 读取成功: $path';
      });
      return jsonEncode({
        'ok': true,
        'path': path,
        'content': _truncateModelOutput(content, 12000),
      });
    }

    if (name == 'read_file_part') {
      final path = _readArgString(args, 'path');
      final startLine = _readArgInt(args, 'start_line', fallback: 1);
      final maxLines = _readArgInt(args, 'max_lines', fallback: 160);
      final result = await _readFilePart(
        path,
        startLine: startLine,
        maxLines: maxLines,
      );
      _filePathController.text = path;
      _fileContentController.text = _truncateModelOutput(
        result['content']?.toString() ?? '',
        12000,
      );
      setState(() {
        _fileOpsStatus = 'AI read file slice: $path';
      });
      return jsonEncode(result);
    }

    if (name == 'find_files') {
      final pattern = _readArgString(args, 'pattern');
      final path = _readArgString(args, 'path', fallback: '.');
      final limit = _readArgInt(
        args,
        'limit',
        fallback: 80,
      ).clamp(1, 240).toInt();
      final caseSensitive = _readArgBool(
        args,
        'case_sensitive',
        fallback: false,
      );
      final result = await _findProjectFiles(
        pattern: pattern,
        relativePath: path,
        limit: limit,
        caseSensitive: caseSensitive,
      );
      setState(() {
        _fileOpsStatus = 'AI searched files: $pattern';
      });
      return jsonEncode(result);
    }

    if (name == 'file_exists') {
      final path = _readArgString(args, 'path');
      final result = await _readFileExists(path);
      setState(() {
        _fileOpsStatus = 'AI checked path existence: $path';
      });
      return jsonEncode(result);
    }

    if (name == 'write_file') {
      final path = _readArgString(args, 'path');
      final content = _readArgString(args, 'content');
      await _captureUndoSnapshotIfNeeded(roundDraft, path);
      await _writeFileText(path, content);
      await _loadProjectFolder(_projectRootPath!, silent: true);
      _filePathController.text = path;
      _fileContentController.text = content;
      setState(() {
        _fileOpsStatus = 'AI 写入成功: $path';
      });
      return jsonEncode({
        'ok': true,
        'action': 'write_file',
        'path': path,
        'bytes': utf8.encode(content).length,
      });
    }

    if (name == 'replace_in_file') {
      final path = _readArgString(args, 'path');
      final oldText = _readArgString(args, 'old_text');
      final newText = _readArgString(args, 'new_text', fallback: '');
      final replaceAll = _readArgBool(args, 'replace_all', fallback: false);
      await _captureUndoSnapshotIfNeeded(roundDraft, path);
      final result = await _replaceTextInFile(
        relativePath: path,
        oldText: oldText,
        newText: newText,
        replaceAll: replaceAll,
      );
      await _loadProjectFolder(_projectRootPath!, silent: true);
      _filePathController.text = path;
      setState(() {
        _fileOpsStatus = 'AI replaced text in: $path';
      });
      return jsonEncode(<String, dynamic>{
        'ok': true,
        'action': 'replace_in_file',
        ...result,
      });
    }

    if (name == 'create_file') {
      final path = _readArgString(args, 'path');
      final content = _readArgString(args, 'content', fallback: '');
      await _captureUndoSnapshotIfNeeded(roundDraft, path);
      await _writeFileText(path, content);
      await _loadProjectFolder(_projectRootPath!, silent: true);
      _filePathController.text = path;
      _fileContentController.text = content;
      setState(() {
        _fileOpsStatus = 'AI 新建文件成功: $path';
      });
      return jsonEncode({'ok': true, 'action': 'create_file', 'path': path});
    }

    if (name == 'create_dir') {
      final path = _readArgString(args, 'path');
      await _captureUndoSnapshotIfNeeded(roundDraft, path);
      await _createDirectory(path);
      await _loadProjectFolder(_projectRootPath!, silent: true);
      _filePathController.text = path;
      setState(() {
        _fileOpsStatus = 'AI 新建目录成功: $path';
      });
      return jsonEncode({'ok': true, 'action': 'create_dir', 'path': path});
    }

    if (name == 'delete_entry') {
      final path = _readArgString(args, 'path');
      await _captureUndoSnapshotIfNeeded(roundDraft, path);
      await _deleteEntry(path);
      await _loadProjectFolder(_projectRootPath!, silent: true);
      _filePathController.text = path;
      setState(() {
        _fileOpsStatus = 'AI 删除成功: $path';
      });
      return jsonEncode({'ok': true, 'action': 'delete_entry', 'path': path});
    }

    if (name == 'copy_file') {
      final fromPath = _readArgString(args, 'from_path');
      final toPath = _readArgString(args, 'to_path');
      await _captureUndoSnapshotIfNeeded(roundDraft, toPath);
      final result = await _copyProjectEntry(fromPath, toPath);
      await _loadProjectFolder(_projectRootPath!, silent: true);
      _filePathController.text = toPath;
      setState(() {
        _fileOpsStatus = 'AI copied entry: $fromPath -> $toPath';
      });
      return jsonEncode(result);
    }

    if (name == 'move_file') {
      final fromPath = _readArgString(args, 'from_path');
      final toPath = _readArgString(args, 'to_path');
      await _captureUndoSnapshotIfNeeded(roundDraft, fromPath);
      await _captureUndoSnapshotIfNeeded(roundDraft, toPath);
      final result = await _moveProjectEntry(fromPath, toPath);
      await _loadProjectFolder(_projectRootPath!, silent: true);
      _filePathController.text = toPath;
      setState(() {
        _fileOpsStatus = 'AI moved entry: $fromPath -> $toPath';
      });
      return jsonEncode(result);
    }

    if (name == 'apply_patch') {
      final operations = _readArgList(args, 'operations');
      final result = await _applyStructuredPatch(
        roundDraft: roundDraft,
        operations: operations,
      );
      await _loadProjectFolder(_projectRootPath!, silent: true);
      setState(() {
        _fileOpsStatus = 'AI applied structured patch';
      });
      return jsonEncode(result);
    }

    if (name == 'list_files') {
      final limit = _readArgInt(args, 'limit', fallback: 80).clamp(1, 200);
      final effectiveRoot = _requireEffectiveProjectAccessRootPath();
      final scan = await _scanProjectSnippets(effectiveRoot);
      if (scan.readError != null) {
        throw Exception('读取文件索引失败: ${scan.readError}');
      }
      _projectFiles = scan.snippets;
      final files = _projectFiles
          .take(limit)
          .map(
            (f) => {
              'path': f.path,
              'size_bytes': f.sizeBytes,
              'binary': f.isBinary,
            },
          )
          .toList();
      setState(() {
        _fileOpsStatus = 'AI 读取文件索引: ${files.length}条';
      });
      return jsonEncode({
        'ok': true,
        'root': effectiveRoot,
        'count': _projectFiles.length,
        'files': files,
      });
    }

    if (name == 'list_dir') {
      final path = _readArgString(args, 'path', fallback: '.');
      final limit = _readArgInt(args, 'limit', fallback: 120).clamp(1, 240);
      final result = await _listDirectoryEntries(path, limit: limit);
      setState(() {
        _fileOpsStatus = 'AI listed directory: $path';
      });
      return jsonEncode(<String, dynamic>{
        'ok': true,
        'action': 'list_dir',
        ...result,
      });
    }

    if (name == 'file_info') {
      final path = _readArgString(args, 'path');
      final result = await _readFileInfo(path);
      setState(() {
        _fileOpsStatus = 'AI inspected path: $path';
      });
      return jsonEncode(<String, dynamic>{
        'ok': true,
        'action': 'file_info',
        ...result,
      });
    }

    if (name == 'grep_code') {
      final query = _readArgString(args, 'query');
      final path = _readArgString(args, 'path', fallback: '.');
      final limit = _readArgInt(args, 'limit', fallback: 40).clamp(1, 120);
      final caseSensitive = _readArgBool(
        args,
        'case_sensitive',
        fallback: false,
      );
      final result = await _grepProjectCode(
        query: query,
        relativePath: path,
        limit: limit,
        caseSensitive: caseSensitive,
      );
      setState(() {
        _fileOpsStatus = 'AI searched code for: $query';
      });
      return jsonEncode(<String, dynamic>{
        'ok': true,
        'action': 'grep_code',
        ...result,
      });
    }

    if (name == 'create_project') {
      final projectName = _readArgString(args, 'name');
      final readme = _readArgString(args, 'readme', fallback: '').trim();
      await _captureUndoSnapshotIfNeeded(roundDraft, projectName);
      await _createDirectory(projectName);
      final normalized = _normalizeInputPath(projectName);
      final readmeContent = readme.isEmpty
          ? '# ${normalized.split('/').last}'
          : readme;
      await _writeFileText('$normalized/README.md', '$readmeContent\n');
      await _loadProjectFolder(_projectRootPath!, silent: true);
      _filePathController.text = normalized;
      setState(() {
        _fileOpsStatus = 'AI 创建项目成功: $normalized';
      });
      return jsonEncode({
        'ok': true,
        'action': 'create_project',
        'project_path': normalized,
        'readme': '$normalized/README.md',
      });
    }

    if (name == 'git_status') {
      final timeoutMs = _readArgInt(args, 'timeout_ms', fallback: 20000);
      final maxOutputBytes = _readArgInt(
        args,
        'max_output_bytes',
        fallback: 131072,
      );
      final result = await _runGitStatusTool(
        timeoutMs: timeoutMs,
        maxOutputBytes: maxOutputBytes,
      );
      setState(() {
        _fileOpsStatus = 'AI ran git status';
      });
      return jsonEncode(result);
    }

    if (name == 'git_diff') {
      final path = _readArgString(args, 'path', fallback: '');
      final staged = _readArgBool(args, 'staged', fallback: false);
      final timeoutMs = _readArgInt(args, 'timeout_ms', fallback: 20000);
      final maxOutputBytes = _readArgInt(
        args,
        'max_output_bytes',
        fallback: 131072,
      );
      final result = await _runGitDiffTool(
        path: path,
        staged: staged,
        timeoutMs: timeoutMs,
        maxOutputBytes: maxOutputBytes,
      );
      setState(() {
        _fileOpsStatus = 'AI ran git diff';
      });
      return jsonEncode(result);
    }

    if (name == 'git_log') {
      final limit = _readArgInt(args, 'limit', fallback: 20);
      final timeoutMs = _readArgInt(args, 'timeout_ms', fallback: 20000);
      final maxOutputBytes = _readArgInt(
        args,
        'max_output_bytes',
        fallback: 131072,
      );
      final result = await _runGitLogTool(
        limit: limit,
        timeoutMs: timeoutMs,
        maxOutputBytes: maxOutputBytes,
      );
      setState(() {
        _fileOpsStatus = 'AI ran git log';
      });
      return jsonEncode(result);
    }

    if (name == 'git_show') {
      final ref = _readArgString(args, 'ref');
      final path = _readArgString(args, 'path', fallback: '');
      final timeoutMs = _readArgInt(args, 'timeout_ms', fallback: 20000);
      final maxOutputBytes = _readArgInt(
        args,
        'max_output_bytes',
        fallback: 131072,
      );
      final result = await _runGitShowTool(
        ref: ref,
        path: path,
        timeoutMs: timeoutMs,
        maxOutputBytes: maxOutputBytes,
      );
      setState(() {
        _fileOpsStatus = 'AI ran git show';
      });
      return jsonEncode(result);
    }

    if (name == 'download_asset') {
      final url = _readArgString(args, 'url');
      final path = _readArgString(args, 'path');
      final overwrite = _readArgBool(args, 'overwrite', fallback: true);
      final requestedMaxBytes = _readArgInt(
        args,
        'max_bytes',
        fallback: _downloadAssetMaxBytes,
      );
      final maxBytes = _normalizeDownloadMaxBytes(requestedMaxBytes);
      await _captureUndoSnapshotIfNeeded(roundDraft, path);
      final downloaded = await _downloadUrlToProject(
        url: url,
        relativePath: path,
        overwrite: overwrite,
        maxBytes: maxBytes,
      );
      await _loadProjectFolder(_projectRootPath!, silent: true);
      _filePathController.text = path;
      setState(() {
        _fileOpsStatus = 'AI 下载素材成功: $path';
      });
      return jsonEncode(<String, dynamic>{
        'ok': true,
        'action': 'download_asset',
        'url': url,
        ...downloaded,
      });
    }

    throw Exception('未知工具: $name');
  }

  bool _isGodotMcpTool(String toolName) {
    switch (toolName) {
      case 'godot_get_version':
      case 'godot_list_projects':
      case 'godot_get_project_info':
      case 'godot_launch_editor':
      case 'godot_run_project':
      case 'godot_get_debug_output':
      case 'godot_stop_project':
        return true;
      default:
        return false;
    }
  }

  String _mapToRemoteGodotTool(String toolName) {
    switch (toolName) {
      case 'godot_get_version':
        return 'get_godot_version';
      case 'godot_list_projects':
        return 'list_projects';
      case 'godot_get_project_info':
        return 'get_project_info';
      case 'godot_launch_editor':
        return 'launch_editor';
      case 'godot_run_project':
        return 'run_project';
      case 'godot_get_debug_output':
        return 'get_debug_output';
      case 'godot_stop_project':
        return 'stop_project';
      default:
        throw Exception('未知 Godot MCP 工具: $toolName');
    }
  }

  Future<String> _executeGodotMcpTool(
    String toolName,
    Map<String, dynamic> args,
  ) async {
    if (!_godotMcpReady) {
      throw Exception('Godot MCP 未启用或网关地址为空');
    }
    if (!await _hasNetworkConnectivity()) {
      throw Exception('当前网络不可用，无法连接 Godot MCP 网关');
    }

    final remoteTool = _mapToRemoteGodotTool(toolName);
    final remoteArgs = <String, dynamic>{};

    if (toolName == 'godot_list_projects') {
      remoteArgs['directory'] = _readArgString(args, 'directory');
      remoteArgs['recursive'] = _readArgBool(
        args,
        'recursive',
        fallback: false,
      );
    } else if (toolName == 'godot_get_project_info' ||
        toolName == 'godot_launch_editor') {
      remoteArgs['projectPath'] = _readArgString(args, 'project_path');
    } else if (toolName == 'godot_run_project') {
      remoteArgs['projectPath'] = _readArgString(args, 'project_path');
      final scene = _readArgString(args, 'scene', fallback: '').trim();
      if (scene.isNotEmpty) {
        remoteArgs['scene'] = scene;
      }
    }

    final response = await _callGodotMcpBridge(
      path: '/tool',
      payload: <String, dynamic>{'name': remoteTool, 'arguments': remoteArgs},
    );
    final result = response['result'];
    setState(() {
      _fileOpsStatus = 'Godot MCP 调用成功: $remoteTool';
    });
    return jsonEncode(<String, dynamic>{
      'ok': true,
      'action': toolName,
      'remote_tool': remoteTool,
      'result': result,
    });
  }

  Uri _resolveGodotBridgeUri(String path) {
    final base = _godotMcpBridgeUrl.trim();
    if (base.isEmpty) {
      throw Exception('Godot MCP 网关地址未配置');
    }
    final baseUri = Uri.parse(base);
    if (!baseUri.hasScheme) {
      throw Exception('Godot MCP 网关地址缺少协议，例如 http://');
    }
    return baseUri.resolve(path);
  }

  Map<String, String> _buildGodotBridgeHeaders() {
    final headers = <String, String>{
      HttpHeaders.acceptHeader: 'application/json',
      HttpHeaders.contentTypeHeader: 'application/json',
    };
    final token = _godotMcpBridgeToken.trim();
    if (token.isNotEmpty) {
      headers['x-bridge-token'] = token;
      headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> _callGodotMcpBridge({
    required String path,
    required Map<String, dynamic> payload,
  }) async {
    final uri = _resolveGodotBridgeUri(path);
    final client = _createHttpClient(improveNetworkCompatibility: true);
    HttpClientRequest? request;
    try {
      request = await client.postUrl(uri).timeout(const Duration(seconds: 20));
      _applyRequestNetworkProfile(request, improveNetworkCompatibility: true);
      for (final entry in _buildGodotBridgeHeaders().entries) {
        request.headers.set(entry.key, entry.value);
      }
      request.add(utf8.encode(jsonEncode(payload)));
      final response = await request.close().timeout(
        const Duration(seconds: 40),
      );
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final snippet = _condenseErrorBody(body);
        final suffix = snippet.isEmpty ? '' : ' - $snippet';
        throw Exception('Godot MCP HTTP ${response.statusCode}$suffix');
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Godot MCP 返回格式异常');
      }
      final ok = decoded['ok'] == true;
      if (!ok) {
        final error = decoded['error']?.toString().trim() ?? 'unknown';
        throw Exception('Godot MCP 调用失败: $error');
      }
      return decoded;
    } finally {
      client.close(force: true);
    }
  }

  Map<String, dynamic> _decodeToolArguments(String raw) {
    final content = raw.trim();
    if (content.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(content);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    throw Exception('工具参数必须是 JSON 对象');
  }

  String _readArgString(
    Map<String, dynamic> args,
    String key, {
    String? fallback,
  }) {
    final value = args[key];
    if (value == null) {
      if (fallback != null) return fallback;
      throw Exception('工具参数缺失: $key');
    }
    final text = value.toString();
    if (text.trim().isEmpty && fallback == null) {
      throw Exception('工具参数不能为空: $key');
    }
    return text;
  }

  int _readArgInt(
    Map<String, dynamic> args,
    String key, {
    required int fallback,
  }) {
    final value = args[key];
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  bool _readArgBool(
    Map<String, dynamic> args,
    String key, {
    required bool fallback,
  }) {
    final value = args[key];
    if (value == null) return fallback;
    if (value is bool) return value;
    final text = value.toString().trim().toLowerCase();
    if (text == 'true' || text == '1' || text == 'yes') return true;
    if (text == 'false' || text == '0' || text == 'no') return false;
    return fallback;
  }

  List<dynamic> _readArgList(Map<String, dynamic> args, String key) {
    final value = args[key];
    if (value is List) {
      return value;
    }
    throw Exception('Tool argument must be an array: $key');
  }

  Future<List<Map<String, dynamic>>> _searchWeb({
    required String query,
    required int maxResults,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      throw Exception('搜索关键词不能为空');
    }
    if (!await _hasNetworkConnectivity()) {
      throw Exception('当前网络不可用，请先检查网络后重试');
    }

    final improveNetworkCompatibility =
        _activeProviderConfig.improveNetworkCompatibility;
    final results = <Map<String, dynamic>>[];
    final seenUrls = <String>{};
    final errors = <String>[];

    void merge(List<Map<String, dynamic>> source) {
      for (final item in source) {
        final url = item['url']?.toString().trim() ?? '';
        if (url.isEmpty || !seenUrls.add(url)) continue;
        results.add(item);
        if (results.length >= maxResults) return;
      }
    }

    try {
      final bingResults = await _searchByBingHtml(
        query: normalizedQuery,
        maxResults: maxResults,
        host: 'www.bing.com',
        sourceLabel: 'bing',
        improveNetworkCompatibility: improveNetworkCompatibility,
      );
      merge(bingResults);
    } catch (error) {
      errors.add('Bing: $error');
    }

    if (results.length < maxResults) {
      try {
        final bingCnResults = await _searchByBingHtml(
          query: normalizedQuery,
          maxResults: maxResults,
          host: 'cn.bing.com',
          sourceLabel: 'bing_cn',
          improveNetworkCompatibility: improveNetworkCompatibility,
        );
        merge(bingCnResults);
      } catch (error) {
        errors.add('Bing CN: $error');
      }
    }

    if (results.length < maxResults) {
      try {
        final bingRssResults = await _searchByBingRss(
          query: normalizedQuery,
          maxResults: maxResults,
          host: 'www.bing.com',
          sourceLabel: 'bing_rss',
          improveNetworkCompatibility: improveNetworkCompatibility,
        );
        merge(bingRssResults);
      } catch (error) {
        errors.add('Bing RSS: $error');
      }
    }

    if (results.length < maxResults) {
      try {
        final bingCnRssResults = await _searchByBingRss(
          query: normalizedQuery,
          maxResults: maxResults,
          host: 'cn.bing.com',
          sourceLabel: 'bing_cn_rss',
          improveNetworkCompatibility: improveNetworkCompatibility,
        );
        merge(bingCnRssResults);
      } catch (error) {
        errors.add('Bing CN RSS: $error');
      }
    }

    if (results.length < maxResults) {
      try {
        final ddgResults = await _searchByDuckDuckGoHtml(
          query: normalizedQuery,
          maxResults: maxResults,
          improveNetworkCompatibility: improveNetworkCompatibility,
        );
        merge(ddgResults);
      } catch (error) {
        errors.add('DuckDuckGo: $error');
      }
    }

    if (results.length < maxResults) {
      try {
        final ddgLiteResults = await _searchByDuckDuckGoLite(
          query: normalizedQuery,
          maxResults: maxResults,
          improveNetworkCompatibility: improveNetworkCompatibility,
        );
        merge(ddgLiteResults);
      } catch (error) {
        errors.add('DuckDuckGo Lite: $error');
      }
    }

    if (results.isEmpty) {
      final detail = errors.isEmpty ? '' : ' (${errors.join(' | ')})';
      throw Exception('未获取到搜索结果$detail');
    }
    return results.take(maxResults).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> _searchByDuckDuckGoHtml({
    required String query,
    required int maxResults,
    required bool improveNetworkCompatibility,
  }) async {
    final uris = <Uri>[
      Uri.https('duckduckgo.com', '/html/', <String, String>{
        'q': query,
        'kl': 'wt-wt',
      }),
      Uri.https('html.duckduckgo.com', '/html/', <String, String>{
        'q': query,
        'kl': 'wt-wt',
      }),
    ];
    final errors = <String>[];

    for (final uri in uris) {
      try {
        final body = await _httpGetText(
          uri: uri,
          improveNetworkCompatibility: improveNetworkCompatibility,
          maxBytes: 3145728,
        );
        final results = <Map<String, dynamic>>[];
        final linkPattern = RegExp(
          r'<a[^>]*class="[^"]*result__a[^"]*"[^>]*href="([^"]+)"[^>]*>(.*?)</a>',
          caseSensitive: false,
          dotAll: true,
        );

        for (final match in linkPattern.allMatches(body)) {
          final rawHref = match.group(1) ?? '';
          final url = _normalizeSearchResultUrl(rawHref);
          if (url.isEmpty) continue;
          final title = _sanitizeHtmlText(match.group(2) ?? '');
          if (title.isEmpty) continue;

          final snippetWindowStart = (match.start - 360).clamp(0, body.length);
          final snippetWindowEnd = (match.end + 820).clamp(0, body.length);
          final snippetWindow = body.substring(
            snippetWindowStart,
            snippetWindowEnd,
          );
          final snippetMatch = RegExp(
            r'<a[^>]*class="[^"]*result__snippet[^"]*"[^>]*>(.*?)</a>|<div[^>]*class="[^"]*result__snippet[^"]*"[^>]*>(.*?)</div>',
            caseSensitive: false,
            dotAll: true,
          ).firstMatch(snippetWindow);
          final snippet = _sanitizeHtmlText(
            snippetMatch?.group(1) ?? snippetMatch?.group(2) ?? '',
          );

          results.add(<String, dynamic>{
            'title': title,
            'url': url,
            'snippet': snippet,
            'source': 'duckduckgo',
          });
          if (results.length >= maxResults) break;
        }
        if (results.isNotEmpty) {
          return results;
        }
      } catch (error) {
        errors.add('${uri.host}: $error');
      }
    }
    throw Exception(errors.isEmpty ? 'DuckDuckGo 无结果' : errors.join(' | '));
  }

  Future<List<Map<String, dynamic>>> _searchByBingHtml({
    required String query,
    required int maxResults,
    required String host,
    required String sourceLabel,
    required bool improveNetworkCompatibility,
  }) async {
    final uri = Uri.https(host, '/search', <String, String>{
      'q': query,
      'setlang': 'zh-Hans',
      'ensearch': '0',
    });
    final body = await _httpGetText(
      uri: uri,
      improveNetworkCompatibility: improveNetworkCompatibility,
      maxBytes: 3145728,
    );

    final results = <Map<String, dynamic>>[];
    final blockPattern = RegExp(
      r'<li[^>]*class="b_algo"[^>]*>(.*?)</li>',
      caseSensitive: false,
      dotAll: true,
    );
    for (final block in blockPattern.allMatches(body)) {
      final html = block.group(1) ?? '';
      final linkMatch = RegExp(
        r'<h2>\s*<a[^>]*href="(https?://[^"]+)"[^>]*>(.*?)</a>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(html);
      if (linkMatch == null) continue;

      final url = _normalizeSearchResultUrl(linkMatch.group(1) ?? '');
      final title = _sanitizeHtmlText(linkMatch.group(2) ?? '');
      if (url.isEmpty || title.isEmpty) continue;

      final snippetMatch = RegExp(
        r'<div[^>]*class="[^"]*b_caption[^"]*"[^>]*>.*?<p>(.*?)</p>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(html);
      final snippet = _sanitizeHtmlText(snippetMatch?.group(1) ?? '');

      results.add(<String, dynamic>{
        'title': title,
        'url': url,
        'snippet': snippet,
        'source': sourceLabel,
      });
      if (results.length >= maxResults) break;
    }
    return results;
  }

  Future<List<Map<String, dynamic>>> _searchByBingRss({
    required String query,
    required int maxResults,
    required String host,
    required String sourceLabel,
    required bool improveNetworkCompatibility,
  }) async {
    final uri = Uri.https(host, '/search', <String, String>{
      'q': query,
      'format': 'rss',
      'setlang': 'zh-Hans',
      'ensearch': '0',
    });
    final body = await _httpGetText(
      uri: uri,
      improveNetworkCompatibility: improveNetworkCompatibility,
      maxBytes: 1048576,
      headers: const <String, String>{
        HttpHeaders.acceptHeader:
            'application/rss+xml,application/xml;q=0.9,text/xml;q=0.8,*/*;q=0.6',
      },
    );

    final results = <Map<String, dynamic>>[];
    final itemPattern = RegExp(
      r'<item\b[^>]*>(.*?)</item>',
      caseSensitive: false,
      dotAll: true,
    );
    for (final itemMatch in itemPattern.allMatches(body)) {
      final itemXml = itemMatch.group(1) ?? '';
      final titleRaw = RegExp(
        r'<title\b[^>]*>(.*?)</title>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(itemXml)?.group(1);
      final linkRaw = RegExp(
        r'<link\b[^>]*>(.*?)</link>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(itemXml)?.group(1);
      final descRaw = RegExp(
        r'<description\b[^>]*>(.*?)</description>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(itemXml)?.group(1);

      final title = _sanitizeXmlText(titleRaw ?? '');
      final url = _normalizeSearchResultUrl(_sanitizeXmlText(linkRaw ?? ''));
      final snippet = _sanitizeXmlText(descRaw ?? '');
      if (title.isEmpty || url.isEmpty) continue;

      results.add(<String, dynamic>{
        'title': title,
        'url': url,
        'snippet': snippet,
        'source': sourceLabel,
      });
      if (results.length >= maxResults) break;
    }
    return results;
  }

  Future<List<Map<String, dynamic>>> _searchByDuckDuckGoLite({
    required String query,
    required int maxResults,
    required bool improveNetworkCompatibility,
  }) async {
    final uri = Uri.https('lite.duckduckgo.com', '/lite/', <String, String>{
      'q': query,
      'kp': '-1',
    });
    final body = await _httpGetText(
      uri: uri,
      improveNetworkCompatibility: improveNetworkCompatibility,
      maxBytes: 3145728,
    );

    final results = <Map<String, dynamic>>[];
    final links = RegExp(
      r'<a[^>]*href="([^"]+)"[^>]*>(.*?)</a>',
      caseSensitive: false,
      dotAll: true,
    );
    final seen = <String>{};
    for (final match in links.allMatches(body)) {
      final rawHref = match.group(1) ?? '';
      final url = _normalizeSearchResultUrl(rawHref);
      if (url.isEmpty || !seen.add(url)) continue;

      final title = _sanitizeHtmlText(match.group(2) ?? '');
      if (title.isEmpty) continue;
      if (title == 'Next' || title == 'Previous') continue;

      results.add(<String, dynamic>{
        'title': title,
        'url': url,
        'snippet': '',
        'source': 'duckduckgo_lite',
      });
      if (results.length >= maxResults) break;
    }
    return results;
  }

  Future<Map<String, dynamic>> _fetchWebpage({
    required String url,
    required int maxChars,
  }) async {
    if (!await _hasNetworkConnectivity()) {
      throw Exception('当前网络不可用，请先检查网络后重试');
    }
    final parsed = Uri.tryParse(url.trim());
    if (parsed == null || !parsed.hasScheme) {
      throw Exception('URL 无效: $url');
    }
    final scheme = parsed.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      throw Exception('仅支持 http/https 网页');
    }

    final improveNetworkCompatibility =
        _activeProviderConfig.improveNetworkCompatibility;
    final candidates = <Uri>[parsed, ..._buildWebFetchFallbackUris(parsed)];
    final errors = <String>[];

    for (final candidate in candidates) {
      try {
        final body = await _httpGetText(
          uri: candidate,
          improveNetworkCompatibility: improveNetworkCompatibility,
          maxBytes: 3145728,
        );
        final titleMatch = RegExp(
          r'<title[^>]*>(.*?)</title>',
          caseSensitive: false,
          dotAll: true,
        ).firstMatch(body);
        var title = _sanitizeHtmlText(titleMatch?.group(1) ?? '');
        final content = _sanitizeHtmlText(body);
        if (content.isEmpty) {
          throw Exception('网页内容为空或不可解析');
        }
        if (title.isEmpty) {
          title = parsed.host;
        }
        final clipped = content.length <= maxChars
            ? content
            : '${content.substring(0, maxChars)}...';

        return <String, dynamic>{
          'url': parsed.toString(),
          'title': title,
          'content': clipped,
          'content_length': content.length,
          'truncated': content.length > maxChars,
          'fetched_via': candidate.toString(),
          'fallback_used': candidate.toString() != parsed.toString(),
        };
      } catch (error) {
        errors.add('${candidate.host}: $error');
      }
    }
    throw Exception('网页抓取失败: ${errors.join(' | ')}');
  }

  List<Uri> _buildWebFetchFallbackUris(Uri target) {
    final candidates = <Uri>[];
    final hostPath = StringBuffer()
      ..write(target.host)
      ..write(target.path);
    if (target.hasQuery) {
      hostPath
        ..write('?')
        ..write(target.query);
    }
    candidates.add(
      Uri.parse('https://r.jina.ai/http://${hostPath.toString()}'),
    );
    candidates.add(Uri.parse('https://r.jina.ai/http://${target.toString()}'));

    final dedup = <String>{};
    final out = <Uri>[];
    for (final uri in candidates) {
      final text = uri.toString();
      if (!dedup.add(text)) continue;
      out.add(uri);
    }
    return out;
  }

  Future<String> _httpGetText({
    required Uri uri,
    required bool improveNetworkCompatibility,
    Map<String, String> headers = const {},
    int maxBytes = 2097152,
  }) async {
    final requestTimeout = Duration(
      seconds: improveNetworkCompatibility ? 75 : 45,
    );
    final maxAttempts = improveNetworkCompatibility ? 3 : 2;
    Object? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final client = _createHttpClient(
        improveNetworkCompatibility: improveNetworkCompatibility,
      );
      try {
        final request = await client.getUrl(uri).timeout(requestTimeout);
        _applyRequestNetworkProfile(
          request,
          improveNetworkCompatibility: improveNetworkCompatibility,
        );
        request.headers.set(
          HttpHeaders.acceptHeader,
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        );
        for (final entry in headers.entries) {
          final value = entry.value.trim();
          if (value.isEmpty) continue;
          request.headers.set(entry.key, value);
        }
        final response = await request.close().timeout(requestTimeout);
        final bytes = <int>[];
        await for (final chunk in response.timeout(requestTimeout)) {
          bytes.addAll(chunk);
          if (bytes.length > maxBytes) {
            throw Exception('响应内容过大，超过限制 $maxBytes bytes');
          }
        }
        final body = utf8.decode(bytes, allowMalformed: true);
        if (response.statusCode < 200 || response.statusCode >= 300) {
          final snippet = _condenseErrorBody(body);
          final suffix = snippet.isEmpty ? '' : ' - $snippet';
          throw Exception('HTTP ${response.statusCode}$suffix');
        }
        return body;
      } catch (error) {
        lastError = error;
        final retryable = _isTransientNetworkError(error);
        if (!retryable || attempt >= maxAttempts) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 350 * attempt));
      } finally {
        client.close(force: true);
      }
    }
    throw Exception('请求失败: $lastError');
  }

  String _normalizeSearchResultUrl(String rawUrl) {
    var url = _decodeHtmlEntities(rawUrl).trim();
    if (url.isEmpty) return '';
    if (url.startsWith('//')) {
      url = 'https:$url';
    }

    Uri? parsed;
    if (url.startsWith('/')) {
      parsed = Uri.tryParse('https://duckduckgo.com$url');
    } else {
      parsed = Uri.tryParse(url);
    }
    if (parsed == null) return '';

    if (parsed.host.contains('duckduckgo.com') && parsed.path == '/l/') {
      final wrapped = parsed.queryParameters['uddg'] ?? '';
      if (wrapped.trim().isNotEmpty) {
        url = Uri.decodeFull(wrapped);
        parsed = Uri.tryParse(url);
        if (parsed == null) return '';
      }
    }

    if (!parsed.hasScheme) return '';
    final scheme = parsed.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') return '';
    return parsed.toString();
  }

  String _sanitizeHtmlText(String input) {
    final noScript = input
        .replaceAll(
          RegExp(
            r'<script[^>]*>.*?</script>',
            caseSensitive: false,
            dotAll: true,
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
            r'<style[^>]*>.*?</style>',
            caseSensitive: false,
            dotAll: true,
          ),
          ' ',
        );
    final noTags = noScript.replaceAll(
      RegExp(r'<[^>]+>', caseSensitive: false, dotAll: true),
      ' ',
    );
    final decoded = _decodeHtmlEntities(noTags);
    return decoded.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _sanitizeXmlText(String input) {
    var text = input
        .replaceAll('<![CDATA[', '')
        .replaceAll(']]>', '')
        .replaceAll(RegExp(r'<[^>]+>', caseSensitive: false), ' ');
    text = _decodeHtmlEntities(text);
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _decodeHtmlEntities(String input) {
    var text = input;
    const named = <String, String>{
      '&amp;': '&',
      '&quot;': '"',
      '&#39;': "'",
      '&apos;': "'",
      '&lt;': '<',
      '&gt;': '>',
      '&nbsp;': ' ',
    };
    for (final entry in named.entries) {
      text = text.replaceAll(entry.key, entry.value);
    }
    return text.replaceAllMapped(RegExp(r'&#(x?[0-9A-Fa-f]+);'), (match) {
      final raw = match.group(1) ?? '';
      if (raw.isEmpty) return match.group(0) ?? '';
      final isHex = raw.startsWith('x') || raw.startsWith('X');
      final value = int.tryParse(
        isHex ? raw.substring(1) : raw,
        radix: isHex ? 16 : 10,
      );
      if (value == null || value <= 0 || value > 0x10FFFF) {
        return match.group(0) ?? '';
      }
      return String.fromCharCode(value);
    });
  }

  Future<Map<String, dynamic>> _downloadUrlToProject({
    required String url,
    required String relativePath,
    required bool overwrite,
    required int maxBytes,
  }) async {
    if (!await _hasNetworkConnectivity()) {
      throw Exception('当前网络不可用，请先检查网络后重试');
    }
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) {
      throw Exception('URL 无效: $url');
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      throw Exception('仅支持 http/https 下载');
    }

    final targetPath = _resolveWithinProject(relativePath);
    final targetFile = File(targetPath);
    if (!overwrite && await targetFile.exists()) {
      throw Exception('目标文件已存在，且 overwrite=false: $relativePath');
    }
    await targetFile.parent.create(recursive: true);
    final improveNetworkCompatibility =
        _activeProviderConfig.improveNetworkCompatibility;
    final candidates = _buildDownloadCandidates(uri);
    final errors = <String>[];

    for (final candidate in candidates) {
      try {
        final downloaded = await _downloadSingleUrlToFile(
          uri: candidate,
          targetFile: targetFile,
          maxBytes: maxBytes,
          improveNetworkCompatibility: improveNetworkCompatibility,
        );
        return <String, dynamic>{
          'path': _normalizeInputPath(relativePath),
          'bytes': downloaded.bytes,
          'mime': downloaded.mime,
          'status_code': downloaded.statusCode,
          'source_url': candidate.toString(),
          'fallback_used': candidate.toString() != uri.toString(),
        };
      } catch (error) {
        errors.add('${candidate.host}: $error');
        if (await targetFile.exists()) {
          try {
            await targetFile.delete();
          } catch (_) {}
        }
      }
    }
    throw Exception('下载失败（已尝试${candidates.length}个地址）: ${errors.join(' | ')}');
  }

  Future<_DownloadAttemptResult> _downloadSingleUrlToFile({
    required Uri uri,
    required File targetFile,
    required int maxBytes,
    required bool improveNetworkCompatibility,
  }) async {
    final requestTimeout = Duration(
      seconds: improveNetworkCompatibility ? 90 : 50,
    );
    final maxAttempts = improveNetworkCompatibility ? 3 : 2;
    Object? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      final client = _createHttpClient(
        improveNetworkCompatibility: improveNetworkCompatibility,
      );
      IOSink? sink;
      var totalBytes = 0;
      try {
        final request = await client.getUrl(uri).timeout(requestTimeout);
        _applyRequestNetworkProfile(
          request,
          improveNetworkCompatibility: improveNetworkCompatibility,
        );
        request.headers.set(HttpHeaders.acceptHeader, '*/*');
        final response = await request.close().timeout(requestTimeout);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          final snippet = await _readResponseSnippet(response);
          final suffix = snippet.isEmpty ? '' : ' - $snippet';
          throw Exception('HTTP ${response.statusCode}$suffix');
        }

        final expectedBytes = response.contentLength;
        if (expectedBytes > 0 && expectedBytes > maxBytes) {
          throw Exception(
            '文件大小超过限制: $expectedBytes > $maxBytes bytes (max_bytes 上限: $_maxDownloadMaxBytes)',
          );
        }

        sink = targetFile.openWrite(mode: FileMode.write);
        await for (final chunk in response.timeout(requestTimeout)) {
          totalBytes += chunk.length;
          if (totalBytes > maxBytes) {
            throw Exception(
              '文件大小超过限制: $totalBytes > $maxBytes bytes (max_bytes 上限: $_maxDownloadMaxBytes)',
            );
          }
          sink.add(chunk);
        }
        await sink.flush();
        await sink.close();
        sink = null;

        return _DownloadAttemptResult(
          statusCode: response.statusCode,
          bytes: totalBytes,
          mime: response.headers.contentType?.mimeType ?? '',
        );
      } catch (error) {
        lastError = error;
        try {
          await sink?.close();
        } catch (_) {}
        if (await targetFile.exists()) {
          try {
            await targetFile.delete();
          } catch (_) {}
        }
        final retryable = _isTransientNetworkError(error);
        if (!retryable || attempt >= maxAttempts) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 450 * attempt));
      } finally {
        client.close(force: true);
      }
    }
    throw Exception('下载失败: $lastError');
  }

  List<Uri> _buildDownloadCandidates(Uri original) {
    final candidates = <Uri>[original];
    final githubRaw = _toGithubRawUri(original);
    if (githubRaw != null) {
      candidates.add(githubRaw);
      final jsdelivr = _toJsDelivrUri(githubRaw);
      if (jsdelivr != null) {
        candidates.add(jsdelivr);
      }
      candidates.add(Uri.parse('https://ghproxy.com/${githubRaw.toString()}'));
      candidates.add(
        Uri.parse('https://mirror.ghproxy.com/${githubRaw.toString()}'),
      );
    } else if (_isGithubHost(original.host)) {
      candidates.add(Uri.parse('https://ghproxy.com/${original.toString()}'));
      candidates.add(
        Uri.parse('https://mirror.ghproxy.com/${original.toString()}'),
      );
    }

    final dedup = <String>{};
    final out = <Uri>[];
    for (final uri in candidates) {
      final text = uri.toString();
      if (!dedup.add(text)) continue;
      out.add(uri);
    }
    return out;
  }

  bool _isGithubHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'github.com' ||
        normalized == 'raw.githubusercontent.com' ||
        normalized.endsWith('.githubusercontent.com');
  }

  Uri? _toGithubRawUri(Uri source) {
    final host = source.host.toLowerCase();
    if (host == 'raw.githubusercontent.com') {
      return source.replace(query: '', fragment: '');
    }
    if (host != 'github.com') return null;
    final segments = source.pathSegments;
    if (segments.length >= 5 &&
        (segments[2] == 'blob' || segments[2] == 'raw')) {
      final owner = segments[0];
      final repo = segments[1];
      final ref = segments[3];
      final rest = segments.sublist(4).join('/');
      if (owner.isEmpty || repo.isEmpty || ref.isEmpty || rest.isEmpty) {
        return null;
      }
      return Uri.https('raw.githubusercontent.com', '/$owner/$repo/$ref/$rest');
    }
    return null;
  }

  Uri? _toJsDelivrUri(Uri rawGithubUri) {
    if (rawGithubUri.host.toLowerCase() != 'raw.githubusercontent.com') {
      return null;
    }
    final segments = rawGithubUri.pathSegments;
    if (segments.length < 4) return null;
    final owner = segments[0];
    final repo = segments[1];
    final ref = segments[2];
    final rest = segments.sublist(3).join('/');
    if (owner.isEmpty || repo.isEmpty || ref.isEmpty || rest.isEmpty) {
      return null;
    }
    return Uri.https('cdn.jsdelivr.net', '/gh/$owner/$repo@$ref/$rest');
  }

  Future<String> _readResponseSnippet(HttpClientResponse response) async {
    const limit = 2048;
    final bytes = <int>[];
    var read = 0;
    await for (final chunk in response) {
      if (read >= limit) break;
      final remain = limit - read;
      if (chunk.length <= remain) {
        bytes.addAll(chunk);
        read += chunk.length;
      } else {
        bytes.addAll(chunk.take(remain));
        read += remain;
      }
    }
    final compact = utf8
        .decode(bytes, allowMalformed: true)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (compact.length <= 180) return compact;
    return '${compact.substring(0, 180)}...';
  }

  String _truncateModelOutput(String input, int limit) {
    if (input.length <= limit) return input;
    return '${input.substring(0, limit)}\n...(truncated ${input.length - limit} chars)';
  }

  String _summarizeForLog(String text) {
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 150) return compact;
    return '${compact.substring(0, 150)}...';
  }

  String _toolArgsPreview(String rawArgs) {
    final compact = rawArgs.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.isEmpty) return '';
    if (compact.length <= 80) return compact;
    return '${compact.substring(0, 80)}...';
  }

  bool _shouldCacheToolResult(String toolName) {
    switch (toolName) {
      case 'web_search':
      case 'fetch_webpage':
      case 'list_files':
      case 'list_dir':
      case 'file_info':
      case 'find_files':
      case 'file_exists':
      case 'godot_get_version':
      case 'godot_list_projects':
      case 'godot_get_project_info':
        return true;
      default:
        return false;
    }
  }

  String _toolCallSignature(_ToolCall call) {
    dynamic decoded;
    try {
      decoded = jsonDecode(call.argumentsJson);
    } catch (_) {
      decoded = call.argumentsJson.trim();
    }
    final normalized = _normalizeToolArgumentForSignature(decoded);
    return '${call.name}|${jsonEncode(normalized)}';
  }

  dynamic _normalizeToolArgumentForSignature(dynamic value) {
    if (value is Map) {
      final keys = value.keys.map((item) => item.toString()).toList()..sort();
      final normalized = <String, dynamic>{};
      for (final key in keys) {
        normalized[key] = _normalizeToolArgumentForSignature(value[key]);
      }
      return normalized;
    }
    if (value is List) {
      return value.map(_normalizeToolArgumentForSignature).toList();
    }
    if (value == null) return null;
    if (value is num || value is bool || value is String) return value;
    return value.toString();
  }

  String _buildToolLoopGuardResult({
    required _ToolCall call,
    required int repeatedCount,
    required String reason,
    required int webSearchCount,
    required int fetchWebpageCount,
    required int downloadAssetCount,
  }) {
    return jsonEncode(<String, dynamic>{
      'ok': false,
      'action': call.name,
      'error': reason,
      'repeat_count': repeatedCount,
      'next_step': '请避免重复调用同一工具参数。若已拿到候选链接，先 fetch_webpage 再 download_asset。',
      'stats': <String, int>{
        'web_search': webSearchCount,
        'fetch_webpage': fetchWebpageCount,
        'download_asset': downloadAssetCount,
      },
    });
  }

  Future<List<String>> _requestModels({
    required ModelProvider provider,
    required String baseUrl,
    required String apiKey,
    String modelListPath = '',
    Map<String, String> extraHeaders = const <String, String>{},
    bool improveNetworkCompatibility = false,
  }) async {
    final catalog = await _requestModelCatalog(
      provider: provider,
      baseUrl: baseUrl,
      apiKey: apiKey,
      modelListPath: modelListPath,
      extraHeaders: extraHeaders,
      improveNetworkCompatibility: improveNetworkCompatibility,
    );
    return catalog.modelIds;
  }

  Future<_ModelCatalog> _requestModelCatalog({
    required ModelProvider provider,
    required String baseUrl,
    required String apiKey,
    String modelListPath = '',
    Map<String, String> extraHeaders = const <String, String>{},
    bool improveNetworkCompatibility = false,
  }) async {
    var endpoint = baseUrl.trim();
    if (endpoint.isEmpty) {
      throw Exception('请先填写 Base URL');
    }
    endpoint = endpoint.replaceAll(RegExp(r'/+$'), '');

    final guide = kProviderGuides[provider.id];
    if (guide != null &&
        !guide.supportsAutoFetch &&
        modelListPath.trim().isEmpty) {
      throw Exception('该提供方暂不支持自动拉取模型，请按文档手动填写模型名');
    }

    final candidates = _buildModelFetchPlans(
      providerId: provider.id,
      baseUrl: endpoint,
      apiKey: apiKey,
      modelListPath: modelListPath,
      extraHeaders: extraHeaders,
    );
    if (candidates.isEmpty) {
      throw Exception('该提供方未配置自动获取模型接口');
    }

    final errors = <String>[];
    for (final plan in candidates) {
      try {
        final catalog = await _requestModelCatalogFromUri(
          uri: plan.uri,
          headers: plan.headers,
          improveNetworkCompatibility: improveNetworkCompatibility,
        );
        if (catalog.modelIds.isNotEmpty) {
          return catalog;
        }
      } catch (error) {
        errors.add('${plan.label} -> $error');
      }
    }
    throw Exception(errors.isEmpty ? '未获取到模型列表' : errors.join(' | '));
  }

  bool _endsWithPath(String endpoint, String suffix) {
    final normalizedEndpoint = endpoint.toLowerCase().replaceAll(
      RegExp(r'/+$'),
      '',
    );
    final normalizedSuffix = suffix.toLowerCase().replaceAll(
      RegExp(r'^/+'),
      '',
    );
    return normalizedEndpoint.endsWith('/$normalizedSuffix');
  }

  Uri _joinBase(String endpoint, String path) {
    final normalizedEndpoint = endpoint.replaceAll(RegExp(r'/+$'), '');
    final normalizedPath = path.replaceAll(RegExp(r'^/+'), '');
    return Uri.parse('$normalizedEndpoint/$normalizedPath');
  }

  Uri _resolveEndpointByCustomPath({
    required String baseUrl,
    required String customPath,
  }) {
    final trimmed = customPath.trim();
    if (trimmed.isEmpty) {
      return Uri.parse(baseUrl.trim());
    }

    final absolute = Uri.tryParse(trimmed);
    if (absolute != null && absolute.hasScheme) {
      return absolute;
    }

    var normalized = trimmed;
    if (!normalized.startsWith('/')) {
      normalized = '/$normalized';
    }

    final customUri = Uri.parse(normalized);
    final endpoint = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (customUri.path.isNotEmpty && _endsWithPath(endpoint, customUri.path)) {
      final baseUri = Uri.parse(endpoint);
      if (baseUri.query.isEmpty && customUri.query.isNotEmpty) {
        return baseUri.replace(query: customUri.query);
      }
      return baseUri;
    }

    return Uri.parse('$endpoint$normalized');
  }

  Map<String, String> _cleanHeaderMap(Map<String, String> raw) {
    final headers = <String, String>{};
    for (final entry in raw.entries) {
      final key = entry.key.trim();
      final value = entry.value.trim();
      if (key.isEmpty || value.isEmpty) continue;
      headers[key] = value;
    }
    return headers;
  }

  List<_ModelFetchPlan> _buildModelFetchPlans({
    required String providerId,
    required String baseUrl,
    required String apiKey,
    String modelListPath = '',
    Map<String, String> extraHeaders = const <String, String>{},
  }) {
    final normalizedExtraHeaders = _cleanHeaderMap(extraHeaders);
    final bearerHeaders = <String, String>{
      if (apiKey.isNotEmpty) HttpHeaders.authorizationHeader: 'Bearer $apiKey',
      ...normalizedExtraHeaders,
    };
    final pathOverride = modelListPath.trim();
    final plans = <_ModelFetchPlan>[];

    Map<String, String> mergeHeaders(Map<String, String> headers) {
      return <String, String>{...headers, ...normalizedExtraHeaders};
    }

    switch (providerId) {
      case 'gemini':
        final endpoint = _endsWithPath(baseUrl, 'models')
            ? Uri.parse(baseUrl)
            : _joinBase(baseUrl, 'models');
        plans.add(
          _ModelFetchPlan(
            label: endpoint.toString(),
            uri: endpoint,
            headers: mergeHeaders({
              if (apiKey.isNotEmpty) 'x-goog-api-key': apiKey,
            }),
          ),
        );
        if (apiKey.isNotEmpty) {
          plans.add(
            _ModelFetchPlan(
              label: '${endpoint.path}?key=***',
              uri: endpoint.replace(
                queryParameters: <String, String>{
                  ...endpoint.queryParameters,
                  'key': apiKey,
                },
              ),
              headers: normalizedExtraHeaders,
            ),
          );
        }
        break;
      case 'claude':
        Uri endpoint;
        if (_endsWithPath(baseUrl, 'v1/models')) {
          endpoint = Uri.parse(baseUrl);
        } else if (_endsWithPath(baseUrl, 'v1')) {
          endpoint = _joinBase(baseUrl, 'models');
        } else {
          endpoint = _joinBase(baseUrl, 'v1/models');
        }
        plans.add(
          _ModelFetchPlan(
            label: endpoint.toString(),
            uri: endpoint,
            headers: mergeHeaders({
              if (apiKey.isNotEmpty) 'x-api-key': apiKey,
              'anthropic-version': '2023-06-01',
            }),
          ),
        );
        break;
      case 'azure_openai':
        Uri endpoint;
        if (_endsWithPath(baseUrl, 'openai/v1/models')) {
          endpoint = Uri.parse(baseUrl);
        } else if (_endsWithPath(baseUrl, 'openai/v1')) {
          endpoint = _joinBase(baseUrl, 'models');
        } else {
          endpoint = _joinBase(baseUrl, 'openai/v1/models');
        }
        if (!endpoint.queryParameters.containsKey('api-version')) {
          endpoint = endpoint.replace(
            queryParameters: <String, String>{
              ...endpoint.queryParameters,
              'api-version': 'preview',
            },
          );
        }
        plans.add(
          _ModelFetchPlan(
            label: endpoint.path,
            uri: endpoint,
            headers: mergeHeaders({if (apiKey.isNotEmpty) 'api-key': apiKey}),
          ),
        );
        break;
      case 'ollama':
        Uri endpoint;
        if (_endsWithPath(baseUrl, 'api/tags') ||
            _endsWithPath(baseUrl, 'tags')) {
          endpoint = Uri.parse(baseUrl);
        } else if (_endsWithPath(baseUrl, 'api')) {
          endpoint = _joinBase(baseUrl, 'tags');
        } else {
          endpoint = _joinBase(baseUrl, 'api/tags');
        }
        plans.add(
          _ModelFetchPlan(
            label: endpoint.toString(),
            uri: endpoint,
            headers: normalizedExtraHeaders,
          ),
        );
        break;
      case 'xai':
        Uri endpoint;
        if (_endsWithPath(baseUrl, 'v1/models')) {
          endpoint = Uri.parse(baseUrl);
        } else if (_endsWithPath(baseUrl, 'v1')) {
          endpoint = _joinBase(baseUrl, 'models');
        } else {
          endpoint = _joinBase(baseUrl, 'v1/models');
        }
        plans.add(
          _ModelFetchPlan(
            label: endpoint.toString(),
            uri: endpoint,
            headers: bearerHeaders,
          ),
        );
        break;
      case 'perplexity':
      case 'volcano':
      case 'chatglm':
      case 'custom':
        break;
      default:
        Uri modelsEndpoint;
        if (_endsWithPath(baseUrl, 'models')) {
          modelsEndpoint = Uri.parse(baseUrl);
        } else {
          modelsEndpoint = _joinBase(baseUrl, 'models');
        }

        Uri v1ModelsEndpoint;
        if (_endsWithPath(baseUrl, 'v1/models')) {
          v1ModelsEndpoint = Uri.parse(baseUrl);
        } else if (_endsWithPath(baseUrl, 'v1')) {
          v1ModelsEndpoint = _joinBase(baseUrl, 'models');
        } else {
          v1ModelsEndpoint = _joinBase(baseUrl, 'v1/models');
        }

        plans.add(
          _ModelFetchPlan(
            label: modelsEndpoint.toString(),
            uri: modelsEndpoint,
            headers: bearerHeaders,
          ),
        );
        if (v1ModelsEndpoint.toString() != modelsEndpoint.toString()) {
          plans.add(
            _ModelFetchPlan(
              label: v1ModelsEndpoint.toString(),
              uri: v1ModelsEndpoint,
              headers: bearerHeaders,
            ),
          );
        }
        break;
    }

    if (pathOverride.isNotEmpty) {
      final customUri = _resolveEndpointByCustomPath(
        baseUrl: baseUrl,
        customPath: pathOverride,
      );
      Map<String, String> customHeaders;
      switch (providerId) {
        case 'azure_openai':
          customHeaders = mergeHeaders({
            if (apiKey.isNotEmpty) 'api-key': apiKey,
          });
          break;
        case 'gemini':
          customHeaders = mergeHeaders({
            if (apiKey.isNotEmpty) 'x-goog-api-key': apiKey,
          });
          break;
        case 'claude':
          customHeaders = mergeHeaders({
            if (apiKey.isNotEmpty) 'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
          });
          break;
        case 'ollama':
          customHeaders = normalizedExtraHeaders;
          break;
        default:
          customHeaders = bearerHeaders;
          break;
      }

      if (!plans.any((item) => item.uri.toString() == customUri.toString())) {
        plans.insert(
          0,
          _ModelFetchPlan(
            label: customUri.toString(),
            uri: customUri,
            headers: customHeaders,
          ),
        );
      }
      if (providerId == 'gemini' &&
          apiKey.isNotEmpty &&
          !customUri.queryParameters.containsKey('key')) {
        plans.insert(
          min(1, plans.length),
          _ModelFetchPlan(
            label: '${customUri.path}?key=***',
            uri: customUri.replace(
              queryParameters: <String, String>{
                ...customUri.queryParameters,
                'key': apiKey,
              },
            ),
            headers: normalizedExtraHeaders,
          ),
        );
      }
    }

    return plans;
  }

  String _condenseErrorBody(String body) {
    final compact = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 180) return compact;
    return '${compact.substring(0, 180)}...';
  }

  Future<_ModelCatalog> _requestModelCatalogFromUri({
    required Uri uri,
    Map<String, String> headers = const {},
    bool improveNetworkCompatibility = false,
  }) async {
    final client = _createHttpClient(
      improveNetworkCompatibility: improveNetworkCompatibility,
    );
    try {
      final request = await client.getUrl(uri);
      _applyRequestNetworkProfile(
        request,
        improveNetworkCompatibility: improveNetworkCompatibility,
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      for (final entry in headers.entries) {
        final value = entry.value.trim();
        if (value.isEmpty) continue;
        request.headers.set(entry.key, value);
      }
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final snippet = _condenseErrorBody(body);
        final suffix = snippet.isEmpty ? '' : ' - $snippet';
        throw Exception('HTTP ${response.statusCode}$suffix');
      }
      final dynamic payload = jsonDecode(body);
      return _extractModelCatalog(payload);
    } finally {
      client.close(force: true);
    }
  }

  _ModelCatalog _extractModelCatalog(dynamic payload) {
    List<dynamic> rawList = const [];
    if (payload is List) {
      rawList = payload;
    } else if (payload is Map<String, dynamic>) {
      if (payload['data'] is List) {
        rawList = payload['data'] as List<dynamic>;
      } else if (payload['models'] is List) {
        rawList = payload['models'] as List<dynamic>;
      } else if (payload['list'] is List) {
        rawList = payload['list'] as List<dynamic>;
      }
    }

    final output = <String>{};
    final signalsByNormalizedId = <String, _ModelCapabilitySignal>{};

    void mergeSignal(String modelId, _ModelCapabilitySignal signal) {
      final normalized = _normalizeModelIdentity(modelId);
      final existing = signalsByNormalizedId[normalized];
      signalsByNormalizedId[normalized] = existing == null
          ? signal
          : existing.merge(signal);
    }

    void addModel(
      String raw, [
      _ModelCapabilitySignal signal = const _ModelCapabilitySignal(),
    ]) {
      final value = raw.trim();
      if (value.isEmpty) return;
      output.add(value);
      mergeSignal(value, signal);
      final normalized = _normalizeModelIdentity(value);
      if (normalized != value) {
        output.add(normalized);
        mergeSignal(normalized, signal);
      }
    }

    for (final item in rawList) {
      if (item is String && item.trim().isNotEmpty) {
        addModel(item);
        continue;
      }
      if (item is! Map) continue;
      final map = item.map((key, value) => MapEntry(key.toString(), value));
      final value =
          (map['id'] ?? map['name'] ?? map['model'])?.toString().trim() ?? '';
      if (value.isEmpty) continue;
      final signal = _extractModelSignal(map, modelId: value);
      addModel(value, signal);
      if (value.startsWith('models/')) {
        addModel(value.replaceFirst('models/', ''), signal);
      }
    }

    final sorted = output.toList()..sort();
    return _ModelCatalog(
      modelIds: sorted,
      signalsByNormalizedId: signalsByNormalizedId,
    );
  }

  _ModelCapabilitySignal _extractModelSignal(
    Map<String, dynamic> item, {
    required String modelId,
  }) {
    final lower = modelId.toLowerCase();
    final hints = <String>{};
    const hintKeys = [
      'capabilities',
      'modality',
      'modalities',
      'input_modality',
      'input_modalities',
      'output_modality',
      'output_modalities',
      'supported_input_modalities',
      'supported_output_modalities',
      'supported_modalities',
      'supported_generation_methods',
      'features',
      'tags',
      'type',
      'sub_type',
      'architecture',
      'description',
      'details',
    ];
    for (final key in hintKeys) {
      if (!item.containsKey(key)) continue;
      _collectTokenHints(item[key], hints);
    }
    final hintText = hints.join(' ');

    var isEmbedding = _containsAnyToken(lower, const [
      'embedding',
      'embed',
      'rerank',
    ]);
    var isImageGeneration = _containsAnyToken(lower, const [
      'gpt-image',
      'image-gen',
      'imagegen',
      'stable-diffusion',
      'sdxl',
      'flux',
      'midjourney',
      'kandinsky',
      'hunyuan-image',
      'wanx',
      'seedream',
      'imagen',
    ]);
    var supportsImageInput = _containsAnyToken(lower, const [
      'vision',
      '-vl',
      '/vl',
      'multimodal',
      'omni',
      '4o',
      'gemini',
      'pixtral',
      'llava',
      'glm-4v',
      'qwen-vl',
      'internvl',
      'grok-vision',
      'claude-3',
      'claude-sonnet-4',
      'gemma3',
      'smolvlm',
      'minicpm-v',
      'mllama',
      'molmo',
      'phi-4-multimodal',
      'idefics',
      'fuyu',
      'janus',
      'vision-instruct',
    ]);
    var supportsImageOutput = _containsAnyToken(lower, const [
      'img2img',
      'image-edit',
      'edit',
      'variation',
    ]);

    if (hintText.isNotEmpty) {
      if (_containsAnyToken(hintText, const ['embedding', 'embed', 'rerank'])) {
        isEmbedding = true;
      }
      if (_containsAnyToken(hintText, const [
        'image-generation',
        'text-to-image',
        'txt2img',
        'image-gen',
        'imagegen',
      ])) {
        isImageGeneration = true;
      }
      if (_containsAnyToken(hintText, const [
        'image',
        'vision',
        'multimodal',
        'vl',
        'omni',
      ])) {
        supportsImageInput = true;
      }
      if (_containsAnyToken(hintText, const [
        'image',
        'img2img',
        'edit',
        'variation',
        'generation',
      ])) {
        supportsImageOutput = true;
      }
    }

    if (isImageGeneration) {
      supportsImageOutput = true;
    }
    return _ModelCapabilitySignal(
      supportsImageInput: supportsImageInput,
      supportsImageOutput: supportsImageOutput,
      isEmbedding: isEmbedding,
      isImageGeneration: isImageGeneration,
    );
  }

  void _collectTokenHints(dynamic value, Set<String> output) {
    if (value == null) return;
    if (value is String) {
      final token = value.trim().toLowerCase();
      if (token.isNotEmpty) output.add(token);
      return;
    }
    if (value is num || value is bool) {
      output.add(value.toString().toLowerCase());
      return;
    }
    if (value is List) {
      for (final item in value) {
        _collectTokenHints(item, output);
      }
      return;
    }
    if (value is Map) {
      for (final entry in value.entries) {
        output.add(entry.key.toString().toLowerCase());
        _collectTokenHints(entry.value, output);
      }
      return;
    }
    final token = value.toString().trim().toLowerCase();
    if (token.isNotEmpty) output.add(token);
  }

  void _toggleTerminal([bool? value]) {
    final nextValue = value ?? !_showTerminal;
    setState(() {
      _showTerminal = nextValue;
    });
    if (nextValue) {
      _startTerminalPolling();
      unawaited(_refreshShellSnapshot());
    } else {
      _stopTerminalPolling();
    }
    _persistState();
  }

  void _runTerminalCommand() {
    final cmd = _terminalController.text.trim();
    if (cmd.isEmpty) return;
    _terminalController.clear();

    if (cmd.startsWith('@fs ')) {
      _promptController.text = cmd;
      unawaited(_sendPrompt());
      return;
    }

    if (cmd == 'clear' && Platform.isAndroid && _localRuntimeStatus.supported) {
      unawaited(_clearShellBuffer());
      return;
    }

    if (cmd == 'runtime') {
      setState(() {
        _terminalLogs.add(
          '[runtime] running: ${_localRuntimeStatus.isRunning}',
        );
        _terminalLogs.add(
          '[runtime] shell: ${_localRuntimeStatus.shellRunning}',
        );
        _terminalLogs.add(
          '[runtime] workspace: ${_localRuntimeStatus.activeWorkspacePath.isEmpty ? 'not prepared' : _localRuntimeStatus.activeWorkspacePath}',
        );
      });
      _persistState();
      return;
    }

    if (Platform.isAndroid && _localRuntimeStatus.supported) {
      unawaited(_sendShellInput(cmd));
      return;
    }

    setState(() {
      _terminalLogs.add('\$ $cmd');
    });

    if (cmd == 'help') {
      _terminalLogs.add('命令: help, ls, provider, project, clear');
      _terminalLogs.add(
        '文件命令: @fs read|write|create-file|create-dir|delete|download',
      );
    } else if (cmd == 'ls') {
      if (_projectFiles.isEmpty) {
        _terminalLogs.add('未加载项目文件');
      } else {
        for (final file in _projectFiles.take(40)) {
          _terminalLogs.add(file.path);
        }
      }
    } else if (cmd.startsWith('@fs ')) {
      _promptController.text = cmd;
      _sendPrompt();
    } else if (cmd == 'provider') {
      final cfg = _activeProviderConfig;
      final model = cfg.model.isEmpty ? '未设置' : cfg.model;
      _terminalLogs.add('provider: ${_activeProvider.name}');
      _terminalLogs.add('model: $model');
    } else if (cmd == 'project') {
      _terminalLogs.add('root: ${_projectRootPath ?? '未选择'}');
      _terminalLogs.add('files: ${_projectFiles.length}');
    } else if (cmd == 'clear') {
      _terminalLogs
        ..clear()
        ..add('Astra Terminal ready.');
    } else {
      _terminalLogs.add('移动端终端不执行系统命令，仅支持内置命令。');
    }

    setState(() {});
    _persistState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_terminalScroll.hasClients) {
        _terminalScroll.animateTo(
          _terminalScroll.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawerEnableOpenDragGesture: true,
      drawer: _buildConversationDrawer(),
      endDrawerEnableOpenDragGesture: true,
      endDrawer: _buildSettingsDrawer(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTabIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: '聊天',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_copy_outlined),
            selectedIcon: Icon(Icons.folder_copy_rounded),
            label: '工作区',
          ),
          NavigationDestination(
            icon: Icon(Icons.android_outlined),
            selectedIcon: Icon(Icons.android_rounded),
            label: '安卓工具',
          ),
          NavigationDestination(
            icon: Icon(Icons.terminal_outlined),
            selectedIcon: Icon(Icons.terminal_rounded),
            label: '终端',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune_rounded),
            label: '设置',
          ),
        ],
      ),
      body: Stack(
        children: [
          const _WorkbenchBackground(),
          SafeArea(child: _buildActiveTabBody()),
          _buildTerminalPanel(),
        ],
      ),
    );
  }

  Widget _buildActiveTabBody() {
    switch (_selectedTabIndex) {
      case 1:
        return _buildWorkspaceTab();
      case 2:
        return _buildAndroidToolsTab();
      case 3:
        return _buildTerminalTab();
      case 4:
        return _buildSettingsTab();
      case 0:
      default:
        return _buildChatHomeTab();
    }
  }

  Widget _buildChatHomeTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        children: [
          _buildTopBar(),
          const SizedBox(height: 10),
          Expanded(child: _buildChatPanel()),
          const SizedBox(height: 10),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildWorkspaceTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        children: [
          _buildPageHeader(title: '工作区', subtitle: '浏览项目、查看差异、同步镜像和源目录。'),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildProjectSection(),
                const SizedBox(height: 12),
                _buildRuntimeWorkbenchSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAndroidToolsTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        children: [
          _buildPageHeader(title: '安卓工具', subtitle: '构建、安装、日志、反编译和执行后端都集中在这里。'),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildExecutionBackendsSection(),
                const SizedBox(height: 12),
                _buildAndroidToolkitSection(),
                const SizedBox(height: 12),
                _buildAgentExecutionSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        children: [
          _buildPageHeader(
            title: '终端',
            subtitle: '查看本地 Shell 日志，并在手机上做轻量手动干预。',
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _buildTerminalWorkbenchCard()),
                const SizedBox(height: 12),
                _buildBackgroundGuardSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        children: [
          _buildPageHeader(title: '设置', subtitle: '模型连接、本地运行时、权限和高级能力。'),
          const SizedBox(height: 10),
          Expanded(child: _buildSettingsBody()),
        ],
      ),
    );
  }

  Widget _buildPageHeader({required String title, required String subtitle}) {
    return _GlassCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0x100B6E4F),
              border: Border.all(color: AppPalette.border),
            ),
            child: IconButton(
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              icon: const Icon(Icons.menu_rounded, color: AppPalette.ink),
              tooltip: '会话列表',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppPalette.muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            icon: const Icon(Icons.tune_rounded, color: AppPalette.ink),
            tooltip: '设置',
          ),
        ],
      ),
    );
  }

  Widget _buildSessionOverviewCard() {
    final hasProject = _projectRootPath?.trim().isNotEmpty ?? false;
    final currentModel = _activeProviderConfig.model.trim();
    final modelLabel = currentModel.isEmpty ? '未选模型' : currentModel;
    final runtimeLabel = _localRuntimeStatus.isRunning ? '运行中' : '未启动';
    final mirrorLabel = _localRuntimeStatus.hasWorkspace ? '已镜像' : '未镜像';
    final backendLabel = _primaryBackendLabel(_primaryExecutionBackend);
    return _GlassCard(
      radius: 22,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '开发会话',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppPalette.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasProject
                ? '当前项目：${_drawerExplorerProjectName()}'
                : '还没有绑定项目目录，建议先选择项目后再发起开发任务。',
            style: const TextStyle(
              fontSize: 12,
              color: AppPalette.muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AgentMetricChip(
                label:
                    '项目 ${hasProject ? _drawerExplorerProjectName() : '未选择'}',
              ),
              _AgentMetricChip(label: '运行时 $runtimeLabel'),
              _AgentMetricChip(label: '镜像 $mirrorLabel'),
              _AgentMetricChip(label: '后端 $backendLabel'),
              _AgentMetricChip(
                label: '模型 ${_singleLinePreview(modelLabel, maxLength: 18)}',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: hasProject
                    ? () {
                        setState(() {
                          _selectedTabIndex = 1;
                        });
                      }
                    : _pickProjectFolder,
                icon: Icon(
                  hasProject
                      ? Icons.folder_copy_rounded
                      : Icons.folder_open_rounded,
                ),
                label: Text(hasProject ? '打开工作区' : '选择项目'),
              ),
              FilledButton.tonalIcon(
                onPressed: () {
                  setState(() {
                    _selectedTabIndex = 2;
                  });
                },
                icon: const Icon(Icons.android_rounded),
                label: const Text('安卓工具'),
              ),
              OutlinedButton.icon(
                onPressed: _localRuntimeStatus.isRunning
                    ? _prepareLocalWorkspaceMirror
                    : _startLocalRuntime,
                icon: Icon(
                  _localRuntimeStatus.isRunning
                      ? Icons.copy_all_rounded
                      : Icons.play_arrow_rounded,
                ),
                label: Text(_localRuntimeStatus.isRunning ? '准备镜像' : '启动运行时'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTaskPanel() {
    return _GlassCard(
      radius: 22,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '快捷任务',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppPalette.ink,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickPromptChip(
                '修复构建失败',
                '请先运行 Gradle 构建，定位当前 Android 项目的报错，修改代码并给我 diff 与原因。',
              ),
              _buildQuickPromptChip(
                '修改页面',
                '请先阅读相关页面文件，理解当前布局，再帮我修改页面并说明影响范围。',
              ),
              _buildQuickPromptChip(
                '新增功能',
                '请先分析项目结构和现有模式，再为我实现这个新功能，并给出验证步骤。',
              ),
              _buildQuickPromptChip(
                '分析 APK',
                '请帮我分析 APK，必要时使用 apktool 或 JADX，并总结关键入口与核心逻辑。',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _projectRootPath == null
                    ? null
                    : () {
                        setState(() {
                          _selectedTabIndex = 2;
                        });
                        unawaited(
                          _runAndroidToolkitAction(
                            title: 'Gradle 构建',
                            action: () => _runAndroidGradleBuildTool(),
                          ),
                        );
                      },
                icon: const Icon(Icons.build_circle_rounded),
                label: const Text('构建'),
              ),
              FilledButton.tonalIcon(
                onPressed: _projectRootPath == null
                    ? null
                    : () {
                        setState(() {
                          _selectedTabIndex = 1;
                        });
                        unawaited(
                          _runRuntimeWorkbenchCommand(
                            title: 'Git 差异',
                            action: () =>
                                _runGitDiffTool(maxOutputBytes: 196608),
                          ),
                        );
                      },
                icon: const Icon(Icons.difference_rounded),
                label: const Text('查看 Diff'),
              ),
              FilledButton.tonalIcon(
                onPressed: () {
                  setState(() {
                    _selectedTabIndex = 2;
                  });
                  unawaited(
                    _runAndroidToolkitAction(
                      title: 'Logcat 日志',
                      action: () => _runAndroidLogcatTool(),
                    ),
                  );
                },
                icon: const Icon(Icons.article_outlined),
                label: const Text('抓日志'),
              ),
              FilledButton.tonalIcon(
                onPressed: _localRuntimeStatus.hasWorkspace
                    ? () {
                        setState(() {
                          _selectedTabIndex = 1;
                        });
                        unawaited(_syncMirrorWorkspaceBackToSource());
                      }
                    : null,
                icon: const Icon(Icons.sync_alt_rounded),
                label: const Text('同步回源'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPromptChip(String label, String prompt) {
    return ActionChip(
      label: Text(label),
      onPressed: () => _applyPromptTemplate(prompt),
      avatar: const Icon(
        Icons.bolt_rounded,
        size: 16,
        color: AppPalette.primary,
      ),
      side: const BorderSide(color: AppPalette.border),
      backgroundColor: Colors.white.withValues(alpha: 0.72),
      labelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppPalette.ink,
      ),
    );
  }

  void _applyPromptTemplate(String prompt) {
    _promptController.text = prompt;
    _promptController.selection = TextSelection.collapsed(
      offset: _promptController.text.length,
    );
    _promptFocusNode.requestFocus();
  }

  Widget _buildTerminalWorkbenchCard() {
    return _PanelCard(
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '终端控制台',
                  style: TextStyle(
                    color: AppPalette.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                _localShellSnapshot.isRunning ? 'shell on' : 'shell off',
                style: const TextStyle(
                  color: AppPalette.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  setState(
                    () => _terminalLogs
                      ..clear()
                      ..add('Astra Terminal ready.'),
                  );
                  _persistState();
                },
                child: const Text('清空'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1220).withValues(alpha: 0.97),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF203048)),
              ),
              child: ListView.builder(
                controller: _terminalScroll,
                itemCount: _terminalLogs.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      _terminalLogs[index],
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 12,
                        color: Color(0xFFBAD0EB),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF111B2D),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF203048)),
            ),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    r'$',
                    style: TextStyle(
                      color: Color(0xFF7AD7A0),
                      fontFamily: 'JetBrainsMono',
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _terminalController,
                    onSubmitted: (_) => _runTerminalCommand(),
                    style: const TextStyle(
                      color: Color(0xFFE2EEFF),
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '输入命令',
                      hintStyle: TextStyle(
                        color: Color(0xFF7088A4),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _runTerminalCommand,
                  icon: const Icon(
                    Icons.play_arrow_rounded,
                    color: Color(0xFF7AD7A0),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final compact = screenWidth < 410;
    final tiny = screenWidth < 360;
    return _GlassCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0x100B6E4F),
              border: Border.all(color: AppPalette.border),
            ),
            child: IconButton(
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              icon: const Icon(Icons.menu_rounded, color: AppPalette.ink),
              tooltip: '会话列表',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _normalizedConversationTitle(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 24 : 30,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.ink,
                      height: 1.05,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _showConversationTitleEditor,
                  tooltip: '编辑标题',
                  icon: const Icon(
                    Icons.edit_rounded,
                    size: 20,
                    color: AppPalette.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compact ? 94 : 128),
            child: SizedBox(
              height: 34,
              child: FilledButton.icon(
                onPressed: _startNewConversation,
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.add_comment_rounded, size: 14),
                label: Text(
                  tiny ? '新建' : (compact ? '新对话' : '开始新对话'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            icon: const Icon(Icons.tune_rounded, color: AppPalette.ink),
            tooltip: '设置',
          ),
        ],
      ),
    );
  }

  Widget _buildProjectHint() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _GlassCard(
        radius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.folder_open_rounded,
              size: 18,
              color: AppPalette.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${_projectRootPath!} | ${_projectFiles.length} files',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppPalette.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentExecutionBanner() {
    final hasContent =
        _sendingPrompt ||
        _agentPlanSummary.isNotEmpty ||
        _agentProgressEntries.isNotEmpty ||
        _agentToolEvents.isNotEmpty;
    if (!hasContent) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F9FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD9E6F5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _sendingPrompt
                        ? const Color(0xFF0B6E4F)
                        : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _agentLiveStatus,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.ink,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                  icon: const Icon(Icons.insights_rounded, size: 16),
                  label: const Text('执行台'),
                ),
              ],
            ),
            if (_agentPlanSummary.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                _agentPlanSummary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppPalette.muted,
                  height: 1.35,
                ),
              ),
            ],
            if (_agentToolEvents.isNotEmpty || _agentCurrentRound > 0) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _AgentMetricChip(label: '步骤 ${_agentProgressEntries.length}'),
                  _AgentMetricChip(label: '工具 ${_agentToolEvents.length}'),
                ],
              ),
            ],
            if (_agentCurrentRound > 0) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _AgentMetricChip(label: '阶段 $_agentExecutionPhase'),
                  if (_agentMaxRounds > 0)
                    _AgentMetricChip(
                      label: '回合 $_agentCurrentRound / $_agentMaxRounds',
                    ),
                  if (_agentSummaryMode) const _AgentMetricChip(label: '总结模式'),
                ],
              ),
            ],
            if (_agentConvergenceSummary.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                _agentConvergenceSummary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppPalette.muted,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChatPanel() {
    return _GlassCard(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      child: ListView.builder(
        controller: _chatScroll,
        padding: EdgeInsets.zero,
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];
          if (_isToolLogMessage(message)) {
            return const SizedBox.shrink();
          }
          final isUser = message.role == ChatRole.user;
          final isSystem = message.role == ChatRole.system;
          final canRollbackHere = isUser
              ? _canRollbackFromUserMessage(index)
              : false;
          final isRollbackTarget =
              _rollingBackRound && _rollingBackMessageIndex == index;
          final isEditingMessage = !isSystem && _editingMessageIndex == index;
          final background = isUser
              ? const Color(0x1A0B6E4F)
              : isSystem
              ? const Color(0x1A334155)
              : Colors.white.withValues(alpha: 0.78);

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: isUser
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isUser)
                  Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSystem
                          ? const Color(0x1A334155)
                          : const Color(0x220B6E4F),
                    ),
                    child: Icon(
                      isSystem
                          ? Icons.info_outline_rounded
                          : Icons.smart_toy_rounded,
                      size: 16,
                      color: isSystem
                          ? const Color(0xFF334155)
                          : AppPalette.primary,
                    ),
                  ),
                if (isUser)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 2),
                    child: Tooltip(
                      message: '回退这条消息',
                      child: InkWell(
                        onTap: !canRollbackHere || _rollingBackRound
                            ? null
                            : () => _rollbackFromUserMessage(index),
                        borderRadius: BorderRadius.circular(999),
                        child: Ink(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: canRollbackHere
                                ? const Color(0x1A334155)
                                : const Color(0x11334155),
                            border: Border.all(
                              color: canRollbackHere
                                  ? AppPalette.border
                                  : AppPalette.border.withValues(alpha: 0.55),
                            ),
                          ),
                          child: Center(
                            child: isRollbackTarget
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    Icons.undo_rounded,
                                    size: 16,
                                    color: canRollbackHere
                                        ? AppPalette.muted
                                        : AppPalette.muted.withValues(
                                            alpha: 0.45,
                                          ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppPalette.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isEditingMessage)
                          TextField(
                            controller: _messageEditController,
                            autofocus: true,
                            minLines: 2,
                            maxLines: 8,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppPalette.ink,
                              height: 1.45,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.88),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: AppPalette.border,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                  color: AppPalette.border,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: AppPalette.primary,
                                ),
                              ),
                            ),
                          )
                        else if (!isUser &&
                            !isSystem &&
                            message.hasStructuredParts)
                          _buildStructuredAssistantMessageCard(
                            message: message,
                            messageIndex: index,
                          )
                        else
                          Text(
                            message.text,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppPalette.ink,
                              height: 1.45,
                            ),
                          ),
                        const SizedBox(height: 5),
                        Text(
                          message.time,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppPalette.muted,
                          ),
                        ),
                        if (!isSystem) ...[
                          const SizedBox(height: 6),
                          if (isEditingMessage)
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _buildMessageActionButton(
                                  icon: Icons.check_rounded,
                                  label: '保存',
                                  onPressed: () =>
                                      _saveInlineMessageEdit(index),
                                ),
                                _buildMessageActionButton(
                                  icon: Icons.close_rounded,
                                  label: '取消',
                                  onPressed: _cancelInlineMessageEdit,
                                ),
                              ],
                            )
                          else
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _buildMessageActionButton(
                                  icon: Icons.edit_rounded,
                                  label: '编辑',
                                  onPressed: () => _editMessageAt(index),
                                ),
                                _buildMessageActionButton(
                                  icon: Icons.content_copy_rounded,
                                  label: '复制',
                                  onPressed: () => _copyMessageAt(index),
                                ),
                                _buildMessageActionButton(
                                  icon: Icons.refresh_rounded,
                                  label: '重试',
                                  onPressed: _sendingPrompt
                                      ? null
                                      : () => _retryMessageAt(index),
                                ),
                              ],
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (isUser)
                  Container(
                    width: 28,
                    height: 28,
                    margin: const EdgeInsets.only(left: 8),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0x1AFF9F1C),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      size: 16,
                      color: Color(0xFFB35500),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _drawerExplorerProjectName() {
    final root = _projectRootPath;
    if (root == null || root.trim().isEmpty) return '未选择目录';
    final normalized = root
        .replaceAll('\\', '/')
        .replaceAll(RegExp(r'/+$'), '');
    if (normalized.isEmpty) return root;
    final index = normalized.lastIndexOf('/');
    if (index < 0) return normalized;
    return normalized.substring(index + 1);
  }

  void _toggleDrawerExplorerCollapsed() {
    setState(() {
      _drawerExplorerCollapsed = !_drawerExplorerCollapsed;
    });
  }

  void _toggleDrawerExplorerPath(String path) {
    final shouldExpand = !_drawerExplorerExpandedPaths.contains(path);
    setState(() {
      if (shouldExpand) {
        _drawerExplorerExpandedPaths.add(path);
      } else {
        _drawerExplorerExpandedPaths.remove(path);
      }
    });
    if (shouldExpand) {
      unawaited(_loadDrawerExplorerChildren(path));
    }
  }

  void _collapseDrawerExplorerPaths() {
    setState(() {
      _drawerExplorerExpandedPaths
        ..clear()
        ..add(_drawerExplorerRootKey);
    });
  }

  (IconData, Color) _drawerExplorerFileStyle(String relativePath) {
    final lower = relativePath.toLowerCase();
    if (lower.endsWith('.dart')) {
      return (Icons.code_rounded, const Color(0xFF2F7DCA));
    }
    if (lower.endsWith('.md') || lower.endsWith('.txt')) {
      return (Icons.article_rounded, const Color(0xFF2F9162));
    }
    if (lower.endsWith('.json') ||
        lower.endsWith('.yaml') ||
        lower.endsWith('.yml') ||
        lower.endsWith('.xml')) {
      return (Icons.data_object_rounded, const Color(0xFFC9822A));
    }
    if (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.svg')) {
      return (Icons.image_rounded, const Color(0xFF1B9786));
    }
    if (lower.endsWith('.sh') ||
        lower.endsWith('.bat') ||
        lower.endsWith('.ps1')) {
      return (Icons.terminal_rounded, const Color(0xFF5D6EC9));
    }
    return (Icons.insert_drive_file_rounded, const Color(0xFF8090A5));
  }

  String _drawerExplorerFileMeta(ProjectFileSnippet file) {
    return '${_formatBytes(file.sizeBytes)} · ${file.isBinary ? '二进制' : '文本'}';
  }

  Future<ProjectFileSnippet> _drawerExplorerSnippetOfFile(
    _DrawerExplorerEntry entry,
  ) async {
    final file = File(entry.absolutePath);
    if (!await file.exists()) {
      throw Exception('文件不存在: ${entry.path}');
    }
    late final (String preview, bool isBinary) previewInfo;
    try {
      previewInfo = await _readPreview(file);
    } catch (_) {
      previewInfo = ('<unreadable file>', true);
    }
    final sizeBytes = entry.sizeBytes > 0
        ? entry.sizeBytes
        : (await file.stat()).size;
    return ProjectFileSnippet(
      path: entry.path,
      absolutePath: entry.absolutePath,
      preview: previewInfo.$1,
      sizeBytes: sizeBytes,
      isBinary: previewInfo.$2,
    );
  }

  Future<void> _onDrawerExplorerFileTap(_DrawerExplorerEntry entry) async {
    final segments = entry.path
        .split('/')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    final parentPath = <String>[];
    setState(() {
      _drawerExplorerSelectedPath = entry.path;
      _drawerExplorerExpandedPaths.add(_drawerExplorerRootKey);
      for (var i = 0; i < max(0, segments.length - 1); i++) {
        final segment = segments[i];
        parentPath.add(segment);
        _drawerExplorerExpandedPaths.add(parentPath.join('/'));
      }
    });
    ProjectFileSnippet snippet;
    try {
      snippet = await _drawerExplorerSnippetOfFile(entry);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('读取文件失败: $error')));
      return;
    }
    if (!mounted) return;
    setState(() {
      final index = _projectFiles.indexWhere(
        (item) => item.path == snippet.path,
      );
      if (index >= 0) {
        _projectFiles[index] = snippet;
      } else {
        _projectFiles = <ProjectFileSnippet>[..._projectFiles, snippet];
      }
    });
    await _showDrawerExplorerFilePreview(snippet);
  }

  Future<void> _showDrawerExplorerFilePreview(ProjectFileSnippet file) async {
    if (!mounted) return;
    final preview = file.preview.trim().isEmpty
        ? (file.isBinary ? '<binary file>' : '<empty file>')
        : file.preview;
    final panelHeight = min(
      420.0,
      max(220.0, MediaQuery.of(context).size.height * 0.45),
    );
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.path,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _drawerExplorerFileMeta(file),
                  style: const TextStyle(fontSize: 12, color: AppPalette.muted),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: panelHeight,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F8FC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppPalette.border),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        preview,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: Color(0xFF233243),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: file.path));
                        ScaffoldMessenger.of(
                          sheetContext,
                        ).showSnackBar(const SnackBar(content: Text('已复制路径')));
                      },
                      icon: const Icon(Icons.content_copy_rounded, size: 18),
                      label: const Text('复制路径'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _promptController.text = '@fs read ${file.path}';
                        _promptFocusNode.requestFocus();
                      },
                      icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                      label: const Text('读取全文'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDrawerExplorerToolButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    final enabled = onPressed != null;
    return SizedBox(
      width: 30,
      height: 30,
      child: IconButton(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        splashRadius: 16,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: 18,
          color: enabled ? const Color(0xFF3E536B) : const Color(0xFFB0BCCB),
        ),
      ),
    );
  }

  Widget _buildDrawerExplorerNodeTile({
    required _DrawerExplorerEntry entry,
    required int depth,
    required bool expanded,
  }) {
    final (iconData, iconColor) = entry.isDirectory
        ? (
            expanded ? Icons.folder_open_rounded : Icons.folder_rounded,
            expanded ? const Color(0xFFD39B3D) : const Color(0xFFC98B2A),
          )
        : _drawerExplorerFileStyle(entry.path);
    final selected =
        !entry.isDirectory && _drawerExplorerSelectedPath == entry.path;
    final leftInset = 6.0 + max(0, depth - 1) * 14.0;

    return InkWell(
      onTap: () {
        if (entry.isDirectory) {
          _toggleDrawerExplorerPath(entry.path);
          return;
        }
        unawaited(_onDrawerExplorerFileTap(entry));
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: EdgeInsets.fromLTRB(leftInset, 0, 6, 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: selected ? const Color(0xFFEAF2FF) : const Color(0x00000000),
          border: selected ? Border.all(color: const Color(0xFF9EC0EE)) : null,
        ),
        child: Row(
          children: [
            if (entry.isDirectory)
              Icon(
                expanded
                    ? Icons.expand_more_rounded
                    : Icons.chevron_right_rounded,
                size: 16,
                color: const Color(0xFF7890AA),
              )
            else
              const SizedBox(width: 16),
            Icon(iconData, size: 16, color: iconColor),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                entry.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF172332),
                ),
              ),
            ),
            if (!entry.isDirectory)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  _formatBytes(entry.sizeBytes),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF7388A1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerExplorerInlineHintRow({
    required int depth,
    required String text,
    Color color = const Color(0xFF7D8FA4),
  }) {
    final leftInset = 30.0 + max(0, depth - 1) * 14.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(leftInset, 2, 12, 6),
      child: Text(text, style: TextStyle(fontSize: 11, color: color)),
    );
  }

  List<Widget> _buildDrawerExplorerTreeRows() {
    const maxRows = 320;
    final rows = <Widget>[];
    var rowCount = 0;
    var truncated = false;

    void visit(String parentPath, int depth) {
      final children =
          _drawerExplorerChildrenByPath[parentPath] ??
          const <_DrawerExplorerEntry>[];
      for (final child in children) {
        if (rowCount >= maxRows) {
          truncated = true;
          return;
        }
        final expanded =
            child.isDirectory &&
            _drawerExplorerExpandedPaths.contains(child.path);
        rows.add(
          _buildDrawerExplorerNodeTile(
            entry: child,
            depth: depth,
            expanded: expanded,
          ),
        );
        rowCount++;
        if (!child.isDirectory || !expanded) {
          continue;
        }
        final loading = _drawerExplorerLoadingPaths.contains(child.path);
        if (loading) {
          if (rowCount >= maxRows) {
            truncated = true;
            return;
          }
          rows.add(
            _buildDrawerExplorerInlineHintRow(depth: depth + 1, text: '加载中...'),
          );
          rowCount++;
          continue;
        }
        final error = _drawerExplorerLoadErrors[child.path];
        if (error != null) {
          if (rowCount >= maxRows) {
            truncated = true;
            return;
          }
          rows.add(
            _buildDrawerExplorerInlineHintRow(
              depth: depth + 1,
              text: '读取失败: $error',
              color: const Color(0xFFB85C5C),
            ),
          );
          rowCount++;
          continue;
        }
        if (!_drawerExplorerChildrenByPath.containsKey(child.path)) {
          if (rowCount >= maxRows) {
            truncated = true;
            return;
          }
          rows.add(
            _buildDrawerExplorerInlineHintRow(
              depth: depth + 1,
              text: '展开后按需加载子目录',
            ),
          );
          rowCount++;
          continue;
        }
        visit(child.path, depth + 1);
        if (truncated) return;
      }
    }

    visit(_drawerExplorerRootKey, 1);
    if (truncated) {
      rows.add(
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: Text(
            '目录过大，已截断展示前 320 项',
            style: TextStyle(fontSize: 11, color: Color(0xFF7D8FA4)),
          ),
        ),
      );
    }
    return rows;
  }

  Widget _buildDrawerExplorerSection() {
    final hasProject = _projectRootPath != null && _projectRootPath!.isNotEmpty;
    final rootExpanded = _drawerExplorerExpandedPaths.contains(
      _drawerExplorerRootKey,
    );
    final rootEntries =
        _drawerExplorerChildrenByPath[_drawerExplorerRootKey] ??
        const <_DrawerExplorerEntry>[];
    final rootLoaded = _drawerExplorerChildrenByPath.containsKey(
      _drawerExplorerRootKey,
    );
    final rootLoading = _drawerExplorerLoadingPaths.contains(
      _drawerExplorerRootKey,
    );
    final rootError = _drawerExplorerLoadErrors[_drawerExplorerRootKey];
    final rows = hasProject && rootExpanded
        ? _buildDrawerExplorerTreeRows()
        : const <Widget>[];
    final maxTreeHeight = MediaQuery.of(context).size.height < 720
        ? 210.0
        : 270.0;
    final treeHeight = min(maxTreeHeight, max(120.0, rows.length * 34.0));

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD9E3EE)),
          boxShadow: [
            BoxShadow(
              blurRadius: 12,
              offset: const Offset(0, 5),
              color: Colors.black.withValues(alpha: 0.08),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: _toggleDrawerExplorerCollapsed,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.folder_copy_rounded,
                      size: 18,
                      color: Color(0xFF30445B),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '资源管理器',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1C2735),
                        ),
                      ),
                    ),
                    Text(
                      '${rootEntries.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6A7E96),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _drawerExplorerCollapsed
                          ? Icons.expand_more_rounded
                          : Icons.expand_less_rounded,
                      size: 20,
                      color: const Color(0xFF6E839D),
                    ),
                  ],
                ),
              ),
            ),
            if (!_drawerExplorerCollapsed) ...[
              const Divider(height: 1, thickness: 1, color: Color(0xFFE4EBF4)),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: hasProject
                            ? () => _toggleDrawerExplorerPath(
                                _drawerExplorerRootKey,
                              )
                            : null,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7FAFE),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFD5E0EC)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                rootExpanded
                                    ? Icons.expand_more_rounded
                                    : Icons.chevron_right_rounded,
                                size: 16,
                                color: const Color(0xFF758AA3),
                              ),
                              const Icon(
                                Icons.folder_open_rounded,
                                size: 16,
                                color: Color(0xFFC98D2C),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _drawerExplorerProjectName().toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1F2A37),
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildDrawerExplorerToolButton(
                      icon: Icons.folder_open_rounded,
                      tooltip: '选择目录',
                      onPressed: _pickProjectFolder,
                    ),
                    _buildDrawerExplorerToolButton(
                      icon: Icons.refresh_rounded,
                      tooltip: '刷新',
                      onPressed: !hasProject || _readingProject
                          ? null
                          : () => _loadProjectFolder(_projectRootPath!),
                    ),
                    _buildDrawerExplorerToolButton(
                      icon: Icons.unfold_less_rounded,
                      tooltip: '收起子目录',
                      onPressed: hasProject
                          ? _collapseDrawerExplorerPaths
                          : null,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(
                  children: [
                    Text(
                      hasProject ? '根目录: ${rootEntries.length} 项' : '未加载项目目录',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B8098),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_readingProject || rootLoading)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.7,
                          color: Color(0xFF477EC0),
                        ),
                      ),
                  ],
                ),
              ),
              if (!hasProject)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F9FD),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFD8E2EE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '请先选择项目文件夹',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF243245),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2D4A69),
                            side: const BorderSide(color: Color(0xFFB8CADF)),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: _pickProjectFolder,
                          icon: const Icon(Icons.folder_open_rounded, size: 18),
                          label: const Text('选择目录'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (!rootExpanded)
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 2, 12, 12),
                  child: Text(
                    '点击根目录可展开文件树',
                    style: TextStyle(fontSize: 12, color: Color(0xFF7D8FA4)),
                  ),
                )
              else if (rootError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
                  child: Text(
                    '读取失败: $rootError',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB85C5C),
                    ),
                  ),
                )
              else if (!rootLoaded || rootLoading)
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 2, 12, 12),
                  child: Text(
                    '正在加载根目录...',
                    style: TextStyle(fontSize: 12, color: Color(0xFF7D8FA4)),
                  ),
                )
              else if (rootEntries.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 2, 12, 12),
                  child: Text(
                    '当前目录为空或无可读取条目，点击刷新重试',
                    style: TextStyle(fontSize: 12, color: Color(0xFF7D8FA4)),
                  ),
                )
              else
                SizedBox(
                  height: treeHeight,
                  child: Scrollbar(
                    thumbVisibility: rows.length > 12,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(0, 2, 0, 8),
                      children: rows,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConversationDrawer() {
    final grouped = <String, List<_ConversationSummary>>{};
    final sortedHistory = List<_ConversationSummary>.from(_conversationHistory)
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) {
          return a.isPinned ? -1 : 1;
        }
        return b.timestampMs.compareTo(a.timestampMs);
      });
    final pinnedHistory = <_ConversationSummary>[];
    for (final item in sortedHistory) {
      if (item.isPinned) {
        pinnedHistory.add(item);
        continue;
      }
      final date = DateTime.fromMillisecondsSinceEpoch(item.timestampMs);
      final section = _historyGroupTitle(date);
      grouped.putIfAbsent(section, () => <_ConversationSummary>[]).add(item);
    }
    final currentTitle = _normalizedConversationTitle();
    final avatar = currentTitle.isEmpty ? '聊' : currentTitle.substring(0, 1);
    final currentWorkspaceLabel = _workspaceBindingLabel(_projectRootPath);

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.86,
      elevation: 0,
      backgroundColor: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(right: BorderSide(color: AppPalette.border)),
          boxShadow: [
            BoxShadow(
              blurRadius: 16,
              offset: const Offset(6, 0),
              color: Colors.black.withValues(alpha: 0.08),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0x1A0B6E4F),
                        border: Border.all(color: AppPalette.border),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        avatar,
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${_greetingByTime()} 👋',
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppPalette.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _showConversationTitleEditor,
                      icon: const Icon(
                        Icons.edit_rounded,
                        color: AppPalette.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _buildDrawerExplorerSection(),
              _buildDrawerQuickAction(
                icon: Icons.search_rounded,
                label: '搜索聊天',
                onTap: () {
                  Navigator.of(context).pop();
                  Future<void>.delayed(const Duration(milliseconds: 120), () {
                    if (!mounted) return;
                    unawaited(_showConversationSearch());
                  });
                },
              ),
              _buildDrawerQuickAction(
                icon: Icons.info_outline_rounded,
                label: '关于应用',
                onTap: _showAboutAppDialog,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
                  children: [
                    const Text(
                      '今天',
                      style: TextStyle(
                        fontSize: 20,
                        color: AppPalette.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildDrawerConversationTile(
                      title: currentTitle,
                      subtitle: _singleLinePreview(
                        _buildConversationPreview(),
                        maxLength: 32,
                      ),
                      workspaceLabel: currentWorkspaceLabel,
                      active: true,
                      pinned: _activeConversationPinned,
                      busy:
                          _sendingPrompt &&
                          _sendingConversationId == _activeConversationId,
                    ),
                    const SizedBox(height: 12),
                    if (pinnedHistory.isNotEmpty) ...[
                      const Text(
                        '置顶',
                        style: TextStyle(
                          fontSize: 20,
                          color: AppPalette.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...pinnedHistory.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildDrawerConversationTile(
                            title: item.title,
                            subtitle: item.preview,
                            workspaceLabel: _workspaceBindingLabel(
                              item.projectRootPath,
                            ),
                            active: false,
                            pinned: true,
                            busy:
                                _sendingPrompt &&
                                _sendingConversationId == item.id,
                            onTap: () => _restoreConversationFromHistory(item),
                            onLongPress: () =>
                                _showConversationHistoryActions(item),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    for (final section in grouped.entries) ...[
                      if (section.key != '今天') ...[
                        const SizedBox(height: 4),
                        Text(
                          section.key,
                          style: const TextStyle(
                            fontSize: 20,
                            color: AppPalette.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      ...section.value.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildDrawerConversationTile(
                            title: item.title,
                            subtitle: item.preview,
                            workspaceLabel: _workspaceBindingLabel(
                              item.projectRootPath,
                            ),
                            active: false,
                            pinned: item.isPinned,
                            busy:
                                _sendingPrompt &&
                                _sendingConversationId == item.id,
                            onTap: () => _restoreConversationFromHistory(item),
                            onLongPress: () =>
                                _showConversationHistoryActions(item),
                          ),
                        ),
                      ),
                    ],
                    if (_conversationHistory.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 18),
                        child: Text(
                          '还没有历史对话，先发一条消息吧',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppPalette.muted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFFF8FAFD),
            border: Border.all(color: AppPalette.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppPalette.ink, size: 24),
              const SizedBox(width: 14),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppPalette.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerConversationTile({
    required String title,
    required String subtitle,
    required bool active,
    String? workspaceLabel,
    bool pinned = false,
    bool busy = false,
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) {
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: active ? const Color(0xFFF2F7FC) : Colors.white,
        border: Border.all(
          color: active ? const Color(0x4D0B6E4F) : AppPalette.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    color: AppPalette.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppPalette.primary,
                    ),
                  ),
                ),
              if (pinned)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.push_pin_rounded,
                    size: 14,
                    color: AppPalette.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: AppPalette.muted),
          ),
          if (workspaceLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              workspaceLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: active ? AppPalette.primary : AppPalette.muted,
              ),
            ),
          ],
        ],
      ),
    );
    if (onTap == null && onLongPress == null) return card;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(16),
      child: card,
    );
  }

  Widget _buildComposer() {
    final modelOptions = _composerModelOptions();
    final currentModel = _activeProviderConfig.model.trim();
    final activeModelLabel = currentModel.isEmpty ? '选择模型' : currentModel;
    final activeReasoning = _activeReasoningEffort();
    final activeReasoningLabel = _reasoningEffortLabel(activeReasoning);

    return _GlassCard(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_composerAttachments.isNotEmpty) ...[
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _composerAttachments.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final item = _composerAttachments[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0x110B6E4F),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppPalette.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.isImageLike
                              ? Icons.image_rounded
                              : Icons.attach_file_rounded,
                          size: 14,
                          color: AppPalette.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppPalette.ink,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatBytes(item.sizeBytes),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppPalette.muted,
                          ),
                        ),
                        const SizedBox(width: 2),
                        InkWell(
                          onTap: () => _removeComposerAttachment(item.id),
                          borderRadius: BorderRadius.circular(999),
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: AppPalette.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              IconButton(
                onPressed: _toggleTerminal,
                icon: const Icon(Icons.terminal_rounded),
                color: AppPalette.primary,
                tooltip: '终端',
              ),
              IconButton(
                onPressed: _sendingPrompt ? null : _pickComposerFiles,
                icon: const Icon(Icons.upload_file_rounded),
                color: AppPalette.primary,
                tooltip: '上传文件',
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppPalette.border),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: _promptController,
                    focusNode: _promptFocusNode,
                    enabled: !_sendingPrompt,
                    minLines: 1,
                    maxLines: 4,
                    onSubmitted: _sendingPrompt ? null : (_) => _sendPrompt(),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: '描述你的编程需求，AI 会生成修改方案...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: AppPalette.muted,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [AppPalette.primary, Color(0xFF14919B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: IconButton(
                  onPressed: _sendingPrompt ? _stopCurrentReply : _sendPrompt,
                  tooltip: _sendingPrompt ? '停止接收' : '发送',
                  icon: _sendingPrompt
                      ? const Icon(Icons.stop_rounded, color: Colors.white)
                      : const Icon(Icons.send_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PopupMenuButton<String>(
                  tooltip: '选择模型',
                  enabled: !_sendingPrompt && modelOptions.isNotEmpty,
                  color: const Color(0xFF2B2F34),
                  onSelected: (value) => _switchComposerModel(value),
                  itemBuilder: (context) {
                    return modelOptions
                        .map(
                          (item) => CheckedPopupMenuItem<String>(
                            value: item,
                            checked: item == currentModel,
                            child: Text(
                              item,
                              style: const TextStyle(color: Color(0xFFE9EEF5)),
                            ),
                          ),
                        )
                        .toList();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xAA30353A),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0x55687380)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          activeModelLabel,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFE6EDF5),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: Color(0xFFB8C3D1),
                        ),
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: '选择推理强度',
                  enabled: !_sendingPrompt,
                  color: const Color(0xFF2B2F34),
                  onSelected: (value) => _switchComposerReasoningEffort(value),
                  itemBuilder: (context) {
                    return _reasoningEffortOrder
                        .map(
                          (item) => CheckedPopupMenuItem<String>(
                            value: item,
                            checked: item == activeReasoning,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.psychology_alt_rounded,
                                  size: 16,
                                  color: Color(0xFFCED9E7),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _reasoningEffortLabel(item),
                                  style: const TextStyle(
                                    color: Color(0xFFE9EEF5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xAA30353A),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0x55687380)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          activeReasoningLabel,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFE6EDF5),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: Color(0xFFB8C3D1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalPanel() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      left: 0,
      right: 0,
      bottom: _showTerminal ? 0 : -340,
      child: IgnorePointer(
        ignoring: !_showTerminal,
        child: Container(
          height: 320,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0A1220).withValues(alpha: 0.97),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            border: Border.all(color: const Color(0xFF203048)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.terminal_rounded, color: Color(0xFF9CB4D0)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Terminal Debug',
                      style: TextStyle(
                        color: Color(0xFFE2EEFF),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    _localShellSnapshot.isRunning ? 'shell on' : 'shell off',
                    style: const TextStyle(
                      color: Color(0xFF7AD7A0),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      setState(
                        () => _terminalLogs
                          ..clear()
                          ..add('Astra Terminal ready.'),
                      );
                      _persistState();
                    },
                    child: const Text('清空'),
                  ),
                  IconButton(
                    onPressed: () => _toggleTerminal(false),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFFE2EEFF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: _terminalScroll,
                  itemCount: _terminalLogs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        _terminalLogs[index],
                        style: const TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 12,
                          color: Color(0xFFBAD0EB),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF111B2D),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF203048)),
                ),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        r'$',
                        style: TextStyle(
                          color: Color(0xFF7AD7A0),
                          fontFamily: 'JetBrainsMono',
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _terminalController,
                        onSubmitted: (_) => _runTerminalCommand(),
                        style: const TextStyle(
                          color: Color(0xFFE2EEFF),
                          fontFamily: 'JetBrainsMono',
                          fontSize: 12,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '输入命令',
                          hintStyle: TextStyle(
                            color: Color(0xFF7088A4),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _runTerminalCommand,
                      icon: const Icon(
                        Icons.play_arrow_rounded,
                        color: Color(0xFF7AD7A0),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsDrawer() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.9,
      backgroundColor: const Color(0xFFF8F9FB),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  const Expanded(
                    child: Text(
                      '工作台设置',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _showAboutAppDialog,
                    icon: const Icon(Icons.info_outline_rounded),
                    tooltip: '关于应用',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _buildSettingsBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildAssistantMarkdownBody(String markdown) {
    return MarkdownBody(
      data: markdown,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: const TextStyle(fontSize: 13, color: AppPalette.ink, height: 1.55),
        code: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 12,
          color: AppPalette.ink,
        ),
        codeblockDecoration: BoxDecoration(
          color: const Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppPalette.border),
        ),
        blockquote: const TextStyle(
          fontSize: 12,
          color: AppPalette.muted,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildStructuredAssistantMessageCard({
    required ChatMessage message,
    required int messageIndex,
  }) {
    final reasoningParts = message.parts.whereType<ReasoningPart>().toList();
    final contentParts = message.parts.whereType<ContentPart>().toList();
    final toolParts = message.parts.whereType<ToolCallPart>().toList();
    final progressParts = message.parts.whereType<AgentProgressPart>().toList();
    final toolActivityParts = message.parts
        .whereType<ToolActivityPart>()
        .toList();
    final citationParts = message.parts.whereType<CitationPart>().toList();
    final metadataPart = message.parts
        .whereType<MetadataPart>()
        .cast<MetadataPart?>()
        .firstWhere((item) => item != null, orElse: () => null);
    final metadata = metadataPart?.metadata ?? message.metadata;
    final hasVisibleSection =
        (_isReplySectionEnabled(_replySectionReasoning) &&
            reasoningParts.isNotEmpty) ||
        (_isReplySectionEnabled(_replySectionContent) &&
            contentParts.isNotEmpty) ||
        (_isReplySectionEnabled(_replySectionToolCalls) &&
            toolParts.isNotEmpty) ||
        (_isReplySectionEnabled(_replySectionAgentProgress) &&
            progressParts.isNotEmpty) ||
        (_isReplySectionEnabled(_replySectionToolActivity) &&
            toolActivityParts.isNotEmpty) ||
        (_isReplySectionEnabled(_replySectionMetadata) &&
            metadata != null &&
            metadata.hasAnyValue) ||
        citationParts.isNotEmpty;

    if (!hasVisibleSection) {
      return Text(
        message.text,
        style: const TextStyle(
          fontSize: 13,
          color: AppPalette.ink,
          height: 1.45,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isReplySectionEnabled(_replySectionReasoning) &&
            reasoningParts.isNotEmpty)
          _buildStructuredSection(
            messageIndex: messageIndex,
            sectionId: 'reasoning',
            title: '思考',
            subtitle: reasoningParts.length > 1
                ? '${reasoningParts.length} 段'
                : '',
            defaultExpanded: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: reasoningParts
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        item.summary,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppPalette.muted,
                          height: 1.5,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        if (_isReplySectionEnabled(_replySectionContent) &&
            contentParts.isNotEmpty)
          ...contentParts.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildAssistantMarkdownBody(item.markdown),
            ),
          ),
        if (_legacyStructuredAssistantSectionsEnabled &&
            _isReplySectionEnabled(_replySectionContent) &&
            contentParts.isNotEmpty)
          _buildStructuredSection(
            messageIndex: messageIndex,
            sectionId: 'content',
            title: '主体内容',
            subtitle: '',
            defaultExpanded: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: contentParts
                  .map(
                    (item) => MarkdownBody(
                      data: item.markdown,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(
                          fontSize: 13,
                          color: AppPalette.ink,
                          height: 1.55,
                        ),
                        code: const TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 12,
                          color: AppPalette.ink,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: const Color(0xFFF5F7FA),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppPalette.border),
                        ),
                        blockquote: const TextStyle(
                          fontSize: 12,
                          color: AppPalette.muted,
                          height: 1.5,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        if (_isReplySectionEnabled(_replySectionToolCalls) &&
            toolParts.isNotEmpty)
          ...toolParts.map(
            (item) => _buildToolCallTranscriptSection(
              messageIndex: messageIndex,
              item: item,
            ),
          ),
        if (_legacyStructuredAssistantSectionsEnabled &&
            _isReplySectionEnabled(_replySectionToolCalls) &&
            toolParts.isNotEmpty)
          _buildStructuredSection(
            messageIndex: messageIndex,
            sectionId: 'tools',
            title: '工具调用',
            subtitle: '${toolParts.length} 次',
            defaultExpanded: false,
            child: Column(
              children: toolParts
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFD),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppPalette.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.toolName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppPalette.ink,
                                    ),
                                  ),
                                ),
                                Text(
                                  item.status,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppPalette.muted,
                                  ),
                                ),
                              ],
                            ),
                            if (item.reason.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                '原因：${item.reason}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppPalette.muted,
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            SelectableText(
                              item.argumentsJson,
                              style: const TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 11,
                                color: AppPalette.ink,
                                height: 1.45,
                              ),
                            ),
                            if (item.outputPreview.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                '结果：${item.outputPreview}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppPalette.muted,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        if (_isReplySectionEnabled(_replySectionAgentProgress) &&
            progressParts.isNotEmpty)
          _buildStructuredSection(
            messageIndex: messageIndex,
            sectionId: 'agent_progress',
            title: '智能体进度说明',
            subtitle:
                '${progressParts.fold<int>(0, (sum, item) => sum + item.entries.length)} 条',
            defaultExpanded: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: progressParts.map((part) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFD),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppPalette.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (part.summary.trim().isNotEmpty)
                          Text(
                            part.summary,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.ink,
                            ),
                          ),
                        if (part.summary.trim().isNotEmpty &&
                            part.entries.isNotEmpty)
                          const SizedBox(height: 8),
                        ...part.entries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  margin: const EdgeInsets.only(top: 5),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppPalette.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.title,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppPalette.ink,
                                        ),
                                      ),
                                      if (entry.detail.trim().isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: Text(
                                            entry.detail,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppPalette.muted,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  entry.time,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppPalette.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        if (_isReplySectionEnabled(_replySectionToolActivity) &&
            toolActivityParts.isNotEmpty)
          _buildStructuredSection(
            messageIndex: messageIndex,
            sectionId: 'tool_activity',
            title: '工具活动',
            subtitle:
                '${toolActivityParts.fold<int>(0, (sum, item) => sum + item.entries.length)} 条',
            defaultExpanded: false,
            child: Column(
              children: toolActivityParts.expand((part) => part.entries).map((
                entry,
              ) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFD),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppPalette.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.toolName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppPalette.ink,
                                ),
                              ),
                            ),
                            if (entry.durationMs != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(
                                  '${entry.durationMs}ms',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppPalette.muted,
                                  ),
                                ),
                              ),
                            Text(
                              entry.status,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppPalette.muted,
                              ),
                            ),
                          ],
                        ),
                        if (entry.argsPreview.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            entry.argsPreview,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppPalette.muted,
                              height: 1.4,
                            ),
                          ),
                        ],
                        if (entry.summary.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            entry.summary,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppPalette.ink,
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          entry.time,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppPalette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        if (citationParts.isNotEmpty)
          _buildStructuredSection(
            messageIndex: messageIndex,
            sectionId: 'citations',
            title: '引用 / 溯源',
            subtitle: '${citationParts.length} 条',
            defaultExpanded: false,
            child: Column(
              children: citationParts
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFD),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppPalette.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title.isEmpty ? item.uri : item.title,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppPalette.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              item.uri,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppPalette.primary,
                              ),
                            ),
                            if (item.snippet.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.snippet,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppPalette.muted,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        if (_isReplySectionEnabled(_replySectionMetadata) &&
            metadata != null &&
            metadata.hasAnyValue)
          _buildStructuredSection(
            messageIndex: messageIndex,
            sectionId: 'metadata',
            title: '详情',
            subtitle: '',
            defaultExpanded: false,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (metadata.model.trim().isNotEmpty)
                  _AgentMetricChip(label: '模型 ${metadata.model}'),
                if (metadata.inputTokens != null)
                  _AgentMetricChip(label: '输入 ${metadata.inputTokens}'),
                if (metadata.outputTokens != null)
                  _AgentMetricChip(label: '输出 ${metadata.outputTokens}'),
                if (metadata.reasoningTokens != null)
                  _AgentMetricChip(label: '推理 ${metadata.reasoningTokens}'),
                if (metadata.elapsedMs != null)
                  _AgentMetricChip(label: '耗时 ${metadata.elapsedMs}ms'),
                if (metadata.finishReason.trim().isNotEmpty)
                  _AgentMetricChip(label: '结束 ${metadata.finishReason}'),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStructuredSection({
    required int messageIndex,
    required String sectionId,
    required String title,
    required String subtitle,
    required bool defaultExpanded,
    required Widget child,
  }) {
    final key = '$messageIndex:$sectionId';
    final expanded =
        _expandedStructuredMessageSections.contains(key) ||
        (_expandedStructuredMessageSections.isEmpty && defaultExpanded);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppPalette.border),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  if (_expandedStructuredMessageSections.contains(key)) {
                    _expandedStructuredMessageSections.remove(key);
                  } else {
                    _expandedStructuredMessageSections.add(key);
                  }
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        subtitle.isEmpty ? title : '$title  $subtitle',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.ink,
                        ),
                      ),
                    ),
                    Icon(
                      expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 18,
                      color: AppPalette.muted,
                    ),
                  ],
                ),
              ),
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: child,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolCallTranscriptSection({
    required int messageIndex,
    required ToolCallPart item,
  }) {
    final command = item.commandText.trim();
    final status = item.status.trim();
    final statusLabel = switch (status) {
      'running' => '运行中',
      'streaming' => '准备调用',
      'cached' => '已复用',
      'failed' => '失败',
      'done' => '已完成',
      _ => status,
    };
    final actionLabel = switch (status) {
      'running' => '正在运行',
      'streaming' => '准备调用',
      _ => command.isNotEmpty ? '已运行' : '已调用',
    };
    final title = command.isNotEmpty
        ? '$actionLabel ${_singleLinePreview(command, maxLength: 64)}'
        : '$actionLabel ${item.toolName}';
    final transcript = StringBuffer();
    if (command.isNotEmpty) {
      transcript.writeln('\$ $command');
    } else if (item.argumentsJson.trim().isNotEmpty) {
      transcript.writeln('参数');
      transcript.writeln(item.argumentsJson.trim());
    }
    if (item.stdout.trim().isNotEmpty) {
      if (transcript.isNotEmpty) transcript.writeln();
      transcript.writeln(item.stdout.trimRight());
    }
    if (item.stderr.trim().isNotEmpty) {
      if (transcript.isNotEmpty) transcript.writeln();
      transcript.writeln('stderr');
      transcript.writeln(item.stderr.trimRight());
    }
    if (transcript.isEmpty && item.outputPreview.trim().isNotEmpty) {
      transcript.writeln(item.outputPreview.trim());
    }

    return _buildStructuredSection(
      messageIndex: messageIndex,
      sectionId: 'tool:${item.id.isEmpty ? item.toolName : item.id}',
      title: title,
      subtitle: statusLabel,
      defaultExpanded: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF2B2B2B),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Shell',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 11,
                color: Color(0xFFB8B8B8),
              ),
            ),
            if (transcript.isNotEmpty) ...[
              const SizedBox(height: 10),
              SelectableText(
                transcript.toString().trimRight(),
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 12,
                  color: Color(0xFFE7E7E7),
                  height: 1.55,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _executeFileAction(String action) async {
    if (_projectRootPath == null &&
        (action == 'write' ||
            action == 'create-file' ||
            action == 'create-dir')) {
      await _createAndBindEmptyWorkspace(
        label: _filePathController.text.trim().isEmpty
            ? _normalizedConversationTitle()
            : _filePathController.text.trim(),
      );
    }
    if (_projectRootPath == null) {
      setState(() {
        _fileOpsStatus = '请先选择项目文件夹';
      });
      return;
    }
    if (!_aiFsGranted) {
      setState(() {
        _fileOpsStatus = '请先开启 AI 文件读写权限';
      });
      return;
    }

    final relativePath = _normalizeInputPath(_filePathController.text);
    if (relativePath.isEmpty) {
      setState(() {
        _fileOpsStatus = '请输入相对路径';
      });
      return;
    }

    try {
      if (action == 'read') {
        final text = await _readFileText(relativePath);
        _fileContentController.text = text;
        _fileOpsStatus = '读取成功: $relativePath';
      } else if (action == 'write') {
        await _writeFileText(relativePath, _fileContentController.text);
        _fileOpsStatus = '写入成功: $relativePath';
      } else if (action == 'create-file') {
        await _writeFileText(relativePath, _fileContentController.text);
        _fileOpsStatus = '新建文件成功: $relativePath';
      } else if (action == 'create-dir') {
        await _createDirectory(relativePath);
        _fileOpsStatus = '新建目录成功: $relativePath';
      } else if (action == 'delete') {
        await _deleteEntry(relativePath);
        _fileOpsStatus = '删除成功: $relativePath';
      }
      await _loadProjectFolder(_projectRootPath!, silent: true);
      setState(() {});
    } catch (error) {
      setState(() {
        _fileOpsStatus = '失败: $error';
      });
    }
  }

  Widget _buildSettingsBody() {
    final sections = <_SettingsSectionEntry>[
      _SettingsSectionEntry(
        id: 'solution_overview',
        title: '方案总览',
        summary: '查看当前移动端 AI 编程工作台的落地状态与性能优化结果。',
        icon: Icons.dashboard_customize_rounded,
        builder: _buildSolutionOverviewSection,
      ),
      _SettingsSectionEntry(
        id: 'components',
        title: '内置组件',
        summary: '查看已内置的运行时、工具链、Agent 能力与外部依赖说明。',
        icon: Icons.widgets_rounded,
        builder: _buildBuiltInComponentsSection,
      ),
      _SettingsSectionEntry(
        id: 'embedded_dev_stack',
        title: '内置开发栈',
        summary: '在 APK 内直接使用 Git、JADX 和 APK 签名校验能力，减少对外部 App 的依赖。',
        icon: Icons.inventory_2_rounded,
        builder: _buildEmbeddedDevStackSection,
      ),
      _SettingsSectionEntry(
        id: 'project',
        title: '项目与工作区',
        summary: '绑定项目目录、导入上下文、准备镜像工作区与文件权限。',
        icon: Icons.folder_copy_rounded,
        builder: _buildProjectSection,
      ),
      _SettingsSectionEntry(
        id: 'local_runtime',
        title: 'Android 本地运行时',
        summary: '管理前台服务、镜像工作区、本地 Shell 与运行状态。',
        icon: Icons.memory_rounded,
        builder: _buildLocalRuntimeSection,
      ),
      _SettingsSectionEntry(
        id: 'execution_backends',
        title: '执行后端',
        summary: '切换 Native / Termux / Shizuku / Root 等执行与设备控制后端。',
        icon: Icons.hub_rounded,
        builder: _buildExecutionBackendsSection,
      ),
      _SettingsSectionEntry(
        id: 'android_toolkit',
        title: 'Android 工具',
        summary: 'Gradle、ADB、Apktool、JADX、签名与安装能力集中在这里。',
        icon: Icons.android_rounded,
        builder: _buildAndroidToolkitSection,
      ),
      _SettingsSectionEntry(
        id: 'runtime_workbench',
        title: '运行时工作台',
        summary: '查看镜像差异、Git 输出、Shell 会话与同步状态。',
        icon: Icons.workspaces_rounded,
        builder: _buildRuntimeWorkbenchSection,
      ),
      _SettingsSectionEntry(
        id: 'agent',
        title: 'Agent 执行',
        summary: '查看规划、进度、工具调用与当前收敛状态。',
        icon: Icons.auto_awesome_rounded,
        builder: _buildAgentExecutionSection,
      ),
      _SettingsSectionEntry(
        id: 'api',
        title: '模型与 API',
        summary: '配置 OpenAI / Claude / DeepSeek 等模型连接。',
        icon: Icons.link_rounded,
        builder: _buildApiConnectionSection,
      ),
      _SettingsSectionEntry(
        id: 'reply_structure',
        title: '回复结构',
        summary: '勾选每次模型回复里默认展示哪些模块，包括思考、工具、进度和元数据。',
        icon: Icons.view_agenda_rounded,
        builder: _buildReplyStructureSection,
      ),
      _SettingsSectionEntry(
        id: 'terminal',
        title: '终端与后台',
        summary: '终端能力、后台守护、通知保活等辅助能力。',
        icon: Icons.dns_rounded,
        builder: () => Column(
          children: [
            _buildBackgroundGuardSection(),
            const SizedBox(height: 12),
            _buildTerminalSection(),
          ],
        ),
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
      itemCount: sections.length,
      itemBuilder: (context, index) =>
          _buildSettingsSectionCard(sections[index]),
    );
  }

  Widget _buildReplyStructureSection() {
    final options =
        <({String id, String title, String subtitle, IconData icon})>[
          (
            id: _replySectionReasoning,
            title: '思考内容',
            subtitle: '展示模型提炼出的推理摘要。',
            icon: Icons.psychology_alt_rounded,
          ),
          (
            id: _replySectionContent,
            title: '主体内容',
            subtitle: '展示最终正文和 Markdown 内容。',
            icon: Icons.subject_rounded,
          ),
          (
            id: _replySectionToolCalls,
            title: '调用工具',
            subtitle: '展示模型规划调用的工具与参数。',
            icon: Icons.handyman_rounded,
          ),
          (
            id: _replySectionAgentProgress,
            title: '智能体进度说明',
            subtitle: '展示执行过程中的计划、阶段和关键步骤。',
            icon: Icons.timeline_rounded,
          ),
          (
            id: _replySectionMetadata,
            title: '元数据',
            subtitle: '展示模型、Token、耗时和结束原因。',
            icon: Icons.data_object_rounded,
          ),
          (
            id: _replySectionToolActivity,
            title: '工具活动',
            subtitle: '展示工具执行状态、摘要和结果回顾。',
            icon: Icons.precision_manufacturing_rounded,
          ),
        ];

    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '每次模型回复的结构构成',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppPalette.ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '勾选后会在聊天区的结构化回复里展示对应模块。取消勾选不会删除数据，只是不再默认展示。',
            style: TextStyle(
              fontSize: 12,
              color: AppPalette.muted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          ...options.map((option) {
            final enabled = _isReplySectionEnabled(option.id);
            return CheckboxListTile(
              value: enabled,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              secondary: Icon(option.icon, color: AppPalette.primary),
              title: Text(option.title),
              subtitle: Text(option.subtitle),
              onChanged: (value) {
                _setReplySectionEnabled(option.id, value ?? false);
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildApiConnectionSection() {
    final activeConnection = _activeConnection;
    final visibleConnections = activeConnection == null
        ? <ApiConnectionProfile>[]
        : <ApiConnectionProfile>[activeConnection];
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'API 连接管理',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.ink,
                  ),
                ),
              ),
              Text(
                '${_apiConnections.length} 个',
                style: const TextStyle(fontSize: 12, color: AppPalette.muted),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _apiConnectionsCollapsed = !_apiConnectionsCollapsed;
                  });
                  _persistState();
                },
                tooltip: _apiConnectionsCollapsed ? '展开' : '折叠',
                icon: Icon(
                  _apiConnectionsCollapsed
                      ? Icons.expand_more_rounded
                      : Icons.expand_less_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            activeConnection == null
                ? '当前未启用连接'
                : '当前启用: ${activeConnection.name} (${_providerName(activeConnection.providerId)} / ${activeConnection.model})',
            style: const TextStyle(fontSize: 12, color: AppPalette.muted),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.primary,
                  ),
                  onPressed: _showApiConnectionManager,
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('打开连接管理'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _showApiConnectionEditor(activateOnSave: true),
                icon: const Icon(Icons.add_rounded),
                tooltip: '新建连接',
              ),
            ],
          ),
          if (visibleConnections.isNotEmpty && !_apiConnectionsCollapsed) ...[
            const SizedBox(height: 10),
            ...visibleConnections.map((item) {
              final provider = _providerById(item.providerId);
              final enabled = item.id == _activeConnectionId;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFD),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppPalette.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ProviderLogo(provider: provider, size: 34),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppPalette.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${provider.name} • ${item.model}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppPalette.muted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _maskApiKey(item.apiKey),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppPalette.muted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '网络兼容: ${item.improveNetworkCompatibility ? '开启' : '关闭'}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppPalette.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: enabled
                            ? null
                            : () => _activateConnection(item.id),
                        child: Text(enabled ? '已启用' : '启用'),
                      ),
                      IconButton(
                        onPressed: () =>
                            _showApiConnectionEditor(editing: item),
                        icon: const Icon(Icons.edit_rounded, size: 20),
                        tooltip: '编辑',
                      ),
                      IconButton(
                        onPressed: () async {
                          final confirmed = await _confirmDeleteConnection(
                            item,
                          );
                          if (!confirmed) return;
                          await _deleteConnection(item);
                        },
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                        ),
                        tooltip: '删除',
                      ),
                    ],
                  ),
                ),
              );
            }),
          ] else if (_apiConnections.isNotEmpty &&
              _apiConnectionsCollapsed) ...[
            const SizedBox(height: 8),
            const Text(
              '连接列表已折叠',
              style: TextStyle(fontSize: 12, color: AppPalette.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConversationWorkspaceHeader() {
    final hasWorkspace = _projectRootPath?.trim().isNotEmpty ?? false;
    final workspacePath = _projectRootPath?.trim() ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: hasWorkspace
                      ? const Color(0x1A0B6E4F)
                      : const Color(0x14334155),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  hasWorkspace
                      ? Icons.folder_copy_rounded
                      : Icons.chat_bubble_outline_rounded,
                  size: 18,
                  color: hasWorkspace ? AppPalette.primary : AppPalette.muted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasWorkspace ? '当前对话工作区' : '当前对话未绑定工作区',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppPalette.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasWorkspace
                          ? workspacePath
                          : '普通聊天不会读取或修改文件；需要文件能力时可绑定文件夹，或创建本地空工作区。',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppPalette.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (_readingProject)
                const Padding(
                  padding: EdgeInsets.only(left: 8, top: 3),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.primary,
                ),
                onPressed: _pickProjectFolder,
                icon: const Icon(Icons.folder_open_rounded),
                label: Text(hasWorkspace ? '更换工作区' : '绑定文件夹'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _createAndBindEmptyWorkspace(),
                icon: const Icon(Icons.create_new_folder_rounded),
                label: const Text('创建空工作区'),
              ),
              OutlinedButton.icon(
                onPressed: hasWorkspace
                    ? () => _loadProjectFolder(_projectRootPath!, silent: true)
                    : null,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('刷新'),
              ),
              OutlinedButton.icon(
                onPressed: hasWorkspace ? _unbindCurrentWorkspace : null,
                icon: const Icon(Icons.link_off_rounded),
                label: const Text('解绑'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProjectSection() {
    const presetDownloadMaxBytes = <int>[
      16777216, // 16 MiB
      33554432, // 32 MiB
      67108864, // 64 MiB
      134217728, // 128 MiB
      268435456, // 256 MiB
      536870912, // 512 MiB
    ];
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildConversationWorkspaceHeader(),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _checkingPermissions
                ? null
                : _auditAndRequestPermissions,
            icon: _checkingPermissions
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.verified_user_rounded),
            label: Text(_checkingPermissions ? '检查中...' : '检查并获取联网/存储权限'),
          ),
          const SizedBox(height: 6),
          Text(
            _permissionAuditStatus,
            style: const TextStyle(fontSize: 11, color: AppPalette.muted),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _projectRootPath == null ? null : _injectProjectContext,
            icon: const Icon(Icons.integration_instructions_rounded),
            label: Text(
              _projectFiles.isEmpty
                  ? '导入到 AI 上下文'
                  : '导入到 AI 上下文 (${_projectFiles.length})',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _projectRootPath == null || _preparingLocalWorkspace
                ? null
                : _prepareLocalWorkspaceMirror,
            icon: _preparingLocalWorkspace
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.copy_all_rounded),
            label: Text(_preparingLocalWorkspace ? '正在准备执行镜像...' : '准备执行镜像'),
          ),
          const SizedBox(height: 6),
          Text(
            _localRuntimeStatus.hasWorkspace
                ? '执行镜像已就绪: ${_localRuntimeStatus.activeWorkspacePath}'
                : '执行镜像尚未准备。',
            style: const TextStyle(fontSize: 11, color: AppPalette.muted),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _aiFsGranted,
            contentPadding: EdgeInsets.zero,
            title: const Text('授予 AI 文件夹读写权限'),
            subtitle: const Text('允许 AI 在此目录执行新建/删除/读写'),
            onChanged: _projectRootPath == null
                ? null
                : (value) {
                    setState(() => _aiFsGranted = value);
                    _persistState();
                  },
          ),
          const Text(
            'AI 命令格式: @fs read 路径 / @fs write 路径 ::: 内容 / @fs create-file / @fs create-dir / @fs delete / @fs download URL ::: 路径',
            style: TextStyle(fontSize: 11, color: AppPalette.muted),
          ),
          const SizedBox(height: 10),
          const Text(
            '下载大小上限',
            style: TextStyle(
              fontSize: 12,
              color: AppPalette.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '当前: ${_formatBytes(_downloadAssetMaxBytes)} ($_downloadAssetMaxBytes bytes)，范围 64 KB - ${_formatBytes(_maxDownloadMaxBytes)}',
            style: const TextStyle(fontSize: 11, color: AppPalette.muted),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presetDownloadMaxBytes.map((limit) {
              return ChoiceChip(
                label: Text(_formatBytes(limit)),
                selected: _downloadAssetMaxBytes == limit,
                onSelected: (_) => _updateDownloadMaxBytes(limit),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          TextFormField(
            key: ValueKey('download_max_bytes_$_downloadAssetMaxBytes'),
            initialValue: _downloadAssetMaxBytes.toString(),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: '自定义 max_bytes',
              hintText: '输入字节数，例如 134217728',
              isDense: true,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: '恢复默认',
                onPressed: () =>
                    _updateDownloadMaxBytes(_defaultDownloadMaxBytes),
                icon: const Icon(Icons.restart_alt_rounded),
              ),
            ),
            onFieldSubmitted: _applyDownloadMaxBytesInput,
          ),
          const SizedBox(height: 8),
          const Text(
            '文件操作路径（相对项目根目录）',
            style: TextStyle(fontSize: 12, color: AppPalette.muted),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _filePathController,
            decoration: const InputDecoration(
              hintText: '例如: lib/new_page.dart 或 assets/images',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '文件内容',
            style: TextStyle(fontSize: 12, color: AppPalette.muted),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _fileContentController,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: '读取后会显示内容；写入/新建文件时使用这里的内容',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: () => _executeFileAction('read'),
                child: const Text('读取'),
              ),
              FilledButton.tonal(
                onPressed: () => _executeFileAction('write'),
                child: const Text('写入'),
              ),
              FilledButton.tonal(
                onPressed: () => _executeFileAction('create-file'),
                child: const Text('新建文件'),
              ),
              FilledButton.tonal(
                onPressed: () => _executeFileAction('create-dir'),
                child: const Text('新建目录'),
              ),
              FilledButton.tonal(
                onPressed: () => _executeFileAction('delete'),
                child: const Text('删除'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _fileOpsStatus,
            style: const TextStyle(fontSize: 12, color: AppPalette.muted),
          ),
          if (_projectFiles.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              '文件预览',
              style: TextStyle(
                fontSize: 12,
                color: AppPalette.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            ..._projectFiles.take(5).map((file) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${file.path}  (${file.sizeBytes}B${file.isBinary ? ', binary' : ''})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppPalette.muted),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildLocalRuntimeSection() {
    final supported = Platform.isAndroid && _localRuntimeStatus.supported;
    final running = _localRuntimeStatus.isRunning;
    final summary = _localRuntimeStatus.summary;
    final workspacePath = _localRuntimeStatus.activeWorkspacePath;
    final runtimeRoot = _localRuntimeStatus.runtimeRoot;
    final workspacesRoot = _localRuntimeStatus.workspacesRoot;
    final lastError = _localRuntimeStatus.lastError;
    final fileCount = _localRuntimeStatus.mirroredFileCount;
    final directoryCount = _localRuntimeStatus.mirroredDirectoryCount;
    final shellRunning = _localRuntimeStatus.shellRunning;
    final shellWorkingDirectory = _localRuntimeStatus.shellWorkingDirectory;
    final shellLastError = _localRuntimeStatus.shellLastError;

    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  summary,
                  style: const TextStyle(fontSize: 12, color: AppPalette.muted),
                ),
              ),
              if (_loadingLocalRuntimeStatus)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: !supported || _loadingLocalRuntimeStatus
                    ? null
                    : (running ? _stopLocalRuntime : _startLocalRuntime),
                icon: Icon(
                  running
                      ? Icons.stop_circle_outlined
                      : Icons.play_arrow_rounded,
                ),
                label: Text(running ? '停止运行时' : '启动运行时'),
              ),
              OutlinedButton.icon(
                onPressed: _loadingLocalRuntimeStatus
                    ? null
                    : () =>
                          _refreshLocalRuntimeStatus(showFailureSnackBar: true),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('刷新'),
              ),
              OutlinedButton.icon(
                onPressed: !supported || _preparingLocalWorkspace
                    ? null
                    : _prepareLocalWorkspaceMirror,
                icon: const Icon(Icons.copy_all_rounded),
                label: const Text('镜像工作区'),
              ),
              OutlinedButton.icon(
                onPressed: !supported
                    ? null
                    : (shellRunning ? _stopShellSession : _startShellSession),
                icon: Icon(
                  shellRunning
                      ? Icons.terminal_rounded
                      : Icons.play_circle_outline_rounded,
                ),
                label: Text(shellRunning ? '停止 Shell' : '启动 Shell'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            supported ? '平台: 已启用 Android 本地运行时' : '平台: 当前设备不可用',
            style: const TextStyle(fontSize: 12, color: AppPalette.ink),
          ),
          if (runtimeRoot.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '运行时根目录: $runtimeRoot',
              style: const TextStyle(fontSize: 11, color: AppPalette.muted),
            ),
          ],
          if (workspacesRoot.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '工作区根目录: $workspacesRoot',
              style: const TextStyle(fontSize: 11, color: AppPalette.muted),
            ),
          ],
          if (workspacePath.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '当前镜像目录: $workspacePath',
              style: const TextStyle(fontSize: 11, color: AppPalette.muted),
            ),
            const SizedBox(height: 4),
            Text(
              '镜像统计: $fileCount 个文件，$directoryCount 个目录',
              style: const TextStyle(fontSize: 11, color: AppPalette.muted),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            shellRunning ? 'Shell 会话: 运行中' : 'Shell 会话: 已停止',
            style: const TextStyle(fontSize: 11, color: AppPalette.muted),
          ),
          if (shellWorkingDirectory.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Shell 工作目录: $shellWorkingDirectory',
              style: const TextStyle(fontSize: 11, color: AppPalette.muted),
            ),
          ],
          if (shellLastError.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Shell 错误: $shellLastError',
              style: const TextStyle(fontSize: 11, color: Colors.redAccent),
            ),
          ],
          if (lastError.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '最近错误: $lastError',
              style: const TextStyle(fontSize: 11, color: Colors.redAccent),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExecutionBackendsSection() {
    final supported = Platform.isAndroid;
    final termuxReady = _runtimeBackendStatus.termuxReady;
    final termuxTemplateHint =
        'proot-distro login ubuntu --shared-tmp -- /bin/bash -lc {{command}}';

    Widget buildBackendCard({
      required String title,
      required String summary,
      required bool ready,
      required IconData icon,
      VoidCallback? onOpen,
    }) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFD),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppPalette.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: ready ? AppPalette.primary : AppPalette.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    summary,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppPalette.muted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Chip(
                  label: Text(ready ? '就绪' : '待配置'),
                  visualDensity: VisualDensity.compact,
                ),
                if (onOpen != null)
                  TextButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('打开'),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    final executionRoot = _primaryExecutionBackend == 'termux'
        ? _termuxWorkingDirectory()
        : _localRuntimeExecutionRoot();
    final backendError = _runtimeBackendStatus.lastError.trim();

    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '把构建、Git、安装与日志等操作分发到专用 Android 执行后端。',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppPalette.muted,
                    height: 1.45,
                  ),
                ),
              ),
              if (_loadingRuntimeBackendStatus)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          buildBackendCard(
            title: '原生 Shell 后端',
            summary: '保留当前本地运行时流程，适合轻量命令与镜像工作区工具。',
            ready: _runtimeBackendStatus.nativeAvailable,
            icon: Icons.developer_mode_rounded,
          ),
          const SizedBox(height: 8),
          buildBackendCard(
            title: 'Termux / PRoot 后端',
            summary: termuxReady
                ? '推荐作为主后端，用于 Gradle、Python、Node、Git、apktool、jadx 与 Ubuntu 工具链。'
                : '请先安装 Termux、授予 RUN_COMMAND 权限，再按需套用 PRoot Ubuntu 命令模板。',
            ready: termuxReady,
            icon: Icons.terminal_rounded,
            onOpen: _runtimeBackendStatus.termuxLaunchable
                ? () => _openRuntimeBackendApp('termux')
                : null,
          ),
          const SizedBox(height: 8),
          buildBackendCard(
            title: 'Root / SU 设备后端',
            summary: _runtimeBackendStatus.rootAvailable
                ? '当 Shizuku 不可用时，可使用 Root 权限执行 pm 安装、设备命令和更完整的日志读取。'
                : '这是面向已 Root 设备的备用方案；未 Root 设备可继续使用 CLI / ADB 或 Shizuku / 系统后端。',
            ready: _runtimeBackendStatus.rootAvailable,
            icon: Icons.security_rounded,
          ),
          const SizedBox(height: 8),
          buildBackendCard(
            title: 'Shizuku / 设备后端',
            summary: _runtimeBackendStatus.shizukuInstalled
                ? '适合在不依赖 CLI 工具链时执行 APK 安装与设备侧日志采集。'
                : '安装 Shizuku 后可获得更丰富的设备操作能力，当前桥接已支持打开 Shizuku 和系统安装/日志动作。',
            ready:
                _runtimeBackendStatus.shizukuInstalled ||
                _runtimeBackendStatus.systemLogcatAvailable,
            icon: Icons.android_rounded,
            onOpen: _runtimeBackendStatus.shizukuLaunchable
                ? () => _openRuntimeBackendApp('shizuku')
                : null,
          ),
          const SizedBox(height: 12),
          const Text(
            '主要执行后端',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppPalette.ink,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('原生 Shell'),
                selected: _primaryExecutionBackend == 'native',
                onSelected: !supported
                    ? null
                    : (_) {
                        setState(() {
                          _primaryExecutionBackend = 'native';
                        });
                        _persistState();
                      },
              ),
              ChoiceChip(
                label: const Text('Termux / PRoot'),
                selected: _primaryExecutionBackend == 'termux',
                onSelected: !supported
                    ? null
                    : (_) {
                        setState(() {
                          _primaryExecutionBackend = 'termux';
                        });
                        _persistState();
                      },
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '设备操作后端',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppPalette.ink,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('CLI / ADB'),
                selected: _deviceOperationsBackend == 'native',
                onSelected: !supported
                    ? null
                    : (_) {
                        setState(() {
                          _deviceOperationsBackend = 'native';
                        });
                        _persistState();
                      },
              ),
              ChoiceChip(
                label: const Text('Shizuku / 系统'),
                selected: _deviceOperationsBackend == 'shizuku',
                onSelected: !supported
                    ? null
                    : (_) {
                        setState(() {
                          _deviceOperationsBackend = 'shizuku';
                        });
                        _persistState();
                      },
              ),
              ChoiceChip(
                label: const Text('Root / SU'),
                selected: _deviceOperationsBackend == 'root',
                onSelected: !supported
                    ? null
                    : (_) {
                        setState(() {
                          _deviceOperationsBackend = 'root';
                        });
                        _persistState();
                      },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InputField(
            label: 'Termux 工作目录',
            controller: _termuxWorkdirController,
            hintText: '/storage/emulated/0/your-project',
            onChanged: (_) => _persistState(),
          ),
          const SizedBox(height: 10),
          _InputField(
            label: 'Termux 命令模板',
            controller: _termuxCommandTemplateController,
            hintText: termuxTemplateHint,
            onChanged: (_) => _persistState(),
          ),
          const SizedBox(height: 6),
          Text(
            '使用 {{command}} 作为生成命令的占位符；留空则直接在 Termux 中执行原始命令。',
            style: const TextStyle(fontSize: 11, color: AppPalette.muted),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppPalette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前主要后端：${_primaryBackendLabel(_primaryExecutionBackend)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '执行根目录：${executionRoot.isEmpty ? '尚未配置' : executionRoot}',
                  style: const TextStyle(fontSize: 11, color: AppPalette.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  '设备后端：${_deviceBackendLabel(_deviceOperationsBackend)}',
                  style: const TextStyle(fontSize: 11, color: AppPalette.muted),
                ),
                if (backendError.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    '最近后端错误：$backendError',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _loadingRuntimeBackendStatus
                    ? null
                    : () => _refreshRuntimeBackendStatus(
                        showFailureSnackBar: true,
                      ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('刷新'),
              ),
              OutlinedButton.icon(
                onPressed: _runtimeBackendStatus.termuxLaunchable
                    ? () => _openRuntimeBackendApp('termux')
                    : null,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('打开 Termux'),
              ),
              OutlinedButton.icon(
                onPressed: _runtimeBackendStatus.shizukuLaunchable
                    ? () => _openRuntimeBackendApp('shizuku')
                    : null,
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('打开 Shizuku'),
              ),
              FilledButton.tonalIcon(
                onPressed: !supported ? null : _testCurrentExecutionBackend,
                icon: const Icon(Icons.play_circle_outline_rounded),
                label: const Text('测试后端'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAndroidToolkitSection() {
    final supported =
        Platform.isAndroid &&
        (_primaryExecutionBackend == 'termux'
            ? _runtimeBackendStatus.termuxReady
            : _localRuntimeStatus.supported);
    final executionRoot = _primaryExecutionBackend == 'termux'
        ? _termuxWorkingDirectory()
        : _localRuntimeExecutionRoot();
    final reverseLabel = _androidToolkitReverseLabel();
    final reverseRoot = _androidToolkitReverseRoot(reverseLabel);
    final busy = _runningAndroidToolkitAction;

    Future<void> runAction(
      String title,
      Future<Map<String, dynamic>> Function() action,
    ) {
      return _runAndroidToolkitAction(title: title, action: action);
    }

    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '使用所选执行后端来构建 Android 项目、分析 APK、借助 apktool 与 JADX 处理产物，并重新打包或签名。',
            style: TextStyle(
              fontSize: 12,
              color: AppPalette.muted,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppPalette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '状态：$_androidToolkitStatus',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppPalette.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '执行根目录：${executionRoot.isEmpty ? '尚未就绪' : executionRoot}',
                  style: const TextStyle(fontSize: 11, color: AppPalette.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  '主要后端：${_primaryBackendLabel(_primaryExecutionBackend)}',
                  style: const TextStyle(fontSize: 11, color: AppPalette.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  '反编译工作区：$reverseRoot',
                  style: const TextStyle(fontSize: 11, color: AppPalette.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _InputField(
            label: 'APK 路径',
            controller: _androidToolkitApkPathController,
            hintText: '/storage/emulated/0/Download/app.apk',
            onChanged: (_) => _persistState(),
            suffix: IconButton(
              tooltip: '选择 APK',
              onPressed: () {
                unawaited(
                  _pickAndroidToolkitFile(
                    _androidToolkitApkPathController,
                    allowedExtensions: const <String>[
                      'apk',
                      'apkm',
                      'xapk',
                      'aab',
                    ],
                    updateReverseLabelFromApk: true,
                  ),
                );
              },
              icon: const Icon(Icons.upload_file_rounded),
            ),
          ),
          const SizedBox(height: 10),
          _InputField(
            label: '反编译标签',
            controller: _androidToolkitReverseLabelController,
            hintText: 'sample_apk',
            onChanged: (_) => _persistState(),
          ),
          const SizedBox(height: 10),
          _InputField(
            label: 'Gradle 任务',
            controller: _androidToolkitGradleTaskController,
            hintText: 'assembleDebug',
            onChanged: (_) => _persistState(),
          ),
          const SizedBox(height: 10),
          _InputField(
            label: '安装包路径',
            controller: _androidToolkitInstallApkPathController,
            hintText: 'app/build/outputs/apk/debug/app-debug.apk',
            onChanged: (_) => _persistState(),
          ),
          const SizedBox(height: 10),
          _InputField(
            label: 'Logcat 过滤器',
            controller: _androidToolkitLogcatFilterController,
            hintText: 'MyApp:D *:S',
            onChanged: (_) => _persistState(),
          ),
          const SizedBox(height: 10),
          _InputField(
            label: 'JADX 搜索',
            controller: _androidToolkitJadxQueryController,
            hintText: 'MainActivity',
            onChanged: (_) => _persistState(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: !supported || busy
                    ? null
                    : () {
                        unawaited(
                          runAction(
                            'Gradle 构建',
                            () => _runAndroidGradleBuildTool(),
                          ),
                        );
                      },
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.build_circle_outlined),
                label: const Text('构建'),
              ),
              OutlinedButton.icon(
                onPressed: !supported || busy
                    ? null
                    : () {
                        unawaited(
                          runAction(
                            '安装 APK',
                            () => _runAndroidInstallApkTool(),
                          ),
                        );
                      },
                icon: const Icon(Icons.phone_android_rounded),
                label: const Text('安装'),
              ),
              OutlinedButton.icon(
                onPressed: !supported || busy
                    ? null
                    : () {
                        unawaited(
                          runAction('Logcat 日志', () => _runAndroidLogcatTool()),
                        );
                      },
                icon: const Icon(Icons.subject_rounded),
                label: const Text('日志'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: !_embeddedDevToolkitStatus.jadxAvailable || busy
                    ? null
                    : () {
                        unawaited(
                          runAction('内置 JADX 反编译', _runEmbeddedJadxTool),
                        );
                      },
                icon: const Icon(Icons.integration_instructions_rounded),
                label: const Text('内置 JADX'),
              ),
              OutlinedButton.icon(
                onPressed: !_embeddedDevToolkitStatus.apkSigAvailable || busy
                    ? null
                    : () {
                        unawaited(
                          runAction('校验 APK 签名', _verifyEmbeddedApkSignature),
                        );
                      },
                icon: const Icon(Icons.verified_user_rounded),
                label: const Text('内置签名校验'),
              ),
              OutlinedButton.icon(
                onPressed: !supported || busy
                    ? null
                    : () {
                        unawaited(
                          runAction(
                            'Apktool 反编译',
                            () => _runAndroidApktoolDecodeTool(),
                          ),
                        );
                      },
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Apktool'),
              ),
              OutlinedButton.icon(
                onPressed: !supported || busy
                    ? null
                    : () {
                        unawaited(
                          runAction('运行 JADX', () => _runAndroidJadxTool()),
                        );
                      },
                icon: const Icon(Icons.code_rounded),
                label: const Text('JADX'),
              ),
              OutlinedButton.icon(
                onPressed: !supported || busy
                    ? null
                    : () {
                        unawaited(
                          runAction(
                            '搜索 JADX',
                            () => _runAndroidJadxSearchTool(),
                          ),
                        );
                      },
                icon: const Icon(Icons.search_rounded),
                label: const Text('搜索'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: !supported || busy
                    ? null
                    : () {
                        unawaited(
                          runAction(
                            '重建 APK',
                            () => _runAndroidApktoolBuildTool(),
                          ),
                        );
                      },
                icon: const Icon(Icons.construction_rounded),
                label: const Text('重建'),
              ),
              OutlinedButton.icon(
                onPressed: !supported || busy
                    ? null
                    : () {
                        unawaited(
                          runAction('签名 APK', () => _runAndroidSignApkTool()),
                        );
                      },
                icon: const Icon(Icons.verified_rounded),
                label: const Text('签名'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppPalette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '工具链',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppPalette.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '这些命令会在当前选中的 CLI 后端中执行，请填写该环境里真实存在的二进制命令。',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppPalette.muted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                _InputField(
                  label: 'ADB 命令',
                  controller: _androidToolkitAdbCommandController,
                  hintText: 'adb',
                  onChanged: (_) => _persistState(),
                ),
                const SizedBox(height: 10),
                _InputField(
                  label: 'Gradle 备用命令',
                  controller: _androidToolkitGradleCommandController,
                  hintText: 'gradle',
                  onChanged: (_) => _persistState(),
                ),
                const SizedBox(height: 10),
                _InputField(
                  label: 'Apktool 命令',
                  controller: _androidToolkitApktoolCommandController,
                  hintText: 'apktool',
                  onChanged: (_) => _persistState(),
                ),
                const SizedBox(height: 10),
                _InputField(
                  label: 'JADX 命令',
                  controller: _androidToolkitJadxCommandController,
                  hintText: 'jadx',
                  onChanged: (_) => _persistState(),
                ),
                const SizedBox(height: 10),
                _InputField(
                  label: 'Apksigner 命令',
                  controller: _androidToolkitApksignerCommandController,
                  hintText: 'apksigner',
                  onChanged: (_) => _persistState(),
                ),
                const SizedBox(height: 10),
                _InputField(
                  label: 'Zipalign 命令',
                  controller: _androidToolkitZipalignCommandController,
                  hintText: 'zipalign',
                  onChanged: (_) => _persistState(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppPalette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '签名配置',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppPalette.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        unawaited(
                          _pickAndroidToolkitFile(
                            _androidToolkitKeystorePathController,
                            allowedExtensions: const <String>[
                              'jks',
                              'keystore',
                              'p12',
                              'pkcs12',
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.key_rounded, size: 16),
                      label: const Text('选择'),
                    ),
                  ],
                ),
                _InputField(
                  label: 'Keystore 路径',
                  controller: _androidToolkitKeystorePathController,
                  hintText: '/storage/emulated/0/Download/release.jks',
                  onChanged: (_) => _persistState(),
                ),
                const SizedBox(height: 10),
                _InputField(
                  label: '别名',
                  controller: _androidToolkitKeystoreAliasController,
                  hintText: 'release',
                  onChanged: (_) => _persistState(),
                ),
                const SizedBox(height: 10),
                _InputField(
                  label: 'Store 密码',
                  controller: _androidToolkitStorePasswordController,
                  hintText: '签名时必填',
                  obscureText: true,
                  onChanged: (_) => _persistState(),
                ),
                const SizedBox(height: 10),
                _InputField(
                  label: 'Key 密码',
                  controller: _androidToolkitKeyPasswordController,
                  hintText: '若与 Store 密码相同可留空',
                  obscureText: true,
                  onChanged: (_) => _persistState(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '工具箱输出',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.ink,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _androidToolkitOutput.trim().isEmpty
                    ? null
                    : () =>
                          _copyPlainText(_androidToolkitOutput, '安卓工具箱输出已复制。'),
                icon: const Icon(Icons.copy_all_rounded, size: 14),
                label: const Text('复制'),
              ),
            ],
          ),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 120, maxHeight: 260),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppPalette.border),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                _androidToolkitOutput.trim().isEmpty
                    ? '这里会显示安卓构建、分析、签名与日志输出。'
                    : _androidToolkitOutput,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.45,
                  color: AppPalette.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuntimeWorkbenchSection() {
    Color chipColor(String changeType) {
      switch (changeType) {
        case 'added':
          return const Color(0xFF0B6E4F);
        case 'modified':
          return const Color(0xFF2563EB);
        case 'deleted':
          return const Color(0xFFB45309);
        default:
          return const Color(0xFF7C3AED);
      }
    }

    String changeLabel(String changeType) {
      switch (changeType) {
        case 'added':
          return '新增';
        case 'modified':
          return '修改';
        case 'deleted':
          return '删除';
        default:
          return '类型变化';
      }
    }

    final sourceRoot = _projectRootPath?.trim() ?? '';
    final effectiveRoot = _displayProjectAccessRootPath();
    final mirrorRoot = _localRuntimeStatus.activeWorkspacePath.trim();
    final hasMirror = mirrorRoot.isNotEmpty;
    final shellRunning = _localShellSnapshot.isRunning;

    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '把 AI 工作区、镜像同步、Git 和 Shell 放到一起，方便你直接观察工具执行环境。',
            style: TextStyle(
              fontSize: 12,
              color: AppPalette.muted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppPalette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '源目录: ${sourceRoot.isEmpty ? '未选择' : sourceRoot}',
                  style: const TextStyle(fontSize: 11, color: AppPalette.ink),
                ),
                const SizedBox(height: 6),
                Text(
                  'AI 当前访问根: ${effectiveRoot.isEmpty ? '未就绪' : effectiveRoot}',
                  style: const TextStyle(fontSize: 11, color: AppPalette.ink),
                ),
                const SizedBox(height: 6),
                Text(
                  '镜像工作区: ${hasMirror ? mirrorRoot : '尚未准备'}',
                  style: const TextStyle(fontSize: 11, color: AppPalette.muted),
                ),
                const SizedBox(height: 6),
                Text(
                  'Shell 会话: ${shellRunning ? '运行中' : '未运行'}',
                  style: const TextStyle(fontSize: 11, color: AppPalette.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _preparingLocalWorkspace
                    ? null
                    : _prepareLocalWorkspaceMirror,
                icon: _preparingLocalWorkspace
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.copy_all_rounded),
                label: const Text('准备镜像'),
              ),
              OutlinedButton.icon(
                onPressed: _loadingMirrorPreview
                    ? null
                    : _previewMirrorWorkspaceChanges,
                icon: _loadingMirrorPreview
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.preview_rounded),
                label: const Text('预览差异'),
              ),
              OutlinedButton.icon(
                onPressed: _syncingMirrorToSource
                    ? null
                    : _syncMirrorWorkspaceBackToSource,
                icon: _syncingMirrorToSource
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_alt_rounded),
                label: const Text('同步回源目录'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _runningRuntimeWorkbenchCommand
                    ? null
                    : () => _runRuntimeWorkbenchCommand(
                        title: 'Git 状态',
                        action: () => _runGitStatusTool(maxOutputBytes: 196608),
                      ),
                icon: const Icon(Icons.account_tree_outlined),
                label: const Text('Git 状态'),
              ),
              OutlinedButton.icon(
                onPressed: _runningRuntimeWorkbenchCommand
                    ? null
                    : () => _runRuntimeWorkbenchCommand(
                        title: 'Git 差异',
                        action: () => _runGitDiffTool(maxOutputBytes: 196608),
                      ),
                icon: const Icon(Icons.difference_rounded),
                label: const Text('Git 差异'),
              ),
              OutlinedButton.icon(
                onPressed: _runningRuntimeWorkbenchCommand
                    ? null
                    : () => _runRuntimeWorkbenchCommand(
                        title: 'Git 日志',
                        action: () =>
                            _runGitLogTool(limit: 20, maxOutputBytes: 131072),
                      ),
                icon: const Icon(Icons.history_rounded),
                label: const Text('Git 日志'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _loadingLocalRuntimeStatus
                    ? null
                    : () =>
                          _refreshLocalRuntimeStatus(showFailureSnackBar: true),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('刷新状态'),
              ),
              OutlinedButton.icon(
                onPressed: shellRunning
                    ? _stopShellSession
                    : _startShellSession,
                icon: Icon(
                  shellRunning
                      ? Icons.stop_circle_outlined
                      : Icons.play_circle_outline_rounded,
                ),
                label: Text(shellRunning ? '停止 Shell' : '启动 Shell'),
              ),
              OutlinedButton.icon(
                onPressed: _clearShellBuffer,
                icon: const Icon(Icons.cleaning_services_outlined),
                label: const Text('清空 Shell'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _mirrorPreviewSummary,
            style: const TextStyle(fontSize: 12, color: AppPalette.muted),
          ),
          if (_mirrorPreviewEntries.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppPalette.border),
              ),
              child: Column(
                children: _mirrorPreviewEntries.take(12).map((entry) {
                  final color = chipColor(entry.changeType);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            changeLabel(entry.changeType),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${entry.path}  (${entry.entityType})',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppPalette.ink,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '运行输出',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.ink,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _runtimeWorkbenchOutput.trim().isEmpty
                    ? null
                    : () => _copyPlainText(_runtimeWorkbenchOutput, '工作区输出已复制'),
                icon: const Icon(Icons.copy_all_rounded, size: 14),
                label: const Text('复制'),
              ),
            ],
          ),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 120, maxHeight: 260),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppPalette.border),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                _runtimeWorkbenchOutput.trim().isEmpty
                    ? '这里会显示镜像预览、同步结果、Git 输出和 Shell 状态。'
                    : _runtimeWorkbenchOutput,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.45,
                  color: AppPalette.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _agentStatusColor(String status) {
    switch (status) {
      case 'running':
        return const Color(0xFF0B6E4F);
      case 'cached':
        return const Color(0xFF2563EB);
      case 'failed':
        return const Color(0xFFB45309);
      default:
        return const Color(0xFF475569);
    }
  }

  IconData _agentStatusIcon(String status) {
    switch (status) {
      case 'running':
        return Icons.autorenew_rounded;
      case 'cached':
        return Icons.layers_rounded;
      case 'failed':
        return Icons.warning_amber_rounded;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }

  String _agentStatusLabel(String status) {
    switch (status) {
      case 'running':
        return '执行中';
      case 'cached':
        return '缓存';
      case 'failed':
        return '失败';
      default:
        return '完成';
    }
  }

  String _formatDurationLabel(int? durationMs) {
    if (durationMs == null || durationMs <= 0) return '--';
    if (durationMs < 1000) return '${durationMs}ms';
    final seconds = durationMs / 1000;
    return '${seconds.toStringAsFixed(seconds >= 10 ? 0 : 1)}s';
  }

  Widget _buildAgentExecutionSection() {
    final runningCount = _agentToolEvents
        .where((item) => item.status == 'running')
        .length;
    final doneCount = _agentToolEvents
        .where((item) => item.status == 'done' || item.status == 'cached')
        .length;
    final failedCount = _agentToolEvents
        .where((item) => item.status == 'failed')
        .length;

    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '智能体执行台',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _agentLiveStatus,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppPalette.muted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _agentProgressEntries.clear();
                    _agentToolEvents.clear();
                    _expandedAgentToolEventIds.clear();
                    _agentPlanSummary = '';
                    _agentExecutionPhase = _sendingPrompt ? '执行' : '待命';
                    _agentConvergenceSummary = _sendingPrompt
                        ? '等待新的工具活动'
                        : '等待下一次请求';
                    _agentConvergenceWarning = '';
                    _agentCurrentRound = 0;
                    _agentMaxRounds = 0;
                    _agentSummaryMode = false;
                    _agentToolFamilyCounts.clear();
                    _agentLiveStatus = _sendingPrompt ? '执行中' : '空闲';
                  });
                },
                icon: const Icon(Icons.cleaning_services_rounded),
                tooltip: '清空面板',
              ),
            ],
          ),
          if (_agentPlanSummary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F9FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD9E6F5)),
              ),
              child: Text(
                _agentPlanSummary,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppPalette.ink,
                  height: 1.4,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AgentMetricChip(label: '步骤 ${_agentProgressEntries.length}'),
              _AgentMetricChip(label: '工具 ${_agentToolEvents.length}'),
              _AgentMetricChip(label: '执行中 $runningCount'),
              _AgentMetricChip(label: '完成 $doneCount'),
              if (failedCount > 0) _AgentMetricChip(label: '失败 $failedCount'),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AgentMetricChip(label: '阶段 $_agentExecutionPhase'),
              if (_agentMaxRounds > 0)
                _AgentMetricChip(
                  label: '回合 $_agentCurrentRound / $_agentMaxRounds',
                ),
              if (_agentSummaryMode) const _AgentMetricChip(label: '总结模式'),
            ],
          ),
          if (_agentConvergenceSummary.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD6E0EA)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '收敛状态',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _agentConvergenceSummary,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppPalette.muted,
                      height: 1.35,
                    ),
                  ),
                  if (_agentConvergenceWarning.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFF1C78A)),
                      ),
                      child: Text(
                        _agentConvergenceWarning,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9A5A00),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                  if (_agentToolFamilyCounts.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _agentToolFamilyCounts.entries
                          .where((entry) => entry.value > 0)
                          .map(
                            (entry) => _AgentMetricChip(
                              label: '${entry.key} ${entry.value}',
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              setState(() {
                _agentProgressCollapsed = !_agentProgressCollapsed;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '进度说明',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.ink,
                      ),
                    ),
                  ),
                  Icon(
                    _agentProgressCollapsed
                        ? Icons.expand_more_rounded
                        : Icons.expand_less_rounded,
                  ),
                ],
              ),
            ),
          ),
          if (!_agentProgressCollapsed) ...[
            if (_agentProgressEntries.isEmpty)
              const Text(
                '当前还没有进度记录。',
                style: TextStyle(fontSize: 12, color: AppPalette.muted),
              )
            else
              ..._agentProgressEntries.reversed
                  .take(8)
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFD),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppPalette.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.title,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppPalette.ink,
                                    ),
                                  ),
                                ),
                                Text(
                                  entry.time,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppPalette.muted,
                                  ),
                                ),
                              ],
                            ),
                            if (entry.detail.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                entry.detail,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppPalette.muted,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
          ],
          const SizedBox(height: 6),
          InkWell(
            onTap: () {
              setState(() {
                _agentToolsCollapsed = !_agentToolsCollapsed;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '工具活动',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.ink,
                      ),
                    ),
                  ),
                  Icon(
                    _agentToolsCollapsed
                        ? Icons.expand_more_rounded
                        : Icons.expand_less_rounded,
                  ),
                ],
              ),
            ),
          ),
          if (!_agentToolsCollapsed) ...[
            if (_agentToolEvents.isEmpty)
              const Text(
                '当前还没有工具调用。',
                style: TextStyle(fontSize: 12, color: AppPalette.muted),
              )
            else
              ..._agentToolEvents.reversed
                  .take(10)
                  .map(
                    (event) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Builder(
                        builder: (context) {
                          final expanded = _expandedAgentToolEventIds.contains(
                            event.id,
                          );
                          final statusColor = _agentStatusColor(event.status);
                          return Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFD),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppPalette.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (expanded) {
                                        _expandedAgentToolEventIds.remove(
                                          event.id,
                                        );
                                      } else {
                                        _expandedAgentToolEventIds.add(
                                          event.id,
                                        );
                                      }
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              _agentStatusIcon(event.status),
                                              size: 16,
                                              color: statusColor,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                event.name,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppPalette.ink,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: statusColor.withValues(
                                                  alpha: 0.12,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                _agentStatusLabel(event.status),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: statusColor,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Icon(
                                              expanded
                                                  ? Icons.expand_less_rounded
                                                  : Icons.expand_more_rounded,
                                              size: 18,
                                              color: AppPalette.muted,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            _AgentMetricChip(
                                              label: '时间 ${event.time}',
                                            ),
                                            _AgentMetricChip(
                                              label:
                                                  '耗时 ${_formatDurationLabel(event.durationMs)}',
                                            ),
                                            if (event.commandText.isNotEmpty)
                                              _AgentMetricChip(label: '含命令详情'),
                                          ],
                                        ),
                                        if (event.summary.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            event.summary,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppPalette.ink,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                if (expanded) ...[
                                  const Divider(height: 1),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      10,
                                      10,
                                      10,
                                      10,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (event.commandText.isNotEmpty) ...[
                                          Row(
                                            children: [
                                              const Expanded(
                                                child: Text(
                                                  '命令原文',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppPalette.ink,
                                                  ),
                                                ),
                                              ),
                                              TextButton.icon(
                                                onPressed: () => _copyPlainText(
                                                  event.commandText,
                                                  '命令已复制',
                                                ),
                                                icon: const Icon(
                                                  Icons.copy_all_rounded,
                                                  size: 14,
                                                ),
                                                label: const Text('复制'),
                                              ),
                                            ],
                                          ),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: AppPalette.border,
                                              ),
                                            ),
                                            child: SelectableText(
                                              event.commandText,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                height: 1.4,
                                                color: AppPalette.ink,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                        ],
                                        Row(
                                          children: [
                                            const Expanded(
                                              child: Text(
                                                '原始调用参数',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppPalette.ink,
                                                ),
                                              ),
                                            ),
                                            TextButton.icon(
                                              onPressed: () => _copyPlainText(
                                                event.rawArgs,
                                                '调用参数已复制',
                                              ),
                                              icon: const Icon(
                                                Icons.copy_all_rounded,
                                                size: 14,
                                              ),
                                              label: const Text('复制'),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: AppPalette.border,
                                            ),
                                          ),
                                          child: SelectableText(
                                            event.rawArgs,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              height: 1.4,
                                              color: AppPalette.ink,
                                            ),
                                          ),
                                        ),
                                        if (event.stdout.trim().isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          const Text(
                                            '标准输出 stdout',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: AppPalette.ink,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: AppPalette.border,
                                              ),
                                            ),
                                            child: SelectableText(
                                              event.stdout,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                height: 1.4,
                                                color: AppPalette.ink,
                                              ),
                                            ),
                                          ),
                                        ],
                                        if (event.stderr.trim().isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          const Text(
                                            '错误输出 stderr',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFFB45309),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: const Color(0xFFE9C7A4),
                                              ),
                                            ),
                                            child: SelectableText(
                                              event.stderr,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                height: 1.4,
                                                color: Color(0xFF8A4B08),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
          ],
        ],
      ),
    );
  }

  Widget _buildBackgroundGuardSection() {
    final supported = Platform.isAndroid;
    final statusText = _sendingPrompt
        ? (_backgroundGuardActive
              ? '通知已运行：${_backgroundReplyProgress.isEmpty ? '处理中' : _backgroundReplyProgress}'
              : '回复中，通知未运行（请检查通知权限）')
        : '空闲';
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            value: supported ? _backgroundGuardEnabled : false,
            contentPadding: EdgeInsets.zero,
            title: const Text('后台防中断模式'),
            subtitle: Text(
              supported
                  ? '开启后在 AI 回复期间启动前台通知，降低切后台被系统中断的概率。'
                  : '当前平台暂不支持（仅 Android 可用）',
            ),
            onChanged: supported
                ? (value) {
                    unawaited(_setBackgroundGuardEnabled(value));
                  }
                : null,
          ),
          const SizedBox(height: 4),
          Text(
            '状态: $statusText',
            style: const TextStyle(fontSize: 12, color: AppPalette.muted),
          ),
          if (_backgroundGuardEnabled) ...[
            const SizedBox(height: 6),
            Text(
              '通知内容会显示“当前阶段 + 已进行时长”，并在回复结束后自动关闭。',
              style: const TextStyle(fontSize: 11, color: AppPalette.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTerminalSection() {
    return _PanelCard(
      child: Column(
        children: [
          SwitchListTile(
            value: _showTerminal,
            contentPadding: EdgeInsets.zero,
            title: const Text('底部终端调试'),
            subtitle: const Text('点击后主界面底部弹出终端'),
            onChanged: (value) {
              _toggleTerminal(value);
              if (value) {
                Navigator.of(context).maybePop();
              }
            },
          ),
          FilledButton.icon(
            onPressed: () {
              _toggleTerminal(true);
              Navigator.of(context).maybePop();
            },
            icon: const Icon(Icons.terminal_rounded),
            label: const Text('打开终端'),
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionEntry {
  const _SettingsSectionEntry({
    required this.id,
    required this.title,
    required this.summary,
    required this.icon,
    required this.builder,
  });

  final String id;
  final String title;
  final String summary;
  final IconData icon;
  final Widget Function() builder;
}

class _SolutionStatusCard extends StatelessWidget {
  const _SolutionStatusCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.active,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String statusLabel;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tone = active ? const Color(0xFF0B6E4F) : const Color(0xFF9A6B16);
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppPalette.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppPalette.muted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: tone,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SolutionComponentRow extends StatelessWidget {
  const _SolutionComponentRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: tone),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppPalette.muted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: tone,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerExplorerEntry {
  const _DrawerExplorerEntry.directory({
    required this.name,
    required this.path,
    required this.absolutePath,
  }) : isDirectory = true,
       sizeBytes = 0;

  const _DrawerExplorerEntry.file({
    required this.name,
    required this.path,
    required this.absolutePath,
    required this.sizeBytes,
  }) : isDirectory = false;

  final String name;
  final String path;
  final String absolutePath;
  final bool isDirectory;
  final int sizeBytes;
}

class _ModelFetchPlan {
  const _ModelFetchPlan({
    required this.label,
    required this.uri,
    required this.headers,
  });

  final String label;
  final Uri uri;
  final Map<String, String> headers;
}

class _ModelCatalog {
  const _ModelCatalog({
    this.modelIds = const <String>[],
    this.signalsByNormalizedId = const <String, _ModelCapabilitySignal>{},
  });

  final List<String> modelIds;
  final Map<String, _ModelCapabilitySignal> signalsByNormalizedId;
}

class _ModelCapabilitySignal {
  const _ModelCapabilitySignal({
    this.supportsImageInput = false,
    this.supportsImageOutput = false,
    this.isEmbedding = false,
    this.isImageGeneration = false,
  });

  final bool supportsImageInput;
  final bool supportsImageOutput;
  final bool isEmbedding;
  final bool isImageGeneration;

  _ModelCapabilitySignal merge(_ModelCapabilitySignal other) {
    return _ModelCapabilitySignal(
      supportsImageInput: supportsImageInput || other.supportsImageInput,
      supportsImageOutput: supportsImageOutput || other.supportsImageOutput,
      isEmbedding: isEmbedding || other.isEmbedding,
      isImageGeneration: isImageGeneration || other.isImageGeneration,
    );
  }
}

class _ModelCapabilityDetection {
  const _ModelCapabilityDetection({
    required this.modelDisplayName,
    required this.modelType,
    required this.inputModes,
    required this.outputModes,
    required this.capabilityTools,
    required this.capabilityReasoning,
    required this.statusText,
    this.availableModels = const <String>[],
  });

  final String modelDisplayName;
  final String modelType;
  final Set<String> inputModes;
  final Set<String> outputModes;
  final bool capabilityTools;
  final bool capabilityReasoning;
  final String statusText;
  final List<String> availableModels;
}

class _ComposerAttachment {
  const _ComposerAttachment({
    required this.id,
    required this.name,
    required this.path,
    required this.displayPath,
    required this.sizeBytes,
    required this.isTextLike,
    required this.isImageLike,
  });

  final String id;
  final String name;
  final String? path;
  final String displayPath;
  final int sizeBytes;
  final bool isTextLike;
  final bool isImageLike;
}

class _PreparedAttachments {
  const _PreparedAttachments({
    this.promptBlock = '',
    this.images = const <_OutgoingImageAttachment>[],
  });

  final String promptBlock;
  final List<_OutgoingImageAttachment> images;
}

class _OutgoingImageAttachment {
  const _OutgoingImageAttachment({
    required this.name,
    required this.mime,
    required this.sizeBytes,
    required this.dataUrl,
  });

  final String name;
  final String mime;
  final int sizeBytes;
  final String dataUrl;
}

class _DownloadAttemptResult {
  const _DownloadAttemptResult({
    required this.statusCode,
    required this.bytes,
    required this.mime,
  });

  final int statusCode;
  final int bytes;
  final String mime;
}

class _ModelRequestCancelledException implements Exception {
  const _ModelRequestCancelledException();

  @override
  String toString() => '模型请求已取消';
}

class _ChatCompletionStreamSnapshot {
  const _ChatCompletionStreamSnapshot({
    required this.content,
    required this.reasoningSummary,
    required this.toolCalls,
    required this.metadata,
  });

  final String content;
  final String reasoningSummary;
  final List<_ToolCall> toolCalls;
  final ResponseMetadata metadata;

  bool get hasVisibleOutput =>
      content.trim().isNotEmpty ||
      reasoningSummary.trim().isNotEmpty ||
      toolCalls.isNotEmpty;
}

class _ChatCompletionResult {
  const _ChatCompletionResult({
    required this.content,
    required this.toolCalls,
    this.reasoningSummary = '',
    this.metadata = const ResponseMetadata(),
  });

  final String content;
  final List<_ToolCall> toolCalls;
  final String reasoningSummary;
  final ResponseMetadata metadata;
}

class _StreamingToolCallAccumulator {
  _StreamingToolCallAccumulator({required this.fallbackId});

  final String fallbackId;
  String id = '';
  String name = '';
  final StringBuffer arguments = StringBuffer();

  _ToolCall toToolCall() {
    final resolvedId = id.trim().isEmpty ? fallbackId : id.trim();
    return _ToolCall(
      id: resolvedId,
      name: name.trim(),
      argumentsJson: arguments.toString().trim().isEmpty
          ? '{}'
          : arguments.toString(),
    );
  }
}

class _ToolCall {
  const _ToolCall({
    required this.id,
    required this.name,
    required this.argumentsJson,
  });

  final String id;
  final String name;
  final String argumentsJson;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'type': 'function',
      'function': <String, dynamic>{'name': name, 'arguments': argumentsJson},
    };
  }
}

class _AiRoundDraft {
  _AiRoundDraft({
    required this.id,
    required this.prompt,
    required this.messageStartIndex,
    required this.projectRootPath,
  });

  final String id;
  final String prompt;
  final int messageStartIndex;
  final String? projectRootPath;
  final List<_PathUndoSnapshot> snapshots = <_PathUndoSnapshot>[];
  final Set<String> capturedPaths = <String>{};
  Directory? backupDir;
}

class _AiRoundRecord {
  const _AiRoundRecord({
    required this.id,
    required this.prompt,
    required this.messageStartIndex,
    required this.messageEndIndex,
    required this.projectRootPath,
    required this.snapshots,
    required this.backupDirPath,
  });

  final String id;
  final String prompt;
  final int messageStartIndex;
  final int messageEndIndex;
  final String? projectRootPath;
  final List<_PathUndoSnapshot> snapshots;
  final String? backupDirPath;
}

enum _PathSnapshotType { missing, file, directory }

class _PathUndoSnapshot {
  const _PathUndoSnapshot({
    required this.relativePath,
    required this.beforeType,
    this.backupEntryName,
  });

  final String relativePath;
  final _PathSnapshotType beforeType;
  final String? backupEntryName;
}

class _ConversationSummary {
  const _ConversationSummary({
    required this.id,
    required this.title,
    required this.preview,
    required this.timestampMs,
    this.messages = const [],
    this.isPinned = false,
    this.projectRootPath,
    this.projectContext = '',
  });

  final String id;
  final String title;
  final String preview;
  final int timestampMs;
  final List<ChatMessage> messages;
  final bool isPinned;
  final String? projectRootPath;
  final String projectContext;

  _ConversationSummary copyWith({
    String? id,
    String? title,
    String? preview,
    int? timestampMs,
    List<ChatMessage>? messages,
    bool? isPinned,
    String? projectRootPath,
    bool clearProjectRootPath = false,
    String? projectContext,
    bool clearProjectContext = false,
  }) {
    return _ConversationSummary(
      id: id ?? this.id,
      title: title ?? this.title,
      preview: preview ?? this.preview,
      timestampMs: timestampMs ?? this.timestampMs,
      messages: messages ?? this.messages,
      isPinned: isPinned ?? this.isPinned,
      projectRootPath: clearProjectRootPath
          ? null
          : projectRootPath ?? this.projectRootPath,
      projectContext: clearProjectContext
          ? ''
          : projectContext ?? this.projectContext,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'preview': preview,
      'timestampMs': timestampMs,
      'messages': messages.map((item) => item.toJson()).toList(),
      'isPinned': isPinned,
      'projectRootPath': projectRootPath,
      'projectContext': projectContext,
    };
  }

  static _ConversationSummary fromJson(Map<String, dynamic> json) {
    final rawMs = json['timestampMs'];
    final timestampMs = switch (rawMs) {
      int value => value,
      String value => int.tryParse(value) ?? 0,
      _ => 0,
    };
    final rawMessages = json['messages'];
    final messages = <ChatMessage>[];
    if (rawMessages is List) {
      for (final item in rawMessages) {
        if (item is Map<String, dynamic>) {
          messages.add(ChatMessage.fromJson(item));
        } else if (item is Map) {
          messages.add(
            ChatMessage.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          );
        }
      }
    }
    final rawId = (json['id'] ?? '').toString().trim();
    final id = rawId.isEmpty
        ? 'conv_${DateTime.now().microsecondsSinceEpoch}'
        : rawId;
    final rawProjectRootPath = (json['projectRootPath'] ?? '')
        .toString()
        .trim();
    return _ConversationSummary(
      id: id,
      title: (json['title'] ?? '').toString(),
      preview: (json['preview'] ?? '').toString(),
      timestampMs: timestampMs,
      messages: messages,
      isPinned: json['isPinned'] == true,
      projectRootPath: rawProjectRootPath.isEmpty ? null : rawProjectRootPath,
      projectContext: (json['projectContext'] ?? '').toString(),
    );
  }
}

class _ConversationSearchHit {
  const _ConversationSearchHit({
    required this.conversationId,
    required this.title,
    required this.snippet,
    required this.timestampMs,
    required this.isCurrent,
    required this.isPinned,
    required this.score,
    this.messageIndex,
  });

  final String conversationId;
  final String title;
  final String snippet;
  final int timestampMs;
  final bool isCurrent;
  final bool isPinned;
  final int score;
  final int? messageIndex;
}

class _ProviderLogo extends StatelessWidget {
  const _ProviderLogo({required this.provider, this.size = 44});

  final ModelProvider provider;
  final double size;

  @override
  Widget build(BuildContext context) {
    final darkText = provider.color.computeLuminance() > 0.6;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: provider.color),
      alignment: Alignment.center,
      child: Text(
        provider.icon,
        style: TextStyle(
          color: darkText ? const Color(0xFF111111) : Colors.white,
          fontSize: size * 0.28,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.label,
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.suffix,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppPalette.muted,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hintText,
            suffixIcon: suffix,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );
  }
}

class _TextEditingAlertDialog extends StatefulWidget {
  const _TextEditingAlertDialog({
    required this.title,
    required this.initialValue,
    required this.hintText,
    required this.submitLabel,
    this.maxLength,
    this.trimOnSubmit = false,
  });

  final String title;
  final String initialValue;
  final String hintText;
  final String submitLabel;
  final int? maxLength;
  final bool trimOnSubmit;

  @override
  State<_TextEditingAlertDialog> createState() =>
      _TextEditingAlertDialogState();
}

class _TextEditingAlertDialogState extends State<_TextEditingAlertDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = widget.trimOnSubmit
        ? _controller.text.trim()
        : _controller.text;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        maxLength: widget.maxLength,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(hintText: widget.hintText),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.submitLabel)),
      ],
    );
  }
}

class _AgentProgressEntry {
  const _AgentProgressEntry({
    required this.title,
    required this.detail,
    required this.time,
  });

  final String title;
  final String detail;
  final String time;
}

class _AgentToolEvent {
  const _AgentToolEvent({
    required this.id,
    required this.name,
    required this.status,
    required this.argsPreview,
    required this.summary,
    required this.time,
    required this.startedAtMs,
    required this.durationMs,
    required this.rawArgs,
    required this.commandText,
    required this.stdout,
    required this.stderr,
  });

  final String id;
  final String name;
  final String status;
  final String argsPreview;
  final String summary;
  final String time;
  final int startedAtMs;
  final int? durationMs;
  final String rawArgs;
  final String commandText;
  final String stdout;
  final String stderr;
}

class _MirrorChangeEntry {
  const _MirrorChangeEntry({
    required this.path,
    required this.changeType,
    required this.entityType,
  });

  final String path;
  final String changeType;
  final String entityType;
}

class _AgentMetricChip extends StatelessWidget {
  const _AgentMetricChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FA),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD6E0EA)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppPalette.ink,
        ),
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8ECF1)),
      ),
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }
}

class _WorkbenchBackground extends StatelessWidget {
  const _WorkbenchBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF7F9F4), Color(0xFFEFF4FA), Color(0xFFFFF5E3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        const Positioned(
          top: -30,
          left: -45,
          child: _GlowOrb(size: 190, color: Color(0x5514919B)),
        ),
        const Positioned(
          top: 220,
          right: -40,
          child: _GlowOrb(size: 170, color: Color(0x55FFB347)),
        ),
        const Positioned(
          bottom: -40,
          left: 70,
          child: _GlowOrb(size: 220, color: Color(0x440B6E4F)),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.radius = 26,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: AppPalette.card,
            border: Border.all(color: AppPalette.border),
            boxShadow: [
              BoxShadow(
                blurRadius: 20,
                offset: const Offset(0, 10),
                color: Colors.black.withValues(alpha: 0.08),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
