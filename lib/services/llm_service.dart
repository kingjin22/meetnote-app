import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/meeting_summary.dart';
import 'prompts/meeting_summary_prompt.dart';

enum LLMProvider {
  claude,
  openai;

  String get name {
    switch (this) {
      case LLMProvider.claude:
        return 'Claude';
      case LLMProvider.openai:
        return 'OpenAI';
    }
  }
}

class LLMServiceException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;

  LLMServiceException(this.message, {this.statusCode, this.details});

  @override
  String toString() {
    if (statusCode != null) {
      return 'LLMServiceException: $message (Status: $statusCode)';
    }
    return 'LLMServiceException: $message';
  }
}

class LLMService {
  static const int maxRetries = 2;
  static const Duration timeout = Duration(seconds: 60);

  // Claude API configuration
  static const String claudeApiUrl = 'https://api.anthropic.com/v1/messages';
  static const String claudeModel = 'claude-3-5-sonnet-20241022';
  static const String claudeVersion = '2023-06-01';

  // OpenAI API configuration
  static const String openaiApiUrl = 'https://api.openai.com/v1/chat/completions';
  static const String openaiModel = 'gpt-4o-mini';

  /// Generate meeting summary using specified LLM provider
  Future<MeetingSummary> generateSummary(
    String transcriptText, {
    LLMProvider? provider,
    bool simplified = false,
  }) async {
    final selectedProvider = provider ?? _getDefaultProvider();
    
    switch (selectedProvider) {
      case LLMProvider.claude:
        return _generateSummaryWithClaude(transcriptText, simplified: simplified);
      case LLMProvider.openai:
        return _generateSummaryWithGPT(transcriptText, simplified: simplified);
    }
  }

  LLMProvider _getDefaultProvider() {
    final providerName = dotenv.env['DEFAULT_LLM_PROVIDER']?.toLowerCase() ?? 'claude';
    return providerName == 'openai' ? LLMProvider.openai : LLMProvider.claude;
  }

  /// Generate summary using Claude API
  Future<MeetingSummary> _generateSummaryWithClaude(
    String transcriptText, {
    required bool simplified,
  }) async {
    final apiKey = dotenv.env['ANTHROPIC_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw LLMServiceException('Anthropic API key not configured');
    }

    final userPrompt = simplified
        ? MeetingSummaryPrompt.createSimplifiedPrompt(transcriptText)
        : MeetingSummaryPrompt.createUserPrompt(transcriptText);

    final requestBody = {
      'model': claudeModel,
      'max_tokens': 4096,
      'messages': [
        {
          'role': 'user',
          'content': '${MeetingSummaryPrompt.systemPrompt}\n\n$userPrompt',
        }
      ],
    };

    try {
      final response = await http
          .post(
            Uri.parse(claudeApiUrl),
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': apiKey,
              'anthropic-version': claudeVersion,
            },
            body: jsonEncode(requestBody),
          )
          .timeout(timeout);

      if (response.statusCode != 200) {
        final errorBody = jsonDecode(response.body);
        throw LLMServiceException(
          'Claude API request failed: ${errorBody['error']?['message'] ?? 'Unknown error'}',
          statusCode: response.statusCode,
          details: errorBody,
        );
      }

      final responseData = jsonDecode(response.body);
      final content = responseData['content'][0]['text'] as String;

      return _parseSummaryResponse(content);
    } catch (e) {
      if (e is LLMServiceException) rethrow;
      throw LLMServiceException('Failed to generate summary with Claude: $e');
    }
  }

  /// Generate summary using OpenAI GPT API
  Future<MeetingSummary> _generateSummaryWithGPT(
    String transcriptText, {
    required bool simplified,
  }) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw LLMServiceException('OpenAI API key not configured');
    }

    final userPrompt = simplified
        ? MeetingSummaryPrompt.createSimplifiedPrompt(transcriptText)
        : MeetingSummaryPrompt.createUserPrompt(transcriptText);

    final requestBody = {
      'model': openaiModel,
      'messages': [
        {
          'role': 'system',
          'content': MeetingSummaryPrompt.systemPrompt,
        },
        {
          'role': 'user',
          'content': userPrompt,
        }
      ],
      'response_format': {'type': 'json_object'},
    };

    try {
      final response = await http
          .post(
            Uri.parse(openaiApiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(timeout);

      if (response.statusCode != 200) {
        final errorBody = jsonDecode(response.body);
        throw LLMServiceException(
          'OpenAI API request failed: ${errorBody['error']?['message'] ?? 'Unknown error'}',
          statusCode: response.statusCode,
          details: errorBody,
        );
      }

      final responseData = jsonDecode(response.body);
      final content = responseData['choices'][0]['message']['content'] as String;

      return _parseSummaryResponse(content);
    } catch (e) {
      if (e is LLMServiceException) rethrow;
      throw LLMServiceException('Failed to generate summary with OpenAI: $e');
    }
  }

  /// Parse LLM response and create MeetingSummary object
  MeetingSummary _parseSummaryResponse(String content) {
    try {
      // Extract JSON from markdown code blocks if present
      String jsonContent = content.trim();
      if (jsonContent.startsWith('```json')) {
        jsonContent = jsonContent.substring(7);
        if (jsonContent.endsWith('```')) {
          jsonContent = jsonContent.substring(0, jsonContent.length - 3);
        }
      } else if (jsonContent.startsWith('```')) {
        jsonContent = jsonContent.substring(3);
        if (jsonContent.endsWith('```')) {
          jsonContent = jsonContent.substring(0, jsonContent.length - 3);
        }
      }
      jsonContent = jsonContent.trim();

      final data = jsonDecode(jsonContent) as Map<String, dynamic>;

      return MeetingSummary(
        overview: data['overview'] as String? ?? '회의 내용 없음',
        discussions: (data['discussions'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        decisions: (data['decisions'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        actionItems: (data['actionItems'] as List?)
                ?.map((e) => ActionItem.fromMap(e as Map<String, dynamic>))
                .toList() ??
            [],
        nextMeeting: data['nextMeeting'] as String?,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      throw LLMServiceException('Failed to parse LLM response: $e\nContent: $content');
    }
  }

  /// Generate summary with retry logic
  Future<MeetingSummary> generateSummaryWithRetry(
    String transcriptText, {
    LLMProvider? provider,
    bool simplified = false,
  }) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        return await generateSummary(
          transcriptText,
          provider: provider,
          simplified: simplified,
        );
      } catch (e) {
        if (attempt == maxRetries - 1) rethrow;
        // Wait before retry (exponential backoff)
        await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
      }
    }
    throw LLMServiceException('Failed after $maxRetries attempts');
  }

  /// Estimate token count (rough approximation)
  int estimateTokenCount(String text) {
    // Rough estimate: 1 token ≈ 4 characters for English, ~2-3 for Korean
    return (text.length / 2.5).ceil();
  }

  /// Estimate cost for generation
  Map<String, double> estimateCost(String transcriptText, {LLMProvider? provider}) {
    final selectedProvider = provider ?? _getDefaultProvider();
    final inputTokens = estimateTokenCount(transcriptText);
    const outputTokens = 1000; // Estimated output

    double inputCost, outputCost;

    switch (selectedProvider) {
      case LLMProvider.claude:
        // Claude Sonnet: $3/MTok input, $15/MTok output
        inputCost = (inputTokens / 1000000) * 3;
        outputCost = (outputTokens / 1000000) * 15;
        break;
      case LLMProvider.openai:
        // GPT-4o-mini: $0.150/MTok input, $0.600/MTok output
        inputCost = (inputTokens / 1000000) * 0.150;
        outputCost = (outputTokens / 1000000) * 0.600;
        break;
    }

    return {
      'inputCost': inputCost,
      'outputCost': outputCost,
      'totalCost': inputCost + outputCost,
      'inputTokens': inputTokens.toDouble(),
      'outputTokens': outputTokens.toDouble(),
    };
  }
}
