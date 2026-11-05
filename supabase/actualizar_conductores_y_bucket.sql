-- ==============================================================================
-- ACTUALIZACIÓN DE TABLA CONDUCTORES Y BUCKET GENERAL PARA EJETUR
-- ==============================================================================

-- 1. CREACIÓN Y PERMISOS DEL BUCKET 'general' EN SUPABASE STORAGE
INSERT INTO storage.buckets (id, name, public) 
VALUES ('general', 'general', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Permitir acceso público de lectura y escritura en el bucket 'general'
DROP POLICY IF EXISTS "Public Access General Bucket" ON storage.objects;
CREATE POLICY "Public Access General Bucket" ON storage.objects 
FOR ALL TO public 
USING (bucket_id = 'general') 
WITH CHECK (bucket_id = 'general');

-- 2. ASEGURAR COLUMNAS EN LA TABLA public.conductores
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS user_id TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS nombre TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS nombre_completo TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS correo TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS telefono TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS marca TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS modelo TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS modelo_auto TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS ano TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS anio_auto TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS color TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS color_auto TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS placas TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS imagen_perfil TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS foto_auto_url TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS foto_placas_url TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS ine_url TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS ine_frente_url TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS ine_reverso_url TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS licencia_url TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS seguro_url TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS tarjeta_url TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS tarjeta_circulacion_url TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS banco TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS cuenta_bancaria TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS clabe TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS estatus TEXT DEFAULT 'inactivo';
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS "Perfi_terminado" BOOLEAN DEFAULT false;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS "Aprobacion" TEXT DEFAULT 'Pendiente';

-- Sincronizar user_id si hay registros con id pero sin user_id
UPDATE public.conductores SET user_id = id::text WHERE user_id IS NULL;

-- Índices de consulta rápida
CREATE INDEX IF NOT EXISTS idx_conductores_user_id ON public.conductores(user_id);
CREATE INDEX IF NOT EXISTS idx_conductores_correo ON public.conductores(correo);
CREATE INDEX IF NOT EXISTS idx_conductores_estatus ON public.conductores(estatus);
