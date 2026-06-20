-- ============================================================================
-- ScrollIQ – Supabase schema
-- Run this in Supabase SQL Editor.
-- ============================================================================

-- Extensions ----------------------------------------------------------------
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- ===========================================================================
-- 1. USERS
-- ===========================================================================
create table if not exists public.users (
    id            uuid primary key references auth.users(id) on delete cascade,
    name          text not null default '',
    email         text not null,
    avatar_url    text,
    fcm_token     text,
    -- Short, shareable invite code used to build referral URLs.
    referral_code text unique,
    created_at    timestamptz not null default now()
);

create index if not exists users_email_idx on public.users (lower(email));
create index if not exists users_name_idx  on public.users (lower(name));

-- For older databases created before referral_code existed.
alter table public.users add column if not exists referral_code text;
create unique index if not exists users_referral_code_idx
    on public.users (referral_code);

-- ---------------------------------------------------------------------------
-- Referral-code generator: 8-char uppercase hex, guaranteed unique.
-- Uses core md5()/random() (no pgcrypto dependency, which lives in the
-- `extensions` schema and isn't on this function's search_path).
-- ---------------------------------------------------------------------------
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

-- Backfill codes for any existing rows that don't have one yet.
update public.users
set referral_code = public.gen_referral_code()
where referral_code is null;

-- Auto-insert profile row on signup (now also assigns a referral code)
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

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- ===========================================================================
-- 2. DAILY USAGE
-- ===========================================================================
create table if not exists public.daily_usage (
    id                  uuid primary key default uuid_generate_v4(),
    user_id             uuid not null references public.users(id) on delete cascade,
    date                date not null,
    total_screen_time   int  not null default 0, -- minutes
    instagram_time      int  not null default 0,
    youtube_time        int  not null default 0,
    tiktok_time         int  not null default 0,
    facebook_time       int  not null default 0,
    snapchat_time       int  not null default 0,
    twitter_time        int  not null default 0,
    -- Heuristic estimates (Phase 0). Kept for older clients.
    reels_estimated     int  not null default 0,
    shorts_estimated    int  not null default 0,
    -- Accurate per-platform counts from the AccessibilityService (Phase A).
    instagram_reels     int  not null default 0,
    youtube_shorts      int  not null default 0,
    tiktok_reels        int  not null default 0,
    snapchat_spotlight  int  not null default 0,
    facebook_reels      int  not null default 0,
    total_reels         int  generated always as (
        instagram_reels + youtube_shorts + tiktok_reels
        + snapchat_spotlight + facebook_reels
    ) stored,
    late_night_minutes  int  not null default 0,
    brain_score         int  not null default 100,
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now(),
    unique (user_id, date)
);

create index if not exists daily_usage_user_date_idx
    on public.daily_usage (user_id, date desc);

create index if not exists daily_usage_score_idx
    on public.daily_usage (date, brain_score desc);

create index if not exists daily_usage_total_reels_idx
    on public.daily_usage (date, total_reels desc);

-- Trigger: keep updated_at fresh
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists daily_usage_set_updated_at on public.daily_usage;
create trigger daily_usage_set_updated_at
before update on public.daily_usage
for each row execute function public.set_updated_at();

-- ===========================================================================
-- 3. FRIENDS
-- ===========================================================================
create type friend_status as enum ('pending', 'accepted', 'declined', 'blocked');

create table if not exists public.friends (
    id          uuid primary key default uuid_generate_v4(),
    sender_id   uuid not null references public.users(id) on delete cascade,
    receiver_id uuid not null references public.users(id) on delete cascade,
    status      friend_status not null default 'pending',
    created_at  timestamptz not null default now(),
    updated_at  timestamptz not null default now(),
    check (sender_id <> receiver_id),
    unique (sender_id, receiver_id)
);

create index if not exists friends_sender_idx   on public.friends (sender_id);
create index if not exists friends_receiver_idx on public.friends (receiver_id);

drop trigger if exists friends_set_updated_at on public.friends;
create trigger friends_set_updated_at
before update on public.friends
for each row execute function public.set_updated_at();

-- ===========================================================================
-- 4. CHALLENGES
-- ===========================================================================
create table if not exists public.challenges (
    id            uuid primary key default uuid_generate_v4(),
    title         text not null,
    description   text not null,
    duration_days int  not null check (duration_days > 0),
    min_score     int  not null default 75,
    is_default    boolean not null default false,
    created_at    timestamptz not null default now()
);

create table if not exists public.challenge_participants (
    id            uuid primary key default uuid_generate_v4(),
    challenge_id  uuid not null references public.challenges(id) on delete cascade,
    user_id       uuid not null references public.users(id)      on delete cascade,
    score         int  not null default 0,
    days_completed int not null default 0,
    started_at    timestamptz not null default now(),
    completed_at  timestamptz,
    unique (challenge_id, user_id)
);

create index if not exists cp_user_idx on public.challenge_participants (user_id);
create index if not exists cp_challenge_idx on public.challenge_participants (challenge_id);

-- Default challenge
insert into public.challenges (title, description, duration_days, min_score, is_default)
select '7-Day Scroll Detox',
       'Maintain a Brain Score above 75 for 7 consecutive days.',
       7, 75, true
where not exists (select 1 from public.challenges where is_default = true);

-- ===========================================================================
-- 5. VIEWS
-- ===========================================================================
-- Today's leaderboard
create or replace view public.leaderboard_today as
select
    row_number() over (
        order by du.brain_score desc, du.total_reels asc, u.created_at asc
    ) as rank,
    u.id            as user_id,
    u.name,
    u.avatar_url,
    du.brain_score,
    du.total_screen_time,
    du.date,
    du.total_reels
from public.daily_usage du
join public.users u on u.id = du.user_id
where du.date = current_date;

-- Profile aggregates
create or replace view public.user_stats as
select
    u.id as user_id,
    u.name,
    u.avatar_url,
    coalesce((select brain_score from public.daily_usage
              where user_id = u.id order by date desc limit 1), 100) as current_score,
    coalesce((select round(avg(brain_score))::int from public.daily_usage
              where user_id = u.id and date >= current_date - 6), 100) as weekly_avg_score,
    coalesce((select count(*) from public.daily_usage
              where user_id = u.id and brain_score >= 70), 0) as focus_days,
    coalesce((select sum(total_reels)::int from public.daily_usage
              where user_id = u.id and date >= current_date - 6), 0) as weekly_reels
from public.users u;

-- ===========================================================================
-- 6. ROW LEVEL SECURITY
-- ===========================================================================
alter table public.users                    enable row level security;
alter table public.daily_usage              enable row level security;
alter table public.friends                  enable row level security;
alter table public.challenges               enable row level security;
alter table public.challenge_participants   enable row level security;

-- USERS ---------------------------------------------------------------------
drop policy if exists "Users: read all"        on public.users;
drop policy if exists "Users: update self"     on public.users;
drop policy if exists "Users: insert self"     on public.users;

create policy "Users: read all"
    on public.users for select
    using (true);

create policy "Users: insert self"
    on public.users for insert
    with check (auth.uid() = id);

create policy "Users: update self"
    on public.users for update
    using (auth.uid() = id)
    with check (auth.uid() = id);

-- DAILY USAGE ---------------------------------------------------------------
drop policy if exists "DailyUsage: read own or friend"     on public.daily_usage;
drop policy if exists "DailyUsage: insert self"            on public.daily_usage;
drop policy if exists "DailyUsage: update self"            on public.daily_usage;
drop policy if exists "DailyUsage: read all for leaderboard" on public.daily_usage;

-- Leaderboard requires reading all rows for current_date – we expose only
-- via the view, but RLS still gates SELECT.  Allow read of any user's record.
create policy "DailyUsage: read all"
    on public.daily_usage for select
    using (true);

create policy "DailyUsage: insert self"
    on public.daily_usage for insert
    with check (auth.uid() = user_id);

create policy "DailyUsage: update self"
    on public.daily_usage for update
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

-- FRIENDS -------------------------------------------------------------------
drop policy if exists "Friends: read involved"  on public.friends;
drop policy if exists "Friends: insert sender"  on public.friends;
drop policy if exists "Friends: update receiver" on public.friends;
drop policy if exists "Friends: delete involved" on public.friends;

create policy "Friends: read involved"
    on public.friends for select
    using (auth.uid() = sender_id or auth.uid() = receiver_id);

create policy "Friends: insert sender"
    on public.friends for insert
    with check (auth.uid() = sender_id);

create policy "Friends: update receiver"
    on public.friends for update
    using (auth.uid() = receiver_id or auth.uid() = sender_id)
    with check (auth.uid() = receiver_id or auth.uid() = sender_id);

create policy "Friends: delete involved"
    on public.friends for delete
    using (auth.uid() = sender_id or auth.uid() = receiver_id);

-- CHALLENGES (read-all, admin write) ---------------------------------------
drop policy if exists "Challenges: read all" on public.challenges;
create policy "Challenges: read all"
    on public.challenges for select
    using (true);

-- CHALLENGE PARTICIPANTS ----------------------------------------------------
drop policy if exists "CP: read all"        on public.challenge_participants;
drop policy if exists "CP: insert self"     on public.challenge_participants;
drop policy if exists "CP: update self"     on public.challenge_participants;
drop policy if exists "CP: delete self"     on public.challenge_participants;

create policy "CP: read all"
    on public.challenge_participants for select
    using (true);

create policy "CP: insert self"
    on public.challenge_participants for insert
    with check (auth.uid() = user_id);

create policy "CP: update self"
    on public.challenge_participants for update
    using (auth.uid() = user_id)
    with check (auth.uid() = user_id);

create policy "CP: delete self"
    on public.challenge_participants for delete
    using (auth.uid() = user_id);

-- ===========================================================================
-- 7. RPC: search users
-- ===========================================================================
create or replace function public.search_users(q text)
returns table (id uuid, name text, email text, avatar_url text)
language sql
stable
security definer
set search_path = public
as $$
    select id, name, email, avatar_url
    from public.users
    where (lower(name)  like '%' || lower(q) || '%'
        or lower(email) like '%' || lower(q) || '%')
      and id <> auth.uid()
    limit 25;
$$;

grant execute on function public.search_users(text) to anon, authenticated;

-- ===========================================================================
-- 8. RPC: referrals
-- ===========================================================================

-- Look up the owner of a referral code. Callable by anon so the invite
-- landing/preview works before the invited user has authenticated.
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

-- Redeem a referral code for the *currently authenticated* user. Creates a
-- pending friend request from the referrer (sender) to the new user (me,
-- receiver). Runs as security definer so it can insert a row whose sender_id
-- is the referrer — which the standard "Friends: insert sender" RLS policy
-- would otherwise forbid. Idempotent and self-referral-safe.
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

    -- Can't refer yourself.
    if referrer = me then
        return;
    end if;

    -- Don't clobber an existing relationship (pending/accepted/declined).
    insert into public.friends (sender_id, receiver_id, status)
    values (referrer, me, 'pending')
    on conflict (sender_id, receiver_id) do nothing;
end;
$$;

grant execute on function public.redeem_referral(text) to authenticated;
