const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
const supabasePublishableKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

export function getSupabaseEnv() {
  const resolvedKey = supabaseAnonKey ?? supabasePublishableKey ?? "";
  return {
    supabaseUrl: supabaseUrl ?? "",
    supabaseAnonKey: resolvedKey,
    isConfigured: Boolean(supabaseUrl && resolvedKey),
  };
}
