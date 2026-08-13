import type { Metadata, Viewport } from "next";
import { Cinzel, Source_Sans_3 } from "next/font/google";
import { cookies } from "next/headers";
import { Suspense } from "react";
import { Navbar } from "@/components/navbar";
import { SiteFooter } from "@/components/site-footer";
import {
  ACTIVE_CHARACTER_COOKIE,
  resolveActiveCharacter,
} from "@/lib/active-character";
import { fetchUserCharacters } from "@/lib/data";
import "./globals.css";

const display = Cinzel({
  variable: "--font-display",
  subsets: ["latin"],
  weight: ["500", "600", "700"],
});

const body = Source_Sans_3({
  variable: "--font-body",
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
});

export const metadata: Metadata = {
  title: "Classic Glory | Classic Era Achievements",
  description:
    "Retail-style achievement tracking for World of Warcraft Classic Era and Hardcore — install the in-game addon, then sync SavedVariables to public leaderboards.",
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
  themeColor: "#09090b",
};

async function Header() {
  const characters = await fetchUserCharacters();
  const cookieStore = await cookies();
  const selected = resolveActiveCharacter(
    characters,
    cookieStore.get(ACTIVE_CHARACTER_COOKIE)?.value,
  );

  return (
    <Navbar characters={characters} selectedId={selected?.id ?? null} />
  );
}

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang="en"
      className={`${display.variable} ${body.variable} h-full antialiased`}
    >
      <body className="flex min-h-full min-w-0 flex-col font-sans">
        <Suspense fallback={<Navbar />}>
          <Header />
        </Suspense>
        <main className="min-w-0 flex-1">{children}</main>
        <SiteFooter />
      </body>
    </html>
  );
}
