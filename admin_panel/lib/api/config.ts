const apiBaseUrl = process.env.NEXT_PUBLIC_API_BASE_URL;
const adminApiKey = process.env.NEXT_PUBLIC_ADMIN_API_KEY;

export function getApiConfig() {
  const resolvedBaseUrl = apiBaseUrl?.trim() || "http://localhost:8000";
  return {
    apiBaseUrl: resolvedBaseUrl,
    adminApiKey: adminApiKey?.trim() ?? "",
    isConfigured: Boolean(resolvedBaseUrl),
  };
}
