-- Run this whole file once in Supabase: SQL Editor > New query > Run

-- ============ TABLES ============
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  email text,
  is_admin boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.loan_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  full_name text not null,
  email text not null,
  phone text not null,
  id_number text not null,
  bank_name text not null,
  account_name text not null,
  account_number text not null check (account_number ~ '^[0-9]{10}$'),
  category text not null,
  employment_status text,
  amount numeric(14,2) not null check (amount between 10000 and 5000000),
  duration_months int not null check (duration_months between 1 and 24),
  total_repayment numeric(14,2) not null,
  document_path text,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  admin_note text,
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create index on public.loan_requests (user_id);
create index on public.loan_requests (status, created_at desc);

-- ============ AUTO-CREATE PROFILE ON SIGNUP ============
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, full_name)
  values (new.id, new.email, new.raw_user_meta_data->>'full_name');
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============ ADMIN CHECK ============
create or replace function public.is_admin()
returns boolean language sql security definer stable set search_path = public as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false);
$$;

-- ============ ROW LEVEL SECURITY ============
alter table public.profiles enable row level security;
alter table public.loan_requests enable row level security;

-- profiles: read own (or all if admin). No client updates at all (balance/is_admin can't be edited from the browser).
create policy "profiles read" on public.profiles for select
  using (id = auth.uid() or public.is_admin());

-- loan_requests: users insert their own pending requests, read their own. Admin reads all.
create policy "loans insert own" on public.loan_requests for insert
  with check (user_id = auth.uid() and status = 'pending');
create policy "loans read" on public.loan_requests for select
  using (user_id = auth.uid() or public.is_admin());

-- ============ ADMIN ACTIONS (atomic) ============
-- Admin sends the money from their bank app, then clicks Approve (marks the loan as paid/approved).
create or replace function public.approve_loan(p_loan_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Not allowed'; end if;
  update public.loan_requests
    set status = 'approved', reviewed_by = auth.uid(), reviewed_at = now()
    where id = p_loan_id and status = 'pending';
  if not found then raise exception 'Loan not found or already reviewed'; end if;
end $$;

create or replace function public.reject_loan(p_loan_id uuid, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Not allowed'; end if;
  update public.loan_requests
    set status = 'rejected', admin_note = p_note, reviewed_by = auth.uid(), reviewed_at = now()
    where id = p_loan_id and status = 'pending';
  if not found then raise exception 'Loan not found or already reviewed'; end if;
end $$;

revoke all on function public.approve_loan(uuid) from public, anon;
revoke all on function public.reject_loan(uuid, text) from public, anon;
grant execute on function public.approve_loan(uuid) to authenticated;
grant execute on function public.reject_loan(uuid, text) to authenticated;

-- ============ STORAGE (private bucket for ID documents) ============
insert into storage.buckets (id, name, public) values ('loan-docs', 'loan-docs', false)
on conflict (id) do nothing;

create policy "docs upload own folder" on storage.objects for insert to authenticated
  with check (bucket_id = 'loan-docs' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "docs read own or admin" on storage.objects for select to authenticated
  using (bucket_id = 'loan-docs' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));

-- ============ MAKE YOURSELF ADMIN ============
-- 1) Sign up on your site with your admin email.
-- 2) Then run (with your email):
-- update public.profiles set is_admin = true where email = 'you@example.com';
