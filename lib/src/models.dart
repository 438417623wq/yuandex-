import 'package:flutter/material.dart';

enum ChatRole { user, assistant, system }

enum ResponsePartKind {
  reasoning,
  content,
  toolCall,
  citation,
  metadata,
  agentProgress,
  toolActivity,
}

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.text,
    required this.time,
    this.parts = const <ResponsePart>[],
    this.metadata,
  });

  final ChatRole role;
  final String text;
  final String time;
  final List<ResponsePart> parts;
  final ResponseMetadata? metadata;

  bool get hasStructuredParts => parts.isNotEmpty;

  ChatMessage copyWith({
    ChatRole? role,
    String? text,
    String? time,
    List<ResponsePart>? parts,
    ResponseMetadata? metadata,
    bool clearMetadata = false,
  }) {
    return ChatMessage(
      role: role ?? this.role,
      text: text ?? this.text,
      time: time ?? this.time,
      parts: parts ?? this.parts,
      metadata: clearMetadata ? null : (metadata ?? this.metadata),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'role': role.name,
      'text': text,
      'time': time,
      if (parts.isNotEmpty)
        'parts': parts.map((item) => item.toJson()).toList(),
      if (metadata != null) 'metadata': metadata!.toJson(),
    };
  }

  static ChatMessage fromJson(Map<String, dynamic> json) {
    final roleName = (json['role'] ?? 'assistant').toString();
    final role = ChatRole.values.firstWhere(
      (value) => value.name == roleName,
      orElse: () => ChatRole.assistant,
    );

    final rawParts = json['parts'];
    final parts = <ResponsePart>[];
    if (rawParts is List) {
      for (final item in rawParts) {
        if (item is Map<String, dynamic>) {
          final part = ResponsePart.fromJson(item);
          if (part != null) parts.add(part);
        } else if (item is Map) {
          final part = ResponsePart.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          );
          if (part != null) parts.add(part);
        }
      }
    }

    ResponseMetadata? metadata;
    final rawMetadata = json['metadata'];
    if (rawMetadata is Map<String, dynamic>) {
      metadata = ResponseMetadata.fromJson(rawMetadata);
    } else if (rawMetadata is Map) {
      metadata = ResponseMetadata.fromJson(
        rawMetadata.map((key, value) => MapEntry(key.toString(), value)),
      );
    }

    return ChatMessage(
      role: role,
      text: (json['text'] ?? '').toString(),
      time: (json['time'] ?? '').toString(),
      parts: parts,
      metadata: metadata,
    );
  }
}

abstract class ResponsePart {
  const ResponsePart({required this.kind});

  final ResponsePartKind kind;

  Map<String, dynamic> toJson();

  static ResponsePart? fromJson(Map<String, dynamic> json) {
    final kindRaw = (json['kind'] ?? '').toString().trim();
    switch (kindRaw) {
      case 'reasoning':
        return ReasoningPart.fromJson(json);
      case 'content':
        return ContentPart.fromJson(json);
      case 'tool_call':
        return ToolCallPart.fromJson(json);
      case 'citation':
        return CitationPart.fromJson(json);
      case 'metadata':
        return MetadataPart.fromJson(json);
      case 'agent_progress':
        return AgentProgressPart.fromJson(json);
      case 'tool_activity':
        return ToolActivityPart.fromJson(json);
      default:
        return null;
    }
  }
}

class ReasoningPart extends ResponsePart {
  const ReasoningPart({required this.summary, this.collapsedByDefault = true})
    : super(kind: ResponsePartKind.reasoning);

  final String summary;
  final bool collapsedByDefault;

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'kind': 'reasoning',
      'summary': summary,
      'collapsedByDefault': collapsedByDefault,
    };
  }

  static ReasoningPart fromJson(Map<String, dynamic> json) {
    return ReasoningPart(
      summary: (json['summary'] ?? '').toString(),
      collapsedByDefault: json['collapsedByDefault'] != false,
    );
  }
}

class ContentPart extends ResponsePart {
  const ContentPart({required this.markdown})
    : super(kind: ResponsePartKind.content);

  final String markdown;

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{'kind': 'content', 'markdown': markdown};
  }

  static ContentPart fromJson(Map<String, dynamic> json) {
    return ContentPart(markdown: (json['markdown'] ?? '').toString());
  }
}

class ToolCallPart extends ResponsePart {
  const ToolCallPart({
    required this.id,
    required this.toolName,
    required this.argumentsJson,
    this.reason = '',
    this.status = 'done',
    this.outputPreview = '',
  }) : super(kind: ResponsePartKind.toolCall);

  final String id;
  final String toolName;
  final String argumentsJson;
  final String reason;
  final String status;
  final String outputPreview;

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'kind': 'tool_call',
      'id': id,
      'toolName': toolName,
      'argumentsJson': argumentsJson,
      'reason': reason,
      'status': status,
      'outputPreview': outputPreview,
    };
  }

  static ToolCallPart fromJson(Map<String, dynamic> json) {
    return ToolCallPart(
      id: (json['id'] ?? '').toString(),
      toolName: (json['toolName'] ?? '').toString(),
      argumentsJson: (json['argumentsJson'] ?? '{}').toString(),
      reason: (json['reason'] ?? '').toString(),
      status: (json['status'] ?? 'done').toString(),
      outputPreview: (json['outputPreview'] ?? '').toString(),
    );
  }
}

class CitationPart extends ResponsePart {
  const CitationPart({
    required this.title,
    required this.uri,
    this.snippet = '',
    this.sourceType = 'web',
  }) : super(kind: ResponsePartKind.citation);

  final String title;
  final String uri;
  final String snippet;
  final String sourceType;

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'kind': 'citation',
      'title': title,
      'uri': uri,
      'snippet': snippet,
      'sourceType': sourceType,
    };
  }

  static CitationPart fromJson(Map<String, dynamic> json) {
    return CitationPart(
      title: (json['title'] ?? '').toString(),
      uri: (json['uri'] ?? '').toString(),
      snippet: (json['snippet'] ?? '').toString(),
      sourceType: (json['sourceType'] ?? 'web').toString(),
    );
  }
}

class MetadataPart extends ResponsePart {
  const MetadataPart({required this.metadata})
    : super(kind: ResponsePartKind.metadata);

  final ResponseMetadata metadata;

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{'kind': 'metadata', 'metadata': metadata.toJson()};
  }

  static MetadataPart fromJson(Map<String, dynamic> json) {
    final rawMetadata = json['metadata'];
    if (rawMetadata is Map<String, dynamic>) {
      return MetadataPart(metadata: ResponseMetadata.fromJson(rawMetadata));
    }
    if (rawMetadata is Map) {
      return MetadataPart(
        metadata: ResponseMetadata.fromJson(
          rawMetadata.map((key, value) => MapEntry(key.toString(), value)),
        ),
      );
    }
    return const MetadataPart(metadata: ResponseMetadata());
  }
}

class AgentProgressSnapshot {
  const AgentProgressSnapshot({
    required this.title,
    required this.detail,
    required this.time,
  });

  final String title;
  final String detail;
  final String time;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'title': title, 'detail': detail, 'time': time};
  }

  static AgentProgressSnapshot fromJson(Map<String, dynamic> json) {
    return AgentProgressSnapshot(
      title: (json['title'] ?? '').toString(),
      detail: (json['detail'] ?? '').toString(),
      time: (json['time'] ?? '').toString(),
    );
  }
}

class AgentProgressPart extends ResponsePart {
  const AgentProgressPart({
    required this.summary,
    this.entries = const <AgentProgressSnapshot>[],
  }) : super(kind: ResponsePartKind.agentProgress);

  final String summary;
  final List<AgentProgressSnapshot> entries;

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'kind': 'agent_progress',
      'summary': summary,
      'entries': entries.map((item) => item.toJson()).toList(),
    };
  }

  static AgentProgressPart fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'];
    final entries = <AgentProgressSnapshot>[];
    if (rawEntries is List) {
      for (final item in rawEntries) {
        if (item is Map<String, dynamic>) {
          entries.add(AgentProgressSnapshot.fromJson(item));
        } else if (item is Map) {
          entries.add(
            AgentProgressSnapshot.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          );
        }
      }
    }
    return AgentProgressPart(
      summary: (json['summary'] ?? '').toString(),
      entries: entries,
    );
  }
}

class ToolActivitySnapshot {
  const ToolActivitySnapshot({
    required this.toolName,
    required this.status,
    required this.summary,
    required this.argsPreview,
    required this.time,
    this.durationMs,
  });

  final String toolName;
  final String status;
  final String summary;
  final String argsPreview;
  final String time;
  final int? durationMs;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'toolName': toolName,
      'status': status,
      'summary': summary,
      'argsPreview': argsPreview,
      'time': time,
      'durationMs': durationMs,
    };
  }

  static ToolActivitySnapshot fromJson(Map<String, dynamic> json) {
    int? readInt(String key) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse('${value ?? ''}');
    }

    return ToolActivitySnapshot(
      toolName: (json['toolName'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      argsPreview: (json['argsPreview'] ?? '').toString(),
      time: (json['time'] ?? '').toString(),
      durationMs: readInt('durationMs'),
    );
  }
}

class ToolActivityPart extends ResponsePart {
  const ToolActivityPart({this.entries = const <ToolActivitySnapshot>[]})
    : super(kind: ResponsePartKind.toolActivity);

  final List<ToolActivitySnapshot> entries;

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'kind': 'tool_activity',
      'entries': entries.map((item) => item.toJson()).toList(),
    };
  }

  static ToolActivityPart fromJson(Map<String, dynamic> json) {
    final rawEntries = json['entries'];
    final entries = <ToolActivitySnapshot>[];
    if (rawEntries is List) {
      for (final item in rawEntries) {
        if (item is Map<String, dynamic>) {
          entries.add(ToolActivitySnapshot.fromJson(item));
        } else if (item is Map) {
          entries.add(
            ToolActivitySnapshot.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          );
        }
      }
    }
    return ToolActivityPart(entries: entries);
  }
}

class ResponseMetadata {
  const ResponseMetadata({
    this.model = '',
    this.elapsedMs,
    this.inputTokens,
    this.outputTokens,
    this.reasoningTokens,
    this.finishReason = '',
  });

  final String model;
  final int? elapsedMs;
  final int? inputTokens;
  final int? outputTokens;
  final int? reasoningTokens;
  final String finishReason;

  bool get hasAnyValue =>
      model.trim().isNotEmpty ||
      elapsedMs != null ||
      inputTokens != null ||
      outputTokens != null ||
      reasoningTokens != null ||
      finishReason.trim().isNotEmpty;

  ResponseMetadata copyWith({
    String? model,
    int? elapsedMs,
    int? inputTokens,
    int? outputTokens,
    int? reasoningTokens,
    String? finishReason,
  }) {
    return ResponseMetadata(
      model: model ?? this.model,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      inputTokens: inputTokens ?? this.inputTokens,
      outputTokens: outputTokens ?? this.outputTokens,
      reasoningTokens: reasoningTokens ?? this.reasoningTokens,
      finishReason: finishReason ?? this.finishReason,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'model': model,
      'elapsedMs': elapsedMs,
      'inputTokens': inputTokens,
      'outputTokens': outputTokens,
      'reasoningTokens': reasoningTokens,
      'finishReason': finishReason,
    };
  }

  static ResponseMetadata fromJson(Map<String, dynamic> json) {
    int? readInt(String key) {
      final value = json[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse('${value ?? ''}');
    }

    return ResponseMetadata(
      model: (json['model'] ?? '').toString(),
      elapsedMs: readInt('elapsedMs'),
      inputTokens: readInt('inputTokens'),
      outputTokens: readInt('outputTokens'),
      reasoningTokens: readInt('reasoningTokens'),
      finishReason: (json['finishReason'] ?? '').toString(),
    );
  }
}

class ModelProvider {
  const ModelProvider({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
  });

  final String id;
  final String name;
  final Color color;
  final String icon;
}

class ProviderConfig {
  const ProviderConfig({
    this.baseUrl = '',
    this.apiPath = '',
    this.modelListPath = '',
    this.apiKey = '',
    this.extraHeaders = const {},
    this.model = '',
    this.availableModels = const [],
    this.improveNetworkCompatibility = false,
    this.reasoningEffort = 'very_high',
  });

  final String baseUrl;
  final String apiPath;
  final String modelListPath;
  final String apiKey;
  final Map<String, String> extraHeaders;
  final String model;
  final List<String> availableModels;
  final bool improveNetworkCompatibility;
  final String reasoningEffort;

  ProviderConfig copyWith({
    String? baseUrl,
    String? apiPath,
    String? modelListPath,
    String? apiKey,
    Map<String, String>? extraHeaders,
    String? model,
    List<String>? availableModels,
    bool? improveNetworkCompatibility,
    String? reasoningEffort,
  }) {
    return ProviderConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      apiPath: apiPath ?? this.apiPath,
      modelListPath: modelListPath ?? this.modelListPath,
      apiKey: apiKey ?? this.apiKey,
      extraHeaders: extraHeaders ?? this.extraHeaders,
      model: model ?? this.model,
      availableModels: availableModels ?? this.availableModels,
      improveNetworkCompatibility:
          improveNetworkCompatibility ?? this.improveNetworkCompatibility,
      reasoningEffort: reasoningEffort ?? this.reasoningEffort,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'baseUrl': baseUrl,
      'apiPath': apiPath,
      'modelListPath': modelListPath,
      'apiKey': apiKey,
      'extraHeaders': extraHeaders,
      'model': model,
      'availableModels': availableModels,
      'improveNetworkCompatibility': improveNetworkCompatibility,
      'reasoningEffort': reasoningEffort,
    };
  }

  static ProviderConfig fromJson(Map<String, dynamic> json) {
    final rawModels = json['availableModels'];
    final rawHeaders = json['extraHeaders'];
    return ProviderConfig(
      baseUrl: (json['baseUrl'] ?? '').toString(),
      apiPath: (json['apiPath'] ?? '').toString(),
      modelListPath: (json['modelListPath'] ?? '').toString(),
      apiKey: (json['apiKey'] ?? '').toString(),
      extraHeaders: rawHeaders is Map
          ? rawHeaders.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const {},
      model: (json['model'] ?? '').toString(),
      availableModels: rawModels is List
          ? rawModels.map((item) => item.toString()).toList()
          : const [],
      improveNetworkCompatibility: json['improveNetworkCompatibility'] == true,
      reasoningEffort: (json['reasoningEffort'] ?? 'very_high').toString(),
    );
  }
}

class ApiConnectionProfile {
  const ApiConnectionProfile({
    required this.id,
    required this.name,
    required this.providerId,
    required this.baseUrl,
    this.apiPath = '',
    this.modelListPath = '',
    required this.apiKey,
    this.extraHeaders = const {},
    required this.model,
    this.availableModels = const [],
    this.improveNetworkCompatibility = false,
    this.modelDisplayName = '',
    this.modelType = 'chat',
    this.inputModes = const ['text'],
    this.outputModes = const ['text'],
    this.capabilityTools = false,
    this.capabilityReasoning = false,
    this.reasoningEffort = 'very_high',
  });

  final String id;
  final String name;
  final String providerId;
  final String baseUrl;
  final String apiPath;
  final String modelListPath;
  final String apiKey;
  final Map<String, String> extraHeaders;
  final String model;
  final List<String> availableModels;
  final bool improveNetworkCompatibility;
  final String modelDisplayName;
  final String modelType;
  final List<String> inputModes;
  final List<String> outputModes;
  final bool capabilityTools;
  final bool capabilityReasoning;
  final String reasoningEffort;

  ProviderConfig toConfig() {
    return ProviderConfig(
      baseUrl: baseUrl,
      apiPath: apiPath,
      modelListPath: modelListPath,
      apiKey: apiKey,
      extraHeaders: extraHeaders,
      model: model,
      availableModels: availableModels,
      improveNetworkCompatibility: improveNetworkCompatibility,
      reasoningEffort: reasoningEffort,
    );
  }

  ApiConnectionProfile copyWith({
    String? id,
    String? name,
    String? providerId,
    String? baseUrl,
    String? apiPath,
    String? modelListPath,
    String? apiKey,
    Map<String, String>? extraHeaders,
    String? model,
    List<String>? availableModels,
    bool? improveNetworkCompatibility,
    String? modelDisplayName,
    String? modelType,
    List<String>? inputModes,
    List<String>? outputModes,
    bool? capabilityTools,
    bool? capabilityReasoning,
    String? reasoningEffort,
  }) {
    return ApiConnectionProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      providerId: providerId ?? this.providerId,
      baseUrl: baseUrl ?? this.baseUrl,
      apiPath: apiPath ?? this.apiPath,
      modelListPath: modelListPath ?? this.modelListPath,
      apiKey: apiKey ?? this.apiKey,
      extraHeaders: extraHeaders ?? this.extraHeaders,
      model: model ?? this.model,
      availableModels: availableModels ?? this.availableModels,
      improveNetworkCompatibility:
          improveNetworkCompatibility ?? this.improveNetworkCompatibility,
      modelDisplayName: modelDisplayName ?? this.modelDisplayName,
      modelType: modelType ?? this.modelType,
      inputModes: inputModes ?? this.inputModes,
      outputModes: outputModes ?? this.outputModes,
      capabilityTools: capabilityTools ?? this.capabilityTools,
      capabilityReasoning: capabilityReasoning ?? this.capabilityReasoning,
      reasoningEffort: reasoningEffort ?? this.reasoningEffort,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'providerId': providerId,
      'baseUrl': baseUrl,
      'apiPath': apiPath,
      'modelListPath': modelListPath,
      'apiKey': apiKey,
      'extraHeaders': extraHeaders,
      'model': model,
      'availableModels': availableModels,
      'improveNetworkCompatibility': improveNetworkCompatibility,
      'modelDisplayName': modelDisplayName,
      'modelType': modelType,
      'inputModes': inputModes,
      'outputModes': outputModes,
      'capabilityTools': capabilityTools,
      'capabilityReasoning': capabilityReasoning,
      'reasoningEffort': reasoningEffort,
    };
  }

  static ApiConnectionProfile fromJson(Map<String, dynamic> json) {
    final rawModels = json['availableModels'];
    final rawHeaders = json['extraHeaders'];
    final rawInputModes = json['inputModes'];
    final rawOutputModes = json['outputModes'];
    final parsedInputModes = rawInputModes is List
        ? rawInputModes.map((item) => item.toString()).toList()
        : const <String>[];
    final parsedOutputModes = rawOutputModes is List
        ? rawOutputModes.map((item) => item.toString()).toList()
        : const <String>[];
    return ApiConnectionProfile(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      providerId: (json['providerId'] ?? 'openai').toString(),
      baseUrl: (json['baseUrl'] ?? '').toString(),
      apiPath: (json['apiPath'] ?? '').toString(),
      modelListPath: (json['modelListPath'] ?? '').toString(),
      apiKey: (json['apiKey'] ?? '').toString(),
      extraHeaders: rawHeaders is Map
          ? rawHeaders.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const {},
      model: (json['model'] ?? '').toString(),
      availableModels: rawModels is List
          ? rawModels.map((item) => item.toString()).toList()
          : const [],
      improveNetworkCompatibility: json['improveNetworkCompatibility'] == true,
      modelDisplayName: (json['modelDisplayName'] ?? '').toString(),
      modelType: (json['modelType'] ?? 'chat').toString(),
      inputModes: parsedInputModes.isEmpty ? const ['text'] : parsedInputModes,
      outputModes: parsedOutputModes.isEmpty
          ? const ['text']
          : parsedOutputModes,
      capabilityTools: json['capabilityTools'] == true,
      capabilityReasoning: json['capabilityReasoning'] == true,
      reasoningEffort: (json['reasoningEffort'] ?? 'very_high').toString(),
    );
  }
}

class ProjectFileSnippet {
  const ProjectFileSnippet({
    required this.path,
    required this.absolutePath,
    required this.preview,
    required this.sizeBytes,
    required this.isBinary,
  });

  final String path;
  final String absolutePath;
  final String preview;
  final int sizeBytes;
  final bool isBinary;
}

class ProviderGuide {
  const ProviderGuide({
    required this.baseUrl,
    required this.auth,
    required this.modelListPath,
    required this.docsUrl,
    required this.note,
    this.supportsAutoFetch = true,
  });

  final String baseUrl;
  final String auth;
  final String modelListPath;
  final String docsUrl;
  final String note;
  final bool supportsAutoFetch;
}

const List<ModelProvider> kProviders = [
  ModelProvider(
    id: 'openai',
    name: 'OpenAI',
    color: Color(0xFF111111),
    icon: 'OA',
  ),
  ModelProvider(
    id: 'openai_responses',
    name: 'OpenAI (Responses)',
    color: Color(0xFF202020),
    icon: 'OR',
  ),
  ModelProvider(
    id: 'gemini',
    name: 'Gemini',
    color: Color(0xFF2D7FF9),
    icon: 'GM',
  ),
  ModelProvider(
    id: 'claude',
    name: 'Claude',
    color: Color(0xFFDE8454),
    icon: 'CL',
  ),
  ModelProvider(
    id: 'deepseek',
    name: 'DeepSeek',
    color: Color(0xFF4C6DF6),
    icon: 'DS',
  ),
  ModelProvider(
    id: 'siliconflow',
    name: '硅基流动',
    color: Color(0xFF6D35FF),
    icon: 'SF',
  ),
  ModelProvider(
    id: 'openrouter',
    name: 'OpenRouter',
    color: Color(0xFF111111),
    icon: 'OR',
  ),
  ModelProvider(
    id: 'ollama',
    name: 'Ollama',
    color: Color(0xFFE8E8ED),
    icon: 'OL',
  ),
  ModelProvider(
    id: 'lmstudio',
    name: 'LM Studio',
    color: Color(0xFF4B41D4),
    icon: 'LM',
  ),
  ModelProvider(
    id: 'azure_openai',
    name: 'Azure OpenAI',
    color: Color(0xFF111111),
    icon: 'AZ',
  ),
  ModelProvider(id: 'groq', name: 'Groq', color: Color(0xFF111111), icon: 'GQ'),
  ModelProvider(id: 'xai', name: 'xAI', color: Color(0xFF111111), icon: 'XI'),
  ModelProvider(
    id: 'mistral',
    name: 'Mistral AI',
    color: Color(0xFFF2A53B),
    icon: 'MS',
  ),
  ModelProvider(
    id: 'perplexity',
    name: 'Perplexity',
    color: Color(0xFF111111),
    icon: 'PP',
  ),
  ModelProvider(
    id: 'volcano',
    name: '火山引擎',
    color: Color(0xFF4C6DF6),
    icon: 'VE',
  ),
  ModelProvider(
    id: 'chatglm',
    name: '智谱 BigModel',
    color: Color(0xFF4C6DF6),
    icon: 'GL',
  ),
  ModelProvider(id: 'custom', name: '自定义', color: Color(0xFF355273), icon: '自'),
];

const Map<String, ProviderGuide> kProviderGuides = {
  'openai': ProviderGuide(
    baseUrl: 'https://api.openai.com/v1',
    auth: 'Authorization: Bearer <OPENAI_API_KEY>',
    modelListPath: '/models',
    docsUrl: 'https://platform.openai.com/docs/api-reference/models/list',
    note: '官方模型列表接口为 GET /v1/models，建议优先使用 Responses API 完成对话调用。',
  ),
  'openai_responses': ProviderGuide(
    baseUrl: 'https://api.openai.com/v1',
    auth: 'Authorization: Bearer <OPENAI_API_KEY>',
    modelListPath: '/models',
    docsUrl: 'https://platform.openai.com/docs/api-reference/models/list',
    note: '与 OpenAI 同源，适合以 Responses API 为主的接入方式。',
  ),
  'gemini': ProviderGuide(
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
    auth: 'x-goog-api-key: <GEMINI_API_KEY>',
    modelListPath: 'GET /models（Header 或 ?key=）',
    docsUrl: 'https://ai.google.dev/gemini-api/docs/models',
    note: '模型列表返回字段通常为 models[].name，例如 models/gemini-2.5-pro。',
  ),
  'claude': ProviderGuide(
    baseUrl: 'https://api.anthropic.com',
    auth: 'x-api-key + anthropic-version',
    modelListPath: '/v1/models',
    docsUrl: 'https://docs.anthropic.com/en/api/models-list',
    note: 'Anthropic 原生 API 需要 anthropic-version 请求头，模型列表接口为 GET /v1/models。',
  ),
  'deepseek': ProviderGuide(
    baseUrl: 'https://api.deepseek.com',
    auth: 'Authorization: Bearer <DEEPSEEK_API_KEY>',
    modelListPath: '/models',
    docsUrl: 'https://api-docs.deepseek.com/api/list-models',
    note: '兼容 OpenAI 协议；官方也说明 /v1 只是兼容层，与模型版本无关。',
  ),
  'siliconflow': ProviderGuide(
    baseUrl: 'https://api.siliconflow.cn/v1',
    auth: 'Authorization: Bearer <SILICONFLOW_API_KEY>',
    modelListPath: '/models',
    docsUrl:
        'https://docs.siliconflow.cn/en/api-reference/models/get-model-list',
    note: '支持按 type / sub_type 过滤模型。',
  ),
  'openrouter': ProviderGuide(
    baseUrl: 'https://openrouter.ai/api/v1',
    auth: 'Authorization: Bearer <OPENROUTER_API_KEY>',
    modelListPath: '/models',
    docsUrl: 'https://openrouter.ai/docs/api-reference/models/get-models',
    note: '可选携带 HTTP-Referer 和 X-Title 请求头，用于应用归属与统计。',
  ),
  'ollama': ProviderGuide(
    baseUrl: 'http://localhost:11434/api',
    auth: '本地默认无需鉴权；云端可 Bearer',
    modelListPath: '/tags',
    docsUrl: 'https://docs.ollama.com/api/tags',
    note: '本地常用 /api/tags 获取模型列表。',
  ),
  'lmstudio': ProviderGuide(
    baseUrl: 'http://localhost:1234/v1',
    auth: '通常可使用任意占位 key，例如 lm-studio。',
    modelListPath: '/models',
    docsUrl: 'https://lmstudio.ai/docs/app/api/openai-compat',
    note: 'OpenAI 兼容接口，支持 /v1/models。',
  ),
  'azure_openai': ProviderGuide(
    baseUrl: 'https://<resource>.openai.azure.com',
    auth: 'api-key: <AZURE_OPENAI_KEY>',
    modelListPath: '/openai/v1/models?api-version=preview',
    docsUrl:
        'https://learn.microsoft.com/en-us/azure/foundry/openai/reference-preview',
    note: '官方预览文档包含 GET /openai/v1/models；聊天调用通常使用 deployment-name。',
  ),
  'groq': ProviderGuide(
    baseUrl: 'https://api.groq.com/openai/v1',
    auth: 'Authorization: Bearer <GROQ_API_KEY>',
    modelListPath: '/models',
    docsUrl: 'https://console.groq.com/docs/api-reference',
    note: 'OpenAI 兼容接口，模型列表走 /openai/v1/models。',
  ),
  'xai': ProviderGuide(
    baseUrl: 'https://api.x.ai',
    auth: 'Authorization: Bearer <XAI_API_KEY>',
    modelListPath: '/v1/models',
    docsUrl: 'https://docs.x.ai/developers/api-reference/models',
    note: '官方全局入口为 api.x.ai，鉴权使用 Bearer Token。',
  ),
  'mistral': ProviderGuide(
    baseUrl: 'https://api.mistral.ai/v1',
    auth: 'Authorization: Bearer <MISTRAL_API_KEY>',
    modelListPath: '/models',
    docsUrl: 'https://docs.mistral.ai/api/endpoint/models',
    note: '官方模型列表接口为 GET /v1/models。',
  ),
  'perplexity': ProviderGuide(
    baseUrl: 'https://api.perplexity.ai',
    auth: 'Authorization: Bearer <PERPLEXITY_API_KEY>',
    modelListPath: '建议按文档模型页手动选择',
    docsUrl: 'https://docs.perplexity.ai/docs/agent-api/openai-compatibility',
    note: '官方同时给出 OpenAI 兼容方式，但不同 API 版本文档中的基础地址可能不同，例如 v1 / v2。',
    supportsAutoFetch: false,
  ),
  'volcano': ProviderGuide(
    baseUrl: 'https://ark.cn-beijing.volces.com/api/v3',
    auth: 'Authorization: Bearer <ARK_API_KEY>',
    modelListPath: '控制台模型列表 / 固定 Model ID',
    docsUrl: 'https://www.volcengine.com/docs/82379/1338552',
    note: '火山方舟支持 API Key + Response API；模型 ID 通常从控制台获取。',
    supportsAutoFetch: false,
  ),
  'chatglm': ProviderGuide(
    baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
    auth: 'Authorization: Bearer <BIGMODEL_API_KEY>',
    modelListPath: '模型概览页 / 固定 Model ID',
    docsUrl: 'https://docs.bigmodel.cn/api-reference',
    note: '智谱 BigModel 文档提供统一鉴权与接口说明，模型通常按文档或控制台选择。',
    supportsAutoFetch: false,
  ),
  'custom': ProviderGuide(
    baseUrl: '',
    auth: '按目标平台要求配置',
    modelListPath: '按目标平台定义',
    docsUrl: 'https://platform.openai.com/docs/api-reference/models/list',
    note: '自定义提供商可按 OpenAI 兼容模式接入。',
    supportsAutoFetch: false,
  ),
};
