#!/usr/bin/env python3
import json
import os
import random
import sys

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
}


def load_quotes():
    with open(QUOTES_FILE, "r", encoding="utf-8") as f:
        return json.load(f)


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
            "original": "No quotes in this category yet.",
            "translation": "У цій категорії поки немає цитат. Додай кілька в обране!",
            "author": "Quote Library",
            "source": "Local Storage",
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

    print(json.dumps(build_output(quotes, state), ensure_ascii=False))


if __name__ == "__main__":
    main()
