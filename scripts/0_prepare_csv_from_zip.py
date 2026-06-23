#!/usr/bin/env python3
"""Prepare five CSV files from the Kaggle cost-of-living ZIP."""

from pathlib import Path
import random
import zipfile

import pandas as pd


ZIP_PATH = Path("cost-of-living.csv.zip")
OUT_DIR = Path("data")
RANDOM_SEED = 0

# Official Kaggle data dictionary was available, so we use the real names.
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
    if not ZIP_PATH.is_file():
        raise FileNotFoundError(f"ZIP file not found: {ZIP_PATH}")

    with zipfile.ZipFile(ZIP_PATH) as zf:
        csv_names = [name for name in zf.namelist() if name.lower().endswith(".csv")]
        if len(csv_names) != 1:
            raise ValueError(f"Expected one CSV inside ZIP, found: {csv_names}")
        with zf.open(csv_names[0]) as f:
            df = pd.read_csv(f, encoding="utf-8-sig")

    OUT_DIR.mkdir(parents=True, exist_ok=True)

    # Clean up the source columns.
    df = df.rename(columns={"city": "city_name", "country": "country_name", "data_quality": "data_quality_code"})
    df["city_name"] = df["city_name"].astype(str).str.strip()
    df["country_name"] = df["country_name"].astype(str).str.strip()
    df["data_quality_code"] = pd.to_numeric(df["data_quality_code"], errors="raise").astype(int)

    # 1) countries.csv
    countries = df[["country_name"]].drop_duplicates().sort_values("country_name").reset_index(drop=True)
    countries.to_csv(OUT_DIR / "countries.csv", index=False)

    # 2) cities.csv
    cities = (
        df[["city_name", "country_name", "data_quality_code"]]
        .drop_duplicates(subset=["city_name", "country_name"])
        .sort_values(["country_name", "city_name"])
        .reset_index(drop=True)
    )
    cities.to_csv(OUT_DIR / "cities.csv", index=False)

    # 3) cost_items.csv
    cost_items = pd.DataFrame(ITEMS, columns=["item_code", "item_name", "unit", "category_name"])
    cost_items.to_csv(OUT_DIR / "cost_items.csv", index=False)

    # 4) city_cost_values.csv
    value_columns = [code for code, _, _, _ in ITEMS]
    city_cost_values = df[["city_name", "country_name", *value_columns]].melt(
        id_vars=["city_name", "country_name"],
        value_vars=value_columns,
        var_name="item_code",
        value_name="cost_value",
    )
    city_cost_values["cost_value"] = pd.to_numeric(city_cost_values["cost_value"], errors="coerce")
    city_cost_values = city_cost_values.dropna(subset=["cost_value"])
    city_cost_values = city_cost_values.drop_duplicates(subset=["city_name", "country_name", "item_code"])
    city_cost_values.to_csv(OUT_DIR / "city_cost_values.csv", index=False)

    # 5) user_favorite_cities.csv
    rng = random.Random(RANDOM_SEED)
    users = []
    city_pairs = cities[["city_name", "country_name"]].to_records(index=False).tolist()
    for n in range(1, 251):
        user_email = f"user{n:03d}@example.com"
        user_name = f"User {n:03d}"
        picked = rng.sample(city_pairs, 1 + n % 2)
        for i, (city_name, country_name) in enumerate(picked):
            created_at = f"2026-01-{(n - 1) % 28 + 1:02d} {9 + i:02d}:00:00"
            users.append([user_email, user_name, city_name, country_name, created_at])

    user_favorite_cities = pd.DataFrame(
        users,
        columns=["user_email", "user_name", "city_name", "country_name", "created_at"],
    ).drop_duplicates(subset=["user_email", "city_name", "country_name"])
    user_favorite_cities.to_csv(OUT_DIR / "user_favorite_cities.csv", index=False)

    print(f"countries.csv: {len(countries)} rows")
    print(f"cities.csv: {len(cities)} rows")
    print(f"cost_items.csv: {len(cost_items)} rows")
    print(f"city_cost_values.csv: {len(city_cost_values)} rows")
    print(f"user_favorite_cities.csv: {len(user_favorite_cities)} rows")


if __name__ == "__main__":
    main()
