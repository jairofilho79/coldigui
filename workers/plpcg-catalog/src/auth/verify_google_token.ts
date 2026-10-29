import { createRemoteJWKSet, jwtVerify } from 'jose';

const GOOGLE_ISSUERS = new Set([
  'https://accounts.google.com',
  'accounts.google.com',
]);

const JWKS_URL = new URL('https://www.googleapis.com/oauth2/v3/certs');

// Cache JWKS across requests in the isolate (jose remote JWK set already caches).
const googleJwks = createRemoteJWKSet(JWKS_URL);

export interface GoogleClaims {
  sub: string;
  email?: string;
  name?: string;
  picture?: string;
}

function asString(value: unknown): string | undefined {
  return typeof value === 'string' && value.length > 0 ? value : undefined;
}

export async function verifyGoogleIdToken(
  token: string,
  clientId: string,
): Promise<GoogleClaims> {
  const { payload } = await jwtVerify(token, googleJwks, {
    audience: clientId,
    clockTolerance: 60,
  });

  const iss = asString(payload.iss);
  if (!iss || !GOOGLE_ISSUERS.has(iss)) {
    throw new Error('invalid_issuer');
  }

  const sub = asString(payload.sub);
  if (!sub) {
    throw new Error('missing_sub');
  }

  return {
    sub,
    email: asString(payload.email),
    name: asString(payload.name),
    picture: asString(payload.picture),
  };
}
