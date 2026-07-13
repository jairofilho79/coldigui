export type PublicationReach = 'pontual' | 'usual';
export type PublicationCategory =
  | 'evangelizacao'
  | 'aprendizado'
  | 'medleys'
  | 'cultoEspecial';

const REACHES: ReadonlySet<string> = new Set(['pontual', 'usual']);
const CATEGORIES: ReadonlySet<string> = new Set([
  'evangelizacao',
  'aprendizado',
  'medleys',
  'cultoEspecial',
]);

export function isPublicationReach(value: unknown): value is PublicationReach {
  return typeof value === 'string' && REACHES.has(value);
}

export function isPublicationCategory(
  value: unknown,
): value is PublicationCategory {
  return typeof value === 'string' && CATEGORIES.has(value);
}

export interface PublicationInput {
  isPublished?: unknown;
  publicationReach?: unknown;
  publicationCategory?: unknown;
}

export interface ExistingPublication {
  is_published: number;
  publication_reach: string | null;
  publication_category: string | null;
  published_at: string | null;
}

/** Valida transição de publicação. Retorna mensagem de erro ou null. */
export function validatePublication(
  existing: ExistingPublication | null,
  body: PublicationInput,
): string | null {
  const wantsPublish = body.isPublished === true;
  const alreadyPublished = (existing?.is_published ?? 0) === 1;

  if (alreadyPublished) {
    if (body.isPublished === false) {
      return 'cannot unpublish';
    }
    if (
      body.publicationReach !== undefined &&
      body.publicationReach !== existing?.publication_reach
    ) {
      return 'publicationReach immutable';
    }
    if (
      body.publicationCategory !== undefined &&
      body.publicationCategory !== existing?.publication_category
    ) {
      return 'publicationCategory immutable';
    }
    return null;
  }

  if (!wantsPublish) {
    if (
      body.publicationReach != null ||
      body.publicationCategory != null
    ) {
      return 'publication metadata requires isPublished';
    }
    return null;
  }

  if (!isPublicationCategory(body.publicationCategory)) {
    return 'publicationCategory required';
  }
  if (
    body.publicationReach != null &&
    !isPublicationReach(body.publicationReach)
  ) {
    return 'invalid publicationReach';
  }
  return null;
}

export function resolvePublicationFields(
  existing: ExistingPublication | null,
  body: PublicationInput,
): {
  isPublished: number;
  publicationReach: PublicationReach | null;
  publicationCategory: PublicationCategory | null;
  publishedAt: string | null;
  newlyPublished: boolean;
} {
  const alreadyPublished = (existing?.is_published ?? 0) === 1;
  if (alreadyPublished) {
    return {
      isPublished: 1,
      publicationReach: existing!.publication_reach as PublicationReach,
      publicationCategory:
        existing!.publication_category as PublicationCategory,
      publishedAt: existing!.published_at,
      newlyPublished: false,
    };
  }

  if (body.isPublished === true) {
    const reach: PublicationReach = isPublicationReach(body.publicationReach)
      ? body.publicationReach
      : 'usual';
    return {
      isPublished: 1,
      publicationReach: reach,
      publicationCategory: body.publicationCategory as PublicationCategory,
      publishedAt: null, // caller sets now
      newlyPublished: true,
    };
  }

  return {
    isPublished: 0,
    publicationReach: null,
    publicationCategory: null,
    publishedAt: null,
    newlyPublished: false,
  };
}
