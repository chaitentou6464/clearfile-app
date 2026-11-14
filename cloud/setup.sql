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

-- 会社（本部）
create table if not exists public.orgs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  code text not null unique,            -- 本部の人が参加するときの本部コード
  created_at timestamptz not null default now()
);
create table if not exists public.hq_members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  org_id uuid not null references public.orgs(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now()
);
alter table public.shops add column if not exists org_id uuid references public.orgs(id) on delete set null;
alter table public.shops add column if not exists mgr_code text unique;  -- 店長が参加するときの店長コード
alter table public.orgs       enable row level security;
alter table public.hq_members enable row level security;

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

create or replace function public.my_org() returns uuid
language sql stable security definer set search_path = public as
$$ select org_id from public.hq_members where user_id = auth.uid() $$;

create or replace function public.my_shop_org() returns uuid
language sql stable security definer set search_path = public as
$$ select org_id from public.shops where id = public.my_shop() $$;

create or replace function public.hq_shop_ids() returns setof uuid
language sql stable security definer set search_path = public as
$$ select id from public.shops where org_id is not null and org_id = public.my_org() $$;

create or replace function public.new_code() returns text
language sql volatile as
$$ select upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10)) $$;

-- 見られる範囲のルール
drop policy if exists shops_read on public.shops;
create policy shops_read on public.shops for select to authenticated
  using (id = public.my_shop() or id in (select public.hq_shop_ids()));

drop policy if exists orgs_read on public.orgs;
create policy orgs_read on public.orgs for select to authenticated
  using (id = public.my_org() or id = public.my_shop_org());

drop policy if exists hq_read on public.hq_members;
create policy hq_read on public.hq_members for select to authenticated using (org_id = public.my_org());

drop policy if exists members_read on public.members;
create policy members_read on public.members for select to authenticated
  using (shop_id = public.my_shop() or shop_id in (select public.hq_shop_ids()));

drop policy if exists states_read on public.states;
create policy states_read on public.states for select to authenticated
  using (user_id = auth.uid() or (public.my_role() = 'manager' and shop_id = public.my_shop())
         or shop_id in (select public.hq_shop_ids()));

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
  if exists (select 1 from members where user_id = auth.uid()) or exists (select 1 from hq_members where user_id = auth.uid()) then raise exception 'already_member'; end if;
  if length(trim(member_name)) = 0 or length(member_name) > 30 or length(shop_name) > 40 then raise exception 'bad_name'; end if;
  loop
    new_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));
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
  if exists (select 1 from members where user_id = auth.uid()) or exists (select 1 from hq_members where user_id = auth.uid()) then raise exception 'already_member'; end if;
  if length(trim(member_name)) = 0 or length(member_name) > 30 then raise exception 'bad_name'; end if;
  select id, name into sid, sname from shops where code = upper(trim(shop_code));
  if sid is null then raise exception 'bad_code'; end if;
  insert into members(user_id, shop_id, name, role) values (auth.uid(), sid, trim(member_name), 'staff');
  return sname;
end $$;

-- 自分の名前を変える
create or replace function public.set_my_name(new_name text) returns void
language sql security definer set search_path = public as
$$ update members set name = trim(new_name) where user_id = auth.uid() and trim(new_name) <> '' and length(new_name) <= 30 $$;

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

-- 店長：店舗コードを作り直す（前のコードは使えなくなる）
create or replace function public.regenerate_code() returns text
language plpgsql security definer set search_path = public as $$
declare new_code text;
begin
  if public.my_role() <> 'manager' then raise exception 'not_manager'; end if;
  loop
    new_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));
    exit when not exists (select 1 from shops where code = new_code);
  end loop;
  update shops set code = new_code where id = public.my_shop();
  return new_code;
end $$;

-- 本部：会社を作る（作った人が本部メンバーになる）
create or replace function public.create_org(org_name text, member_name text) returns text
language plpgsql security definer set search_path = public as $$
declare c text; oid uuid;
begin
  if auth.uid() is null then raise exception 'not_logged_in'; end if;
  if exists (select 1 from members where user_id = auth.uid()) or exists (select 1 from hq_members where user_id = auth.uid()) then raise exception 'already_member'; end if;
  if length(trim(member_name)) = 0 or length(member_name) > 30 or length(trim(org_name)) = 0 or length(org_name) > 40 then raise exception 'bad_name'; end if;
  loop c := public.new_code(); exit when not exists (select 1 from orgs where code = c); end loop;
  insert into orgs(name, code) values (trim(org_name), c) returning id into oid;
  insert into hq_members(user_id, org_id, name) values (auth.uid(), oid, trim(member_name));
  return c;
end $$;

-- 本部：本部コードで本部メンバーとして参加
create or replace function public.join_org(org_code text, member_name text) returns text
language plpgsql security definer set search_path = public as $$
declare oid uuid; oname text;
begin
  if auth.uid() is null then raise exception 'not_logged_in'; end if;
  if exists (select 1 from members where user_id = auth.uid()) or exists (select 1 from hq_members where user_id = auth.uid()) then raise exception 'already_member'; end if;
  if length(trim(member_name)) = 0 or length(member_name) > 30 then raise exception 'bad_name'; end if;
  select id, name into oid, oname from orgs where code = upper(trim(org_code));
  if oid is null then raise exception 'bad_code'; end if;
  insert into hq_members(user_id, org_id, name) values (auth.uid(), oid, trim(member_name));
  return oname;
end $$;

-- 本部：店舗を追加（スタッフ用の店舗コードと、店長用の店長コードができる）
create or replace function public.hq_add_shop(shop_name text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare c1 text; c2 text; sid uuid;
begin
  if public.my_org() is null then raise exception 'not_hq'; end if;
  if length(trim(shop_name)) = 0 or length(shop_name) > 40 then raise exception 'bad_name'; end if;
  loop c1 := public.new_code(); exit when not exists (select 1 from shops where code = c1 or mgr_code = c1); end loop;
  loop c2 := public.new_code(); exit when c2 <> c1 and not exists (select 1 from shops where code = c2 or mgr_code = c2); end loop;
  insert into shops(name, code, mgr_code, org_id) values (trim(shop_name), c1, c2, public.my_org()) returning id into sid;
  return jsonb_build_object('id', sid, 'code', c1, 'mgr_code', c2);
end $$;

-- 本部：店舗のコードを作り直す
create or replace function public.hq_regen_codes(target uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare c1 text; c2 text;
begin
  if public.my_org() is null or not exists (select 1 from shops where id = target and org_id = public.my_org()) then raise exception 'not_hq'; end if;
  loop c1 := public.new_code(); exit when not exists (select 1 from shops where code = c1 or mgr_code = c1); end loop;
  loop c2 := public.new_code(); exit when c2 <> c1 and not exists (select 1 from shops where code = c2 or mgr_code = c2); end loop;
  update shops set code = c1, mgr_code = c2 where id = target;
  return jsonb_build_object('code', c1, 'mgr_code', c2);
end $$;

-- 本部：店舗の名前を変える
create or replace function public.hq_rename_shop(target uuid, new_name text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if public.my_org() is null or not exists (select 1 from shops where id = target and org_id = public.my_org()) then raise exception 'not_hq'; end if;
  if length(trim(new_name)) = 0 or length(new_name) > 40 then raise exception 'bad_name'; end if;
  update shops set name = trim(new_name) where id = target;
end $$;

-- 本部：設定を全店舗に配る
create or replace function public.hq_share_cfg(new_cfg jsonb) returns void
language plpgsql security definer set search_path = public as $$
begin
  if public.my_org() is null then raise exception 'not_hq'; end if;
  update shops set cfg = new_cfg, cfg_at = now() where org_id = public.my_org();
end $$;

-- 店長コードで、店長として店舗に参加
create or replace function public.join_shop_manager(code_in text, member_name text) returns text
language plpgsql security definer set search_path = public as $$
declare sid uuid; sname text;
begin
  if auth.uid() is null then raise exception 'not_logged_in'; end if;
  if exists (select 1 from members where user_id = auth.uid()) or exists (select 1 from hq_members where user_id = auth.uid()) then raise exception 'already_member'; end if;
  if length(trim(member_name)) = 0 or length(member_name) > 30 then raise exception 'bad_name'; end if;
  select id, name into sid, sname from shops where mgr_code = upper(trim(code_in));
  if sid is null then raise exception 'bad_code'; end if;
  insert into members(user_id, shop_id, name, role) values (auth.uid(), sid, trim(member_name), 'manager');
  return sname;
end $$;

-- 店長：自分の店舗を会社（本部）につなぐ
create or replace function public.link_shop_org(org_code text) returns text
language plpgsql security definer set search_path = public as $$
declare oid uuid; oname text;
begin
  if public.my_role() <> 'manager' then raise exception 'not_manager'; end if;
  select id, name into oid, oname from orgs where code = upper(trim(org_code));
  if oid is null then raise exception 'bad_code'; end if;
  update shops set org_id = oid where id = public.my_shop();
  return oname;
end $$;

-- 1人分のデータが大きくなりすぎないように（約2MBまで）
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'states_data_size') then
    alter table public.states add constraint states_data_size check (pg_column_size(data) < 2000000);
  end if;
end $$;

-- ログインしていない人（anon）は、表に一切さわれないようにする
revoke all on public.shops, public.members, public.states, public.orgs, public.hq_members from anon;

-- 外から直接は呼べないようにして、ログインした人だけに許可
revoke all on function public.create_shop(text,text), public.join_shop(text,text), public.set_my_name(text),
  public.share_cfg(jsonb), public.set_member_role(uuid,text), public.remove_member(uuid), public.regenerate_code(),
  public.my_shop(), public.my_role(), public.my_org(), public.my_shop_org(), public.hq_shop_ids(),
  public.create_org(text,text), public.join_org(text,text), public.hq_add_shop(text), public.hq_regen_codes(uuid),
  public.hq_rename_shop(uuid,text), public.hq_share_cfg(jsonb), public.join_shop_manager(text,text), public.link_shop_org(text) from public, anon;
grant execute on function public.create_shop(text,text), public.join_shop(text,text), public.set_my_name(text),
  public.share_cfg(jsonb), public.set_member_role(uuid,text), public.remove_member(uuid), public.regenerate_code(),
  public.my_shop(), public.my_role(), public.my_org(), public.my_shop_org(), public.hq_shop_ids(),
  public.create_org(text,text), public.join_org(text,text), public.hq_add_shop(text), public.hq_regen_codes(uuid),
  public.hq_rename_shop(uuid,text), public.hq_share_cfg(jsonb), public.join_shop_manager(text,text), public.link_shop_org(text) to authenticated;

-- 店長の画面に自動で反映するため（リアルタイム通知）
do $$ begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and tablename = 'states') then
    execute 'alter publication supabase_realtime add table public.states';
  end if;
end $$;
