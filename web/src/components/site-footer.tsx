import { AddonDownloadButton } from "@/components/addon-download-button";
import { ADDON_GITHUB_URL } from "@/lib/addon";

export function SiteFooter() {
  return (
    <footer className="border-t border-zinc-800/80 py-8 pb-[max(2rem,env(safe-area-inset-bottom))]">
      <div className="mx-auto flex max-w-6xl flex-col items-center gap-3 px-4 text-center text-sm text-zinc-500 sm:px-6">
        <p>
          Classic Glory · in-game addon + website · WoW Classic Era
          / Hardcore
        </p>
        <div className="flex flex-wrap items-center justify-center gap-x-3 gap-y-1">
          <AddonDownloadButton variant="link">
            Download the addon
          </AddonDownloadButton>
          <span className="text-zinc-700">·</span>
          <a
            href={ADDON_GITHUB_URL}
            target="_blank"
            rel="noreferrer"
            className="text-zinc-400 hover:text-zinc-200"
          >
            GitHub
          </a>
          <span className="text-zinc-700">·</span>
          <span>Interface 11509</span>
        </div>
      </div>
    </footer>
  );
}
