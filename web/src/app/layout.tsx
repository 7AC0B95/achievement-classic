import type { Metadata } from "next";
import { Cinzel, Source_Sans_3 } from "next/font/google";
import { Navbar } from "@/components/navbar";
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
  title: "Laucob's Achievements | Classic Era / Hardcore",
  description:
    "Retail-style achievement tracking for World of Warcraft Classic Era and Hardcore — sync your addon SavedVariables to public leaderboards.",
};

export default function RootLayout({ children }: LayoutProps<"/">) {
  return (
    <html
      lang="en"
      className={`${display.variable} ${body.variable} h-full antialiased`}
    >
      <body className="flex min-h-full flex-col font-sans">
        <Navbar />
        <main className="flex-1">{children}</main>
        <footer className="border-t border-zinc-800/80 py-8 text-center text-sm text-zinc-500">
          Laucob&apos;s Achievements · WoW Classic Era / Hardcore · Addon Interface 11509
        </footer>
      </body>
    </html>
  );
}
