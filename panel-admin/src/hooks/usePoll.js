// Hook custom pour rafraîchir des données à intervalle régulier.
//
// Particularités :
// - Pause automatiquement quand l'onglet passe en background (économise les requêtes)
// - Refetch immédiatement au retour sur l'onglet (refetchOnFocus)
// - Annule les requêtes en vol si le component démonte
// - Retourne { data, error, isLoading, isRefreshing, lastUpdate, refetch }

import { useCallback, useEffect, useRef, useState } from 'react';

export function usePoll(fetchFn, deps = [], { interval = 15000, enabled = true } = {}) {
  const [data, setData] = useState(null);
  const [error, setError] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [lastUpdate, setLastUpdate] = useState(null);

  // Ref pour cancel les requêtes en flight quand un nouveau fetch démarre
  const cancelRef = useRef(false);
  // Ref vers fetchFn pour éviter de recréer l'intervalle si la fonction est inline
  const fetchFnRef = useRef(fetchFn);
  fetchFnRef.current = fetchFn;

  const doFetch = useCallback(async ({ silent = false } = {}) => {
    if (!enabled) return;
    if (!silent) setIsRefreshing(true);
    setError(null);
    cancelRef.current = false;
    try {
      const result = await fetchFnRef.current();
      if (cancelRef.current) return;
      setData(result);
      setLastUpdate(Date.now());
    } catch (err) {
      if (cancelRef.current) return;
      setError(err);
    } finally {
      if (!cancelRef.current) {
        setIsLoading(false);
        setIsRefreshing(false);
      }
    }
  }, [enabled]);

  // Fetch initial + à chaque changement de deps
  useEffect(() => {
    setIsLoading(true);
    doFetch();
    return () => { cancelRef.current = true; };
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
