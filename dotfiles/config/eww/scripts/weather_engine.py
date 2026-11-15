#!/usr/bin/env python3
import json
import os
import urllib.request

CACHE_DIR = os.path.expanduser("~/.cache/nord-gruvbox")
CACHE_FILE = os.path.join(CACHE_DIR, "weather.json")

def fetch_weather():
    os.makedirs(CACHE_DIR, exist_ok=True)
    try:
        # wttr.in видає форматований JSON без API-ключів
        url = "https://wttr.in/?format=j1"
        req = urllib.request.Request(url, headers={'User-Agent': 'curl'})
        with urllib.request.urlopen(req, timeout=5) as response:
            data = json.loads(response.read().decode('utf-8'))
            
            current = data.get("current_condition", [{}])[0]
            weather_desc = current.get("weatherDesc", [{}].get("value", "Clear"))
            if isinstance(weather_desc, list):
                weather_desc = weather_desc[0].get("value", "Clear")
                
            result = {
                "temp": f"{current.get('temp_C', '--')}°C",
                "feels": f"{current.get('FeelsLikeC', '--')}°C",
                "desc": weather_desc,
                "humidity": f"{current.get('humidity', '--')}%",
                "wind": f"{current.get('windspeedKmph', '--')} km/h",
                "forecast": []
            }
            
            # Прогноз на кілька днів
            for day in data.get("weather", []):
                date = day.get("date", "")
                max_t = day.get("maxtempC", "")
                min_t = day.get("mintempC", "")
                hourly = day.get("hourly", [{}])[4] # денний час
                desc_d = hourly.get("weatherDesc", [{}].get("value", ""))
                if isinstance(desc_d, list):
                    desc_d = desc_d[0].get("value", "")
                    
                result["forecast"].append({
                    "date": date,
                    "max": f"{max_t}°",
                    "min": f"{min_t}°",
                    "desc": desc_d
                })
                
            with open(CACHE_FILE, "w", encoding="utf-8") as f:
                json.dump(result, f, ensure_ascii=False, indent=2)
            return result
    except Exception:
        if os.path.exists(CACHE_FILE):
            with open(CACHE_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        return {
            "temp": "--°C", "feels": "--°C", "desc": "Offline", 
            "humidity": "--%", "wind": "-- km/h", "forecast": []
        }

if __name__ == "__main__":
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "get"
    if cmd == "update":
        res = fetch_weather()
    else:
        if os.path.exists(CACHE_FILE):
            with open(CACHE_FILE, "r", encoding="utf-8") as f:
                res = json.load(f)
        else:
                res = fetch_weather()
    print(json.dumps(res, ensure_ascii=False))
