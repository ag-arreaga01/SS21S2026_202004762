-- 1. Total de vuelos
SELECT COUNT(*) AS total_vuelos FROM fact_vuelo;


-- 2. Top 5 destinos más frecuentes
SELECT TOP 5 r.destination_airport, COUNT(*) AS total_vuelos
FROM fact_vuelo f
JOIN dim_ruta r ON f.ruta_key = r.ruta_key
GROUP BY r.destination_airport
ORDER BY total_vuelos DESC;


-- 3. Ingresos por canal de venta
SELECT v.sales_channel, SUM(COALESCE(f.ticket_price_usd_est,0)) AS ingresos_usd
FROM fact_vuelo f
JOIN dim_venta v ON f.venta_key = v.venta_key
GROUP BY v.sales_channel
ORDER BY ingresos_usd DESC;


-- 4. Duración promedio de vuelos por ruta (Top 10 rutas más frecuentes)
SELECT TOP 10 
    r.origin_airport,
    r.destination_airport,
    ROUND(AVG(CAST(f.duration_min AS float)), 0) AS duracion_promedio,
    COUNT(*) AS total_vuelos
FROM fact_vuelo f
JOIN dim_ruta r ON f.ruta_key = r.ruta_key
GROUP BY r.origin_airport, r.destination_airport
ORDER BY total_vuelos DESC;


-- 5. Pasajeros por nacionalidad (Top 10)
SELECT TOP 10 
    p.passenger_nationality,
    COUNT(*) AS total_pasajeros,
    ROUND(AVG(CAST(p.passenger_age AS float)), 0) AS edad_promedio
FROM fact_vuelo f
JOIN dim_pasajero p ON f.pasajero_key = p.pasajero_key
WHERE p.passenger_nationality IS NOT NULL
GROUP BY p.passenger_nationality
ORDER BY total_pasajeros DESC;


-- 6. Aeronaves más utilizados
SELECT TOP 10
    vd.aircraft_type,
    vd.cabin_class,
    COUNT(*) AS total_vuelos,
    ROUND(AVG(CAST(f.delay_min AS float)), 0) AS retraso_promedio
FROM fact_vuelo f
JOIN dim_vuelo_detalle vd ON f.vuelo_detalle_key = vd.vuelo_detalle_key
GROUP BY vd.aircraft_type, vd.cabin_class
ORDER BY total_vuelos DESC;


-- 7. Pasajeros por rango de edad y género
SELECT 
    p.passenger_gender,
    CASE 
        WHEN p.passenger_age < 18 THEN 'Menor'
        WHEN p.passenger_age BETWEEN 18 AND 35 THEN 'Joven'
        WHEN p.passenger_age BETWEEN 36 AND 55 THEN 'Adulto'
        ELSE 'Mayor'
    END AS rango_edad,
    COUNT(*) AS total_pasajeros
FROM fact_vuelo f
JOIN dim_pasajero p ON f.pasajero_key = p.pasajero_key
WHERE p.passenger_age IS NOT NULL
GROUP BY p.passenger_gender, 
    CASE 
        WHEN p.passenger_age < 18 THEN 'Menor'
        WHEN p.passenger_age BETWEEN 18 AND 35 THEN 'Joven'
        WHEN p.passenger_age BETWEEN 36 AND 55 THEN 'Adulto'
        ELSE 'Mayor'
    END
ORDER BY total_pasajeros DESC;


-- 8. Ingresos por mes
SELECT 
    dt.anio,
    dt.mes,
    dt.nombre_mes,
    COUNT(*) AS total_reservas,
    SUM(f.ticket_price_usd_est) AS ingresos_mes
FROM fact_vuelo f
JOIN dim_tiempo dt ON f.booking_tiempo_key = dt.tiempo_key
WHERE dt.anio IS NOT NULL AND dt.mes IS NOT NULL
GROUP BY dt.anio, dt.mes, dt.nombre_mes
ORDER BY dt.anio, dt.mes;