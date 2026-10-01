/// An OpenAI-compatible chat-completions provider the app can send notes to.
///
/// Free tiers and free model IDs change often, so the model is only a default:
/// the user can override it in Settings without an app update.
class AiProvider {
  final String id;
  final String name;

  /// Base URL up to and including `/v1` — `/chat/completions` is appended.
  final String baseUrl;
  final String defaultModel;

  /// Where the user can create an API key.
  final String keyUrl;

  /// Whether the provider supports `response_format: json_schema` (strict).
  final bool supportsJsonSchema;

  const AiProvider({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.defaultModel,
    required this.keyUrl,
    this.supportsJsonSchema = false,
  });

  String get chatCompletionsUrl => '$baseUrl/chat/completions';

  /// Free tier, no credit card, no training on your data, strict JSON output.
  static const groq = AiProvider(
    id: 'groq',
    name: 'Groq',
    baseUrl: 'https://api.groq.com/openai/v1',
    defaultModel: 'openai/gpt-oss-20b',
    keyUrl: 'console.groq.com/keys',
    supportsJsonSchema: true,
  );

  /// Free `:free` models (roster changes often; 50 requests/day without credit).
  static const openRouter = AiProvider(
    id: 'openrouter',
    name: 'OpenRouter',
    baseUrl: 'https://openrouter.ai/api/v1',
    defaultModel: 'openai/gpt-oss-120b:free',
    keyUrl: 'openrouter.ai/keys',
  );

  /// The original provider. Kept for existing keys.
  static const nvidia = AiProvider(
    id: 'nvidia',
    name: 'NVIDIA NIM',
    baseUrl: 'https://integrate.api.nvidia.com/v1',
    defaultModel: 'meta/llama-3.1-8b-instruct',
    keyUrl: 'build.nvidia.com',
  );

  static const all = [groq, openRouter, nvidia];
  static const fallback = groq;

  static AiProvider byId(String? id) =>
      all.firstWhere((p) => p.id == id, orElse: () => fallback);
}
