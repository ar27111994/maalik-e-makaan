/** A small seeded pseudo-random generator (mulberry32) so property tests are reproducible. */
export function mulberry32(seed: number) {
  let state = seed >>> 0;
  const next = () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 2 ** 32;
  };
  return {
    /** A uniformly distributed integer in [0, max). */
    int(max: number): number {
      return Math.floor(next() * max);
    },
  };
}
