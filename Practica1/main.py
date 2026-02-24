import pandas as pd
import sqlalchemy as sa

CSV_PATH = r"data\dataset_vuelos_crudo.csv"

SERVER = "localhost"
PORT = 1433
DATABASE = "Practica1_Semi2"
USERNAME = "sa"
PASSWORD = "SqlServer#2026!"

CONN_STR = (
    "mssql+pyodbc://{user}:{pwd}@{server}:{port}/{db}"
    "?driver=ODBC+Driver+18+for+SQL+Server"
    "&Encrypt=yes"
    "&TrustServerCertificate=yes"
).format(
    user=USERNAME, pwd=PASSWORD, server=SERVER, port=PORT, db=DATABASE
)

engine = sa.create_engine(CONN_STR, fast_executemany=True)

def compute_dia_semana_sun1(dt_series: pd.Series) -> pd.Series:
    return ((dt_series.dt.weekday + 1) % 7) + 1

def normalize_gender(s: pd.Series) -> pd.Series:
    x = s.astype(str).str.strip().str.upper()
    x = x.replace({"": pd.NA, "NAN": pd.NA, "NONE": pd.NA, "NULL": pd.NA})
    m = {"M": "M", "MALE": "M", "HOMBRE": "M", "MASCULINO": "M"}
    f = {"F": "F", "FEMALE": "F", "MUJER": "F", "FEMENINO": "F"}

    out = []
    for v in x:
        if pd.isna(v):
            out.append(pd.NA)
        elif v in m:
            out.append("M")
        elif v in f:
            out.append("F")
        else:
            out.append("O")
    return pd.Series(out, index=s.index, dtype="string")

# -----------------------------
# Build dims
# -----------------------------
def build_dim_tiempo(df: pd.DataFrame) -> pd.DataFrame:
    dep_fecha = df["departure_datetime"].dt.date
    book_fecha = df["booking_datetime"].dt.date

    fechas = pd.Series(list(dep_fecha) + list(book_fecha)).dropna().drop_duplicates()
    dim = pd.DataFrame({"fecha": pd.to_datetime(fechas)})

    dim["anio"] = dim["fecha"].dt.year.astype("Int64")
    dim["mes"] = dim["fecha"].dt.month.astype("Int64")
    dim["dia"] = dim["fecha"].dt.day.astype("Int64")
    dim["dia_semana"] = compute_dia_semana_sun1(dim["fecha"]).astype("Int64")
    dim["nombre_mes"] = dim["fecha"].dt.month_name()
    return dim

def build_dim_aerolinea(df: pd.DataFrame) -> pd.DataFrame:
    dim = df[["airline_code", "airline_name"]].copy()
    dim["airline_code"] = dim["airline_code"].astype(str).str.strip().str.upper()
    dim["airline_name"] = dim["airline_name"].astype(str).str.strip()
    dim = dim.dropna(subset=["airline_code"]).drop_duplicates(subset=["airline_code"])
    return dim

def build_dim_ruta(df: pd.DataFrame) -> pd.DataFrame:
    dim = df[["origin_airport", "destination_airport"]].copy()
    dim["origin_airport"] = dim["origin_airport"].astype(str).str.strip().str.upper()
    dim["destination_airport"] = dim["destination_airport"].astype(str).str.strip().str.upper()
    dim = dim.dropna(subset=["origin_airport", "destination_airport"])
    dim = dim.drop_duplicates(subset=["origin_airport", "destination_airport"])
    return dim

def build_dim_pasajero(df: pd.DataFrame) -> pd.DataFrame:
    dim = df[["passenger_id", "passenger_gender", "passenger_age", "passenger_nationality"]].copy()
    dim["passenger_id"] = dim["passenger_id"].astype(str).str.strip().str.upper()
    dim["passenger_gender"] = normalize_gender(dim["passenger_gender"])
    dim["passenger_age"] = pd.to_numeric(dim["passenger_age"], errors="coerce").astype("Int64")
    dim["passenger_nationality"] = dim["passenger_nationality"].astype(str).str.strip().replace({"": pd.NA, "nan": pd.NA, "NAN": pd.NA})
    dim = dim.dropna(subset=["passenger_id"]).drop_duplicates(subset=["passenger_id"])
    return dim

def build_dim_venta(df: pd.DataFrame) -> pd.DataFrame:
    dim = df[["sales_channel", "payment_method"]].copy()
    dim["sales_channel"] = dim["sales_channel"].astype(str).str.strip().str.upper().replace({"": pd.NA, "NAN": pd.NA})
    dim["payment_method"] = dim["payment_method"].astype(str).str.strip().str.upper().replace({"": pd.NA, "NAN": pd.NA})
    dim["sales_channel"] = dim["sales_channel"].fillna("UNKNOWN")
    dim["payment_method"] = dim["payment_method"].fillna("UNKNOWN")
    dim = dim.drop_duplicates(subset=["sales_channel", "payment_method"])
    return dim

def build_dim_vuelo_detalle(df: pd.DataFrame) -> pd.DataFrame:
    cols = ["flight_number", "aircraft_type", "cabin_class", "seat", "status", "currency"]
    dim = df[cols].copy()
    for c in cols:
        dim[c] = dim[c].astype(str).str.strip().str.upper().replace({"": pd.NA, "NAN": pd.NA})
    dim["seat"] = dim["seat"].fillna("UNKNOWN")
    for c in ["status", "currency", "flight_number", "aircraft_type", "cabin_class"]:
        dim[c] = dim[c].fillna("UNKNOWN")
    dim = dim.drop_duplicates(subset=cols)
    return dim

# -----------------------------
# Load dims
# -----------------------------
def load_dim_simple_unique(conn, table: str, dim_df: pd.DataFrame, unique_cols: list[str]):
    cols_sql = ", ".join(unique_cols)
    existing = pd.read_sql(sa.text(f"SELECT {cols_sql} FROM {table}"), conn)

    if existing.empty:
        existing_keys = set()
    else:
        for c in unique_cols:
            existing[c] = existing[c].astype(str).str.strip().str.upper()
        existing_keys = set(map(tuple, existing[unique_cols].values.tolist()))

    work = dim_df.copy()
    for c in unique_cols:
        work[c] = work[c].astype(str).str.strip().str.upper()

    work["__k__"] = list(map(tuple, work[unique_cols].values.tolist()))
    to_insert = work[~work["__k__"].isin(existing_keys)].drop(columns="__k__")

    print(f"[{table}] existentes: {len(existing_keys)} | nuevos: {len(to_insert)}")
    if len(to_insert) > 0:
        to_insert.to_sql(table, conn, if_exists="append", index=False)
        print(f"[{table}] insert OK")

def load_dim_tiempo(conn, dim_tiempo: pd.DataFrame):
    existing = pd.read_sql(sa.text("SELECT fecha FROM dim_tiempo"), conn)
    if not existing.empty:
        existing["fecha"] = pd.to_datetime(existing["fecha"], errors="coerce")
        existing_set = set(existing["fecha"].dt.date.dropna())
    else:
        existing_set = set()

    work = dim_tiempo.copy()
    work["fecha_date"] = work["fecha"].dt.date
    to_insert = work[~work["fecha_date"].isin(existing_set)].drop(columns="fecha_date")

    print(f"[dim_tiempo] existentes: {len(existing_set)} | nuevos: {len(to_insert)}")
    if len(to_insert) > 0:
        to_insert.to_sql("dim_tiempo", conn, if_exists="append", index=False)
        print("[dim_tiempo] insert OK")

# -----------------------------
# Build & Load FACT
# -----------------------------
def build_fact_input(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()

    df["airline_code"] = df["airline_code"].astype(str).str.strip().str.upper()
    df["origin_airport"] = df["origin_airport"].astype(str).str.strip().str.upper()
    df["destination_airport"] = df["destination_airport"].astype(str).str.strip().str.upper()
    df["passenger_id"] = df["passenger_id"].astype(str).str.strip().str.upper()

    df["sales_channel"] = df["sales_channel"].astype(str).str.strip().str.upper().replace({"": pd.NA, "NAN": pd.NA}).fillna("UNKNOWN")
    df["payment_method"] = df["payment_method"].astype(str).str.strip().str.upper().replace({"": pd.NA, "NAN": pd.NA}).fillna("UNKNOWN")

    # vuelo_detalle
    detalle_cols = ["flight_number", "aircraft_type", "cabin_class", "seat", "status", "currency"]
    for c in detalle_cols:
        df[c] = df[c].astype(str).str.strip().str.upper().replace({"": pd.NA, "NAN": pd.NA})
    df["seat"] = df["seat"].fillna("UNKNOWN")
    for c in ["status", "currency", "flight_number", "aircraft_type", "cabin_class"]:
        df[c] = df[c].fillna("UNKNOWN")

    # medidas
    df["ticket_price"] = df["ticket_price"].astype(str).str.strip().str.replace(",", ".", regex=False)
    df["ticket_price"] = pd.to_numeric(df["ticket_price"], errors="coerce")

    df["duration_min"] = pd.to_numeric(df["duration_min"], errors="coerce").astype("Int64")
    df["delay_min"] = pd.to_numeric(df["delay_min"], errors="coerce").astype("Int64")
    df["bags_total"] = pd.to_numeric(df["bags_total"], errors="coerce").astype("Int64")
    df["bags_checked"] = pd.to_numeric(df["bags_checked"], errors="coerce").astype("Int64")
    df["ticket_price_usd_est"] = pd.to_numeric(df["ticket_price_usd_est"], errors="coerce")

    df["dep_fecha"] = df["departure_datetime"].dt.date
    df["book_fecha"] = df["booking_datetime"].dt.date
    return df

def load_fact_vuelo(conn, df: pd.DataFrame):
    detalle_cols = ["flight_number", "aircraft_type", "cabin_class", "seat", "status", "currency"]

    dim_a = pd.read_sql(sa.text("SELECT aerolinea_key, airline_code FROM dim_aerolinea"), conn)
    dim_r = pd.read_sql(sa.text("SELECT ruta_key, origin_airport, destination_airport FROM dim_ruta"), conn)
    dim_p = pd.read_sql(sa.text("SELECT pasajero_key, passenger_id FROM dim_pasajero"), conn)
    dim_v = pd.read_sql(sa.text("SELECT venta_key, sales_channel, payment_method FROM dim_venta"), conn)
    dim_d = pd.read_sql(sa.text("""
        SELECT vuelo_detalle_key, flight_number, aircraft_type, cabin_class, seat, status, currency
        FROM dim_vuelo_detalle
    """), conn)
    dim_t = pd.read_sql(sa.text("SELECT tiempo_key, fecha FROM dim_tiempo"), conn)

    # normalizar dims
    dim_a["airline_code"] = dim_a["airline_code"].astype(str).str.strip().str.upper()
    dim_r["origin_airport"] = dim_r["origin_airport"].astype(str).str.strip().str.upper()
    dim_r["destination_airport"] = dim_r["destination_airport"].astype(str).str.strip().str.upper()
    dim_p["passenger_id"] = dim_p["passenger_id"].astype(str).str.strip().str.upper()
    dim_v["sales_channel"] = dim_v["sales_channel"].astype(str).str.strip().str.upper()
    dim_v["payment_method"] = dim_v["payment_method"].astype(str).str.strip().str.upper()
    for c in detalle_cols:
        dim_d[c] = dim_d[c].astype(str).str.strip().str.upper()

    dim_t["fecha"] = pd.to_datetime(dim_t["fecha"], errors="coerce")
    dim_t["fecha_date"] = dim_t["fecha"].dt.date

    # lookups
    fact = df.merge(dim_a, on="airline_code", how="left")
    fact = fact.merge(dim_r, on=["origin_airport", "destination_airport"], how="left")
    fact = fact.merge(dim_p, on="passenger_id", how="left")
    fact = fact.merge(dim_v, on=["sales_channel", "payment_method"], how="left")
    fact = fact.merge(dim_d, on=detalle_cols, how="left")
    fact = fact.merge(dim_t[["tiempo_key", "fecha_date"]].rename(columns={"tiempo_key": "departure_tiempo_key", "fecha_date": "dep_fecha"}),on="dep_fecha", how="left")
    fact = fact.merge(dim_t[["tiempo_key", "fecha_date"]].rename(columns={"tiempo_key": "booking_tiempo_key", "fecha_date": "book_fecha"}),on="book_fecha", how="left")

    required_fk = ["aerolinea_key", "ruta_key", "pasajero_key", "venta_key", "vuelo_detalle_key"]
    missing = {c: int(fact[c].isna().sum()) for c in required_fk}
    #print("Faltantes por FK requerida:", missing)
    if any(v > 0 for v in missing.values()):
        print("No se insertará fact_vuelo: hay FKs faltantes.")
        return

    fact_insert = pd.DataFrame({
        "aerolinea_key": fact["aerolinea_key"].astype(int),
        "ruta_key": fact["ruta_key"].astype(int),
        "pasajero_key": fact["pasajero_key"].astype(int),
        "venta_key": fact["venta_key"].astype(int),
        "vuelo_detalle_key": fact["vuelo_detalle_key"].astype(int),
        "departure_tiempo_key": fact["departure_tiempo_key"].astype("Int64"),
        "booking_tiempo_key": fact["booking_tiempo_key"].astype("Int64"),
        "record_id": fact["record_id"].astype(str),
        "duration_min": fact["duration_min"].astype("Int64"),
        "delay_min": fact["delay_min"].astype("Int64"),
        "ticket_price_usd_est": fact["ticket_price_usd_est"],
        "ticket_price": fact["ticket_price"],
        "bags_total": fact["bags_total"].astype("Int64"),
        "bags_checked": fact["bags_checked"].astype("Int64"),
        "departure_datetime": fact["departure_datetime"],
        "arrival_datetime": fact["arrival_datetime"],
        "booking_datetime": fact["booking_datetime"],
    })

    existing_ids = pd.read_sql(sa.text("SELECT record_id FROM fact_vuelo"), conn)
    existing_set = set(existing_ids["record_id"].astype(str)) if not existing_ids.empty else set()
    to_insert = fact_insert[~fact_insert["record_id"].isin(existing_set)].copy()

    print("Fact existentes:", len(existing_set), "| Nuevos a insertar:", len(to_insert))
    if len(to_insert) > 0:
        to_insert.to_sql("fact_vuelo", conn, if_exists="append", index=False)
        print("fact_vuelo insert OK")

# -----------------------------
# MAIN
# -----------------------------
def main():
    df = pd.read_csv(CSV_PATH)

    # Parse fechas
    df["departure_datetime"] = pd.to_datetime(df["departure_datetime"], errors="coerce", dayfirst=True)
    df["arrival_datetime"] = pd.to_datetime(df["arrival_datetime"], errors="coerce", dayfirst=True)
    df["booking_datetime"] = pd.to_datetime(df["booking_datetime"], errors="coerce", dayfirst=True)

    # Construir dims
    dim_tiempo = build_dim_tiempo(df)
    dim_aerolinea = build_dim_aerolinea(df)
    dim_ruta = build_dim_ruta(df)
    dim_pasajero = build_dim_pasajero(df)
    dim_venta = build_dim_venta(df)
    dim_vuelo_detalle = build_dim_vuelo_detalle(df)

    # Cargar dims y fact
    with engine.begin() as conn:
        load_dim_tiempo(conn, dim_tiempo)
        load_dim_simple_unique(conn, "dim_aerolinea", dim_aerolinea, ["airline_code"])
        load_dim_simple_unique(conn, "dim_ruta", dim_ruta, ["origin_airport", "destination_airport"])
        load_dim_simple_unique(conn, "dim_pasajero", dim_pasajero, ["passenger_id"])
        load_dim_simple_unique(conn, "dim_venta", dim_venta, ["sales_channel", "payment_method"])
        load_dim_simple_unique(conn, "dim_vuelo_detalle", dim_vuelo_detalle, ["flight_number", "aircraft_type", "cabin_class", "seat", "status", "currency"])

        # FACT
        fact_input = build_fact_input(df)
        load_fact_vuelo(conn, fact_input)

        totals = {
            "dim_tiempo": conn.execute(sa.text("SELECT COUNT(*) FROM dim_tiempo")).scalar_one(),
            "dim_aerolinea": conn.execute(sa.text("SELECT COUNT(*) FROM dim_aerolinea")).scalar_one(),
            "dim_ruta": conn.execute(sa.text("SELECT COUNT(*) FROM dim_ruta")).scalar_one(),
            "dim_pasajero": conn.execute(sa.text("SELECT COUNT(*) FROM dim_pasajero")).scalar_one(),
            "dim_venta": conn.execute(sa.text("SELECT COUNT(*) FROM dim_venta")).scalar_one(),
            "dim_vuelo_detalle": conn.execute(sa.text("SELECT COUNT(*) FROM dim_vuelo_detalle")).scalar_one(),
            "fact_vuelo": conn.execute(sa.text("SELECT COUNT(*) FROM fact_vuelo")).scalar_one(),
        }
        for k, v in totals.items():
            print(f"{k}: {v}")

if __name__ == "__main__":
    main()