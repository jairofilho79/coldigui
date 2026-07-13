/** Handle público: 3–30 chars, a-z 0-9 _, sempre em minúsculas. */
const USERNAME_RE = /^[a-z0-9_]{3,30}$/;

export function normalizeUsername(raw: string): string {
  return raw.trim().toLowerCase();
}

/** Retorna mensagem de erro ou null se válido. */
export function validateUsername(raw: unknown): string | null {
  if (typeof raw !== 'string') return 'username required';
  const normalized = normalizeUsername(raw);
  if (normalized.length === 0) return 'username required';
  if (!USERNAME_RE.test(normalized)) {
    return 'invalid username';
  }
  return null;
}
