-- ============================================================
-- TABLA DERIVADA LIMPIA
-- ============================================================

CREATE OR REPLACE TABLE `august-outlet-493903-h3.proyecto2.trips_cleaned`
PARTITION BY DATE(pickup_datetime)
CLUSTER BY pickup_location_id, dropoff_location_id AS
SELECT
  pickup_datetime,
  dropoff_datetime,
  passenger_count,
  trip_distance,
  fare_amount,
  tip_amount,
  total_amount,
  payment_type,
  pickup_location_id,
  dropoff_location_id
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
WHERE 
  trip_distance > 0
  AND total_amount > 0
  AND passenger_count > 0
  AND dropoff_datetime > pickup_datetime;

-- ============================================================
-- TABLA DE FEATURES
-- ============================================================

CREATE OR REPLACE TABLE `august-outlet-493903-h3.proyecto2.trips_features` AS
SELECT
  -- Variables originales
  pickup_datetime,
  dropoff_datetime,
  passenger_count,
  trip_distance,
  total_amount,
  pickup_location_id,
  dropoff_location_id,

  -- FEATURES TEMPORALES
  EXTRACT(HOUR FROM pickup_datetime) AS hora,
  EXTRACT(DAYOFWEEK FROM pickup_datetime) AS dia_semana,
  EXTRACT(MONTH FROM pickup_datetime) AS mes,

  -- Fin de semana (1 = sí, 0 = no)
  CASE 
    WHEN EXTRACT(DAYOFWEEK FROM pickup_datetime) IN (1,7) THEN 1
    ELSE 0
  END AS es_fin_semana,

  -- Parte del día
  CASE
    WHEN EXTRACT(HOUR FROM pickup_datetime) BETWEEN 6 AND 11 THEN 'mañana'
    WHEN EXTRACT(HOUR FROM pickup_datetime) BETWEEN 12 AND 17 THEN 'tarde'
    WHEN EXTRACT(HOUR FROM pickup_datetime) BETWEEN 18 AND 23 THEN 'noche'
    ELSE 'madrugada'
  END AS parte_dia,

  -- FEATURES DE DURACIÓN
  TIMESTAMP_DIFF(dropoff_datetime, pickup_datetime, MINUTE) AS duracion_minutos,

  -- FEATURES ECONÓMICAS
  SAFE_DIVIDE(total_amount, trip_distance) AS costo_por_milla,
  SAFE_DIVIDE(tip_amount, total_amount) AS porcentaje_propina,

  -- FEATURES DE EFICIENCIA DEL VIAJE
  SAFE_DIVIDE(trip_distance, 
    TIMESTAMP_DIFF(dropoff_datetime, pickup_datetime, MINUTE)
  ) AS velocidad_promedio

FROM `august-outlet-493903-h3.proyecto2.trips_cleaned`
WHERE 
  dropoff_datetime > pickup_datetime
  AND trip_distance > 0;

-- ============================================================
-- MODELO 1: REGRESIÓN LINEAL
-- ============================================================

CREATE OR REPLACE MODEL `project-ad13d6df-6ba4-487d-a1e.Proyecto2SS2.modelo_regresion`
OPTIONS(
  model_type = 'linear_reg',
  input_label_cols = ['total_amount'],
  data_split_method = 'random',
  data_split_eval_fraction = 0.2
) AS
SELECT
  total_amount,
  hora,
  dia_semana,
  trip_distance,
  duracion_minutos,
  passenger_count,
  pickup_location_id
FROM `project-ad13d6df-6ba4-487d-a1e.Proyecto2SS2.trips_features`;

-- ============================================================
-- MODELO 2: REGRESIÓN LOGÍSTICA (CLASIFICACIÓN)
-- ============================================================

CREATE OR REPLACE MODEL `project-ad13d6df-6ba4-487d-a1e.Proyecto2SS2.modelo_clasificacion`
OPTIONS(
  model_type = 'logistic_reg',
  input_label_cols = ['es_fin_semana'],
  data_split_method = 'random',
  data_split_eval_fraction = 0.2
) AS
SELECT
  es_fin_semana,
  hora,
  dia_semana,
  trip_distance,
  duracion_minutos,
  passenger_count,
  pickup_location_id
FROM `project-ad13d6df-6ba4-487d-a1e.Proyecto2SS2.trips_features`;
