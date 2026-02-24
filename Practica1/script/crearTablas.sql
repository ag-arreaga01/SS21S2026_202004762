-- ====== DIMENSIONES ======

IF OBJECT_ID('dim_aerolinea', 'U') IS NOT NULL DROP TABLE dim_aerolinea;
CREATE TABLE dim_aerolinea (
  aerolinea_key INT IDENTITY(1,1) PRIMARY KEY,
  airline_code  VARCHAR(10) NOT NULL,
  airline_name  VARCHAR(200) NULL,
  CONSTRAINT uq_dim_aerolinea UNIQUE (airline_code)
);

IF OBJECT_ID('dim_ruta', 'U') IS NOT NULL DROP TABLE dim_ruta;
CREATE TABLE dim_ruta (
  ruta_key INT IDENTITY(1,1) PRIMARY KEY,
  origin_airport      VARCHAR(10) NOT NULL,
  destination_airport VARCHAR(10) NOT NULL,
  CONSTRAINT uq_dim_ruta UNIQUE (origin_airport, destination_airport)
);

IF OBJECT_ID('dim_pasajero', 'U') IS NOT NULL DROP TABLE dim_pasajero;
CREATE TABLE dim_pasajero (
  pasajero_key INT IDENTITY(1,1) PRIMARY KEY,
  passenger_id          VARCHAR(50) NOT NULL,
  passenger_gender      VARCHAR(20) NULL,
  passenger_age         INT NULL,
  passenger_nationality VARCHAR(100) NULL,
  CONSTRAINT uq_dim_pasajero UNIQUE (passenger_id)
);

IF OBJECT_ID('dim_venta', 'U') IS NOT NULL DROP TABLE dim_venta;
CREATE TABLE dim_venta (
  venta_key INT IDENTITY(1,1) PRIMARY KEY,
  sales_channel  VARCHAR(50) NULL,
  payment_method VARCHAR(50) NULL,
  CONSTRAINT uq_dim_venta UNIQUE (sales_channel, payment_method)
);

IF OBJECT_ID('dim_vuelo_detalle', 'U') IS NOT NULL DROP TABLE dim_vuelo_detalle;
CREATE TABLE dim_vuelo_detalle (
  vuelo_detalle_key INT IDENTITY(1,1) PRIMARY KEY,
  flight_number VARCHAR(20) NULL,
  aircraft_type VARCHAR(50) NULL,
  cabin_class   VARCHAR(50) NULL,
  seat          VARCHAR(20) NULL,
  status        VARCHAR(30) NULL,
  currency      VARCHAR(10) NULL,
  CONSTRAINT uq_dim_vuelo_detalle UNIQUE (flight_number, aircraft_type, cabin_class, seat, status, currency)
);

IF OBJECT_ID('dim_tiempo', 'U') IS NOT NULL DROP TABLE dim_tiempo;
CREATE TABLE dim_tiempo (
  tiempo_key INT IDENTITY(1,1) PRIMARY KEY,
  fecha       DATE NOT NULL,
  anio        INT  NOT NULL,
  mes         INT  NOT NULL,
  dia         INT  NOT NULL,
  dia_semana  INT  NOT NULL,
  nombre_mes  VARCHAR(20) NULL,
  CONSTRAINT uq_dim_tiempo UNIQUE (fecha)
);

-- ====== HECHOS ======

IF OBJECT_ID('fact_vuelo', 'U') IS NOT NULL DROP TABLE fact_vuelo;
CREATE TABLE fact_vuelo (
  fact_vuelo_key BIGINT IDENTITY(1,1) PRIMARY KEY,

  -- llaves de dimensiones
  aerolinea_key INT NOT NULL,
  ruta_key      INT NOT NULL,
  pasajero_key  INT NOT NULL,
  venta_key     INT NOT NULL,
  vuelo_detalle_key INT NOT NULL,

  departure_tiempo_key INT NULL,
  booking_tiempo_key   INT NULL,

  -- ID del registro original
  record_id VARCHAR(50) NOT NULL,

  -- medidas
  duration_min INT NULL,
  delay_min    INT NULL,
  ticket_price_usd_est DECIMAL(18,2) NULL,
  ticket_price         DECIMAL(18,2) NULL,
  bags_total   INT NULL,
  bags_checked INT NULL,

  -- timestamps originales
  departure_datetime DATETIME2 NULL,
  arrival_datetime   DATETIME2 NULL,
  booking_datetime   DATETIME2 NULL,

  CONSTRAINT fk_fact_aerolinea FOREIGN KEY (aerolinea_key) REFERENCES dim_aerolinea(aerolinea_key),
  CONSTRAINT fk_fact_ruta      FOREIGN KEY (ruta_key)      REFERENCES dim_ruta(ruta_key),
  CONSTRAINT fk_fact_pasajero  FOREIGN KEY (pasajero_key)  REFERENCES dim_pasajero(pasajero_key),
  CONSTRAINT fk_fact_venta     FOREIGN KEY (venta_key)     REFERENCES dim_venta(venta_key),
  CONSTRAINT fk_fact_vuelo_detalle FOREIGN KEY (vuelo_detalle_key) REFERENCES dim_vuelo_detalle(vuelo_detalle_key),
  CONSTRAINT fk_fact_departure_tiempo FOREIGN KEY (departure_tiempo_key) REFERENCES dim_tiempo(tiempo_key),
  CONSTRAINT fk_fact_booking_tiempo   FOREIGN KEY (booking_tiempo_key)   REFERENCES dim_tiempo(tiempo_key)
);

-- Índices
CREATE INDEX ix_fact_departure_time ON fact_vuelo(departure_tiempo_key);
CREATE INDEX ix_fact_booking_time   ON fact_vuelo(booking_tiempo_key);