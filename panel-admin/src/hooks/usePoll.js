import { useCallback, useEffect, useRef, useState } from 'react';

export function usePoll(fetchFn, deps = [], { interval = 15000, enabled = true } = {}) {
  const [data, setData] = useState(null);
  const [error, setError] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [lastUpdate, setLastUpdate] = useState(null);

  const requestIdRef = useRef(0);
  
  const fetchFnRef = useRef(fetchFn);
  fetchFnRef.current = fetchFn;

  const doFetch = useCallback(async ({ silent = false } = {}) => {
    if (!enabled) return;
    const requestId = ++requestIdRef.current;
    if (!silent) setIsRefreshing(true);
    setError(null);
    try {
      const result = await fetchFnRef.current();
      if (requestId !== requestIdRef.current) return;
      setData(result);
      setLastUpdate(Date.now());
    } catch (err) {
      if (requestId !== requestIdRef.current) return;
      setError(err);
    } finally {
      if (requestId === requestIdRef.current) {
        setIsLoading(false);
        setIsRefreshing(false);
      }
    }
  }, [enabled]);

  // Fetch initial + à chaque changement de deps
  useEffect(() => {
    setIsLoading(true);
    doFetch();
    // Invalide toute requête en vol au démontage / changement de deps
    return () => { requestIdRef.current++; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, deps);

  // Polling — pause si onglet en background
  useEffect(() => {
    if (!enabled || !interval) return;

    let timerId = null;

    function tick() {
      // document.hidden est true quand l'onglet est en arrière-plan ou minimisé
      if (!document.hidden) {
        doFetch({ silent: true });
      }
    }

    timerId = setInterval(tick, interval);
    return () => { if (timerId) clearInterval(timerId); };
  }, [doFetch, interval, enabled]);

  // Refetch immédiat quand l'onglet redevient visible
  useEffect(() => {
    function handleVisibilityChange() {
      if (!document.hidden && enabled) {
        doFetch({ silent: true });
      }
    }
    document.addEventListener('visibilitychange', handleVisibilityChange);
    return () => document.removeEventListener('visibilitychange', handleVisibilityChange);
  }, [doFetch, enabled]);

  return {
    data,
    error,
    isLoading,
    isRefreshing,
    lastUpdate,
    refetch: () => doFetch(),
  };
}
