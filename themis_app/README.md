# Themis - App Flutter

Este é o aplicativo Themis desenvolvido em Flutter.

## Arquitetura

O projeto foi dividido em:
- /lib/components/pages: Telas simples da aplicacao (AuthPage, DashboardPage, SettingsPage).
- /lib/hooks: Regras de estado e fluxo de autenticacao (useAuthController, useAuthFormController).
- /lib/components/ui: Widgets reutilizaveis de interface.
- /lib/data: Servicos e dados (incluindo integracao com API de autenticacao).

## Como rodar o projeto

Caso voce queira rodar o aplicativo agora, basta abrir uma janela de terminal nesta mesma pasta (themis_app) e executar:

```
cd themis_app
```

```
flutter run -d windows
```

## Configuracao de autenticacao

1. Confira o arquivo `.env` na raiz do projeto com a URL da API:

```env
AUTH_API_BASE_URL=https://auth.skytrack.space
```

2. Se quiser recriar o arquivo localmente, use `.env.example` como base.

## Endpoints usados

- `POST /auth/login`
- `POST /auth/logout`
- `GET /auth/profile`
- `POST /users/register` (cadastro, role fixo `USER`)




