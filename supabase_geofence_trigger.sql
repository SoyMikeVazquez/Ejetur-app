-- ==============================================================================
-- TRIGGER DE SEGURIDAD: LIMITAR SOLICITUDES DE VIAJES EXCLUSIVAMENTE A CHIAPAS
-- ==============================================================================
-- Este trigger se ejecuta en Supabase antes de insertar cualquier viaje en 'trips'.
-- Si el origen está fuera de Chiapas y el usuario no tiene permiso especial, 
-- la base de datos rechaza la inserción inmediatamente.

-- 1. Función validadora de Geofence
CREATE OR REPLACE FUNCTION public.check_trip_origin_in_chiapas()
RETURNS TRIGGER AS $$
DECLARE
  v_has_special_permission BOOLEAN := FALSE;
BEGIN
  -- Coordenadas de Chiapas (Bounding Box):
  -- Latitud: entre 14.50 y 18.05
  -- Longitud: entre -94.25 y -90.30

  IF NEW.origin_lat IS NOT NULL AND NEW.origin_lng IS NOT NULL THEN
    -- Si las coordenadas están fuera del Bounding Box de Chiapas:
    IF NEW.origin_lat < 14.50 OR NEW.origin_lat > 18.05 
       OR NEW.origin_lng < -94.25 OR NEW.origin_lng > -90.30 THEN

      -- Verificar si el usuario tiene permiso especial en la tabla users
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

      -- Si no tiene permiso especial, se rechaza la inserción
      IF v_has_special_permission IS NOT TRUE THEN
        RAISE EXCEPTION 'El servicio de TaxiSeguro solo está disponible para solicitar conductores en el estado de Chiapas.';
      END IF;

    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Vincular el trigger a la tabla trips
DROP TRIGGER IF EXISTS tr_check_trip_origin_in_chiapas ON public.trips;

CREATE TRIGGER tr_check_trip_origin_in_chiapas
BEFORE INSERT ON public.trips
FOR EACH ROW
EXECUTE FUNCTION public.check_trip_origin_in_chiapas();

