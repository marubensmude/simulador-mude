# Simulador Mude · Mude Imóveis

Plataforma interna de simulação de financiamento imobiliário para a equipe de corretores da Mude Imóveis.

O que ela faz: enquadra o cliente automaticamente no programa mais vantajoso (MCMV Faixas 1 a 4, Pró-Cotista FGTS ou SBPE), calcula a primeira parcela com seguros e tarifa, informa a renda mínima pela regra dos 30%, compara as instituições lado a lado (Caixa, BB, Itaú, Bradesco, Santander, Inter e Sicredi), estima os custos de aquisição em Dourados-MS e salva cada simulação no histórico. Cada corretor acessa com login e senha e enxerga apenas as próprias simulações; o administrador enxerga tudo, aprova novos corretores e mantém a tabela de taxas.

## Arquitetura

| Peça | Onde roda | Custo |
|---|---|---|
| Páginas do sistema (este repositório) | GitHub Pages | gratuito |
| Logins, corretores, taxas e simulações | Supabase (banco de dados na nuvem) | gratuito no plano inicial |
| Robô de verificação de taxas | GitHub Actions (toda segunda, 8h de MS) | gratuito |

As senhas são gerenciadas pelo Supabase (criptografadas; o sistema nunca vê a senha). As regras de acesso ficam no banco de dados, então mesmo alguém lendo o código não consegue ver simulações de outros corretores.

## Instalação (uma única vez, ~30 minutos)

### Parte 1: GitHub

1. Crie uma conta em https://github.com (se ainda não tiver).
2. Crie um repositório novo, público, com o nome `simulador-mude`.
3. Envie todos os arquivos desta pasta para o repositório (botão "Add file > Upload files", arraste a pasta inteira, inclusive as pastas `supabase`, `scripts`, `data` e `.github`).
4. Em **Settings > Pages**, na seção "Build and deployment", escolha "Deploy from a branch", branch `main`, pasta `/ (root)` e salve.
5. Em alguns minutos o sistema estará no ar em `https://SEU-USUARIO.github.io/simulador-mude/`. Nesse primeiro momento ele abre em modo demonstração.

### Parte 2: Supabase (banco de dados e logins)

6. Crie uma conta em https://supabase.com e um projeto novo (região South America / São Paulo). Guarde a senha do banco em local seguro.
7. No menu lateral, abra **SQL Editor**, cole todo o conteúdo do arquivo `supabase/schema.sql` e clique em "Run". Isso cria as tabelas, as regras de acesso e a tabela de taxas inicial.
8. Em **Authentication > Sign In / Up > Email**, desative a opção "Confirm email" (o controle de acesso será feito pela sua aprovação, não por e-mail de confirmação).
9. Em **Settings > API**, copie a "Project URL" e a chave "anon public".

### Parte 3: Conectar as duas pontas

10. No GitHub, abra o arquivo `index.html`, clique no lápis (editar) e preencha as duas linhas do topo do bloco de configuração:
    ```js
    const SUPABASE_URL      = "https://SEU-PROJETO.supabase.co";
    const SUPABASE_ANON_KEY = "sua-chave-anon";
    ```
    Salve (Commit). Essa chave "anon" é pública por natureza; a segurança vem das regras do banco.
11. Abra o sistema no navegador, clique em "Criar conta" e cadastre-se com o e-mail mario@mudeimobiliaria.com.br.
12. Volte ao SQL Editor do Supabase e execute:
    ```sql
    update public.profiles set role='admin', approved=true
     where email='mario@mudeimobiliaria.com.br';
    ```
13. Entre novamente no sistema: a aba **Administração** estará disponível. Pronto.

### Rotina do dia a dia

- **Corretores:** acessam a URL, criam a própria conta e aguardam. Você aprova em Administração > Equipe de corretores. Cada um vê somente as próprias simulações.
- **Taxas:** atualize em Administração > Tabela de taxas (leva minutos). A data da última atualização aparece em todas as simulações.
- **Robô de taxas:** roda sozinho toda segunda-feira às 8h (horário de MS) e, quando detectar número diferente nos sites monitorados, abre um alerta na aba **Issues** do repositório. Para receber por e-mail, clique em "Watch" no repositório. Para rodar na hora: aba Actions > "Verificar taxas dos bancos" > Run workflow. Após confirmar uma mudança e atualizar o painel, atualize também `data/taxas_referencia.json` para silenciar o alerta.
- **Parâmetros locais** (ITBI, cartório, tetos do MCMV, tarifa): editáveis no bloco `PARAM` no topo do `index.html`.

## Avisos importantes

- Os sites dos bancos mudam de layout e podem bloquear robôs; o verificador é um apoio, não uma garantia. A palavra final sobre taxas é sempre do painel administrativo, alimentado por você.
- A simulação é uma curadoria comercial da Mude Imóveis: orienta o cliente e qualifica o atendimento, mas não substitui a análise de crédito da instituição financeira.
- Tetos e faixas vigentes em agosto/2026 (Portaria MCID 333/2026; teto SFH de R$ 2,25 milhões). Revisite o bloco `PARAM` quando o governo atualizar o programa.

---

Mude Imóveis · Mude que a Gente te Acompanha.
