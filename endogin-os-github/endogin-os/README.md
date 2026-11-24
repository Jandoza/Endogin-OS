# Endogin OS

**Plataforma de gestão de mentoria médica** — portal do aluno, área de Customer Success e painel da diretoria, construída sobre Supabase e publicada no Netlify.

Desenvolvida por **Luiz Jandoza** para a Mentoria Endogin, substituindo planilhas e controles manuais por um sistema único que acompanha mais de 460 alunos, do primeiro acesso à renovação.

![Stack](https://img.shields.io/badge/Supabase-PostgreSQL-3ECF8E?logo=supabase&logoColor=white)
![Deno](https://img.shields.io/badge/Edge%20Functions-Deno%20%2F%20TypeScript-000?logo=deno)
![JS](https://img.shields.io/badge/Frontend-HTML%20%2B%20JavaScript-F7DF1E?logo=javascript&logoColor=black)
![Netlify](https://img.shields.io/badge/Deploy-Netlify-00C7B7?logo=netlify&logoColor=white)

---

## O problema

A operação da mentoria rodava em planilhas: carteira de alunos por CS, datas de entrada e vencimento, presença em aulas ao vivo, progresso nos cursos, pesquisas de NPS. Cada informação vivia num lugar, e a diretoria não tinha uma visão consolidada.

## A solução

Um sistema com **três áreas**, cada uma com seu nível de acesso, conectado às ferramentas que a empresa já usava (Cademi, Zoom, Google Forms).

### 🎓 Portal do Aluno
- Jornada do aluno (boas-vindas, perfil DISC, trilha, sessões 1x1)
- Calendário de aulas ao vivo e eventos com confirmação de presença (RSVP)
- Biblioteca de materiais e conteúdos
- Pesquisa de opinião / NPS
- Ficha de primeiro acesso

### 🤝 Área de Customer Success
- Carteira de alunos por CS (com CS de apoio), status e "temperatura" do aluno
- Dashboard, relatórios e exportação para Excel
- Progresso nos cursos sincronizado com a Cademi
- Presença nas aulas ao vivo puxada da API do Zoom
- Calendário, eventos, grupos, recados, feedbacks, aniversários e perfil DISC
- Busca de aulas no catálogo da área de membros

### 📊 Área da Diretoria
- Visão executiva: alunos ativos, em tratativa, trancados e encerrados
- Inadimplência, NPS e distribuição por mentoria e por CS
- Gestão de equipe e de materiais

---

## Arquitetura

```
┌──────────────────────┐        ┌───────────────────────────────┐
│  Frontend (Netlify)  │◄──────►│  Supabase                     │
│  HTML + JS + Chart.js│  Auth  │  • PostgreSQL + RLS (48 policies)
│  Portal · CS · Dir.  │  REST  │  • Funções SQL / RPC          │
└──────────────────────┘        │  • Storage (materiais)        │
                                │  • Edge Functions (Deno/TS)   │
                                └──────┬───────────┬────────────┘
                                       │           │
                     ┌─────────────────┘           └──────────────┐
                     ▼                                            ▼
           Cademi (webhooks + API)                     Zoom API · Google Forms · Resend
```

### Edge Functions (`supabase/functions/`)

| Função | O que faz |
|---|---|
| `cademi-webhook` | Recebe novos alunos e novas entregas da Cademi; distribui o aluno para o CS com menor carteira e gera o link de acesso |
| `cademi-sync-progress` | Puxa pela API o progresso que os alunos já tinham feito nos cursos |
| `cademi-sync-catalog` | Sincroniza o catálogo de produtos e aulas, respeitando o limite de requisições da API |
| `zoom-sync` | Baixa o relatório de participantes das aulas ao vivo e casa cada participante com um aluno |
| `forms-webhook` | Recebe respostas de formulários do Google (via Apps Script) |
| `admin-tools` | Criação, edição e remoção de logins pela equipe, com permissão de administrador |

### Banco de dados (`banco-de-dados/`)

Migrações SQL versionadas (v26 → v72), aplicadas em ordem crescente. Destaques:

- **Row Level Security** em todas as tabelas sensíveis: aluno só vê os próprios dados, CS vê sua carteira, diretoria vê tudo
- Funções `security definer` para operações controladas (ex.: checar e-mail no primeiro acesso)
- Índices para as consultas mais pesadas do painel
- Rotinas de conciliação entre a planilha legada e o banco

---

## Segurança e privacidade

- Nenhum segredo no código: as Edge Functions leem tudo de variáveis de ambiente (veja [`.env.example`](.env.example))
- A chave usada no frontend é a *publishable key* do Supabase, feita para ser pública; a proteção dos dados fica nas políticas de RLS
- Cabeçalhos de segurança HTTP no Netlify (HSTS, X-Frame-Options, nosniff, Permissions-Policy)
- Cloudflare Turnstile contra bots no login
- Webhooks autenticados por segredo compartilhado

> **Nota sobre os dados:** esta é uma versão pública para portfólio. As migrações que importavam dados reais de alunos foram **anonimizadas (LGPD)** — no lugar delas ficaram apenas linhas fictícias de exemplo, no mesmo formato.

---

## Como rodar

1. Crie um projeto no [Supabase](https://supabase.com) e aplique os arquivos de `banco-de-dados/` em ordem crescente de versão.
2. Configure os segredos das funções a partir do `.env.example`:
   ```bash
   supabase secrets set --env-file .env
   supabase functions deploy
   ```
3. Nos arquivos HTML de `frontend/`, troque `SUPABASE_URL` e `SUPABASE_ANON_KEY` pelos do seu projeto.
4. Publique a pasta `frontend/` no Netlify (o `netlify.toml` já faz o build e aplica os cabeçalhos).

## Estrutura

```
endogin-os/
├── frontend/            # Páginas (index, Portal do Aluno, Área CS, Diretoria, 404) + assets
├── banco-de-dados/      # Migrações SQL do Supabase (v26 a v72)
└── supabase/functions/  # Edge Functions em Deno/TypeScript
```

---

## Autor

**Luiz Jandoza** — [luizjandoza6@gmail.com](mailto:luizjandoza6@gmail.com)

© Mentoria Endogin. Código publicado para fins de portfólio; todos os direitos reservados.
