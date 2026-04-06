/*
  Proyecto 1 - Validaciones de Data Warehouse
  Ejecutar en SQL Server (conexion a localhost,14333) sobre base SGFoodDW.
*/

USE SGFoodDW;
GO

/* =========================================================
   1) Conteos base por tabla
   ========================================================= */
SELECT 'DimCliente' AS tabla, COUNT(*) AS total FROM dbo.DimCliente
UNION ALL SELECT 'DimCanal', COUNT(*) FROM dbo.DimCanal
UNION ALL SELECT 'DimUbicacion', COUNT(*) FROM dbo.DimUbicacion
UNION ALL SELECT 'DimProducto', COUNT(*) FROM dbo.DimProducto
UNION ALL SELECT 'DimFecha', COUNT(*) FROM dbo.DimFecha
UNION ALL SELECT 'FactVentasInventario', COUNT(*) FROM dbo.FactVentasInventario;
GO

/* =========================================================
   2) Integridad referencial en tabla de hechos
   (orfandad y nulos en claves foraneas)
   ========================================================= */
SELECT
    SUM(CASE WHEN f.FechaKey IS NULL THEN 1 ELSE 0 END) AS fk_fecha_nula,
    SUM(CASE WHEN f.ClienteKey IS NULL THEN 1 ELSE 0 END) AS fk_cliente_nula,
    SUM(CASE WHEN f.CanalKey IS NULL THEN 1 ELSE 0 END) AS fk_canal_nula,
    SUM(CASE WHEN f.UbicacionKey IS NULL THEN 1 ELSE 0 END) AS fk_ubicacion_nula,
    SUM(CASE WHEN f.ProductoKey IS NULL THEN 1 ELSE 0 END) AS fk_producto_nula
FROM dbo.FactVentasInventario f;
GO

SELECT COUNT(*) AS filas_huerfanas
FROM dbo.FactVentasInventario f
LEFT JOIN dbo.DimFecha dfe ON dfe.FechaKey = f.FechaKey
LEFT JOIN dbo.DimCliente dcl ON dcl.ClienteKey = f.ClienteKey
LEFT JOIN dbo.DimCanal dca ON dca.CanalKey = f.CanalKey
LEFT JOIN dbo.DimUbicacion dub ON dub.UbicacionKey = f.UbicacionKey
LEFT JOIN dbo.DimProducto dpr ON dpr.ProductoKey = f.ProductoKey
WHERE dfe.FechaKey IS NULL
   OR dcl.ClienteKey IS NULL
   OR dca.CanalKey IS NULL
   OR dub.UbicacionKey IS NULL
   OR dpr.ProductoKey IS NULL;
GO

/* =========================================================
   3) Control de claves desconocidas (key = 0)
   ========================================================= */
SELECT
    SUM(CASE WHEN f.FechaKey = 0 THEN 1 ELSE 0 END) AS fecha_desconocida,
    SUM(CASE WHEN f.ClienteKey = 0 THEN 1 ELSE 0 END) AS cliente_desconocido,
    SUM(CASE WHEN f.CanalKey = 0 THEN 1 ELSE 0 END) AS canal_desconocido,
    SUM(CASE WHEN f.UbicacionKey = 0 THEN 1 ELSE 0 END) AS ubicacion_desconocida,
    SUM(CASE WHEN f.ProductoKey = 0 THEN 1 ELSE 0 END) AS producto_desconocido
FROM dbo.FactVentasInventario f;
GO

/* =========================================================
   4) Calidad de medidas (nulos / valores fuera de rango)
   ========================================================= */
SELECT
    SUM(CASE WHEN CantidadVendida IS NULL THEN 1 ELSE 0 END) AS cantidad_nula,
    SUM(CASE WHEN InventarioInicial IS NULL THEN 1 ELSE 0 END) AS inventario_inicial_nulo,
    SUM(CASE WHEN InventarioFinal IS NULL THEN 1 ELSE 0 END) AS inventario_final_nulo,
    SUM(CASE WHEN PrecioUnitario IS NULL THEN 1 ELSE 0 END) AS precio_nulo,
    SUM(CASE WHEN CostoUnitario IS NULL THEN 1 ELSE 0 END) AS costo_nulo,
    SUM(CASE WHEN ImporteNeto IS NULL THEN 1 ELSE 0 END) AS importe_nulo,
    SUM(CASE WHEN MargenEstimado IS NULL THEN 1 ELSE 0 END) AS margen_nulo
FROM dbo.FactVentasInventario;
GO

SELECT
    SUM(CASE WHEN CantidadVendida < 0 THEN 1 ELSE 0 END) AS cantidad_negativa,
    SUM(CASE WHEN PrecioUnitario < 0 THEN 1 ELSE 0 END) AS precio_negativo,
    SUM(CASE WHEN CostoUnitario < 0 THEN 1 ELSE 0 END) AS costo_negativo,
    SUM(CASE WHEN ImporteNeto < 0 THEN 1 ELSE 0 END) AS importe_negativo
FROM dbo.FactVentasInventario;
GO

/* =========================================================
   5) Validaciones espejo DW vs SSAS (1:1 con archivo MDX)
   ========================================================= */

/* 5.1) Totales generales */
SELECT
    SUM(f.CantidadVendida) AS cantidad_vendida,
    SUM(f.ImporteNeto) AS importe_neto,
    SUM(f.MargenEstimado) AS margen_estimado
FROM dbo.FactVentasInventario f;
GO

/* 5.2) Importe Neto por categoria */
SELECT
    p.Categoria,
    SUM(f.ImporteNeto) AS importe_neto
FROM dbo.FactVentasInventario f
INNER JOIN dbo.DimProducto p ON p.ProductoKey = f.ProductoKey
GROUP BY p.Categoria
ORDER BY p.Categoria;
GO

/* 5.3) Cantidad e Importe por canal */
SELECT
    c.CanalVenta,
    SUM(f.CantidadVendida) AS cantidad_vendida,
    SUM(f.ImporteNeto) AS importe_neto
FROM dbo.FactVentasInventario f
INNER JOIN dbo.DimCanal c ON c.CanalKey = f.CanalKey
GROUP BY c.CanalVenta
ORDER BY c.CanalVenta;
GO

/* 5.4) Importe Neto por anio y mes */
SELECT
    d.Anio,
    d.Mes,
    SUM(f.ImporteNeto) AS importe_neto
FROM dbo.FactVentasInventario f
INNER JOIN dbo.DimFecha d ON d.FechaKey = f.FechaKey
GROUP BY d.Anio, d.Mes
ORDER BY d.Anio, d.Mes;
GO

/* 5.5) Top 5 productos por Importe Neto */
SELECT TOP (5)
    p.ProductoNombre,
    SUM(f.ImporteNeto) AS importe_neto
FROM dbo.FactVentasInventario f
INNER JOIN dbo.DimProducto p ON p.ProductoKey = f.ProductoKey
GROUP BY p.ProductoNombre
ORDER BY SUM(f.ImporteNeto) DESC, p.ProductoNombre;
GO

/* 5.6) Importe Neto por municipio */
SELECT
    u.Municipio,
    SUM(f.ImporteNeto) AS importe_neto
FROM dbo.FactVentasInventario f
INNER JOIN dbo.DimUbicacion u ON u.UbicacionKey = f.UbicacionKey
GROUP BY u.Municipio
ORDER BY u.Municipio;
GO

/* 5.7) Cruce categoria x anio */
SELECT
    p.Categoria,
    d.Anio,
    SUM(f.ImporteNeto) AS importe_neto
FROM dbo.FactVentasInventario f
INNER JOIN dbo.DimProducto p ON p.ProductoKey = f.ProductoKey
INNER JOIN dbo.DimFecha d ON d.FechaKey = f.FechaKey
GROUP BY p.Categoria, d.Anio
ORDER BY p.Categoria, d.Anio;
GO
