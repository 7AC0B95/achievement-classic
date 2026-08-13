import JSZip from "jszip";
import {
  ADDON_FOLDER_NAME,
  ADDON_GITHUB_ZIPBALL_URL,
  ADDON_RAW_BASE,
  ADDON_TOC_FILES,
} from "@/lib/addon";

const USER_AGENT = "ClassicGlory-Web";

function fetchFresh(url: string) {
  return fetch(url, {
    cache: "no-store",
    headers: { "User-Agent": USER_AGENT, Accept: "*/*" },
  });
}

export async function buildLatestAddonZip(): Promise<Uint8Array> {
  try {
    return await zipFromGithubZipball();
  } catch {
    return zipFromRawFiles();
  }
}

async function zipFromGithubZipball(): Promise<Uint8Array> {
  const res = await fetchFresh(ADDON_GITHUB_ZIPBALL_URL);
  if (!res.ok) {
    throw new Error(`GitHub zipball failed: ${res.status}`);
  }

  const repoZip = await JSZip.loadAsync(await res.arrayBuffer());
  const out = new JSZip();
  const marker = `/${ADDON_FOLDER_NAME}/`;

  for (const [path, file] of Object.entries(repoZip.files)) {
    if (file.dir) continue;
    const normalized = path.replaceAll("\\", "/");
    const idx = normalized.indexOf(marker);
    if (idx === -1) continue;
    const relative = normalized.slice(idx + 1);
    if (!relative.startsWith(`${ADDON_FOLDER_NAME}/`) || relative.includes("..")) {
      continue;
    }
    out.file(relative, await file.async("uint8array"));
  }

  if (Object.keys(out.files).filter((name) => !out.files[name]?.dir).length === 0) {
    throw new Error("Addon folder missing from GitHub zipball");
  }

  return out.generateAsync({
    type: "uint8array",
    compression: "DEFLATE",
    compressionOptions: { level: 9 },
  });
}

async function zipFromRawFiles(): Promise<Uint8Array> {
  const out = new JSZip();
  const results = await Promise.all(
    ADDON_TOC_FILES.map(async (name) => {
      const res = await fetchFresh(`${ADDON_RAW_BASE}/${name}`);
      if (!res.ok) {
        throw new Error(`Failed to fetch ${name} (${res.status})`);
      }
      return { name, data: new Uint8Array(await res.arrayBuffer()) };
    }),
  );

  for (const { name, data } of results) {
    out.file(`${ADDON_FOLDER_NAME}/${name}`, data);
  }

  return out.generateAsync({
    type: "uint8array",
    compression: "DEFLATE",
    compressionOptions: { level: 9 },
  });
}
