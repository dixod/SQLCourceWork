from pathlib import Path
import random
import zipfile

import pandas as pd


ROOT = Path(__file__).resolve().parents[1]
ZIP_PATH = ROOT / "cost-of-living.csv.zip"
OUT_DIR = ROOT / "data"
RANDOM_SEED = 0

ITEMS = [
    ("x1", "Meal, Inexpensive Restaurant", "USD", "Restaurants"),
    ("x2", "Meal for 2 People, Mid-range Restaurant, Three-course", "USD", "Restaurants"),
    ("x3", "McMeal at McDonalds (or Equivalent Combo Meal)", "USD", "Restaurants"),
    ("x4", "Domestic Beer (0.5 liter draught, in restaurants)", "USD", "Restaurants"),
    ("x5", "Imported Beer (0.33 liter bottle, in restaurants)", "USD", "Restaurants"),
    ("x6", "Cappuccino (regular, in restaurants)", "USD", "Restaurants"),
    ("x7", "Coke/Pepsi (0.33 liter bottle, in restaurants)", "USD", "Restaurants"),
    ("x8", "Water (0.33 liter bottle, in restaurants)", "USD", "Restaurants"),
    ("x9", "Milk (regular), 1 liter", "USD", "Groceries"),
    ("x10", "Loaf of Fresh White Bread (500g)", "USD", "Groceries"),
    ("x11", "Rice (white), 1kg", "USD", "Groceries"),
    ("x12", "Eggs (regular), 12", "USD", "Groceries"),
    ("x13", "Local Cheese, 1kg", "USD", "Groceries"),
    ("x14", "Chicken Fillets, 1kg", "USD", "Groceries"),
    ("x15", "Beef Round, 1kg (or Equivalent Back Leg Red Meat)", "USD", "Groceries"),
    ("x16", "Apples, 1kg", "USD", "Groceries"),
    ("x17", "Banana, 1kg", "USD", "Groceries"),
    ("x18", "Oranges, 1kg", "USD", "Groceries"),
    ("x19", "Tomato, 1kg", "USD", "Groceries"),
    ("x20", "Potato, 1kg", "USD", "Groceries"),
    ("x21", "Onion, 1kg", "USD", "Groceries"),
    ("x22", "Lettuce, 1 head", "USD", "Groceries"),
    ("x23", "Water (1.5 liter bottle, at the market)", "USD", "Groceries"),
    ("x24", "Bottle of Wine (Mid-Range, at the market)", "USD", "Groceries"),
    ("x25", "Domestic Beer (0.5 liter bottle, at the market)", "USD", "Groceries"),
    ("x26", "Imported Beer (0.33 liter bottle, at the market)", "USD", "Groceries"),
    ("x27", "Cigarettes 20 Pack (Marlboro)", "USD", "Groceries"),
    ("x28", "One-way Ticket (Local Transport)", "USD", "Transportation"),
    ("x29", "Monthly Pass (Regular Price)", "USD", "Transportation"),
    ("x30", "Taxi Start (Normal Tariff)", "USD", "Transportation"),
    ("x31", "Taxi 1km (Normal Tariff)", "USD", "Transportation"),
    ("x32", "Taxi 1hour Waiting (Normal Tariff)", "USD", "Transportation"),
    ("x33", "Gasoline, 1 liter", "USD", "Transportation"),
    ("x34", "Volkswagen Golf 1.4 90 KW Trendline (or Equivalent New Car)", "USD", "Transportation"),
    ("x35", "Toyota Corolla Sedan 1.6l 97kW Comfort (or Equivalent New Car)", "USD", "Transportation"),
    ("x36", "Basic Utilities for 85m2 Apartment", "USD", "Utilities and Connectivity"),
    ("x37", "1 min. of Prepaid Mobile Tariff Local", "USD", "Utilities and Connectivity"),
    ("x38", "Internet (60 Mbps or More, Unlimited Data, Cable/ADSL)", "USD", "Utilities and Connectivity"),
    ("x39", "Fitness Club, Monthly Fee for 1 Adult", "USD", "Leisure"),
    ("x40", "Tennis Court Rent (1 Hour on Weekend)", "USD", "Leisure"),
    ("x41", "Cinema, International Release, 1 Seat", "USD", "Leisure"),
    ("x42", "Preschool, Full Day, Private, Monthly for 1 Child", "USD", "Education and Childcare"),
    ("x43", "International Primary School, Yearly for 1 Child", "USD", "Education and Childcare"),
    ("x44", "1 Pair of Jeans (Levis 501 or Similar)", "USD", "Clothing"),
    ("x45", "1 Summer Dress in a Chain Store", "USD", "Clothing"),
    ("x46", "1 Pair of Nike Running Shoes (Mid-Range)", "USD", "Clothing"),
    ("x47", "1 Pair of Men Leather Business Shoes", "USD", "Clothing"),
    ("x48", "Apartment (1 bedroom) in City Centre", "USD", "Housing"),
    ("x49", "Apartment (1 bedroom) Outside of Centre", "USD", "Housing"),
    ("x50", "Apartment (3 bedrooms) in City Centre", "USD", "Housing"),
    ("x51", "Apartment (3 bedrooms) Outside of Centre", "USD", "Housing"),
    ("x52", "Price per Square Meter to Buy Apartment in City Centre", "USD", "Housing"),
    ("x53", "Price per Square Meter to Buy Apartment Outside of Centre", "USD", "Housing"),
    ("x54", "Average Monthly Net Salary (After Tax)", "USD", "Income"),
    ("x55", "Mortgage Interest Rate, Yearly, 20 Years Fixed-Rate", "%", "Finance"),
]


def main() -> None:
    with zipfile.ZipFile(ZIP_PATH) as archive:
        names = [name for name in archive.namelist() if name.lower().endswith(".csv")]
        if len(names) != 1:
            raise ValueError("Expected exactly one CSV in the source ZIP")
        with archive.open(names[0]) as source:
            df = pd.read_csv(source, encoding="utf-8-sig")

    codes = [item[0] for item in ITEMS]
    required = {"city", "country", "data_quality", *codes}
    missing = required - set(df.columns)
    if missing:
        raise ValueError(f"Missing source columns: {sorted(missing)}")

    df = df.rename(columns={
        "city": "city_name", "country": "country_name", "data_quality": "data_quality_code"
    })
    for column in ("city_name", "country_name"):
        df[column] = df[column].astype("string").str.strip()
        if df[column].isna().any() or df[column].eq("").any():
            raise ValueError(f"Empty values in {column}")
    df["data_quality_code"] = pd.to_numeric(df["data_quality_code"], errors="raise")
    if not df["data_quality_code"].isin([0, 1]).all():
        raise ValueError("Data quality must be 0 or 1")
    df["data_quality_code"] = df["data_quality_code"].astype(int)
    if df.duplicated(["city_name", "country_name"]).any():
        raise ValueError("Duplicate city and country in source data")

    countries = df[["country_name"]].drop_duplicates().sort_values("country_name")
    cities = df[["city_name", "country_name", "data_quality_code"]].sort_values(
        ["country_name", "city_name"]
    )
    items = pd.DataFrame(ITEMS, columns=["item_code", "item_name", "unit", "category_name"])
    values = df[["city_name", "country_name", *codes]].melt(
        id_vars=["city_name", "country_name"], value_vars=codes,
        var_name="item_code", value_name="cost_value"
    )
    values["cost_value"] = pd.to_numeric(values["cost_value"], errors="raise")
    values = values.dropna(subset=["cost_value"])
    if values["cost_value"].lt(0).any() or values["cost_value"].isin([float("inf"), -float("inf")]).any():
        raise ValueError("Cost values must be finite and non-negative")

    rng = random.Random(RANDOM_SEED)
    city_pairs = list(cities[["city_name", "country_name"]].itertuples(index=False, name=None))
    favorites = []
    for number in range(1, 251):
        picked = rng.sample(city_pairs, min(len(city_pairs), 1 + number % 2))
        for index, (city_name, country_name) in enumerate(picked):
            favorites.append([
                f"user{number:03d}@example.com", f"User {number:03d}", city_name, country_name,
                f"2026-01-{(number - 1) % 28 + 1:02d} {9 + index:02d}:00:00"
            ])
    favorites = pd.DataFrame(favorites, columns=[
        "user_email", "user_name", "city_name", "country_name", "created_at"
    ])

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, frame in [
        ("countries", countries), ("cities", cities), ("cost_items", items),
        ("city_cost_values", values), ("user_favorite_cities", favorites)
    ]:
        frame.to_csv(OUT_DIR / f"{name}.csv", index=False)
        print(f"{name}.csv: {len(frame)} rows")


if __name__ == "__main__":
    main()
