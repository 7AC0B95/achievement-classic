"use client";

import { useCallback, useEffect, useState } from "react";

const RETRY_DELAYS_MS = [0, 500, 1200, 2500];

export function useRetryingQuery<T>({
  query,
  queryKey,
  initialData,
  isFilled,
}: {
  query: () => Promise<T>;
  queryKey: string;
  initialData?: T;
  isFilled: (data: T | undefined) => boolean;
}) {
  const [data, setData] = useState<T | undefined>(initialData);
  const [loading, setLoading] = useState(() => !isFilled(initialData));
  const [error, setError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);

  const retry = useCallback(() => {
    setError(null);
    setLoading(true);
    setNonce((value) => value + 1);
  }, []);

  useEffect(() => {
    let cancelled = false;
    const keepExistingOnFailure = isFilled(data);

    (async () => {
      let lastError: string | null = null;

      for (let index = 0; index < RETRY_DELAYS_MS.length; index += 1) {
        const delay = RETRY_DELAYS_MS[index];
        if (delay) {
          await new Promise((resolve) => setTimeout(resolve, delay));
        }
        if (cancelled) return;

        try {
          const result = await query();
          if (cancelled) return;
          setData(result);
          setLoading(false);
          setError(null);
          return;
        } catch (caught) {
          lastError =
            caught instanceof Error ? caught.message : "Failed to load";
        }
      }

      if (cancelled) return;
      setLoading(false);
      if (!keepExistingOnFailure) {
        setError(lastError ?? "Failed to load");
      }
    })();

    return () => {
      cancelled = true;
    };
    // `query` / `isFilled` / `data` are captured from the render that
    // changed `queryKey` or `nonce`. Including `data` would refetch in a loop.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [nonce, queryKey]);

  return {
    data,
    error,
    retry,
    loading,
    showPlaceholder: loading && !isFilled(data),
  };
}
