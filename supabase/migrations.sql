-- Extensiones necesarias
create extension if not exists "pgcrypto";

-- Tabla principal de equipos biomédicos
create table if not exists public.equipments (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  brand text,
  model text,
  serial text,
  location text,
  status text not null check (status in ('operativo','mantenimiento','fuera_de_servicio')),
  purchase_date date,
  last_maintenance_date date,
  next_maintenance_date date,
  vendor text,
  warranty_expire_date date,
  notes text,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Trigger para updated_at
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists set_updated_at_equipments on public.equipments;
create trigger set_updated_at_equipments
before update on public.equipments
for each row execute procedure public.set_updated_at();

-- Activar RLS
alter table public.equipments enable row level security;

-- Políticas de acceso
drop policy if exists "Allow read for authenticated" on public.equipments;
create policy "Allow read for authenticated"
on public.equipments
for select
to authenticated
using (true);

drop policy if exists "Allow insert for user" on public.equipments;
create policy "Allow insert for user"
on public.equipments
for insert
to authenticated
with check (auth.uid() = created_by);

drop policy if exists "Allow update own" on public.equipments;
create policy "Allow update own"
on public.equipments
for update
to authenticated
using (auth.uid() = created_by);

drop policy if exists "Allow delete own" on public.equipments;
create policy "Allow delete own"
on public.equipments
for delete
to authenticated
using (auth.uid() = created_by);