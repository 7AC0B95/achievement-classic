"use client";

import { get, set, del } from "idb-keyval";
import { useCallback, useEffect, useState } from "react";
import { syncCharacterFromAddon, type SyncResult } from "@/actions/sync";
import { parseClassicGloryDB } from "@/lib/lua-parser";
import type { ParsedCharacterBundle, ParsedClassicGloryDB } from "@/lib/types";

const FILE_HANDLE_KEY = "classic-glory:achievements-file-handle";
const LAST_LUA_TEXT_KEY = "classic-glory:last-lua-text";
const LAST_LUA_NAME_KEY = "classic-glory:last-lua-name";

export type WowSyncStatus =
  | "idle"
  | "connecting"
  | "connected"
  | "reading"
  | "syncing"
  | "error";

export type WowSyncSource = "none" | "upload" | "handle";

interface UseWowSyncState {
  status: WowSyncStatus;
  source: WowSyncSource;
  fileName: string | null;
  parsed: ParsedClassicGloryDB | null;
  lastSyncedAt: Date | null;
  error: string | null;
  syncMessage: string | null;
  canPersistHandle: boolean;
}

async function verifyPermission(
  handle: FileSystemFileHandle,
  mode: "read" | "readwrite" = "read",
): Promise<boolean> {
  const opts = { mode };
  if ((await handle.queryPermission(opts)) === "granted") return true;
  if ((await handle.requestPermission(opts)) === "granted") return true;
  return false;
}

async function readHandleText(handle: FileSystemFileHandle): Promise<string> {
  const allowed = await verifyPermission(handle, "read");
  if (!allowed) {
    throw new Error("File permission denied. Re-link the SavedVariables file.");
  }
  const file = await handle.getFile();
  return file.text();
}

async function cacheUploadedLua(fileName: string, text: string) {
  await set(LAST_LUA_TEXT_KEY, text);
  await set(LAST_LUA_NAME_KEY, fileName);
  await del(FILE_HANDLE_KEY);
}

export function useWowSync() {
  const [state, setState] = useState<UseWowSyncState>({
    status: "idle",
    source: "none",
    fileName: null,
    parsed: null,
    lastSyncedAt: null,
    error: null,
    syncMessage: null,
    canPersistHandle: false,
  });

  useEffect(() => {
    const canPersistHandle =
      typeof window !== "undefined" && "showOpenFilePicker" in window;
    setState((s) => ({ ...s, canPersistHandle }));

    (async () => {
      try {
        const handle = canPersistHandle
          ? await get<FileSystemFileHandle>(FILE_HANDLE_KEY)
          : undefined;
        if (handle) {
          const allowed = await verifyPermission(handle, "read");
          if (allowed) {
            setState((s) => ({
              ...s,
              status: "connected",
              source: "handle",
              fileName: handle.name,
              error: null,
            }));
            return;
          }
        }

        const cachedName = await get<string>(LAST_LUA_NAME_KEY);
        const cachedText = await get<string>(LAST_LUA_TEXT_KEY);
        if (cachedName && cachedText) {
          try {
            const parsed = parseClassicGloryDB(cachedText);
            setState((s) => ({
              ...s,
              status: "connected",
              source: "upload",
              fileName: cachedName,
              parsed,
              error: null,
            }));
          } catch {
            setState((s) => ({
              ...s,
              status: "connected",
              source: "upload",
              fileName: cachedName,
              error: null,
            }));
          }
        }
      } catch {
        // IndexedDB restore can fail in private mode — ignore.
      }
    })();
  }, []);

  const ingestLuaText = useCallback(
    async (fileName: string, text: string, source: WowSyncSource) => {
      setState((s) => ({
        ...s,
        status: "reading",
        error: null,
        syncMessage: null,
      }));
      const parsed = parseClassicGloryDB(text);
      setState((s) => ({
        ...s,
        status: "connected",
        source,
        fileName,
        parsed,
        error: null,
      }));
      return parsed;
    },
    [],
  );

  const uploadFile = useCallback(
    async (file: File): Promise<ParsedClassicGloryDB> => {
      if (!file.name.toLowerCase().endsWith(".lua")) {
        throw new Error("Please choose a .lua SavedVariables file.");
      }
      const text = await file.text();
      await cacheUploadedLua(file.name, text);
      return ingestLuaText(file.name, text, "upload");
    },
    [ingestLuaText],
  );

  const linkPersistentFile = useCallback(async () => {
    if (!("showOpenFilePicker" in window)) {
      setState((s) => ({
        ...s,
        status: "error",
        error:
          "Persistent file linking needs Chrome or Edge. Use Upload instead — it works from the WoW folder.",
      }));
      return;
    }

    setState((s) => ({ ...s, status: "connecting", error: null, syncMessage: null }));

    try {
      const [handle] = await window.showOpenFilePicker({
        multiple: false,
        types: [
          {
            description: "WoW SavedVariables Lua",
            accept: { "text/plain": [".lua"] },
          },
        ],
        excludeAcceptAllOption: false,
      });

      const text = await readHandleText(handle);
      await set(FILE_HANDLE_KEY, handle);
      await del(LAST_LUA_TEXT_KEY);
      await del(LAST_LUA_NAME_KEY);
      await ingestLuaText(handle.name, text, "handle");
    } catch (error) {
      if (error instanceof DOMException && error.name === "AbortError") {
        setState((s) => ({
          ...s,
          status: s.fileName ? "connected" : "idle",
        }));
        return;
      }

      const message =
        error instanceof Error ? error.message : "Failed to link file.";
      const looksBlocked =
        /system files|not allowed|permission|security/i.test(message) ||
        (error instanceof DOMException &&
          (error.name === "NotAllowedError" || error.name === "SecurityError"));

      setState((s) => ({
        ...s,
        status: "error",
        error: looksBlocked
          ? "Browsers block linking files inside the WoW / Program Files folder. Use Upload instead, or copy ClassicGlory.lua to Documents and link that copy."
          : message,
      }));
    }
  }, [ingestLuaText]);

  const disconnectFile = useCallback(async () => {
    await del(FILE_HANDLE_KEY);
    await del(LAST_LUA_TEXT_KEY);
    await del(LAST_LUA_NAME_KEY);
    setState({
      status: "idle",
      source: "none",
      fileName: null,
      parsed: null,
      lastSyncedAt: null,
      error: null,
      syncMessage: null,
      canPersistHandle:
        typeof window !== "undefined" && "showOpenFilePicker" in window,
    });
  }, []);

  const readAndParse = useCallback(async (): Promise<ParsedClassicGloryDB> => {
    setState((s) => ({ ...s, status: "reading", error: null }));

    const handle = await get<FileSystemFileHandle>(FILE_HANDLE_KEY);
    if (handle) {
      const text = await readHandleText(handle);
      return ingestLuaText(handle.name, text, "handle");
    }

    const cachedText = await get<string>(LAST_LUA_TEXT_KEY);
    const cachedName = await get<string>(LAST_LUA_NAME_KEY);
    if (cachedText && cachedName) {
      return ingestLuaText(cachedName, cachedText, "upload");
    }

    throw new Error("No SavedVariables file loaded. Upload ClassicGlory.lua first.");
  }, [ingestLuaText]);

  const syncBundle = useCallback(
    async (bundle: ParsedCharacterBundle): Promise<SyncResult> => {
      return syncCharacterFromAddon({
        character: bundle.character,
        completed: bundle.completed,
        stats: bundle.stats,
      });
    },
    [],
  );

  const syncCharacters = useCallback(
    async (bundles: ParsedCharacterBundle[]): Promise<SyncResult> => {
      if (bundles.length === 0) {
        return { ok: false, message: "No characters selected to sync." };
      }

      setState((s) => ({ ...s, status: "syncing", syncMessage: null, error: null }));

      const messages: string[] = [];
      let lastOk: SyncResult | null = null;

      for (const bundle of bundles) {
        const result = await syncBundle(bundle);
        if (!result.ok) {
          setState((s) => ({
            ...s,
            status: "error",
            error: result.message,
            syncMessage: null,
          }));
          return result;
        }
        messages.push(result.message);
        lastOk = result;
      }

      const message =
        bundles.length === 1
          ? messages[0]
          : `Synced ${bundles.length} characters successfully.`;

      setState((s) => ({
        ...s,
        status: "connected",
        lastSyncedAt: new Date(),
        syncMessage: message,
        error: null,
      }));

      return lastOk ?? { ok: true, characterId: "", totalPoints: 0, achievementCount: 0, message };
    },
    [syncBundle],
  );

  const uploadAndParse = useCallback(
    async (file: File): Promise<ParsedClassicGloryDB | null> => {
      try {
        return await uploadFile(file);
      } catch (error) {
        const message = error instanceof Error ? error.message : "Upload failed.";
        setState((s) => ({
          ...s,
          status: "error",
          error: message,
          syncMessage: null,
        }));
        return null;
      }
    },
    [uploadFile],
  );

  const fetchUpdates = useCallback(
    async (keys?: string[]): Promise<SyncResult> => {
      try {
        const handle = await get<FileSystemFileHandle>(FILE_HANDLE_KEY);
        let parsed: ParsedClassicGloryDB;
        if (handle) {
          const text = await readHandleText(handle);
          parsed = await ingestLuaText(handle.name, text, "handle");
        } else {
          parsed = await readAndParse();
        }

        const bundles =
          keys && keys.length > 0
            ? parsed.characters.filter((c) => keys.includes(c.key))
            : parsed.characters;

        return syncCharacters(bundles);
      } catch (error) {
        const message = error instanceof Error ? error.message : "Fetch failed.";
        setState((s) => ({
          ...s,
          status: "error",
          error: message,
          syncMessage: null,
        }));
        return { ok: false, message };
      }
    },
    [ingestLuaText, readAndParse, syncCharacters],
  );

  return {
    ...state,
    uploadFile,
    uploadAndParse,
    linkPersistentFile,
    disconnectFile,
    readAndParse,
    syncCharacters,
    fetchUpdates,
  };
}
