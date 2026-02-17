-- KakaoSDK login + Edge Function session/JWT architecture
-- NOTE: 이 마이그레이션은 기존에 users.id가 auth.users.id를 FK로 참조하던 구조를 끊기 위한 변경을 포함합니다.
--       프로젝트마다 FK constraint 이름이 달라질 수 있어, auth.users를 참조하는 FK는 동적으로 찾아 제거합니다.

-- 1) users: kakao_user_id 추가 + (가능하면) auth.users.id FK 제거
alter table if exists public.users
  add column if not exists kakao_user_id text;
-- public.users에서 auth.users를 참조하는 FK는 모두 제거
do $$
declare
  r record;
begin
  for r in
    select c.conname
    from pg_constraint c
    where c.conrelid = 'public.users'::regclass
      and c.contype = 'f'
      and c.confrelid = 'auth.users'::regclass
  loop
    execute format('alter table public.users drop constraint if exists %I', r.conname);
  end loop;
end $$;
-- unique index (NULL은 여러 개 가능: 기존 데이터가 있으면 먼저 backfill 후 NOT NULL로 강화)
create unique index if not exists users_kakao_user_id_key
  on public.users (kakao_user_id);
-- 2) refresh token rotation table
create table if not exists public.user_refresh_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  device_id text not null,
  token_hash text not null unique,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  revoked_at timestamptz null,
  replaced_by uuid null references public.user_refresh_tokens(id)
);
create index if not exists user_refresh_tokens_user_device_idx
  on public.user_refresh_tokens (user_id, device_id);
