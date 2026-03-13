import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://167.99.46.249:8000/glucoapi';

  // GET /api/v1/glucose/report
  Future<Map<String, dynamic>> getGlucoseReport({String days = '7'}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/glucose/report?days=$days'),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch glucose report (${response.statusCode})');
  }

  // GET /api/v1/bolus/timing
  Future<Map<String, dynamic>> getBolustiming({
    String mealType = 'medium_gi',
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/bolus/timing?meal_type=$mealType'),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to get bolus timing (${response.statusCode})');
  }

  // POST /api/v1/bolus/
  Future<Map<String, dynamic>> logBolus({
    required double units,
    String bolusType = 'manual',
    String? mealType,
    double? glucoseAtInjection,
    int? injectToMealMin,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'units': units,
      'bolus_type': bolusType,
      'meal_type': ?mealType,
      'glucose_at_injection': ?glucoseAtInjection,
      'inject_to_meal_min': ?injectToMealMin,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/bolus/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    if (response.statusCode == 201) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to log bolus: ${response.body}');
  }

  // POST /api/v1/basal
  Future<Map<String, dynamic>> logBasal({
    required double units,
    String? insulin,
    String? time,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'units': units,
      'insulin': ?insulin,
      'time': ?time,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/basal'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    if (response.statusCode == 201) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to log basal: ${response.body}');
  }

  // POST /api/v1/hypo
  Future<Map<String, dynamic>> logHypo({
    required double lowestValue,
    required DateTime startedAt,
    DateTime? endedAt,
    int? durationMin,
    String? treatedWith,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'lowest_value': lowestValue,
      'started_at': startedAt.toIso8601String(),
      if (endedAt != null) 'ended_at': endedAt.toIso8601String(),
      'duration_min': ?durationMin,
      if (treatedWith != null && treatedWith.isNotEmpty)
        'treated_with': treatedWith,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/hypo'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    if (response.statusCode == 201) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to log hypo: ${response.body}');
  }

  // GET /api/v1/hypo
  Future<List<dynamic>> getHypos({int limit = 20}) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/hypo?limit=$limit'),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body) as List<dynamic>;
    }
    throw Exception('Failed to get hypos (${response.statusCode})');
  }

  // POST /api/v1/insights/analyse
  Future<Map<String, dynamic>> getAiInsights({int days = 7}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/insights/analyse'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'days': days}),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to get AI insights (${response.statusCode})');
  }

  // POST /api/v1/reports/monthly
  Future<Map<String, dynamic>> getMonthlyReport({int days = 30}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/reports/monthly?days=$days'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({}),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to get monthly report (${response.statusCode})');
  }

  // Download PDF URL builder
  String pdfDownloadUrl(String reportDate) =>
      '$baseUrl/api/v1/reports/download/$reportDate';

  // POST /api/v1/glucose/analyse
  Future<Map<String, dynamic>> analyseUser({
    required String fullName,
    required int age,
    required int weight,
    required int basalUnit,
    required int height,
  }) async {
    final body = {
      'full_name': fullName,
      'age': age,
      'weight': weight,
      'basal_unit': basalUnit,
      'height': height,
    };
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/glucose/analyse'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to analyse user (${response.statusCode})');
  }
}
