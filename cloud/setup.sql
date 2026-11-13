-- 目標達成マネージャー（サーバー版）の設定
-- Supabase の「SQL Editor」に全部貼り付けて「Run」を押してください。何回実行しても大丈夫です。

-- 店舗
create table if not exists public.shops (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  code text not null unique,            -- スタッフが参加するときの店舗コード
  cfg jsonb,                            -- 店長が配った設定（項目・種類・ポイント・足切り）
  cfg_at timestamptz,
  created_at timestamptz not null default now()
);

-- 店舗のメンバー（ログインした人1人につき1行）
create table if not exists public.members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  shop_id uuid not null references public.shops(id) on delete cascade,
  name text not null,
  role text not null default 'staff' check (role in ('staff','manager')),
  created_at timestamptz not null default now()
);

-- 各メンバーのアプリのデータ（実績・設定など）
create table if not exists public.states (
  user_id uuid primary key references auth.users(id) on delete cascade,
  shop_id uuid not null references public.shops(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.shops   enable row level security;
alter table public.members enable row level security;
alter table public.states  enable row level security;

-- 自分の店舗・役割を調べる関数
create or replace function public.my_shop() returns uuid
language sql stable security definer set search_path = public as
$$ select shop_id from public.members where user_id = auth.uid() $$;

create or replace function public.my_role() returns text
language sql stable security definer set search_path = public as
$$ select role from public.members where user_id = auth.uid() $$;

-- 見られる範囲のルール
drop policy if exists shops_read on public.shops;
create policy shops_read on public.shops for select to authenticated using (id = public.my_shop());

drop policy if exists members_read on public.members;
create policy members_read on public.members for select to authenticated using (shop_id = public.my_shop());

drop policy if exists states_read on public.states;
create policy states_read on public.states for select to authenticated
  using (user_id = auth.uid() or (public.my_role() = 'manager' and shop_id = public.my_shop()));

drop policy if exists states_insert on public.states;
create policy states_insert on public.states for insert to authenticated
  with check (user_id = auth.uid() and shop_id = public.my_shop());

drop policy if exists states_update on public.states;
create policy states_update on public.states for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid() and shop_id = public.my_shop());

-- 店舗を作る（作った人が店長になる）
create or replace function public.create_shop(shop_name text, member_name text) returns text
language plpgsql security definer set search_path = public as $$
declare new_code text; sid uuid;
begin
  if auth.uid() is null then raise exception 'not_logged_in'; end if;
  if exists (select 1 from members where user_id = auth.uid()) then raise exception 'already_member'; end if;
  loop
    new_code := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
    exit when not exists (select 1 from shops where code = new_code);
  end loop;
  insert into shops(name, code) values (coalesce(nullif(trim(shop_name), ''), 'お店'), new_code) returning id into sid;
  insert into members(user_id, shop_id, name, role) values (auth.uid(), sid, trim(member_name), 'manager');
  return new_code;
end $$;

-- 店舗コードで参加する（スタッフとして）
create or replace function public.join_shop(shop_code text, member_name text) returns text
language plpgsql security definer set search_path = public as $$
declare sid uuid; sname text;
begin
  if auth.uid() is null then raise exception 'not_logged_in'; end if;
  if exists (select 1 from members where user_id = auth.uid()) then raise exception 'already_member'; end if;
  select id, name into sid, sname from shops where code = upper(trim(shop_code));
  if sid is null then raise exception 'bad_code'; end if;
  insert into members(user_id, shop_id, name, role) values (auth.uid(), sid, trim(member_name), 'staff');
  return sname;
end $$;

-- 自分の名前を変える
create or replace function public.set_my_name(new_name text) returns void
language sql security definer set search_path = public as
$$ update members set name = trim(new_name) where user_id = auth.uid() and trim(new_name) <> '' $$;

-- 店長：設定を店舗全員に配る
create or replace function public.share_cfg(new_cfg jsonb) returns void
language plpgsql security definer set search_path = public as $$
begin
  if public.my_role() <> 'manager' then raise exception 'not_manager'; end if;
  update shops set cfg = new_cfg, cfg_at = now() where id = public.my_shop();
end $$;

-- 店長：メンバーの役割を変える・外す
create or replace function public.set_member_role(target uuid, new_role text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if public.my_role() <> 'manager' then raise exception 'not_manager'; end if;
  if new_role not in ('staff','manager') then raise exception 'bad_role'; end if;
  if target = auth.uid() and new_role = 'staff'
     and (select count(*) from members where shop_id = public.my_shop() and role = 'manager') <= 1 then
    raise exception 'last_manager';
  end if;
  update members set role = new_role where user_id = target and shop_id = public.my_shop();
end $$;

create or replace function public.remove_member(target uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if public.my_role() <> 'manager' then raise exception 'not_manager'; end if;
  if target = auth.uid() then raise exception 'self'; end if;
  delete from states  where user_id = target and shop_id = public.my_shop();
  delete from members where user_id = target and shop_id = public.my_shop();
end $$;

-- 外から直接は呼べないようにして、ログインした人だけに許可
revoke all on function public.create_shop(text,text), public.join_shop(text,text), public.set_my_name(text),
  public.share_cfg(jsonb), public.set_member_role(uuid,text), public.remove_member(uuid),
  public.my_shop(), public.my_role() from public, anon;
grant execute on function public.create_shop(text,text), public.join_shop(text,text), public.set_my_name(text),
  public.share_cfg(jsonb), public.set_member_role(uuid,text), public.remove_member(uuid),
  public.my_shop(), public.my_role() to authenticated;

-- 店長の画面に自動で反映するため（リアルタイム通知）
do $$ begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'states') then
    execute 'alter publication supabase_realtime add table public.states';
  end if;
end $$;
