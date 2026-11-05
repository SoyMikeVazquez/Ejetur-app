-- ==============================================================================
-- ESQUEMA COMPLETO DE BASE DE DATOS PARA SUPABASE
-- PROYECTO: EJETUR / TAXISEGURO
-- ==============================================================================

-- 1. EXTENSIONES
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_cron";

-- ==============================================================================
-- 2. TABLA: users (Usuarios Pasajeros y Perfiles Base)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT,
    nombre TEXT,
    correo TEXT,
    telefono TEXT,
    imagen_perfil TEXT,
    fotodeperfil TEXT,
    "isConductor" BOOLEAN DEFAULT false,
    usuario_activado BOOLEAN DEFAULT false,
    referido TEXT,
    comision_referido NUMERIC(10, 2) DEFAULT 0.00,
    time_referido TIMESTAMPTZ,
    has_special_location_permission BOOLEAN DEFAULT false,
    bypass_geofence BOOLEAN DEFAULT false,
    permiso_especial_ubicacion BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Asegurar columnas si la tabla ya existía previamente
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS user_id TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS nombre TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS correo TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS telefono TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS imagen_perfil TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS fotodeperfil TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS "isConductor" BOOLEAN DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS usuario_activado BOOLEAN DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS referido TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS comision_referido NUMERIC(10, 2) DEFAULT 0.00;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS time_referido TIMESTAMPTZ;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS has_special_location_permission BOOLEAN DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS bypass_geofence BOOLEAN DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS permiso_especial_ubicacion BOOLEAN DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

-- Sincronizar user_id si ya existían registros con id pero sin user_id
DO $$
BEGIN
    UPDATE public.users SET user_id = id::text WHERE user_id IS NULL;
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_users_user_id ON public.users(user_id);
CREATE INDEX IF NOT EXISTS idx_users_referido ON public.users(referido);

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso total users autenticados" ON public.users;
CREATE POLICY "Acceso total users autenticados" ON public.users FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Acceso total users anon" ON public.users;
CREATE POLICY "Acceso total users anon" ON public.users FOR ALL TO anon USING (true) WITH CHECK (true);

-- ==============================================================================
-- 3. TABLA: conductores (Datos y Documentos de Conductores)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.conductores (
    id TEXT PRIMARY KEY,
    user_id TEXT,
    nombre TEXT,
    nombre_completo TEXT,
    correo TEXT,
    telefono TEXT,
    estatus TEXT DEFAULT 'inactivo',
    "Perfi_terminado" BOOLEAN DEFAULT false,
    "Aprobacion" TEXT DEFAULT 'Pendiente',
    modelo_auto TEXT,
    color_auto TEXT,
    placas TEXT,
    anio_auto TEXT,
    ine_url TEXT,
    licencia_url TEXT,
    seguro_url TEXT,
    tarjeta_circulacion_url TEXT,
    banco TEXT,
    cuenta_bancaria TEXT,
    clabe TEXT,
    imagen_perfil TEXT,
    calificacion_promedio NUMERIC(3, 2) DEFAULT 5.0,
    current_lat DOUBLE PRECISION,
    current_lng DOUBLE PRECISION,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Asegurar columnas si la tabla ya existía previamente
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS user_id TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS nombre TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS nombre_completo TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS correo TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS telefono TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS estatus TEXT DEFAULT 'inactivo';
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS "Perfi_terminado" BOOLEAN DEFAULT false;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS "Aprobacion" TEXT DEFAULT 'Pendiente';
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS modelo_auto TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS color_auto TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS placas TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS anio_auto TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS ine_url TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS ine_frente_url TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS ine_reverso_url TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS licencia_url TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS seguro_url TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS tarjeta_circulacion_url TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS banco TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS cuenta_bancaria TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS clabe TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS imagen_perfil TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS foto_auto_url TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS foto_placas_url TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS marca TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS modelo TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS ano TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS color TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS tarjeta_url TEXT;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS calificacion_promedio NUMERIC(3, 2) DEFAULT 5.0;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS current_lat DOUBLE PRECISION;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS current_lng DOUBLE PRECISION;
ALTER TABLE public.conductores ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

-- Sincronizar user_id si ya existían registros con id pero sin user_id
DO $$
BEGIN
    UPDATE public.conductores SET user_id = id::text WHERE user_id IS NULL;
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

CREATE INDEX IF NOT EXISTS idx_conductores_user_id ON public.conductores(user_id);
CREATE INDEX IF NOT EXISTS idx_conductores_estatus ON public.conductores(estatus);

ALTER TABLE public.conductores ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso total conductores autenticados" ON public.conductores;
CREATE POLICY "Acceso total conductores autenticados" ON public.conductores FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Acceso total conductores anon" ON public.conductores;
CREATE POLICY "Acceso total conductores anon" ON public.conductores FOR ALL TO anon USING (true) WITH CHECK (true);

-- ==============================================================================
-- 4. TABLA: trips (Historial y Gestión de Viajes)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.trips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT,
    driver_id TEXT,
    origin_address TEXT,
    destination_address TEXT,
    origin_lat DOUBLE PRECISION,
    origin_lng DOUBLE PRECISION,
    destination_lat DOUBLE PRECISION,
    destination_lng DOUBLE PRECISION,
    postal_code TEXT,
    delegation TEXT,
    status TEXT DEFAULT 'pending',
    fare NUMERIC(10, 2) DEFAULT 0.00,
    distance_km NUMERIC(10, 2) DEFAULT 0.00,
    payment_method TEXT DEFAULT 'efectivo',
    name_driver TEXT,
    photo_driver TEXT,
    total_final NUMERIC(10, 2) DEFAULT 0.00,
    "isReview" BOOLEAN DEFAULT false,
    is_review BOOLEAN DEFAULT false,
    codigo INTEGER,
    cancel_reason TEXT,
    arrived_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Asegurar columnas si la tabla ya existía previamente
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS user_id TEXT;
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS driver_id TEXT;
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS origin_address TEXT;
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS destination_address TEXT;
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS origin_lat DOUBLE PRECISION;
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS origin_lng DOUBLE PRECISION;
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS destination_lat DOUBLE PRECISION;
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS destination_lng DOUBLE PRECISION;
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS postal_code TEXT;
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS delegation TEXT;
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending';
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS fare NUMERIC(10, 2) DEFAULT 0.00;
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS distance_km NUMERIC(10, 2) DEFAULT 0.00;
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS payment_method TEXT DEFAULT 'efectivo';
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS name_driver TEXT;
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS photo_driver TEXT;
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS total_final NUMERIC(10, 2) DEFAULT 0.00;
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS "isReview" BOOLEAN DEFAULT false;
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS is_review BOOLEAN DEFAULT false;
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS codigo INTEGER;
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS cancel_reason TEXT;
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS arrived_at TIMESTAMPTZ;
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;
ALTER TABLE public.trips ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_trips_user_id ON public.trips(user_id);
CREATE INDEX IF NOT EXISTS idx_trips_driver_id ON public.trips(driver_id);
CREATE INDEX IF NOT EXISTS idx_trips_status ON public.trips(status);

ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso total trips autenticados" ON public.trips;
CREATE POLICY "Acceso total trips autenticados" ON public.trips FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Acceso total trips anon" ON public.trips;
CREATE POLICY "Acceso total trips anon" ON public.trips FOR ALL TO anon USING (true) WITH CHECK (true);

-- ==============================================================================
-- 5. TABLA: ads (Publicidad y Banners)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.ads (
    id BIGSERIAL PRIMARY KEY,
    imagen_ads TEXT,
    titulo_ads TEXT,
    descripcion_ads TEXT,
    visitas INTEGER DEFAULT 0,
    vistas INTEGER DEFAULT 0,
    numero_contacto TEXT,
    whatsapp TEXT,
    clicks_contacto INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS imagen_ads TEXT;
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS titulo_ads TEXT;
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS descripcion_ads TEXT;
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS visitas INTEGER DEFAULT 0;
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS vistas INTEGER DEFAULT 0;
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS numero_contacto TEXT;
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS whatsapp TEXT;
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS clicks_contacto INTEGER DEFAULT 0;
ALTER TABLE public.ads ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE public.ads ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso total ads autenticados" ON public.ads;
CREATE POLICY "Acceso total ads autenticados" ON public.ads FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Acceso total ads anon" ON public.ads;
CREATE POLICY "Acceso total ads anon" ON public.ads FOR ALL TO anon USING (true) WITH CHECK (true);

-- ==============================================================================
-- 6. TABLA: ratings (Calificaciones y Reseñas)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.ratings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id TEXT,
    reviewer_id TEXT,
    target_id TEXT,
    role TEXT,
    rating NUMERIC(3, 2) DEFAULT 5.0,
    comment TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.ratings ADD COLUMN IF NOT EXISTS trip_id TEXT;
ALTER TABLE public.ratings ADD COLUMN IF NOT EXISTS reviewer_id TEXT;
ALTER TABLE public.ratings ADD COLUMN IF NOT EXISTS target_id TEXT;
ALTER TABLE public.ratings ADD COLUMN IF NOT EXISTS role TEXT;
ALTER TABLE public.ratings ADD COLUMN IF NOT EXISTS rating NUMERIC(3, 2) DEFAULT 5.0;
ALTER TABLE public.ratings ADD COLUMN IF NOT EXISTS comment TEXT;
ALTER TABLE public.ratings ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_ratings_target_id ON public.ratings(target_id);
CREATE INDEX IF NOT EXISTS idx_ratings_trip_reviewer ON public.ratings(trip_id, reviewer_id);

ALTER TABLE public.ratings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso total ratings autenticados" ON public.ratings;
CREATE POLICY "Acceso total ratings autenticados" ON public.ratings FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Acceso total ratings anon" ON public.ratings;
CREATE POLICY "Acceso total ratings anon" ON public.ratings FOR ALL TO anon USING (true) WITH CHECK (true);

-- ==============================================================================
-- 7. TABLA: facturacion (Ingresos y Tickets)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.facturacion (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cantidad NUMERIC(12, 2) DEFAULT 0.00,
    metodo_pago TEXT,
    fecha_servicio TIMESTAMPTZ DEFAULT NOW(),
    status TEXT DEFAULT 'completado',
    email TEXT,
    telefono TEXT,
    razon_social TEXT,
    datos_adicionales JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.facturacion ADD COLUMN IF NOT EXISTS cantidad NUMERIC(12, 2) DEFAULT 0.00;
ALTER TABLE public.facturacion ADD COLUMN IF NOT EXISTS metodo_pago TEXT;
ALTER TABLE public.facturacion ADD COLUMN IF NOT EXISTS fecha_servicio TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.facturacion ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'completado';
ALTER TABLE public.facturacion ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE public.facturacion ADD COLUMN IF NOT EXISTS telefono TEXT;
ALTER TABLE public.facturacion ADD COLUMN IF NOT EXISTS razon_social TEXT;
ALTER TABLE public.facturacion ADD COLUMN IF NOT EXISTS datos_adicionales JSONB;
ALTER TABLE public.facturacion ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE public.facturacion ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso total facturacion autenticados" ON public.facturacion;
CREATE POLICY "Acceso total facturacion autenticados" ON public.facturacion FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Acceso total facturacion anon" ON public.facturacion;
CREATE POLICY "Acceso total facturacion anon" ON public.facturacion FOR ALL TO anon USING (true) WITH CHECK (true);

-- ==============================================================================
-- 8. TABLA: zonas_tarifa_dinamica (Zonas de Geo-tarifa Dinámica)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.zonas_tarifa_dinamica (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    lat DOUBLE PRECISION NOT NULL,
    lng DOUBLE PRECISION NOT NULL,
    radius_km DOUBLE PRECISION NOT NULL,
    percentage_increase DOUBLE PRECISION NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.zonas_tarifa_dinamica ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso total zonas autenticados" ON public.zonas_tarifa_dinamica;
CREATE POLICY "Acceso total zonas autenticados" ON public.zonas_tarifa_dinamica FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Acceso total zonas anon" ON public.zonas_tarifa_dinamica;
CREATE POLICY "Acceso total zonas anon" ON public.zonas_tarifa_dinamica FOR ALL TO anon USING (true) WITH CHECK (true);

-- ==============================================================================
-- 9. TABLA: tarifas_mapas_calor_perse (Multiplicadores por Densidad)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.tarifas_mapas_calor_perse (
    id SERIAL PRIMARY KEY,
    "Densidad" TEXT NOT NULL UNIQUE,
    "Porcentaje" NUMERIC DEFAULT 0
);

ALTER TABLE public.tarifas_mapas_calor_perse ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso total tarifas calor autenticados" ON public.tarifas_mapas_calor_perse;
CREATE POLICY "Acceso total tarifas calor autenticados" ON public.tarifas_mapas_calor_perse FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Acceso total tarifas calor anon" ON public.tarifas_mapas_calor_perse;
CREATE POLICY "Acceso total tarifas calor anon" ON public.tarifas_mapas_calor_perse FOR ALL TO anon USING (true) WITH CHECK (true);

-- Inserción de valores iniciales si no existen
INSERT INTO public.tarifas_mapas_calor_perse ("Densidad", "Porcentaje")
VALUES 
    ('Alta', 20),
    ('Media', 10),
    ('Baja', 0)
ON CONFLICT ("Densidad") DO NOTHING;

-- ==============================================================================
-- 10. TABLAS: fechas_corte & cortes_conductores (Cortes de Comisiones)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.fechas_corte (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fecha_corte DATE NOT NULL DEFAULT CURRENT_DATE,
    periodo_inicio DATE NOT NULL,
    periodo_fin DATE NOT NULL,
    total_conductores INTEGER NOT NULL DEFAULT 0,
    conductores_pagados INTEGER NOT NULL DEFAULT 0,
    conductores_pendientes INTEGER NOT NULL DEFAULT 0,
    total_ingresos_generados NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    total_comision_20 NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    estatus TEXT NOT NULL DEFAULT 'abierto',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.cortes_conductores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    corte_id UUID REFERENCES public.fechas_corte(id) ON DELETE CASCADE,
    periodo_inicio DATE NOT NULL,
    periodo_fin DATE NOT NULL,
    fecha_corte DATE NOT NULL DEFAULT CURRENT_DATE,
    conductor_id TEXT NOT NULL,
    nombre_conductor TEXT NOT NULL DEFAULT 'Conductor',
    correo_conductor TEXT,
    telefono_conductor TEXT,
    total_viajes INTEGER NOT NULL DEFAULT 0,
    total_generado NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    comision_app NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    saldo_a_pagar NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    estatus_pago TEXT NOT NULL DEFAULT 'pendiente',
    fecha_pago TIMESTAMPTZ,
    metodo_pago TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT uq_corte_periodo_conductor UNIQUE (conductor_id, periodo_inicio, periodo_fin)
);

ALTER TABLE public.cortes_conductores ADD COLUMN IF NOT EXISTS corte_id UUID REFERENCES public.fechas_corte(id) ON DELETE CASCADE;
ALTER TABLE public.cortes_conductores ADD COLUMN IF NOT EXISTS periodo_inicio DATE;
ALTER TABLE public.cortes_conductores ADD COLUMN IF NOT EXISTS periodo_fin DATE;
ALTER TABLE public.cortes_conductores ADD COLUMN IF NOT EXISTS fecha_corte DATE DEFAULT CURRENT_DATE;
ALTER TABLE public.cortes_conductores ADD COLUMN IF NOT EXISTS conductor_id TEXT;
ALTER TABLE public.cortes_conductores ADD COLUMN IF NOT EXISTS nombre_conductor TEXT DEFAULT 'Conductor';
ALTER TABLE public.cortes_conductores ADD COLUMN IF NOT EXISTS correo_conductor TEXT;
ALTER TABLE public.cortes_conductores ADD COLUMN IF NOT EXISTS telefono_conductor TEXT;
ALTER TABLE public.cortes_conductores ADD COLUMN IF NOT EXISTS total_viajes INTEGER DEFAULT 0;
ALTER TABLE public.cortes_conductores ADD COLUMN IF NOT EXISTS total_generado NUMERIC(12, 2) DEFAULT 0.00;
ALTER TABLE public.cortes_conductores ADD COLUMN IF NOT EXISTS comision_app NUMERIC(12, 2) DEFAULT 0.00;
ALTER TABLE public.cortes_conductores ADD COLUMN IF NOT EXISTS saldo_a_pagar NUMERIC(12, 2) DEFAULT 0.00;
ALTER TABLE public.cortes_conductores ADD COLUMN IF NOT EXISTS estatus_pago TEXT DEFAULT 'pendiente';
ALTER TABLE public.cortes_conductores ADD COLUMN IF NOT EXISTS fecha_pago TIMESTAMPTZ;
ALTER TABLE public.cortes_conductores ADD COLUMN IF NOT EXISTS metodo_pago TEXT;
ALTER TABLE public.cortes_conductores ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE public.fechas_corte ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cortes_conductores ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Acceso total fechas_corte autenticados" ON public.fechas_corte;
CREATE POLICY "Acceso total fechas_corte autenticados" ON public.fechas_corte FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Acceso total fechas_corte anon" ON public.fechas_corte;
CREATE POLICY "Acceso total fechas_corte anon" ON public.fechas_corte FOR ALL TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Acceso total cortes_conductores autenticados" ON public.cortes_conductores;
CREATE POLICY "Acceso total cortes_conductores autenticados" ON public.cortes_conductores FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Acceso total cortes_conductores anon" ON public.cortes_conductores;
CREATE POLICY "Acceso total cortes_conductores anon" ON public.cortes_conductores FOR ALL TO anon USING (true) WITH CHECK (true);

-- ==============================================================================
-- 11. TABLA: horarios_conductores (Turnos y Conexión)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.horarios_conductores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conductor_id TEXT,
    fecha DATE DEFAULT CURRENT_DATE,
    hora_conexion TIMESTAMPTZ DEFAULT NOW(),
    hora_desconexion TIMESTAMPTZ,
    minutos_activo NUMERIC DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.horarios_conductores ADD COLUMN IF NOT EXISTS conductor_id TEXT;
ALTER TABLE public.horarios_conductores ADD COLUMN IF NOT EXISTS fecha DATE DEFAULT CURRENT_DATE;
ALTER TABLE public.horarios_conductores ADD COLUMN IF NOT EXISTS hora_conexion TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.horarios_conductores ADD COLUMN IF NOT EXISTS hora_desconexion TIMESTAMPTZ;
ALTER TABLE public.horarios_conductores ADD COLUMN IF NOT EXISTS minutos_activo NUMERIC DEFAULT 0;
ALTER TABLE public.horarios_conductores ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE public.horarios_conductores ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Acceso total horarios autenticados" ON public.horarios_conductores;
CREATE POLICY "Acceso total horarios autenticados" ON public.horarios_conductores FOR ALL TO authenticated USING (true) WITH CHECK (true);
DROP POLICY IF EXISTS "Acceso total horarios anon" ON public.horarios_conductores;
CREATE POLICY "Acceso total horarios anon" ON public.horarios_conductores FOR ALL TO anon USING (true) WITH CHECK (true);

-- ==============================================================================
-- 12. STORAGE BUCKET: general
-- ==============================================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('general', 'general', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "Permitir subida general autenticados" ON storage.objects;
CREATE POLICY "Permitir subida general autenticados" ON storage.objects
FOR INSERT TO authenticated WITH CHECK (bucket_id = 'general');

DROP POLICY IF EXISTS "Permitir subida general anon" ON storage.objects;
CREATE POLICY "Permitir subida general anon" ON storage.objects
FOR INSERT TO anon WITH CHECK (bucket_id = 'general');

DROP POLICY IF EXISTS "Permitir lectura general publica" ON storage.objects;
CREATE POLICY "Permitir lectura general publica" ON storage.objects
FOR SELECT USING (bucket_id = 'general');

DROP POLICY IF EXISTS "Permitir eliminacion general autenticados" ON storage.objects;
CREATE POLICY "Permitir eliminacion general autenticados" ON storage.objects
FOR DELETE TO authenticated USING (bucket_id = 'general');

DROP POLICY IF EXISTS "Permitir eliminacion general anon" ON storage.objects;
CREATE POLICY "Permitir eliminacion general anon" ON storage.objects
FOR DELETE TO anon USING (bucket_id = 'general');

-- ==============================================================================
-- 13. FUNCIÓN Y TRIGGER: GEOFENCE CHIAPAS
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.check_trip_origin_in_chiapas()
RETURNS TRIGGER AS $$
DECLARE
  v_has_special_permission BOOLEAN := FALSE;
BEGIN
  IF NEW.origin_lat IS NOT NULL AND NEW.origin_lng IS NOT NULL THEN
    IF NEW.origin_lat < 14.50 OR NEW.origin_lat > 18.05 
       OR NEW.origin_lng < -94.25 OR NEW.origin_lng > -90.30 THEN
      BEGIN
        SELECT (
          COALESCE(has_special_location_permission, false) OR 
          COALESCE(bypass_geofence, false) OR 
          COALESCE(permiso_especial_ubicacion, false)
        )
        INTO v_has_special_permission
        FROM public.users
        WHERE user_id = NEW.user_id;
      EXCEPTION WHEN OTHERS THEN
        v_has_special_permission := FALSE;
      END;

      IF v_has_special_permission IS NOT TRUE THEN
        RAISE EXCEPTION 'El servicio solo está disponible para solicitar conductores en el estado de Chiapas.';
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_check_trip_origin_in_chiapas ON public.trips;
CREATE TRIGGER tr_check_trip_origin_in_chiapas
BEFORE INSERT ON public.trips
FOR EACH ROW
EXECUTE FUNCTION public.check_trip_origin_in_chiapas();

-- ==============================================================================
-- 14. FUNCIÓN: generar_corte_cada_dos_dias()
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.generar_corte_cada_dos_dias()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_corte_id UUID;
    v_inicio DATE;
    v_fin DATE;
    v_total_viajes_periodo INTEGER := 0;
    v_conductores_count INTEGER := 0;
    v_ingresos_totales NUMERIC(12,2) := 0.00;
    v_comision_total NUMERIC(12,2) := 0.00;
    v_record RECORD;
BEGIN
    v_fin := CURRENT_DATE - INTERVAL '1 day';
    v_inicio := v_fin - INTERVAL '1 day';

    SELECT id INTO v_corte_id
    FROM public.fechas_corte
    WHERE periodo_inicio = v_inicio AND periodo_fin = v_fin
    LIMIT 1;

    IF v_corte_id IS NOT NULL THEN
        RETURN jsonb_build_object(
            'status', 'skipped',
            'message', 'El corte para este periodo ya fue generado previamente.',
            'corte_id', v_corte_id,
            'periodo_inicio', v_inicio,
            'periodo_fin', v_fin
        );
    END IF;

    INSERT INTO public.fechas_corte (
        fecha_corte,
        periodo_inicio,
        periodo_fin,
        estatus
    ) VALUES (
        CURRENT_DATE,
        v_inicio,
        v_fin,
        'abierto'
    ) RETURNING id INTO v_corte_id;

    FOR v_record IN
        SELECT 
            t.driver_id,
            COALESCE(c.nombre_completo, c.nombre, 'Conductor') AS nombre,
            c.correo,
            c.telefono,
            COUNT(t.id) AS cant_viajes,
            COALESCE(SUM(t.fare), 0.00) AS total_fare
        FROM public.trips t
        LEFT JOIN public.conductores c ON (c.user_id = t.driver_id OR c.id = t.driver_id)
        WHERE t.status = 'completed'
          AND t.driver_id IS NOT NULL
          AND t.created_at >= v_inicio::timestamptz
          AND t.created_at < (v_fin + INTERVAL '1 day')::timestamptz
        GROUP BY t.driver_id, c.nombre_completo, c.nombre, c.correo, c.telefono
    LOOP
        INSERT INTO public.cortes_conductores (
            corte_id,
            periodo_inicio,
            periodo_fin,
            fecha_corte,
            conductor_id,
            nombre_conductor,
            correo_conductor,
            telefono_conductor,
            total_viajes,
            total_generado,
            comision_app,
            saldo_a_pagar,
            estatus_pago
        ) VALUES (
            v_corte_id,
            v_inicio,
            v_fin,
            CURRENT_DATE,
            v_record.driver_id,
            v_record.nombre,
            v_record.correo,
            v_record.telefono,
            v_record.cant_viajes,
            v_record.total_fare,
            ROUND(v_record.total_fare * 0.20, 2),
            ROUND(v_record.total_fare * 0.20, 2),
            'pendiente'
        );

        v_conductores_count := v_conductores_count + 1;
        v_total_viajes_periodo := v_total_viajes_periodo + v_record.cant_viajes;
        v_ingresos_totales := v_ingresos_totales + v_record.total_fare;
        v_comision_total := v_comision_total + ROUND(v_record.total_fare * 0.20, 2);
    END LOOP;

    UPDATE public.fechas_corte
    SET 
        total_conductores = v_conductores_count,
        conductores_pendientes = v_conductores_count,
        conductores_pagados = 0,
        total_ingresos_generados = v_ingresos_totales,
        total_comision_20 = v_comision_total
    WHERE id = v_corte_id;

    RETURN jsonb_build_object(
        'status', 'success',
        'message', 'Corte generado exitosamente',
        'corte_id', v_corte_id,
        'conductores_procesados', v_conductores_count,
        'total_ingresos', v_ingresos_totales,
        'comision_esperada', v_comision_total
    );
END;
$$;
