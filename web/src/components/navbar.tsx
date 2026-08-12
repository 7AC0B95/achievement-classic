"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Crown, Menu, Trophy, X } from "lucide-react";
import { useState } from "react";
import { cn } from "@/lib/utils";

const LINKS = [
  { href: "/", label: "Home" },
  { href: "/leaderboard", label: "Leaderboard" },
  { href: "/achievements", label: "Achievements" },
  { href: "/dashboard", label: "Dashboard" },
];

export function Navbar() {
  const pathname = usePathname();
  const [open, setOpen] = useState(false);

  return (
    <header className="sticky top-0 z-50 border-b border-zinc-800/80 bg-zinc-950/80 backdrop-blur-xl">
      <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-4 sm:px-6">
        <Link href="/" className="group flex items-center gap-2.5">
          <span className="flex h-9 w-9 items-center justify-center rounded-lg border border-amber-500/40 bg-amber-500/10 text-amber-400 shadow-[0_0_24px_rgba(245,158,11,0.15)] transition group-hover:border-amber-400/70">
            <Crown className="h-4.5 w-4.5" />
          </span>
          <span className="font-[family-name:var(--font-display)] text-lg tracking-wide text-zinc-50">
            Laucob<span className="text-amber-400">&apos;s</span> Achievements
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
          <Link
            href="/dashboard"
            className="ml-2 inline-flex items-center gap-2 rounded-md bg-amber-500 px-3.5 py-2 text-sm font-semibold text-zinc-950 transition hover:bg-amber-400"
          >
            <Trophy className="h-4 w-4" />
            Connect
          </Link>
        </nav>

        <button
          type="button"
          className="rounded-md border border-zinc-800 p-2 text-zinc-300 md:hidden"
          onClick={() => setOpen((v) => !v)}
          aria-label="Toggle menu"
        >
          {open ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}
        </button>
      </div>

      {open ? (
        <div className="border-t border-zinc-800 px-4 py-3 md:hidden">
          <div className="flex flex-col gap-1">
            {LINKS.map((link) => (
              <Link
                key={link.href}
                href={link.href}
                onClick={() => setOpen(false)}
                className="rounded-md px-3 py-2 text-sm text-zinc-300 hover:bg-zinc-900"
              >
                {link.label}
              </Link>
            ))}
          </div>
        </div>
      ) : null}
    </header>
  );
}
