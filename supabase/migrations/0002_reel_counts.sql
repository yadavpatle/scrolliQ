-- ============================================================================
-- ScrollIQ migration 0002 — accurate reel / short counts
--
-- Phase A of the reel counter ships an Android AccessibilityService that
-- counts individual reel/short transitions per platform. This migration adds
-- five integer columns to `daily_usage` to store those counts, alongside the
-- existing heuristic `reels_estimated` / `shorts_estimated` (kept for
-- backwards-compat with already-shipped clients).
--
-- The migration is idempotent: it only adds columns / indexes that do not
-- already exist, so it is safe to run multiple times.
--
-- Apply via Supabase SQL Editor or `supabase db push` (if you adopt the CLI).
-- ============================================================================

alter table public.daily_usage
    add column if not exists instagram_reels    int not null default 0,
    add column if not exists youtube_shorts     int not null default 0,
    add column if not exists tiktok_reels       int not null default 0,
    add column if not exists snapchat_spotlight int not null default 0,
    add column if not exists facebook_reels     int not null default 0;

-- Generated total so the dashboard / leaderboard can sort without a sum().
-- `add column if not exists` works for generated columns on PG 14+ (Supabase
-- is on PG 15+). If you ever need to recompute, drop & re-add this column.
do $$
begin
    if not exists (
        select 1
          from information_schema.columns
         where table_schema = 'public'
           and table_name   = 'daily_usage'
           and column_name  = 'total_reels'
    ) then
        execute $sql$
            alter table public.daily_usage
                add column total_reels int
                generated always as (
                    instagram_reels
                    + youtube_shorts
                    + tiktok_reels
                    + snapchat_spotlight
                    + facebook_reels
                ) stored;
        $sql$;
    end if;
end $$;

create index if not exists daily_usage_total_reels_idx
    on public.daily_usage (date, total_reels desc);

-- Refresh the leaderboard view so it includes total_reels.
-- NOTE: Postgres `create or replace view` cannot reorder columns — it can
-- only append new columns at the end. So `total_reels` goes last.
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

-- Refresh user_stats with reels-of-the-week.
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
