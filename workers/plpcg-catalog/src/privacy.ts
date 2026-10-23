export function handlePrivacyPolicy(): Response {
  const html = `<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Política de Privacidade — PLPCG</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      line-height: 1.6;
      color: #1f2937;
      max-width: 760px;
      margin: 0 auto;
      padding: 2rem 1.5rem;
      background: #f9fafb;
    }
    .card {
      background: #ffffff;
      border-radius: 12px;
      padding: 2.5rem;
      box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.05), 0 2px 4px -1px rgba(0, 0, 0, 0.03);
    }
    h1 {
      font-size: 1.875rem;
      color: #111827;
      margin-top: 0;
    }
    h2 {
      font-size: 1.25rem;
      color: #1f2937;
      margin-top: 1.75rem;
      border-bottom: 1px solid #e5e7eb;
      padding-bottom: 0.5rem;
    }
    p, li {
      color: #4b5563;
      font-size: 0.975rem;
    }
    ul {
      padding-left: 1.25rem;
    }
    .footer {
      margin-top: 2rem;
      font-size: 0.85rem;
      color: #9ca3af;
      text-align: center;
    }
  </style>
</head>
<body>
  <div class="card">
    <h1>Política de Privacidade — PLPCG</h1>
    <p>Última atualização: Outubro de 2026</p>

    <p>O aplicativo <strong>PLPCG</strong> (Pesquisador de Louvores em Partitura, Cifra e Gestos) tem o compromisso de proteger a privacidade e a segurança das informações dos seus usuários.</p>

    <h2>1. Informações que Coletamos</h2>
    <p>Para proporcionar o funcionamento das funcionalidades de sincronização, coletamos apenas os dados essenciais fornecidos com o seu consentimento:</p>
    <ul>
      <li><strong>Autenticação com o Google:</strong> Quando você escolhe entrar com sua conta Google, recebemos seu identificador único, nome e endereço de e-mail para autenticar sua sessão e vincular suas preferências e playlists salvas.</li>
      <li><strong>Dados de Uso e Preferências:</strong> Playlists personalizadas, anotações de louvores e marcadores salvos para uso local e sincronização entre seus dispositivos.</li>
    </ul>

    <h2>2. Como Usamos as Informações</h2>
    <ul>
      <li>Identificar sua conta e sincronizar suas playlists entre dispositivos.</li>
      <li>Garantir o funcionamento seguro e estável dos serviços do aplicativo.</li>
      <li><strong>Não vendemos, não alugamos e não compartilhamos seus dados pessoais com terceiros para fins publicitários.</strong></li>
    </ul>

    <h2>3. Armazenamento e Segurança</h2>
    <p>Seus dados são transmitidos utilizando criptografia padrão de mercado (HTTPS/TLS) e armazenados de maneira segura em infraestrutura de nuvem protegida.</p>

    <h2>4. Exclusão de Dados</h2>
    <p>Você pode solicitar a exclusão de seus dados ou revogar o acesso da sua conta Google a qualquer momento nas configurações do aplicativo ou entrando em contato pelo e-mail de suporte.</p>

    <h2>5. Contato</h2>
    <p>Em caso de dúvidas sobre esta Política de Privacidade, entre em contato através do e-mail: <strong>contato@plpcg.com</strong>.</p>
  </div>
  <div class="footer">
    © 2026 PLPCG. Todos os direitos reservados.
  </div>
</body>
</html>`;

  return new Response(html, {
    status: 200,
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'public, max-age=3600',
    },
  });
}
