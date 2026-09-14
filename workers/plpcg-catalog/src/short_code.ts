/**
 * Códigos curtos públicos: links de share (`short_links.code`) e salas ao
 * vivo (`live_rooms.code`). 7 caracteres `[a-z0-9]` via
 * `crypto.getRandomValues`. O enviesamento de `256 % 36` é aceitável — não é
 * segredo criptográfico, só um identificador não-adivinhável o bastante.
 */
const CODE_ALPHABET = 'abcdefghijklmnopqrstuvwxyz0123456789';
const CODE_LENGTH = 7;

export const SHORT_CODE_PATTERN = /^[a-z0-9]{7}$/;

export function randomShortCode(): string {
  const bytes = new Uint8Array(CODE_LENGTH);
  crypto.getRandomValues(bytes);
  let code = '';
  for (let i = 0; i < CODE_LENGTH; i++) {
    code += CODE_ALPHABET[bytes[i] % CODE_ALPHABET.length];
  }
  return code;
}

export function isShortCode(value: unknown): value is string {
  return typeof value === 'string' && SHORT_CODE_PATTERN.test(value);
}
