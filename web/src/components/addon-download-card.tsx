"use client";

import { ChevronDown, FolderDown } from "lucide-react";
import { useState } from "react";
import { AddonDownloadButton } from "@/components/addon-download-button";
import {
  ADDON_DOWNLOAD_COLLAPSED_COOKIE,
  ADDON_FOLDER_NAME,
  ADDON_GITHUB_URL,
  ADDON_INSTALL_PATH,
} from "@/lib/addon";
import { cn } from "@/lib/utils";

const COOKIE_MAX_AGE = 60 * 60 * 24 * 365;

function persistOpen(open: boolean) {
  try {
    const collapsed = open ? "0" : "1";
    const secure = window.location.protocol === "https:" ? "; Secure" : "";
    document.cookie = `${ADDON_DOWNLOAD_COLLAPSED_COOKIE}=${collapsed}; Path=/; Max-Age=${COOKIE_MAX_AGE}; SameSite=Lax${secure}`;
  } catch {
    // Private mode / blocked cookies
  }
}

export function AddonDownloadCard({
  defaultOpen = true,
}: {
  defaultOpen?: boolean;
}) {
  const [open, setOpen] = useState(defaultOpen);

  return (
    <section
      id="download-addon"
      className={cn(
        "scroll-mt-24 rounded-xl border border-amber-500/45 bg-gradient-to-br from-amber-500/16 via-zinc-900/85 to-zinc-950/80 shadow-[0_0_48px_rgba(245,158,11,0.12)]",
        open ? "p-6" : "px-4 py-3",
      )}
    >
      <details
        className="group"
        open={open}
        onToggle={(event) => {
          const next = event.currentTarget.open;
          if (next === open) return;
          setOpen(next);
          persistOpen(next);
        }}
      >
        <summary className="flex cursor-pointer list-none flex-wrap items-center justify-between gap-4 [&::-webkit-details-marker]:hidden">
          <div className="flex min-w-0 items-center gap-2">
            <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-lg border border-amber-500/40 bg-amber-500/15 text-amber-300">
              <FolderDown className="h-4.5 w-4.5" />
            </span>
            <div className="min-w-0">
              <p className="text-xs font-semibold uppercase tracking-[0.2em] text-amber-400/90">
                Step 1 · In-game addon
              </p>
              <h2 className="font-[family-name:var(--font-display)] text-xl text-zinc-50 sm:text-2xl">
                Download the WoW addon
              </h2>
            </div>
            <ChevronDown className="h-5 w-5 shrink-0 text-amber-300 transition group-open:rotate-180" />
          </div>

          <div
            className="flex items-center gap-2"
            onClick={(event) => event.stopPropagation()}
            onPointerDown={(event) => event.stopPropagation()}
          >
            <AddonDownloadButton className="px-4 py-2.5" />
          </div>
        </summary>

        <div className="mt-5">
          <p className="max-w-xl text-sm leading-relaxed text-zinc-300">
            Always pulls the latest{" "}
            <code className="rounded bg-zinc-950/80 px-1.5 py-0.5 text-amber-300">
              {ADDON_FOLDER_NAME}
            </code>{" "}
            folder from GitHub — unzip and drop it into your Classic Era AddOns
            folder. Then play, log out, and sync the SavedVariables file below.
          </p>

          <ol className="mt-5 grid gap-3 text-sm text-zinc-400 sm:grid-cols-3">
            <li className="rounded-lg border border-amber-500/20 bg-zinc-950/50 px-3 py-3">
              <span className="font-semibold text-amber-300">1.</span> Download
              the zip (latest from GitHub).
            </li>
            <li className="rounded-lg border border-amber-500/20 bg-zinc-950/50 px-3 py-3">
              <span className="font-semibold text-amber-300">2.</span> Extract{" "}
              <code className="text-zinc-200">{ADDON_FOLDER_NAME}</code> into
              AddOns.
            </li>
            <li className="rounded-lg border border-amber-500/20 bg-zinc-950/50 px-3 py-3">
              <span className="font-semibold text-amber-300">3.</span> In-game{" "}
              <code className="text-zinc-200">/reload</code>, then{" "}
              <code className="text-zinc-200">/la</code>.
            </li>
          </ol>

          <div className="mt-4">
            <p className="text-xs uppercase tracking-wider text-zinc-500">
              Paste into
            </p>
            <code className="mt-2 block break-all rounded-lg border border-zinc-800 bg-zinc-950/80 px-3 py-3 text-xs leading-relaxed text-zinc-400">
              {ADDON_INSTALL_PATH}
            </code>
            <p className="mt-2 text-xs text-zinc-500">
              The zip contains only the addon folder, ready to paste. Source:{" "}
              <a
                href={ADDON_GITHUB_URL}
                target="_blank"
                rel="noreferrer"
                className="text-amber-400 hover:text-amber-300"
              >
                GitHub
              </a>
              .
            </p>
          </div>
        </div>
      </details>
    </section>
  );
}
