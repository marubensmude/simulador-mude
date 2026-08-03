-- ============================================================
-- SIMULADOR MUDE · Mude Imóveis
-- Esquema do banco de dados (Supabase / PostgreSQL)
-- Execute este arquivo inteiro no SQL Editor do Supabase.
-- ============================================================

-- ---------- 1. PERFIS (corretores e administrador) ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nome text,
  email text,
  role text not null default 'corretor',       -- 'corretor' ou 'admin'
  approved boolean not null default false,     -- acesso liberado pelo admin
  created_at timestamptz not null default now()
);

-- Cria o perfil automaticamente quando alguém se cadastra
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, nome, email)
  values (new.id, new.raw_user_meta_data->>'nome', new.email);
  return new;
end; $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Funções auxiliares (security definer para evitar recursão nas regras)
create or replace function public.is_admin()
returns boolean language sql security definer stable set search_path = public as $$
  select exists(select 1 from public.profiles
                where id = auth.uid() and role = 'admin' and approved);
$$;

create or replace function public.is_approved()
returns boolean language sql security definer stable set search_path = public as $$
  select exists(select 1 from public.profiles
                where id = auth.uid() and approved);
$$;

alter table public.profiles enable row level security;

drop policy if exists "perfil: ver o proprio ou admin ve todos" on public.profiles;
create policy "perfil: ver o proprio ou admin ve todos"
  on public.profiles for select
  using (id = auth.uid() or public.is_admin());

drop policy if exists "perfil: admin aprova e edita" on public.profiles;
create policy "perfil: admin aprova e edita"
  on public.profiles for update
  using (public.is_admin());

-- ---------- 2. TAXAS (tabela que alimenta as simulações) ----------
create table if not exists public.taxas (
  id bigint generated always as identity primary key,
  instituicao text not null,
  linha text not null,
  taxa_aa numeric(6,2) not null,
  correcao text not null default 'TR',
  cota_max numeric(5,2) not null default 80,
  prazo_max_meses int not null default 420,
  obs text,
  mcmv_faixa text,          -- 'f1'..'f4' quando for linha do MCMV
  procotista boolean not null default false,
  atualizado_em timestamptz not null default now(),
  unique (instituicao, linha)
);

alter table public.taxas enable row level security;

drop policy if exists "taxas: equipe aprovada consulta" on public.taxas;
create policy "taxas: equipe aprovada consulta"
  on public.taxas for select using (public.is_approved());

drop policy if exists "taxas: somente admin altera" on public.taxas;
create policy "taxas: somente admin altera"
  on public.taxas for all
  using (public.is_admin()) with check (public.is_admin());

-- ---------- 3. SIMULAÇÕES (histórico por corretor) ----------
create table if not exists public.simulacoes (
  id bigint generated always as identity primary key,
  user_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  cliente_nome text,
  cliente_contato text,
  dados jsonb not null,
  created_at timestamptz not null default now()
);

create index if not exists simulacoes_user_idx on public.simulacoes (user_id, created_at desc);

alter table public.simulacoes enable row level security;

drop policy if exists "sim: corretor salva as suas" on public.simulacoes;
create policy "sim: corretor salva as suas"
  on public.simulacoes for insert
  with check (user_id = auth.uid() and public.is_approved());

drop policy if exists "sim: corretor ve as suas, admin ve todas" on public.simulacoes;
create policy "sim: corretor ve as suas, admin ve todas"
  on public.simulacoes for select
  using (user_id = auth.uid() or public.is_admin());

drop policy if exists "sim: excluir as suas ou admin" on public.simulacoes;
create policy "sim: excluir as suas ou admin"
  on public.simulacoes for delete
  using (user_id = auth.uid() or public.is_admin());

-- ---------- 4. TAXAS INICIAIS (levantamento de 03/08/2026) ----------
insert into public.taxas (instituicao, linha, taxa_aa, correcao, cota_max, prazo_max_meses, obs, mcmv_faixa, procotista) values
('Caixa','MCMV Faixa 1',4.50,'TR',80,420,'Renda até R$ 3.200 · imóvel até R$ 275 mil · subsídio até R$ 55 mil','f1',false),
('Caixa','MCMV Faixa 2',5.50,'TR',80,420,'Renda até R$ 5.000 · imóvel até R$ 275 mil · subsídio parcial','f2',false),
('Caixa','MCMV Faixa 3',8.16,'TR',80,420,'Renda até R$ 9.600 · imóvel até R$ 400 mil','f3',false),
('Caixa','MCMV Faixa 4',10.50,'fixa',80,420,'Renda até R$ 13.000 · imóvel até R$ 600 mil · usados: 80% de cota no Centro-Oeste','f4',false),
('Caixa','Pró-Cotista FGTS',9.01,'TR',80,420,'Exige 3+ anos de FGTS e vínculo ativo · sujeito a orçamento anual',null,true),
('BB','Pró-Cotista FGTS',9.00,'TR',80,360,'Exige 3+ anos de FGTS · imóvel novo 80%, usado 50%',null,true),
('Caixa','SBPE',11.19,'TR',80,420,'Com relacionamento (débito em conta + conta-salário); balcão 11,49%',null,false),
('Caixa','SBPE Poupança',10.76,'Poupança',80,420,'Poupança (6,17%) + 4,59% · estimativa efetiva',null,false),
('BB','SBPE',11.60,'TR',80,420,'Balcão; redução p/ conta-salário',null,false),
('Itaú','SBPE',11.70,'TR',90,420,'Resposta de crédito em até 1h (até R$ 1,5 mi) · Pula Parcela 2x/ano',null,false),
('Bradesco','SBPE',11.70,'TR',80,420,'Comprometimento publicado: 30% SAC / 15% Price · financia 5% de custas',null,false),
('Santander','SBPE',11.69,'TR',80,420,'Campanha 6,99% nos 12 primeiros meses c/ relacionamento completo · mín. R$ 90 mil',null,false),
('Inter','SBPE',13.76,'TR',75,360,'Balcão (radar); site anuncia 9,40% bonificada — confirmar em simulação real',null,false),
('Sicredi','SBPE',10.33,'TR',90,420,'Média efetiva BCB; sem tabela pública — confirmar na Sicredi Centro-Sul MS/BA · exige associação',null,false)
on conflict (instituicao, linha) do nothing;

-- ============================================================
-- 5. DEPOIS DE CRIAR SUA PRÓPRIA CONTA NO APLICATIVO,
--    execute a linha abaixo para se tornar administrador:
--
-- update public.profiles set role='admin', approved=true
--  where email='mario@mudeimobiliaria.com.br';
-- ============================================================
