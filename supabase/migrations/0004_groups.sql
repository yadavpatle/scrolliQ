-- ============================================================================
-- ScrollIQ – Groups migration
-- Run this in Supabase SQL Editor after the base schema.
-- ============================================================================

-- ===========================================================================
-- 1. ENUMS
-- ===========================================================================
do $$ begin
    create type group_role as enum ('owner', 'admin', 'member');
exception when duplicate_object then null;
end $$;

do $$ begin
    create type group_invite_status as enum ('pending', 'accepted', 'declined');
exception when duplicate_object then null;
end $$;

-- ===========================================================================
-- 2. GROUPS TABLE
-- ===========================================================================
create table if not exists public.groups (
    id            uuid primary key default uuid_generate_v4(),
    name          text not null,
    description   text not null default '',
    avatar_emoji  text not null default '🔥',
    created_by    uuid not null references public.users(id) on delete cascade,
    invite_code   text not null unique,
    max_members   int  not null default 20 check (max_members > 0),
    created_at    timestamptz not null default now()
);

create index if not exists groups_created_by_idx on public.groups (created_by);
create index if not exists groups_invite_code_idx on public.groups (invite_code);

-- ===========================================================================
-- 3. GROUP MEMBERS TABLE
-- ===========================================================================
create table if not exists public.group_members (
    id        uuid primary key default uuid_generate_v4(),
    group_id  uuid not null references public.groups(id) on delete cascade,
    user_id   uuid not null references public.users(id) on delete cascade,
    role      group_role not null default 'member',
    joined_at timestamptz not null default now(),
    unique (group_id, user_id)
);

create index if not exists gm_group_idx on public.group_members (group_id);
create index if not exists gm_user_idx  on public.group_members (user_id);

-- ===========================================================================
-- 4. GROUP INVITES TABLE (in-app friend invites)
-- ===========================================================================
create table if not exists public.group_invites (
    id          uuid primary key default uuid_generate_v4(),
    group_id    uuid not null references public.groups(id) on delete cascade,
    inviter_id  uuid not null references public.users(id) on delete cascade,
    invitee_id  uuid not null references public.users(id) on delete cascade,
    status      group_invite_status not null default 'pending',
    created_at  timestamptz not null default now(),
    check (inviter_id <> invitee_id),
    unique (group_id, invitee_id)
);

create index if not exists gi_invitee_idx on public.group_invites (invitee_id);
create index if not exists gi_group_idx   on public.group_invites (group_id);

-- ===========================================================================
-- 5. GROUP LEADERBOARD VIEW
-- ===========================================================================
create or replace view public.group_leaderboard as
select
    gm.group_id,
    gm.user_id,
    u.name       as user_name,
    u.avatar_url as user_avatar_url,
    gm.role,
    coalesce(du.brain_score, 0) as brain_score,
    coalesce(du.total_reels, 0) as total_reels,
    du.date,
    rank() over (
        partition by gm.group_id
        order by coalesce(du.brain_score, 0) desc,
                 coalesce(du.total_reels, 0) asc
    ) as rank
from public.group_members gm
join public.users u on u.id = gm.user_id
left join public.daily_usage du
    on du.user_id = gm.user_id
   and du.date = current_date;

-- ===========================================================================
-- 6. INVITE CODE GENERATOR (6-char uppercase)
-- ===========================================================================
create or replace function public.gen_group_invite_code()
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
            md5(random()::text || clock_timestamp()::text), 1, 6));
        exit when not exists (
            select 1 from public.groups where invite_code = candidate
        );
    end loop;
    return candidate;
end;
$$;

-- ===========================================================================
-- 7. RPC: join_group_by_code
-- ===========================================================================
create or replace function public.join_group_by_code(code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
    me         uuid := auth.uid();
    grp        record;
    member_cnt int;
begin
    if me is null then
        raise exception 'Not authenticated';
    end if;

    select id, max_members into grp
    from public.groups
    where invite_code = upper(trim(code))
    limit 1;

    if grp.id is null then
        raise exception 'Invalid invite code';
    end if;

    -- Already a member? Return group id silently.
    if exists (
        select 1 from public.group_members
        where group_id = grp.id and user_id = me
    ) then
        return grp.id;
    end if;

    -- Check max members.
    select count(*) into member_cnt
    from public.group_members
    where group_id = grp.id;

    if member_cnt >= grp.max_members then
        raise exception 'Group is full';
    end if;

    insert into public.group_members (group_id, user_id, role)
    values (grp.id, me, 'member');

    return grp.id;
end;
$$;

grant execute on function public.join_group_by_code(text) to authenticated;

-- ===========================================================================
-- 8. ROW LEVEL SECURITY
-- ===========================================================================
alter table public.groups          enable row level security;
alter table public.group_members   enable row level security;
alter table public.group_invites   enable row level security;

-- GROUPS --------------------------------------------------------------------
drop policy if exists "Groups: read member" on public.groups;
drop policy if exists "Groups: insert self" on public.groups;
drop policy if exists "Groups: update owner" on public.groups;
drop policy if exists "Groups: delete owner" on public.groups;

create policy "Groups: read member"
    on public.groups for select
    using (
        exists (
            select 1 from public.group_members
            where group_members.group_id = groups.id
              and group_members.user_id = auth.uid()
        )
    );

create policy "Groups: insert self"
    on public.groups for insert
    with check (auth.uid() = created_by);

create policy "Groups: update owner"
    on public.groups for update
    using (auth.uid() = created_by)
    with check (auth.uid() = created_by);

create policy "Groups: delete owner"
    on public.groups for delete
    using (auth.uid() = created_by);

-- GROUP MEMBERS -------------------------------------------------------------
-- Helper function to check membership without triggering RLS (breaks recursion).
create or replace function public.is_group_member(gid uuid, uid uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
    select exists (
        select 1 from public.group_members
        where group_id = gid and user_id = uid
    );
$$;

drop policy if exists "GM: read co-member" on public.group_members;
drop policy if exists "GM: insert self"    on public.group_members;
drop policy if exists "GM: delete self or owner" on public.group_members;

create policy "GM: read co-member"
    on public.group_members for select
    using (
        public.is_group_member(group_id, auth.uid())
    );

create policy "GM: insert self"
    on public.group_members for insert
    with check (auth.uid() = user_id);

create policy "GM: delete self or owner"
    on public.group_members for delete
    using (
        auth.uid() = user_id
        or exists (
            select 1 from public.groups
            where groups.id = group_members.group_id
              and groups.created_by = auth.uid()
        )
    );

-- GROUP INVITES -------------------------------------------------------------
drop policy if exists "GI: read involved" on public.group_invites;
drop policy if exists "GI: insert member" on public.group_invites;
drop policy if exists "GI: update invitee" on public.group_invites;
drop policy if exists "GI: delete involved" on public.group_invites;

create policy "GI: read involved"
    on public.group_invites for select
    using (auth.uid() = inviter_id or auth.uid() = invitee_id);

create policy "GI: insert member"
    on public.group_invites for insert
    with check (
        auth.uid() = inviter_id
        and exists (
            select 1 from public.group_members
            where group_members.group_id = group_invites.group_id
              and group_members.user_id = auth.uid()
        )
    );

create policy "GI: update invitee"
    on public.group_invites for update
    using (auth.uid() = invitee_id)
    with check (auth.uid() = invitee_id);

create policy "GI: delete involved"
    on public.group_invites for delete
    using (auth.uid() = inviter_id or auth.uid() = invitee_id);
