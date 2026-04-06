/*
  Proyecto 1 - SGFood Data Warehouse DDL
  Modelo estrella basado en columnas detectadas en SGFood_Proyecto1_Muestra.xlsx
*/

SET NOCOUNT ON;
GO

IF DB_ID('SGFoodDW') IS NULL
BEGIN
    CREATE DATABASE SGFoodDW;
END;
GO

USE SGFoodDW;
GO

/* Limpieza opcional para re-ejecutar el script */
IF OBJECT_ID('dbo.FactVentasInventario', 'U') IS NOT NULL DROP TABLE dbo.FactVentasInventario;
IF OBJECT_ID('dbo.DimProducto', 'U') IS NOT NULL DROP TABLE dbo.DimProducto;
IF OBJECT_ID('dbo.DimUbicacion', 'U') IS NOT NULL DROP TABLE dbo.DimUbicacion;
IF OBJECT_ID('dbo.DimCanal', 'U') IS NOT NULL DROP TABLE dbo.DimCanal;
IF OBJECT_ID('dbo.DimCliente', 'U') IS NOT NULL DROP TABLE dbo.DimCliente;
IF OBJECT_ID('dbo.DimFecha', 'U') IS NOT NULL DROP TABLE dbo.DimFecha;
GO

/* =========================
   DIMENSIONES
   ========================= */

CREATE TABLE dbo.DimFecha
(
    FechaKey            INT             NOT NULL PRIMARY KEY, -- yyyymmdd
    FechaCompleta       DATE            NOT NULL,
    Anio                SMALLINT        NOT NULL,
    Trimestre           TINYINT         NOT NULL,
    Mes                 TINYINT         NOT NULL,
    NombreMes           NVARCHAR(20)    NOT NULL,
    Dia                 TINYINT         NOT NULL,
    NombreDiaSemana     NVARCHAR(20)    NOT NULL,
    EsFinDeSemana       BIT             NOT NULL
);
GO

CREATE TABLE dbo.DimCliente
(
    ClienteKey          INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    ClienteId           NVARCHAR(30)      NOT NULL,
    ClienteNombre       NVARCHAR(200)     NOT NULL,
    SegmentoCliente     NVARCHAR(100)     NOT NULL,
    FechaInicioVigencia DATE              NOT NULL DEFAULT ('1900-01-01'),
    FechaFinVigencia    DATE              NOT NULL DEFAULT ('9999-12-31'),
    EsActual            BIT               NOT NULL DEFAULT (1)
);
GO

CREATE UNIQUE INDEX UX_DimCliente_BK_Actual
    ON dbo.DimCliente (ClienteId, EsActual);
GO

CREATE TABLE dbo.DimCanal
(
    CanalKey            INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    CanalVenta          NVARCHAR(100)     NOT NULL
);
GO

CREATE UNIQUE INDEX UX_DimCanal_CanalVenta
    ON dbo.DimCanal (CanalVenta);
GO

CREATE TABLE dbo.DimUbicacion
(
    UbicacionKey        INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    Departamento        NVARCHAR(100)     NOT NULL,
    Municipio           NVARCHAR(100)     NOT NULL
);
GO

CREATE UNIQUE INDEX UX_DimUbicacion_DepMuni
    ON dbo.DimUbicacion (Departamento, Municipio);
GO

CREATE TABLE dbo.DimProducto
(
    ProductoKey         INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    ProductoSKU         NVARCHAR(50)      NOT NULL,
    ProductoNombre      NVARCHAR(200)     NOT NULL,
    Marca               NVARCHAR(100)     NOT NULL,
    Categoria           NVARCHAR(100)     NOT NULL,
    Subcategoria        NVARCHAR(100)     NOT NULL,
    Fabricante          NVARCHAR(100)     NOT NULL,
    FechaInicioVigencia DATE              NOT NULL DEFAULT ('1900-01-01'),
    FechaFinVigencia    DATE              NOT NULL DEFAULT ('9999-12-31'),
    EsActual            BIT               NOT NULL DEFAULT (1)
);
GO

CREATE UNIQUE INDEX UX_DimProducto_BK_Actual
    ON dbo.DimProducto (ProductoSKU, EsActual);
GO

/* =========================
   TABLA DE HECHOS
   ========================= */

CREATE TABLE dbo.FactVentasInventario
(
    FactKey             BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,

    FechaKey            INT                 NOT NULL,
    ClienteKey          INT                 NOT NULL,
    CanalKey            INT                 NOT NULL,
    UbicacionKey        INT                 NOT NULL,
    ProductoKey         INT                 NOT NULL,

    CantidadVendida     INT                 NOT NULL,
    InventarioInicial   INT                 NOT NULL,
    InventarioFinal     INT                 NOT NULL,

    PrecioUnitario      DECIMAL(18,4)       NOT NULL,
    CostoUnitario       DECIMAL(18,4)       NOT NULL,
    Descuento           DECIMAL(18,4)       NOT NULL,
    ImporteNeto         DECIMAL(18,4)       NOT NULL,
    MargenEstimado      DECIMAL(18,4)       NOT NULL,

    FechaCarga          DATETIME2           NOT NULL DEFAULT (SYSDATETIME())
);
GO

ALTER TABLE dbo.FactVentasInventario WITH CHECK ADD CONSTRAINT FK_Fact_DimFecha
    FOREIGN KEY (FechaKey) REFERENCES dbo.DimFecha (FechaKey);

ALTER TABLE dbo.FactVentasInventario WITH CHECK ADD CONSTRAINT FK_Fact_DimCliente
    FOREIGN KEY (ClienteKey) REFERENCES dbo.DimCliente (ClienteKey);

ALTER TABLE dbo.FactVentasInventario WITH CHECK ADD CONSTRAINT FK_Fact_DimCanal
    FOREIGN KEY (CanalKey) REFERENCES dbo.DimCanal (CanalKey);

ALTER TABLE dbo.FactVentasInventario WITH CHECK ADD CONSTRAINT FK_Fact_DimUbicacion
    FOREIGN KEY (UbicacionKey) REFERENCES dbo.DimUbicacion (UbicacionKey);

ALTER TABLE dbo.FactVentasInventario WITH CHECK ADD CONSTRAINT FK_Fact_DimProducto
    FOREIGN KEY (ProductoKey) REFERENCES dbo.DimProducto (ProductoKey);
GO

CREATE INDEX IX_FactVentasInventario_FechaKey ON dbo.FactVentasInventario(FechaKey);
CREATE INDEX IX_FactVentasInventario_ClienteKey ON dbo.FactVentasInventario(ClienteKey);
CREATE INDEX IX_FactVentasInventario_ProductoKey ON dbo.FactVentasInventario(ProductoKey);
GO

/* =========================
   FILAS DESCONOCIDAS
   ========================= */

IF NOT EXISTS (SELECT 1 FROM dbo.DimFecha WHERE FechaKey = 0)
BEGIN
    INSERT INTO dbo.DimFecha (FechaKey, FechaCompleta, Anio, Trimestre, Mes, NombreMes, Dia, NombreDiaSemana, EsFinDeSemana)
    VALUES (0, '1900-01-01', 1900, 1, 1, 'Desconocido', 1, 'Desconocido', 0);
END;

IF NOT EXISTS (SELECT 1 FROM dbo.DimCliente WHERE ClienteKey = 0)
BEGIN
    SET IDENTITY_INSERT dbo.DimCliente ON;
    INSERT INTO dbo.DimCliente (ClienteKey, ClienteId, ClienteNombre, SegmentoCliente, FechaInicioVigencia, FechaFinVigencia, EsActual)
    VALUES (0, 'N/A', 'Cliente Desconocido', 'Desconocido', '1900-01-01', '9999-12-31', 1);
    SET IDENTITY_INSERT dbo.DimCliente OFF;
END;

IF NOT EXISTS (SELECT 1 FROM dbo.DimCanal WHERE CanalKey = 0)
BEGIN
    SET IDENTITY_INSERT dbo.DimCanal ON;
    INSERT INTO dbo.DimCanal (CanalKey, CanalVenta)
    VALUES (0, 'Desconocido');
    SET IDENTITY_INSERT dbo.DimCanal OFF;
END;

IF NOT EXISTS (SELECT 1 FROM dbo.DimUbicacion WHERE UbicacionKey = 0)
BEGIN
    SET IDENTITY_INSERT dbo.DimUbicacion ON;
    INSERT INTO dbo.DimUbicacion (UbicacionKey, Departamento, Municipio)
    VALUES (0, 'Desconocido', 'Desconocido');
    SET IDENTITY_INSERT dbo.DimUbicacion OFF;
END;

IF NOT EXISTS (SELECT 1 FROM dbo.DimProducto WHERE ProductoKey = 0)
BEGIN
    SET IDENTITY_INSERT dbo.DimProducto ON;
    INSERT INTO dbo.DimProducto
    (
        ProductoKey, ProductoSKU, ProductoNombre, Marca, Categoria, Subcategoria, Fabricante,
        FechaInicioVigencia, FechaFinVigencia, EsActual
    )
    VALUES
    (
        0, 'N/A', 'Producto Desconocido', 'Desconocido', 'Desconocido', 'Desconocido', 'Desconocido',
        '1900-01-01', '9999-12-31', 1
    );
    SET IDENTITY_INSERT dbo.DimProducto OFF;
END;
GO

PRINT 'DDL SGFoodDW creado correctamente.';
GO
