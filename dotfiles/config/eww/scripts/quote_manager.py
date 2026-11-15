#!/usr/bin/env python3
import json
import os
import random
import sys
import urllib.request
import urllib.parse

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
QUOTES_FILE = os.path.join(BASE_DIR, "quotes.json")
STATE_DIR = os.path.expanduser("~/.local/share/nord-gruvbox")
STATE_FILE = os.path.join(STATE_DIR, "quote_state.json")

ICONS = {
    "Games": "🎮",
    "Films": "🎬",
    "Anime": "🎌",
    "Books": "📚",
    "Real People": "👤",
    "Technology": "💻",
    "WikiSync": "🌐",
}

def load_quotes():
    if not os.path.exists(QUOTES_FILE):
        return []
    with open(QUOTES_FILE, "r", encoding="utf-8") as f:
        return json.load(f)

def save_quotes(quotes):
    with open(QUOTES_FILE, "w", encoding="utf-8") as f:
        json.dump(quotes, f, ensure_ascii=False, indent=2)

def load_state(quotes):
    os.makedirs(STATE_DIR, exist_ok=True)
    default_id = quotes[0]["id"] if quotes else ""
    if not os.path.exists(STATE_FILE):
        state = {"active_cat": "All", "current_id": default_id, "favorites": []}
        save_state(state)
        return state
    try:
        with open(STATE_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {"active_cat": "All", "current_id": default_id, "favorites": []}

def save_state(state):
    os.makedirs(STATE_DIR, exist_ok=True)
    with open(STATE_FILE, "w", encoding="utf-8") as f:
        json.dump(state, f, ensure_ascii=False, indent=2)

def sync_from_wikipedia():
    """Синхронізація цікавої цитати/факту з української Вікіпедії через Open API"""
    try:
        url = "https://uk.wikipedia.org/api/rest_v1/page/random/summary"
        req = urllib.request.Request(url, headers={'User-Agent': 'NordGruvboxRice/1.0'})
        with urllib.request.urlopen(req, timeout=3) as response:
            data = json.loads(response.read().decode('utf-8'))
            extract = data.get("extract", "")
            title = data.get("title", "Wikipedia")
            if not extract:
                return False
            
            # Беремо перше речення як «цитату/факт»
            sentence = extract.split(".")[0] + "."
            new_quote = {
                "id": f"wiki_{data.get('pageid', random.randint(1000,9999))}",
                "category": "Technology",
                "original": sentence,
                "translation": sentence, # Українська Вікіпедія вже українською
                "author": title,
                "source": "Wikipedia UA"
            }
            
            quotes = load_quotes()
            # Додаємо, якщо такого ID ще немає
            if not any(q["id"] == new_quote["id"] for q in quotes):
                quotes.insert(0, new_quote)
                save_quotes(quotes)
                return True
    except Exception:
        pass
    return False

def sync_from_fandom(wiki_subdomain="halo"):
    """Синхронізація цитат/статей із Fandom (наприклад, halo.fandom.com)"""
    try:
        url = f"https://{wiki_subdomain}.fandom.com/api.php?action=query&list=random&rnnamespace=0&rnlimit=1&format=json"
        req = urllib.request.Request(url, headers={'User-Agent': 'NordGruvboxRice/1.0'})
        with urllib.request.urlopen(req, timeout=3) as response:
            data = json.loads(response.read().decode('utf-8'))
            pages = data.get("query", {}).get("random", [])
            if not pages:
                return False
            page_title = pages[0]["title"]
            
            new_quote = {
                "id": f"fandom_{pages[0]['id']}",
                "category": "Games",
                "original": f"Lore entry: {page_title}",
                "translation": f"Запис лору: {page_title}",
                "author": f"{wiki_subdomain.capitalize()} Fandom",
                "source": f"{wiki_subdomain}.fandom.wiki"
            }
            
            quotes = load_quotes()
            if not any(q["id"] == new_quote["id"] for q in quotes):
                quotes.insert(0, new_quote)
                save_quotes(quotes)
                return True
    except Exception:
        pass
    return False

def get_filtered(quotes, state):
    cat = state.get("active_cat", "All")
    if cat == "All":
        return quotes
    if cat == "Favorites":
        favs = set(state.get("favorites", []))
        return [q for q in quotes if q["id"] in favs]
    return [q for q in quotes if q["category"] == cat]

def build_output(quotes, state):
    pool = get_filtered(quotes, state)
    favs = set(state.get("favorites", []))
    if not pool:
        return {
            "active_cat": state.get("active_cat", "All"),
            "id": "",
            "original": "No quotes in this category yet. Click Sync!",
            "translation": "У цій категорії поки пусто. Натисни кнопку синхронізації з Мережею!",
            "author": "Quote Library",
            "source": "Offline Storage",
            "category_icon": "★",
            "is_fav": False,
            "fav_count": len(favs),
        }

    current = next((q for q in pool if q["id"] == state.get("current_id")), None)
    if current is None:
        current = pool[0]
        state["current_id"] = current["id"]
        save_state(state)

    return {
        "active_cat": state.get("active_cat", "All"),
        "id": current["id"],
        "original": current["original"],
        "translation": current["translation"],
        "author": current["author"],
        "source": current["source"],
        "category_icon": ICONS.get(current["category"], "💬"),
        "is_fav": current["id"] in favs,
        "fav_count": len(favs),
    }

def main():
    quotes = load_quotes()
    state = load_state(quotes)
    cmd = sys.argv[1] if len(sys.argv) > 1 else "get"

    if cmd == "category" and len(sys.argv) > 2:
        state["active_cat"] = sys.argv[2]
        pool = get_filtered(quotes, state)
        if pool:
            state["current_id"] = pool[0]["id"]
        save_state(state)

    elif cmd == "next":
        pool = get_filtered(quotes, state)
        if len(pool) > 1:
            candidates = [q for q in pool if q["id"] != state.get("current_id")]
            state["current_id"] = random.choice(candidates)["id"]
        elif pool:
            state["current_id"] = pool[0]["id"]
        save_state(state)

    elif cmd == "toggle_fav":
        cid = state.get("current_id")
        favs = state.get("favorites", [])
        if cid:
            if cid in favs:
                favs.remove(cid)
            else:
                favs.append(cid)
            state["favorites"] = favs
            save_state(state)

    elif cmd == "sync_wiki":
        sync_from_wikipedia()
        quotes = load_quotes()
        pool = get_filtered(quotes, state)
        if pool:
            state["current_id"] = pool[0]["id"]
        save_state(state)

    elif cmd == "sync_fandom":
        sync_from_fandom("halo")
        quotes = load_quotes()
        pool = get_filtered(quotes, state)
        if pool:
            state["current_id"] = pool[0]["id"]
        save_state(state)

    print(json.dumps(build_output(quotes, state), ensure_ascii=False))

if __name__ == "__main__":
    main()
