export async function withCache<T>(
  getter: () => Promise<T | null>,
  fetcher: () => Promise<T | null>,
  setter: (v: T) => Promise<void>,
): Promise<T | null> {
  const cached = await getter();
  if (cached) return cached;
  const data = await fetcher();
  if (data) await setter(data);
  return data;
}
