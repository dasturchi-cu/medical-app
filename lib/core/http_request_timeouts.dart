// HTTP kutish vaqtlari — baseUrl bo‘yicha (mahalliy / hosting). api_config dan mustaqil.

bool isLikelyLocalDevBaseUrl(String baseUrl) {
  final u = baseUrl.toLowerCase();
  return u.contains('10.0.2.2') ||
      u.contains('127.0.0.1') ||
      u.contains('localhost');
}

Duration apiListFetchTimeoutForBaseUrl(String baseUrl) =>
    isLikelyLocalDevBaseUrl(baseUrl)
        ? const Duration(seconds: 18)
        : const Duration(seconds: 35);

/// Bir kitob uchun `/books/access` — N+1 fallback, qisqa timeout.
Duration bookAccessCheckTimeoutForBaseUrl(String baseUrl) =>
    isLikelyLocalDevBaseUrl(baseUrl)
        ? const Duration(seconds: 12)
        : const Duration(seconds: 12);

/// Xarid huquqlari — Railway cold start uchun biroz uzoqroq.
Duration purchasesFetchTimeoutForBaseUrl(String baseUrl) =>
    isLikelyLocalDevBaseUrl(baseUrl)
        ? const Duration(seconds: 22)
        : const Duration(seconds: 45);

Duration catalogBootstrapHttpTimeoutForBaseUrl(String baseUrl) =>
    isLikelyLocalDevBaseUrl(baseUrl)
        ? const Duration(seconds: 28)
        : const Duration(seconds: 45);

/// Single-request home bundle (`GET /api/v1/home`) — allow cold Render wake + DB.
Duration homeAggregateHttpTimeoutForBaseUrl(String baseUrl) =>
    isLikelyLocalDevBaseUrl(baseUrl)
        ? const Duration(seconds: 40)
        : const Duration(seconds: 60);

/// Pomodoro reyting endpointi sekin bo'lsa tabni ushlab turmasin.
Duration pomodoroRankingTimeoutForBaseUrl(String baseUrl) =>
    isLikelyLocalDevBaseUrl(baseUrl)
        ? const Duration(seconds: 6)
        : const Duration(seconds: 10);
