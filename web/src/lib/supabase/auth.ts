import { createClient, isSupabaseConfigured } from "@/lib/supabase/client";

// Re-export server-safe check for client components via env
export function supabaseReady() {
  return isSupabaseConfigured();
}

export async function signInWithEmail(email: string) {
  const supabase = createClient();
  return supabase.auth.signInWithOtp({
    email,
    options: {
      emailRedirectTo: `${window.location.origin}/auth/callback`,
    },
  });
}

export async function signOut() {
  const supabase = createClient();
  return supabase.auth.signOut();
}
