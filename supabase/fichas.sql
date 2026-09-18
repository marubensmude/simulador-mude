-- ============================================================
-- SIMULADOR MUDE · Mude Imóveis
-- FICHAS DE CLIENTES (link público de pré-simulação)
-- Execute este arquivo UMA VEZ no SQL Editor do Supabase,
-- depois do schema.sql. Pode ser executado de novo sem problema.
-- ============================================================

create table if not exists public.fichas (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  cliente_nome text not null,
  cliente_contato text not null,
  dados jsonb not null,
  status text not null default 'nova',          -- nova · em_atendimento · simulada · arquivada
  atendida_por uuid references public.profiles(id) on delete set null,
  atendida_por_nome text,
  atendida_em timestamptz,
  simulacao_id bigint references public.simulacoes(id) on delete set null,
  constraint fichas_status_ck check (status in ('nova','em_atendimento','simulada','arquivada')),
  constraint fichas_nome_ck check (char_length(cliente_nome) between 3 and 120 and cliente_nome !~ '[<>"`\\]'),
  constraint fichas_contato_ck check (char_length(cliente_contato) between 8 and 30 and cliente_contato !~ '[<>"`\\]'),
  constraint fichas_tamanho_ck check (pg_column_size(dados) < 16000)
);

alter table public.fichas add column if not exists atendida_por_nome text;

create index if not exists fichas_status_idx on public.fichas (status, created_at desc);

-- Freio contra envios repetidos (robôs ou clique duplo):
-- no máximo 3 fichas do mesmo WhatsApp em 10 minutos e 120 fichas por hora no total.
create or replace function public.fichas_limite()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from public.fichas
       where cliente_contato = new.cliente_contato
         and created_at > now() - interval '10 minutes') >= 3 then
    raise exception 'limite de envios atingido para este contato';
  end if;
  if (select count(*) from public.fichas where created_at > now() - interval '1 hour') >= 120 then
    raise exception 'limite geral de envios atingido';
  end if;
  return new;
end; $$;

drop trigger if exists fichas_limite_trg on public.fichas;
create trigger fichas_limite_trg before insert on public.fichas
  for each row execute function public.fichas_limite();

alter table public.fichas enable row level security;
grant insert on table public.fichas to anon;
grant select, insert, update, delete on table public.fichas to authenticated;

-- O cliente (sem login) só consegue CRIAR uma ficha nova; não lê, não altera, não apaga nada.
drop policy if exists "fichas: publico envia" on public.fichas;
create policy "fichas: publico envia"
  on public.fichas for insert to anon, authenticated
  with check (status = 'nova' and atendida_por is null and atendida_por_nome is null and simulacao_id is null);

-- Link único da Mude Imóveis: toda a equipe aprovada vê e atende as fichas.
drop policy if exists "fichas: equipe consulta" on public.fichas;
create policy "fichas: equipe consulta"
  on public.fichas for select to authenticated
  using (public.is_approved());

drop policy if exists "fichas: equipe atualiza" on public.fichas;
create policy "fichas: equipe atualiza"
  on public.fichas for update to authenticated
  using (public.is_approved()) with check (public.is_approved());

drop policy if exists "fichas: admin exclui" on public.fichas;
create policy "fichas: admin exclui"
  on public.fichas for delete to authenticated
  using (public.is_admin());
