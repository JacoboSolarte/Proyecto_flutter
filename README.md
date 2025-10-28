# Biomedic App (Flutter + Supabase)

Aplicación móvil/web para gestión de equipos biomédicos usando Flutter (última estable), Dart, Supabase (Auth + Postgres) y Clean Architecture (Presentation / Domain / Data). Incluye autenticación, lista con paginación, búsqueda y CRUD completo de equipos, y perfil de usuario.

## Requisitos
- Flutter y Dart instalados (canal stable).
- Cuenta y proyecto en Supabase.

## Variables / Configuración
Las credenciales de Supabase están definidas en `lib/core/config/supabase_config.dart`.

Si deseas cambiar tu `SUPABASE_URL` y `SUPABASE_ANON_KEY`, edita ese archivo:

```
class SupabaseConfig {
  static const String supabaseUrl = 'https://<your-project>.supabase.co';
  static const String supabaseAnonKey = '<your-anon-key>';
}
```

## Ejecutar localmente
1. Instala dependencias:
   - `flutter pub get`
2. Levanta la app:
   - Web: `flutter run -d web-server --web-port 8080`
   - Chrome: `flutter run -d chrome`
   - Windows: `flutter run -d windows`

## Arquitectura
- `lib/core` configuraciones generales.
- `lib/features/auth` autenticación (entidades, repositorio, casos de uso, providers y páginas).
- `lib/features/equipment` equipos (entidades, repositorio, casos de uso, providers y páginas).
- `lib/main.dart` inicializa Supabase, Riverpod y localización (español) y hace `AuthGate`.

## Migraciones SQL (Supabase)
Ejecuta el contenido de `supabase/migrations.sql` en el SQL Editor de Supabase para crear la tabla `equipments`, activar RLS y definir políticas.

### Tabla `equipments`
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

## Funcionalidades
- Registro e inicio de sesión con email y contraseña.
- Pantalla principal con lista paginada e infinite scroll.
- CRUD de equipos (agregar, editar, eliminar).
- Búsqueda por nombre, marca, modelo, serie, ubicación.
- Detalle de equipo.
- Perfil de usuario: ver y editar nombre, cerrar sesión.
- Validaciones mínimas (campos obligatorios) y localización en español.

## Tests
Opcionales: agrega unit tests a casos de uso y repositorios si deseas.

## Notas
- Asegúrate de tener ejecutadas las migraciones y de que las políticas RLS correspondan a tus necesidades.
- Si usas Storage para fotos/documentos del equipo, puedes ampliar el repositorio y la entidad `Equipment`.

## Imágenes (Storage)
- Bucket: `images` (público) con estructura `images/equipment/<equipment_id>/<timestamp>_<filename>`.
- Dependencias: `image_picker`, `file_picker`, `mime`.
- Android: agregar permisos en `android/app/src/main/AndroidManifest.xml`:
  - `<uses-permission android:name="android.permission.INTERNET" />`
  - `<uses-permission android:name="android.permission.CAMERA" />`
- iOS: agregar claves en `ios/Runner/Info.plist`:
  - `NSCameraUsageDescription` = `Se requiere acceso a la cámara para tomar fotos del equipo.`
  - `NSPhotoLibraryUsageDescription` = `Se requiere acceso a la biblioteca para seleccionar imágenes del equipo.`

### Políticas SQL (Supabase Storage)
Ejecuta estas políticas en el editor SQL para el esquema `storage.objects` (bucket `images`). El bucket es público para lectura/listado, pero la subida requiere usuario autenticado:

```
-- Lectura y listado (público)
create policy "public can read images"
on storage.objects for select
to public
using (bucket_id = 'images');

-- Insertar (subir archivos) para usuarios autenticados
create policy "authenticated can insert images"
on storage.objects for insert
to authenticated
with check (bucket_id = 'images');

-- Actualizar (si usas upsert y el archivo ya existe)
create policy "authenticated can update images"
on storage.objects for update
to authenticated
using (bucket_id = 'images')
with check (bucket_id = 'images');

-- Borrar (opcional)
create policy "authenticated can delete images"
on storage.objects for delete
to authenticated
using (bucket_id = 'images');
```

### Flujo en la app
- En crear/editar equipo, puedes seleccionar imagen desde archivos o tomar foto (web/móvil según soporte).
- Tras crear/guardar, si hay imagen seleccionada, se sube a `images` bajo `equipment/<id>/...`.
- En el detalle del equipo y en la edición, se muestra la última imagen subida usando `getPublicUrl` (al ser bucket público).
- La app verifica sesión antes de subir; si no hay sesión, se muestra un mensaje y no se realiza la subida.

### Consejos
- Evita colisiones de nombre de archivo usando la convención con timestamp (implementado).
- Si deseas un bucket privado, cambia la lectura a URLs firmadas (`createSignedUrl`) y ajusta `select` a `authenticated`.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
