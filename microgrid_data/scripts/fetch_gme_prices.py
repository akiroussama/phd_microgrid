"""
Telecharger les prix electricite du marche italien (GME)
Zone: CALA (Calabre) — site de Reggio Calabria
Source: GME (Gestore dei Mercati Energetici S.p.A.)
API: via librairie mercati-energetici

Reference: https://github.com/darcato/mercati-energetici
"""

import asyncio
import csv
import os
from datetime import date, timedelta

async def fetch_prices():
    try:
        from mercati_energetici import MGP
    except ImportError:
        print("ERROR: pip install mercati-energetici")
        return

    output_dir = os.path.join(os.path.dirname(__file__), '..', 'downloads')

    async with MGP() as mgp:
        # Telecharger PUN (prix national) pour juin 2025
        # (le mois le plus proche du papier Prattico)
        print("Fetching GME PUN prices for June 2025...")

        all_rows = []

        start = date(2025, 6, 1)
        end = date(2025, 6, 30)
        current = start

        while current <= end:
            try:
                data = await mgp.get_pun(current)
                if data:
                    for entry in data:
                        hour = entry.get('ora', entry.get('hour', 0))
                        price = entry.get('prezzo', entry.get('price', 0))
                        # GME returns EUR/MWh, convert to EUR/kWh
                        price_kwh = price / 1000.0
                        all_rows.append({
                            'date': current.isoformat(),
                            'hour': hour,
                            'price_EUR_MWh': price,
                            'price_EUR_kWh': round(price_kwh, 5)
                        })
                print(f"  {current}: {len(data) if data else 0} hours")
            except Exception as e:
                print(f"  {current}: ERROR - {e}")
            current += timedelta(days=1)

        if all_rows:
            output_file = os.path.join(output_dir, 'gme_pun_june_2025.csv')
            with open(output_file, 'w', newline='') as f:
                writer = csv.DictWriter(f, fieldnames=['date', 'hour', 'price_EUR_MWh', 'price_EUR_kWh'])
                writer.writeheader()
                writer.writerows(all_rows)
            print(f"\nWrote {len(all_rows)} rows to gme_pun_june_2025.csv")

            # Stats
            prices = [r['price_EUR_kWh'] for r in all_rows]
            print(f"Price range: {min(prices):.4f} - {max(prices):.4f} EUR/kWh")
            print(f"Mean: {sum(prices)/len(prices):.4f} EUR/kWh")
            print(f"Paper range: 0.05 - 0.15 EUR/kWh")
        else:
            print("No data retrieved. GME API may require specific access.")
            print("Creating fallback with typical Italian prices from ARERA data...")
            create_fallback(output_dir)

def create_fallback(output_dir):
    """Create realistic Italian prices from ARERA published tariff bands"""
    print("\nCreating realistic Italian tariff from ARERA bands...")

    # ARERA tariff bands 2024-2025 (Autorita di Regolazione per Energia Reti e Ambiente)
    # F1 (peak): 08-19 weekdays = ~0.12 EUR/kWh
    # F2 (mid):  07-08, 19-23 weekdays + 07-23 Saturday = ~0.10 EUR/kWh
    # F3 (off):  23-07 all days + Sunday = ~0.07 EUR/kWh
    # Source: ARERA delibera 654/2023/R/EEL

    rows = []
    for day in range(1, 31):  # June 1-30
        d = f"2025-06-{day:02d}"
        weekday = (date(2025, 6, day).weekday())  # 0=Monday, 6=Sunday

        for hour in range(24):
            if weekday == 6:  # Sunday = F3
                price = 0.07
                band = 'F3'
            elif weekday == 5:  # Saturday
                if 7 <= hour < 23:
                    price = 0.10
                    band = 'F2'
                else:
                    price = 0.07
                    band = 'F3'
            else:  # Weekday
                if 8 <= hour < 19:
                    price = 0.12
                    band = 'F1'
                elif 7 <= hour < 8 or 19 <= hour < 23:
                    price = 0.10
                    band = 'F2'
                else:
                    price = 0.07
                    band = 'F3'

            rows.append({
                'date': d,
                'hour': hour,
                'price_EUR_kWh': price,
                'band': band,
                'source': 'ARERA 654/2023'
            })

    output_file = os.path.join(output_dir, 'italian_tariff_arera_june_2025.csv')
    with open(output_file, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=['date', 'hour', 'price_EUR_kWh', 'band', 'source'])
        writer.writeheader()
        writer.writerows(rows)

    prices = [r['price_EUR_kWh'] for r in rows]
    print(f"Wrote {len(rows)} rows to italian_tariff_arera_june_2025.csv")
    print(f"Price range: {min(prices):.2f} - {max(prices):.2f} EUR/kWh")
    print(f"Bands: F1(peak)=0.12, F2(mid)=0.10, F3(off)=0.07 EUR/kWh")
    print(f"Source: ARERA delibera 654/2023/R/EEL")

if __name__ == '__main__':
    try:
        asyncio.run(fetch_prices())
    except Exception as e:
        print(f"GME API failed: {e}")
        print("Using ARERA fallback...")
        output_dir = os.path.join(os.path.dirname(__file__), '..', 'downloads')
        create_fallback(output_dir)
