"use client";

import { Download } from "lucide-react";
import type { ReactNode } from "react";
import { ADDON_DOWNLOAD_PATH, ADDON_FOLDER_NAME } from "@/lib/addon";
import { cn } from "@/lib/utils";

type Variant = "primary" | "outline" | "link";

export function AddonDownloadButton({
  className,
  variant = "primary",
  children,
}: {
  className?: string;
  variant?: Variant;
  children?: ReactNode;
}) {
  const onClick = (event: React.MouseEvent<HTMLAnchorElement>) => {
    event.preventDefault();
    window.location.assign(`${ADDON_DOWNLOAD_PATH}?t=${Date.now()}`);
  };

  return (
    <a
      href={ADDON_DOWNLOAD_PATH}
      download={`${ADDON_FOLDER_NAME}.zip`}
      onClick={onClick}
      className={cn(
        "inline-flex items-center gap-2 transition",
        variant === "primary" &&
          "rounded-md bg-amber-500 px-5 py-3 text-sm font-semibold text-zinc-950 hover:bg-amber-400",
        variant === "outline" &&
          "rounded-md border border-amber-500/50 bg-amber-500/10 px-4 py-2.5 text-sm font-semibold text-amber-200 hover:bg-amber-500/20",
        variant === "link" &&
          "font-medium text-amber-400 hover:text-amber-300",
        className,
      )}
    >
      {variant !== "link" ? <Download className="h-4 w-4" /> : null}
      {children ?? "Download latest addon"}
    </a>
  );
}
