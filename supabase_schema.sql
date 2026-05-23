-- ─────────────────────────────────────────────────────────────
-- Stagger iOS app — Supabase schema
-- Paste this into Supabase Dashboard → SQL Editor → Run.
-- Idempotent: safe to re-run.
-- ─────────────────────────────────────────────────────────────

create table if not exists animations (
  id              text primary key,
  name            text not null,
  category        text not null check (category in (
                    'Backgrounds','Loaders','Buttons','Micro-interactions',
                    'Transitions','Navigation','Gestures','Onboarding',
                    'Text effects','Metal Shaders'
                  )),
  difficulty      text not null default 'intermediate'
                    check (difficulty in ('beginner','intermediate','advanced')),
  ios_version     text not null default '17+',
  is_pro          boolean not null default false,
  is_featured     boolean not null default false,
  tint_hex        text not null default '#0a0a0c',
  author          text not null,
  handle          text not null,
  downloads       integer not null default 0,
  rating          numeric(3,2) not null default 5.0,
  price           numeric(10,2),                       -- null = free
  description     text not null,
  swift_code      text not null default '',
  -- Optional parametric preview hints. When provided, the iOS app renders
  -- this row using its built-in ParametricAuroraPreview without an app
  -- rebuild. Engine must be one of: mesh, spin, bloom, streaks, goo.
  palette         text[],
  engine          text check (engine in ('mesh','spin','bloom','streaks','goo')),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- Public read access for the iOS app's anon key.
alter table animations enable row level security;

drop policy if exists "animations are publicly readable" on animations;
create policy "animations are publicly readable"
  on animations for select
  using (true);

-- Touch updated_at on writes.
create or replace function set_updated_at()
  returns trigger language plpgsql as $$
  begin
    new.updated_at := now();
    return new;
  end $$;

drop trigger if exists animations_set_updated_at on animations;
create trigger animations_set_updated_at
  before update on animations
  for each row execute function set_updated_at();

-- Indexes for the queries the iOS app makes.
create index if not exists animations_category_idx   on animations(category);
create index if not exists animations_is_pro_idx     on animations(is_pro);
create index if not exists animations_downloads_idx  on animations(downloads desc);

-- ─────────────────────────────────────────────────────────────
-- Example inserts. Run these to see new rows show up in the app
-- after you've configured `SupabaseConfig` in AppContainer.swift.
-- ─────────────────────────────────────────────────────────────

insert into animations
  (id, name, category, difficulty, ios_version, is_pro, tint_hex,
   author, handle, downloads, rating, price, description,
   palette, engine)
values
  ('au-serverdawn',  'Server Dawn',    'Backgrounds', 'intermediate', '18+', false,
   '#FECACA', 'Faisal Arif', '@faisalarip', 420, 4.8, null,
   'Dropped in via Supabase. Pastel sunrise mesh tuned for morning routines.',
   array['#FECACA','#FDBA74','#FCD34D','#86EFAC'], 'mesh'),

  ('au-servernoir',  'Server Noir',    'Backgrounds', 'advanced',     '18+', true,
   '#0A0A0C', 'Faisal Arif', '@faisalarip', 612, 4.9, 10.00,
   'Dropped in via Supabase. Noir mood with subtle gold spin — premium dark UI.',
   array['#0A0A0C','#27272A','#71717A','#FCD34D'], 'spin')
on conflict (id) do update set
  name        = excluded.name,
  category    = excluded.category,
  difficulty  = excluded.difficulty,
  ios_version = excluded.ios_version,
  is_pro      = excluded.is_pro,
  tint_hex    = excluded.tint_hex,
  author      = excluded.author,
  handle      = excluded.handle,
  downloads   = excluded.downloads,
  rating      = excluded.rating,
  price       = excluded.price,
  description = excluded.description,
  palette     = excluded.palette,
  engine      = excluded.engine;
