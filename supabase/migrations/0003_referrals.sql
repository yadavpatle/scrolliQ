-- ============================================================================
-- ScrollIQ migration 0003 — Supabase-backed referrals / invites
--
-- Adds a unique per-user `referral_code`, a code generator, updates the signup
-- trigger to assign codes, backfills existing users, and adds the
-- `get_referrer` / `redeem_referral` RPCs that power invite links.
--
-- The migration is idempotent: it only adds objects that don't already exist
-- (and uses `create or replace` for functions), so it is safe to run multiple
-- times.
--
-- Apply via Supabase SQL Editor or `supabase db push`.
-- ============================================================================

-- pgcrypto lives in the `extensions` schema on Supabase, so its functions
-- aren't on this function's search_path. Use core md5()/random() instead,
-- which are always available — no extension dependency.

-- 1. Referral code column ----------------------------------------------------
alter table public.users
    add column if not exists referral_code text;

create unique index if not exists users_referral_code_idx
    on public.users (referral_code);

-- 2. Code generator: 8-char uppercase hex, guaranteed unique -----------------
create or replace function public.gen_referral_code()
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
    candidate text;
begin
    loop
        candidate := upper(substr(
            md5(random()::text || clock_timestamp()::text), 1, 8));
        exit when not exists (
            select 1 from public.users where referral_code = candidate
        );
    end loop;
    return candidate;
end;
$$;

-- 3. Backfill existing users -------------------------------------------------
update public.users
set referral_code = public.gen_referral_code()
where referral_code is null;

-- 4. Assign a code on signup -------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.users (id, email, name, avatar_url, referral_code)
    values (
        new.id,
        new.email,
        coalesce(new.raw_user_meta_data->>'name',
                 new.raw_user_meta_data->>'full_name',
                 split_part(new.email, '@', 1)),
        new.raw_user_meta_data->>'avatar_url',
        public.gen_referral_code()
    )
    on conflict (id) do nothing;
    return new;
end;
$$;

-- 5. RPC: look up who owns a referral code (anon-callable for invite preview) -
create or replace function public.get_referrer(code text)
returns table (id uuid, name text, avatar_url text)
language sql
stable
security definer
set search_path = public
as $$
    select id, name, avatar_url
    from public.users
    where referral_code = upper(trim(code))
    limit 1;
$$;

grant execute on function public.get_referrer(text) to anon, authenticated;

-- 6. RPC: redeem a referral code for the current user ------------------------
-- Creates a pending friend request from the referrer (sender) to the
-- redeeming user (receiver). Security definer so it can insert a row whose
-- sender_id is the referrer — which "Friends: insert sender" RLS would forbid.
-- Idempotent and self-referral-safe.
create or replace function public.redeem_referral(code text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    me       uuid := auth.uid();
    referrer uuid;
begin
    if me is null then
        raise exception 'Not authenticated';
    end if;

    select id into referrer
    from public.users
    where referral_code = upper(trim(code))
    limit 1;

    if referrer is null then
        raise exception 'Invalid referral code';
    end if;

    if referrer = me then
        return; -- can't refer yourself
    end if;

    insert into public.friends (sender_id, receiver_id, status)
    values (referrer, me, 'pending')
    on conflict (sender_id, receiver_id) do nothing;
end;
$$;

grant execute on function public.redeem_referral(text) to authenticated;
