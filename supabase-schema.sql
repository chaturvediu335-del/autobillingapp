-- Om Logistics — Supabase setup. Supabase Dashboard -> SQL Editor -> New query -> poora paste -> Run

-- ========== Tables ==========
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  name text,
  role text not null default 'staff' check (role in ('admin','staff'))
);

-- Dashboard data (har row ek JSON record)
create table if not exists public.billing_master (seq bigint generated always as identity, id text primary key, data jsonb not null, updated_at timestamptz default now());
create table if not exists public.monthly_reports (seq bigint generated always as identity, id text primary key, data jsonb not null, updated_at timestamptz default now());
create table if not exists public.employee_codes  (seq bigint generated always as identity, id text primary key, data jsonb not null, updated_at timestamptz default now());

create table if not exists public.submissions (
  id text primary key,
  user_id uuid,
  username text,
  status text not null default 'new',
  ts bigint,
  data jsonb not null,
  updated_at timestamptz default now()
);
create index if not exists submissions_ts_idx on public.submissions(ts);

create table if not exists public.settings (key text primary key, value jsonb);

-- ========== Helper: admin check ==========
create or replace function public.is_admin() returns boolean
language sql security definer stable set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

-- ========== Naya auth user -> profile (role HAMESHA staff; admin SQL se banta hai) ==========
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, username, name, role)
  values (new.id, lower(split_part(new.email,'@',1)),
          coalesce(new.raw_user_meta_data->>'name', split_part(new.email,'@',1)), 'staff')
  on conflict (id) do nothing;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ========== Row Level Security ==========
alter table public.profiles        enable row level security;
alter table public.billing_master  enable row level security;
alter table public.monthly_reports enable row level security;
alter table public.employee_codes  enable row level security;
alter table public.submissions     enable row level security;
alter table public.settings        enable row level security;

drop policy if exists p_sel on public.profiles;
create policy p_sel on public.profiles for select to authenticated using (id = auth.uid() or public.is_admin());

-- billing_master: sab logged-in padh/likh sakte hain, delete sirf admin
drop policy if exists bm_sel on public.billing_master; drop policy if exists bm_ins on public.billing_master;
drop policy if exists bm_upd on public.billing_master; drop policy if exists bm_del on public.billing_master;
create policy bm_sel on public.billing_master for select to authenticated using (true);
create policy bm_ins on public.billing_master for insert to authenticated with check (true);
create policy bm_upd on public.billing_master for update to authenticated using (true) with check (true);
create policy bm_del on public.billing_master for delete to authenticated using (public.is_admin());

-- monthly_reports + employee_codes: sab logged-in (staff ka auto-add inhe regroup karta hai)
do $$ declare t text; begin
  foreach t in array array['monthly_reports','employee_codes'] loop
    execute format('drop policy if exists %1$s_sel on public.%1$s', t);
    execute format('drop policy if exists %1$s_ins on public.%1$s', t);
    execute format('drop policy if exists %1$s_upd on public.%1$s', t);
    execute format('drop policy if exists %1$s_del on public.%1$s', t);
    execute format('create policy %1$s_sel on public.%1$s for select to authenticated using (true)', t);
    execute format('create policy %1$s_ins on public.%1$s for insert to authenticated with check (true)', t);
    execute format('create policy %1$s_upd on public.%1$s for update to authenticated using (true) with check (true)', t);
    execute format('create policy %1$s_del on public.%1$s for delete to authenticated using (true)', t);
  end loop; end $$;

-- submissions: staff sirf apni; admin sab
drop policy if exists s_sel on public.submissions; drop policy if exists s_ins on public.submissions;
drop policy if exists s_upd on public.submissions; drop policy if exists s_del on public.submissions;
create policy s_sel on public.submissions for select to authenticated using (user_id = auth.uid() or public.is_admin());
create policy s_ins on public.submissions for insert to authenticated with check (user_id = auth.uid() or public.is_admin());
create policy s_upd on public.submissions for update to authenticated using (user_id = auth.uid() or public.is_admin()) with check (user_id = auth.uid() or public.is_admin());
create policy s_del on public.submissions for delete to authenticated using (public.is_admin());

-- settings: sab padh sakte, sirf admin badal sakta
drop policy if exists st_sel on public.settings; drop policy if exists st_all on public.settings;
create policy st_sel on public.settings for select to authenticated using (true);
create policy st_all on public.settings for all to authenticated using (public.is_admin()) with check (public.is_admin());

grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
