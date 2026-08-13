import { ADDON_FOLDER_NAME } from "@/lib/addon";
import { buildLatestAddonZip } from "@/lib/addon-zip";

export const dynamic = "force-dynamic";
export const fetchCache = "force-no-store";

const NO_STORE = "no-store, no-cache, must-revalidate, max-age=0";

export async function GET() {
  try {
    const zip = await buildLatestAddonZip();
    const body = Buffer.from(zip);

    return new Response(body, {
      headers: {
        "Content-Type": "application/zip",
        "Content-Disposition": `attachment; filename="${ADDON_FOLDER_NAME}.zip"`,
        "Content-Length": String(body.byteLength),
        "Cache-Control": NO_STORE,
        "CDN-Cache-Control": "no-store",
        "Vercel-CDN-Cache-Control": "no-store",
      },
    });
  } catch {
    return Response.json(
      { error: "Could not fetch the latest addon from GitHub. Try again in a moment." },
      {
        status: 502,
        headers: {
          "Cache-Control": NO_STORE,
        },
      },
    );
  }
}
