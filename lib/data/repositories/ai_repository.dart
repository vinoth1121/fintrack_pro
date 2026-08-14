import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/network/dio_client.dart';
import '../models/models.dart';

/// Logs the *real* reason an AI call failed (timeout vs connection-refused
/// vs 401 vs 500 vs backend-down) to the debug console. The user-facing copy
/// stays friendly/generic, but this makes it possible to actually diagnose
/// "AI service unavailable" reports instead of guessing.
void _logAiFailure(String endpoint, Object e) {
  if (e is DioException) {
    final status = e.response?.statusCode;
    debugPrint(
      '[AI:$endpoint] ${e.type} status=$status url=${e.requestOptions.uri} '
      'message=${e.message} body=${e.response?.data}',
    );
  } else {
    debugPrint('[AI:$endpoint] non-Dio error: $e');
  }
}

class AiRepository {
  const AiRepository._();

  /// Chat with the Lumina AI financial coach.
  static Future<String> chat({
    required List<ChatMessage> history,
    required String context,
  }) async {
    try {
      final res = await dioClient.post(ApiEndpoints.aiChat, data: {
        'messages': history.map((m) => {'role': m.role, 'content': m.content}).toList(),
        'context': context,
        'message': history.isNotEmpty ? history.last.content : '',
      },);
      final data = res.data as Map<String, dynamic>;
      final msg = data['message'] as Map<String, dynamic>?;
      return msg?['content'] as String? ??
          data['reply'] as String? ??
          "I couldn't generate a response. Please try again.";
    } catch (e) {
      _logAiFailure('chat', e);
      return "I'm having trouble connecting to the AI service right now. Please try again in a moment.";
    }
  }

  /// Receipt Scanner — VLM extraction.
  static Future<ReceiptData?> scanReceipt(String base64Image) async {
    try {
      final res = await dioClient.post(ApiEndpoints.aiReceipt, data: {'image': base64Image});
      final data = res.data as Map<String, dynamic>;
      if (data['ok'] != true) return null;
      return ReceiptData.fromJson(data['receipt'] as Map<String, dynamic>);
    } catch (e) {
      _logAiFailure('receipt', e);
      return null;
    }
  }

  /// Voice entry — ASR + LLM parse.
  static Future<VoiceResult> transcribeAndParse(String base64Audio, {String? today}) async {
    try {
      final res = await dioClient.post(ApiEndpoints.aiVoice, data: {
        'audio': base64Audio, 'today': today,
      },);
      final data = res.data as Map<String, dynamic>;
      return VoiceResult(
        ok: data['ok'] as bool? ?? false,
        transcript: data['transcript'] as String? ?? '',
        transaction: data['transaction'] != null
            ? ParsedTransaction.fromJson(data['transaction'] as Map<String, dynamic>)
            : null,
        warning: data['warning'] as String?,
      );
    } catch (e) {
      _logAiFailure('voice', e);
      return const VoiceResult(ok: false, transcript: '', transaction: null);
    }
  }

  /// AI Insights — forecast + anomalies + cards.
  static Future<InsightsPayload?> insights({
    required List<Transaction> transactions,
    required List<Budget> budgets,
    required List<SavingsGoal> goals,
    required String currency,
    required Map<String, String> categoryNameMap,
  }) async {
    try {
      final res = await dioClient.post(ApiEndpoints.aiInsights, data: {
        'transactions': transactions.map((t) => {
          'type': t.type.name, 'amount': t.amount, 'categoryId': t.categoryId,
          'date': t.date.toIso8601String(), 'merchant': t.merchant, 'note': t.note,
        },).toList(),
        'budgets': budgets.map((b) => {'categoryId': b.categoryId, 'limit': b.limit}).toList(),
        'goals': goals.map((g) => {
          'name': g.name, 'target': g.target, 'saved': g.saved,
          'deadline': g.deadline?.toIso8601String(),
        },).toList(),
        'currency': currency, 'categoryNameMap': categoryNameMap,
      },);
      final data = res.data as Map<String, dynamic>;
      if (data['ok'] != true) return null;
      return InsightsPayload.fromJson(data['payload'] as Map<String, dynamic>);
    } catch (e) {
      _logAiFailure('insights', e);
      return null;
    }
  }

  /// Weekly summary — AI smart notification.
  static Future<WeeklySummary?> weeklySummary({
    required List<Transaction> transactions,
    required String currency,
    required Map<String, String> categoryNameMap,
  }) async {
    try {
      final res = await dioClient.post(ApiEndpoints.aiWeeklySummary, data: {
        'transactions': transactions.map((t) => {
          'type': t.type.name, 'amount': t.amount, 'categoryId': t.categoryId,
          'date': t.date.toIso8601String(), 'merchant': t.merchant,
        },).toList(),
        'currency': currency, 'categoryNameMap': categoryNameMap,
      },);
      final data = res.data as Map<String, dynamic>;
      if (data['ok'] != true) return null;
      return WeeklySummary.fromJson(data['summary'] as Map<String, dynamic>);
    } catch (e) {
      _logAiFailure('weeklySummary', e);
      return null;
    }
  }
}

class ReceiptItem { final String name; final int? qty; final double? price; const ReceiptItem(this.name, this.qty, this.price); factory ReceiptItem.fromJson(Map<String,dynamic> j) => ReceiptItem(j['name'] as String, j['qty'] as int?, (j['price'] as num?)?.toDouble()); }

class ReceiptData {
  final String merchant;
  final double? total, subtotal, tax;
  final String? date, currency, rawText;
  final String category;
  final List<ReceiptItem> items;
  const ReceiptData({required this.merchant, this.total, this.subtotal, this.tax, this.date, this.currency, required this.category, required this.items, this.rawText});
  factory ReceiptData.fromJson(Map<String, dynamic> j) => ReceiptData(
    merchant: j['merchant'] as String? ?? '', total: (j['total'] as num?)?.toDouble(),
    subtotal: (j['subtotal'] as num?)?.toDouble(), tax: (j['tax'] as num?)?.toDouble(),
    date: j['date'] as String?, currency: j['currency'] as String?,
    category: j['category'] as String? ?? 'Other',
    items: (j['items'] as List?)?.map((e) => ReceiptItem.fromJson(e)).toList() ?? const [],
    rawText: j['rawText'] as String?,
  );
}

class ParsedTransaction {
  final String type; final double? amount; final String merchant;
  final String category; final String? date; final String note;
  const ParsedTransaction({required this.type, this.amount, required this.merchant, required this.category, this.date, required this.note});
  factory ParsedTransaction.fromJson(Map<String, dynamic> j) => ParsedTransaction(
    type: j['type'] as String? ?? 'expense', amount: (j['amount'] as num?)?.toDouble(),
    merchant: j['merchant'] as String? ?? '', category: j['category'] as String? ?? 'Other',
    date: j['date'] as String?, note: j['note'] as String? ?? '',
  );
}

class VoiceResult {
  final bool ok; final String transcript;
  final ParsedTransaction? transaction; final String? warning;
  const VoiceResult({required this.ok, required this.transcript, this.transaction, this.warning});
}

class InsightCard {
  final String id, kind, title, body, icon, accent; final String? metric;
  const InsightCard({required this.id, required this.kind, required this.title, required this.body, required this.icon, required this.accent, this.metric});
  factory InsightCard.fromJson(Map<String, dynamic> j) => InsightCard(
    id: j['id'] as String? ?? '', kind: j['kind'] as String? ?? 'tip',
    title: j['title'] as String? ?? '', body: j['body'] as String? ?? '',
    icon: j['icon'] as String? ?? 'lightbulb', accent: j['accent'] as String? ?? 'iris',
    metric: j['metric'] as String?,
  );
}

class InsightsPayload {
  final List<InsightCard> cards;
  final Forecast forecast;
  final WeeklySummaryData weeklySummary;
  final List<Anomaly> anomalies;
  const InsightsPayload({required this.cards, required this.forecast, required this.weeklySummary, required this.anomalies});
  factory InsightsPayload.fromJson(Map<String, dynamic> j) => InsightsPayload(
    cards: (j['cards'] as List?)?.map((e) => InsightCard.fromJson(e)).toList() ?? const [],
    forecast: Forecast.fromJson(j['forecast'] as Map<String, dynamic>),
    weeklySummary: WeeklySummaryData.fromJson(j['weeklySummary'] as Map<String, dynamic>),
    anomalies: (j['anomalies'] as List?)?.map((e) => Anomaly.fromJson(e)).toList() ?? const [],
  );
}

class Forecast { final double endOfMonthExpense; final String confidence; final int daysProjected; final String trend; const Forecast(this.endOfMonthExpense, this.confidence, this.daysProjected, this.trend); factory Forecast.fromJson(Map<String,dynamic> j) => Forecast((j['endOfMonthExpense'] as num).toDouble(), j['confidence'] as String? ?? 'medium', j['daysProjected'] as int? ?? 0, j['trend'] as String? ?? 'flat'); }
class WeeklySummaryData { final double weekSpent, weekIncome, topCategoryAmount; final String topCategory; final int vsLastWeekPct; const WeeklySummaryData(this.weekSpent, this.weekIncome, this.topCategory, this.topCategoryAmount, this.vsLastWeekPct); factory WeeklySummaryData.fromJson(Map<String,dynamic> j) => WeeklySummaryData((j['weekSpent'] as num? ?? 0).toDouble(), (j['weekIncome'] as num? ?? 0).toDouble(), j['topCategory'] as String? ?? '—', (j['topCategoryAmount'] as num? ?? 0).toDouble(), j['vsLastWeekPct'] as int? ?? 0); }
class Anomaly { final String date, merchant, reason; final double amount; const Anomaly(this.date, this.merchant, this.amount, this.reason); factory Anomaly.fromJson(Map<String,dynamic> j) => Anomaly(j['date'] as String? ?? '', j['merchant'] as String? ?? '', (j['amount'] as num? ?? 0).toDouble(), j['reason'] as String? ?? ''); }
class WeeklySummary { final String title, body; final List<String> highlights; const WeeklySummary({required this.title, required this.body, required this.highlights}); factory WeeklySummary.fromJson(Map<String,dynamic> j) => WeeklySummary(title: j['title'] as String? ?? '', body: j['body'] as String? ?? '', highlights: (j['highlights'] as List?)?.map((e) => e as String).toList() ?? const []); }
