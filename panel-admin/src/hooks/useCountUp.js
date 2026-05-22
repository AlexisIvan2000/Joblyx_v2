import { useEffect, useRef, useState } from 'react';

// Anime une valeur numérique de 0 (ou previous) vers target via requestAnimationFrame
// duration en ms, easing par défaut easeOutQuart pour un effet premium

const DEFAULT_EASING = (t) => 1 - Math.pow(1 - t, 4);

export function useCountUp(target, { duration = 900, easing = DEFAULT_EASING } = {}) {
  const [value, setValue] = useState(typeof target === 'number' ? target : 0);
  const startRef = useRef(null);
  const fromRef = useRef(0);
  const rafRef = useRef(null);

  useEffect(() => {
    if (typeof target !== 'number' || Number.isNaN(target)) {
      setValue(target);
      return;
    }

    // Respect prefers-reduced-motion, on saute l'anim
    if (typeof window !== 'undefined'
        && window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      setValue(target);
      return;
    }

    fromRef.current = value;
    startRef.current = null;

    const tick = (now) => {
      if (startRef.current === null) startRef.current = now;
      const elapsed = now - startRef.current;
      const progress = Math.min(1, elapsed / duration);
      const eased = easing(progress);
      const current = fromRef.current + (target - fromRef.current) * eased;
      setValue(current);
      if (progress < 1) {
        rafRef.current = requestAnimationFrame(tick);
      } else {
        setValue(target);
      }
    };

    rafRef.current = requestAnimationFrame(tick);
    return () => {
      if (rafRef.current) cancelAnimationFrame(rafRef.current);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [target, duration]);

  return value;
}
