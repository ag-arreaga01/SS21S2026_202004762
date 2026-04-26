-- ============================================================
-- CONSULTAS DE EXPLORACIÓN
-- ============================================================

-- Query básica para explorar los datos
SELECT *
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
LIMIT 10;

-- Query para contar registros totales
SELECT COUNT(*) AS total_registros
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`;

-- Query para ver las columnas de la tabla
SELECT column_name, data_type
FROM `bigquery-public-data.new_york_taxi_trips.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'tlc_yellow_trips_2022';

-- ============================================================
-- CONSULTAS AVANZADAS
-- ============================================================

-- Consulta de viajes por mes
SELECT
  EXTRACT(MONTH FROM pickup_datetime) AS mes,
  COUNT(*) AS total_viajes
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
GROUP BY mes
ORDER BY mes;

-- Consulta de promedio de costos
SELECT
  AVG(total_amount) AS promedio_pago
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`;

-- Consulta de ubicaciones con más viajes
SELECT
  pickup_location_id,
  COUNT(*) AS total_viajes
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
GROUP BY pickup_location_id
ORDER BY total_viajes DESC
LIMIT 10;

-- ============================================================
-- OPTIMIZACIÓN DE CONSULTAS
-- ============================================================

-- Consulta sin optimización
SELECT COUNT(*) AS viajes
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
WHERE DATE(pickup_datetime) = '2022-02-01';

-- Consulta optimizada con particionamiento
SELECT COUNT(*) AS viajes
FROM `august-outlet-493903-h3.proyecto2.trips_cleaned`
WHERE pickup_datetime BETWEEN '2022-01-01' AND '2022-01-02';

-- ============================================================
-- EVALUACIÓN DE MODELOS DE MACHINE LEARNING
-- ============================================================

-- Evaluación modelo de regresión (MAE, RMSE, R²)
SELECT *
FROM ML.EVALUATE(MODEL `project-ad13d6df-6ba4-487d-a1e.Proyecto2SS2.modelo_regresion`);

-- Evaluación modelo de clasificación (Accuracy, Precision, Recall, F1, ROC-AUC)
SELECT *
FROM ML.EVALUATE(MODEL `project-ad13d6df-6ba4-487d-a1e.Proyecto2SS2.modelo_clasificacion`);

-- ============================================================
-- PREDICCIONES
-- ============================================================

-- Predicciones del modelo de regresión
SELECT
  predicted_total_amount,
  total_amount,
  trip_distance,
  hora,
  dia_semana,
  duracion_minutos
FROM ML.PREDICT(MODEL `project-ad13d6df-6ba4-487d-a1e.Proyecto2SS2.modelo_regresion`,
  (SELECT * FROM `project-ad13d6df-6ba4-487d-a1e.Proyecto2SS2.trips_features`
   LIMIT 100));

-- Predicciones del modelo de clasificación
SELECT
  predicted_es_fin_semana,
  es_fin_semana,
  hora,
  dia_semana,
  trip_distance
FROM ML.PREDICT(MODEL `project-ad13d6df-6ba4-487d-a1e.Proyecto2SS2.modelo_clasificacion`,
  (SELECT * FROM `project-ad13d6df-6ba4-487d-a1e.Proyecto2SS2.trips_features`
   LIMIT 100));
   