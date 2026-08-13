"use client";

import { CharacterSelect } from "@/components/character-select";
import type { CharacterRow } from "@/lib/types";
import { cn } from "@/lib/utils";
import { Crown, Menu, Trophy, X } from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";

const LINKS = [
  { href: "/", label: "Home" },
  { href: "/leaderboard", label: "Leaderboard" },
  { href: "/achievements", label: "Achievements" },
];

interface NavbarProps {
  characters?: CharacterRow[];
  selectedId?: string | null;
}

export function Navbar({
  characters = [],
  selectedId = null,
}: NavbarProps) {
  const pathname = usePathname();
  const connectActive = pathname.startsWith("/dashboard");
  const [open, setOpen] = useState(false);

  useEffect(() => {
    setOpen(false);
  }, [pathname]);

  useEffect(() => {
    if (!open) return;
    const previous = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = previous;
    };
  }, [open]);

  return (
    <header className="sticky top-0 z-50 border-b border-zinc-800/80 bg-zinc-950/80 pt-[env(safe-area-inset-top,0px)] backdrop-blur-xl">
      <div className="mx-auto flex h-16 max-w-6xl items-center justify-between gap-3 px-4 sm:px-6">
        <Link href="/" className="group flex min-w-0 items-center gap-2 sm:gap-2.5">
          <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg border border-amber-500/40 bg-amber-500/10 text-amber-400 shadow-[0_0_24px_rgba(245,158,11,0.15)] transition group-hover:border-amber-400/70">
            <Crown className="h-4.5 w-4.5" />
          </span>
          <span className="min-w-0 truncate font-[family-name:var(--font-display)] text-base tracking-wide text-zinc-50 sm:text-lg">
            Classic <span className="text-amber-400">Glory</span>
          </span>
        </Link>

        <nav className="hidden items-center gap-1 md:flex">
          {LINKS.map((link) => {
            const active =
              link.href === "/"
                ? pathname === "/"
                : pathname.startsWith(link.href);
            return (
              <Link
                key={link.href}
                href={link.href}
                className={cn(
                  "rounded-md px-3 py-2 text-sm transition",
                  active
                    ? "bg-zinc-800/80 text-amber-300"
                    : "text-zinc-400 hover:bg-zinc-900 hover:text-zinc-100",
                )}
              >
                {link.label}
              </Link>
            );
          })}
          {characters.length > 0 ? (
            <CharacterSelect
              characters={characters}
              selectedId={selectedId}
              persistActive
              compact
              align="end"
              label="Active character"
              className="w-52"
            />
          ) : null}
          <Link
            href="/dashboard"
            className={cn(
              "inline-flex items-center gap-2 rounded-md px-3.5 py-2 text-sm font-semibold text-zinc-950 transition",
              connectActive
                ? "bg-amber-400 ring-1 ring-amber-200/50"
                : "bg-amber-500 hover:bg-amber-400",
            )}
          >
            <Trophy className="h-4 w-4" />
            Connect
          </Link>
        </nav>

        <button
          type="button"
          className="inline-flex h-11 w-11 shrink-0 items-center justify-center rounded-md border border-zinc-800 text-zinc-300 md:hidden"
          onClick={() => setOpen((v) => !v)}
          aria-expanded={open}
          aria-controls="mobile-nav"
          aria-label={open ? "Close menu" : "Open menu"}
        >
          {open ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
        </button>
      </div>

      {open ? (
        <div
          id="mobile-nav"
          className="max-h-[calc(100dvh-var(--header-offset))] overflow-y-auto border-t border-zinc-800 px-4 py-3 pb-[max(0.75rem,env(safe-area-inset-bottom))] md:hidden"
        >
          <div className="flex flex-col gap-1">
            {LINKS.map((link) => {
              const active =
                link.href === "/"
                  ? pathname === "/"
                  : pathname.startsWith(link.href);
              return (
                <Link
                  key={link.href}
                  href={link.href}
                  onClick={() => setOpen(false)}
                  className={cn(
                    "rounded-md px-3 py-3 text-base transition",
                    active
                      ? "bg-zinc-800/80 text-amber-300"
                      : "text-zinc-300 hover:bg-zinc-900",
                  )}
                >
                  {link.label}
                </Link>
              );
            })}
            {characters.length > 0 ? (
              <div className="px-1 py-2">
                <CharacterSelect
                  characters={characters}
                  selectedId={selectedId}
                  persistActive
                  label="Active character"
                  className="w-full"
                />
              </div>
            ) : null}
            <Link
              href="/dashboard"
              onClick={() => setOpen(false)}
              className={cn(
                "mt-1 inline-flex min-h-11 items-center justify-center gap-2 rounded-md px-3 py-3 text-sm font-semibold text-zinc-950",
                connectActive
                  ? "bg-amber-400 ring-1 ring-amber-200/50"
                  : "bg-amber-500",
              )}
            >
              <Trophy className="h-4 w-4" />
              Connect
            </Link>
          </div>
        </div>
      ) : null}
    </header>
  );
}
