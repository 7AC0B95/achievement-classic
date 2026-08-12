"use client";

import { Loader2, LogIn, LogOut, Mail } from "lucide-react";
import { useEffect, useState } from "react";
import { createClient, isSupabaseConfigured } from "@/lib/supabase/client";
import { signInWithEmail, signOut } from "@/lib/supabase/auth";

export function AuthPanel() {
  const [email, setEmail] = useState("");
  const [userEmail, setUserEmail] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const configured = isSupabaseConfigured();

  useEffect(() => {
    if (!configured) return;
    const supabase = createClient();
    supabase.auth.getUser().then(({ data }) => {
      setUserEmail(data.user?.email ?? null);
    });
    const { data: sub } = supabase.auth.onAuthStateChange((_event, session) => {
      setUserEmail(session?.user?.email ?? null);
    });
    return () => sub.subscription.unsubscribe();
  }, [configured]);

  if (!configured) {
    return (
      <section className="rounded-xl border border-zinc-800 bg-zinc-900/60 p-5 text-sm text-zinc-400">
        Supabase env vars are not set. Add{" "}
        <code className="text-amber-300">NEXT_PUBLIC_SUPABASE_URL</code> and{" "}
        <code className="text-amber-300">NEXT_PUBLIC_SUPABASE_ANON_KEY</code> to{" "}
        <code className="text-amber-300">web/.env.local</code> to enable auth & sync.
      </section>
    );
  }

  const onSignIn = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setMessage(null);
    const { error } = await signInWithEmail(email);
    setLoading(false);
    if (error) {
      setMessage(error.message);
      return;
    }
    setMessage("Check your email for the magic link.");
  };

  const onSignOut = async () => {
    await signOut();
    setMessage("Signed out.");
  };

  return (
    <section className="rounded-xl border border-zinc-800 bg-zinc-900/60 p-5">
      <h2 className="font-[family-name:var(--font-display)] text-lg text-zinc-50">
        Account
      </h2>
      {userEmail ? (
        <div className="mt-3 flex flex-wrap items-center justify-between gap-3">
          <p className="text-sm text-zinc-300">
            Signed in as <span className="text-amber-300">{userEmail}</span>
          </p>
          <button
            type="button"
            onClick={onSignOut}
            className="inline-flex items-center gap-2 rounded-md border border-zinc-700 px-3 py-2 text-sm text-zinc-300 hover:border-rose-500/40 hover:text-rose-300"
          >
            <LogOut className="h-4 w-4" />
            Sign out
          </button>
        </div>
      ) : (
        <form onSubmit={onSignIn} className="mt-3 flex flex-wrap gap-2">
          <label className="relative min-w-[220px] flex-1">
            <Mail className="pointer-events-none absolute top-1/2 left-3 h-4 w-4 -translate-y-1/2 text-zinc-500" />
            <input
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="you@email.com"
              className="w-full rounded-md border border-zinc-700 bg-zinc-950 py-2.5 pr-3 pl-10 text-sm text-zinc-100 outline-none focus:border-amber-500/50"
            />
          </label>
          <button
            type="submit"
            disabled={loading}
            className="inline-flex items-center gap-2 rounded-md bg-zinc-100 px-4 py-2.5 text-sm font-semibold text-zinc-950 hover:bg-white disabled:opacity-50"
          >
            {loading ? (
              <Loader2 className="h-4 w-4 animate-spin" />
            ) : (
              <LogIn className="h-4 w-4" />
            )}
            Magic link
          </button>
        </form>
      )}
      {message ? <p className="mt-3 text-sm text-zinc-400">{message}</p> : null}
    </section>
  );
}
