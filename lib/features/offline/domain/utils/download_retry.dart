/// Retentativa de download — a implementação vive no core.
///
/// `RetryInterceptor` (core) precisa do mesmo veredito de "falha transitória"
/// e não pode importar `features/`. Este arquivo continua existindo porque os
/// chamadores offline já o importam pelo caminho de domínio.
library;

export '../../../../core/network/download_retry.dart'
    show isRetryableDioException, retryDelayForAttempt;
