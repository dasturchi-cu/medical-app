const apiBaseUrl = process.env.NEXT_PUBLIC_API_BASE_URL;
const adminApiKey = process.env.NEXT_PUBLIC_ADMIN_API_KEY;

function resolveApiBaseUrl() {
  const fromEnv = apiBaseUrl?.trim();
  if (fromEnv) return fromEnv;
  if (typeof window !== "undefined") {
    const host = window.location.hostname || "localhost";
    return `http://${host}:8000`;
  }
  return "http://localhost:8000";
}

function resolveApiBaseCandidates() {
  const fromEnv = apiBaseUrl?.trim();
  const candidates: string[] = [];
  const localhostCandidates = ["http://localhost:8000", "http://127.0.0.1:8000"];
  const isLocalBase = (value: string) => value.includes("localhost") || value.includes("127.0.0.1");
  const pushCandidate = (value?: string) => {
    const normalized = value?.trim();
    if (!normalized) return;
    if (!candidates.includes(normalized)) candidates.push(normalized);
  };

  if (typeof window !== "undefined") {
    const host = window.location.hostname?.trim();
    if (host) {
      pushCandidate(`http://${host}:8000`);
      if (fromEnv) {
        if (isLocalBase(fromEnv) && host !== "localhost" && host !== "127.0.0.1") {
          localhostCandidates.forEach(pushCandidate);
          pushCandidate(fromEnv);
          return candidates;
        }
        pushCandidate(fromEnv);
      }
      localhostCandidates.forEach(pushCandidate);
      return candidates;
    }
  }
  pushCandidate(fromEnv);
  localhostCandidates.forEach(pushCandidate);
  return candidates;
}

export function getApiConfig() {
  const resolvedBaseUrl = resolveApiBaseUrl();
  return {
    apiBaseUrl: resolvedBaseUrl,
    apiBaseCandidates: resolveApiBaseCandidates(),
    adminApiKey: adminApiKey?.trim() ?? "",
    isConfigured: Boolean(resolvedBaseUrl),
  };
}

export async function apiFetch(path: string, init?: RequestInit) {
  const { apiBaseCandidates } = getApiConfig();
  const normalizedPath = path.startsWith("/") ? path : `/${path}`;
  let lastError: unknown = null;
  let lastResponse: Response | null = null;

  for (const baseUrl of apiBaseCandidates) {
    const url = `${baseUrl}${normalizedPath}`;
    console.log("API START", url, init?.method ?? "GET");
    try {
      const response = await fetch(url, init);
      let responseData: unknown;
      try {
        const text = await response.clone().text();
        responseData = text ? JSON.parse(text) : null;
      } catch {
        responseData = { _nonJson: true };
      }
      console.log("API RESPONSE", responseData);
      if (response.status >= 500) {
        lastResponse = response;
        continue;
      }
      return response;
    } catch (error) {
      console.log("API ERROR", error);
      lastError = error;
    }
  }
  if (lastResponse) return lastResponse;
  const message = lastError instanceof Error ? lastError.message : "Backendga ulanishda xatolik.";
  return new Response(JSON.stringify({ detail: `Backendga ulanishda xatolik: ${message}` }), {
    status: 503,
    headers: { "Content-Type": "application/json" },
  });
}
