#!/usr/bin/env python3
"""Regenerate the Entity inventory chapter of DASHBOARD.md and align every table.

Usage (from the repository root):

    python3 scripts/dashboard_inventory.py

Run it after any change to views or template files, then lint with
markdownlint -c .markdownlint.yaml DASHBOARD.md. Requires PyYAML.
"""
import yaml, re, unicodedata
IMPL = ""
class L(yaml.SafeLoader): pass
L.add_constructor('!include', lambda l, n: n.value)
ENT = re.compile(r'\b(?:sensor|binary_sensor|switch|cover|climate|lock|alarm_control_panel|camera|vacuum|weather|sun)\.[a-z0-9_]+')
bt = lambda xs: ", ".join(f"`{x}`" for x in xs)

def ring_name(nm):
    nm = str(nm)
    return nm if '{' not in nm else f"{nm.split('-%}')[-1].split('{{')[0].strip()} (+ A/C mode)"

def entities_of(card):
    t = card.get('type', '')
    if t in ('vertical-stack', 'horizontal-stack'):      # recurse into stacked cards
        return [x for c in card.get('cards', []) for x in entities_of(c)]
    if t in ('heading', 'markdown'): return []
    if t == 'custom:mushroom-chips-card':
        return [(bt([c['entity']] if c.get('entity') else sorted(set(ENT.findall(yaml.dump(c))))) or 'none', 'Pill row') for c in card.get('chips', [])]
    if t == 'custom:mushroom-template-card':
        ids = [card['entity']] if card.get('entity') else sorted(set(ENT.findall(yaml.dump(card))))
        prim = str(card.get('primary', '')).strip()
        return [(bt(ids), prim if '{' not in prim else ('Condition' if card.get('secondary') == 'Now' else str(card.get('secondary', 'Status'))))]
    if t == 'custom:modern-circular-gauge':
        s = card.get('secondary', {})
        ids = [card['entity']] + ([s['entity']] if isinstance(s, dict) and s.get('entity') else []) + ENT.findall(str(card.get('name', '')))
        return [(bt(ids), ring_name(card.get('name', '')))]
    if t == 'custom:sankey-chart':
        ids = []
        for n in card['nodes']:
            e = n.get('entity_id', n['id'])
            if '.' in e and e not in ids: ids.append(e)
        return [(bt(ids), 'Sankey')]
    return [(bt([card['entity']]), card.get('name', ''))] if 'entity' in card else []

def inventory():
    root = yaml.load(open(IMPL + 'sites/vie/configuration/ui-lovelace.yaml'), Loader=L)
    lines = ["", "## Entity inventory", "", "Generated from the view and template files at the time of writing. Regenerate",
             "or update it when views change.", ""]
    for inc in root['views']:
        v = yaml.load(open(IMPL + 'sites/vie/configuration/' + inc), Loader=L)
        lines += [f"### {v['title']} (`{inc.split('/')[-1]}`)", "", "| Section | Span | Name | Entities |", "| --- | --- | --- | --- |"]
        for s in v['sections']:
            head = s['cards'][0].get('heading', '').title().replace(' & ', ' and ').replace('(Forecast)', '(forecast)')
            chips = " (chips)" if s.get('theme') == 'family_dashboard_chips' else ""
            for c in s['cards'][1:]:
                for e, n in entities_of(c):
                    lines.append(f"| {head}{chips} | {s.get('column_span', 1)} | {n} | {e} |")
        lines.append("")
    t = yaml.safe_load(open(IMPL + 'sites/vie/configuration/template/safety_status.yaml'))[0]['binary_sensor']
    lines += ["### Safety status sensors (`template/safety_status.yaml`)", "",
              "| Entity | Alarm entities (red) | Attention entities (orange) |", "| --- | --- | --- |"]
    for b in t:
        alarm = sorted(set(ENT.findall(b['state']))); attn = sorted(set(ENT.findall(b['attributes']['summary'])) - set(alarm))
        lines.append(f"| `{b['default_entity_id']}` | {bt(alarm) or 'none'} | {bt(attn) or 'none'} |")
    lines += ["", "### Dashboard status sensors (`template/dashboard_status.yaml`)", "", "| Entity | Discovers | Used by |", "| --- | --- | --- |",
              "| `sensor.house_ac_status` | All `climate` entities | Overview, Indoor climate pill row |",
              "| `sensor.house_battery_status` | All battery `sensor` and `binary_sensor` entities | Overview, Security batteries summary |"]
    return lines

def width(x): return sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in x)
def split_row(line):
    body, cells, cur, code = line.strip()[1:-1], [], "", False
    for ch in body:
        if ch == "`": code = not code
        if ch == "|" and not code: cells.append(cur.strip()); cur = ""
        else: cur += ch
    cells.append(cur.strip()); return cells
def fmt(rows):
    P = [split_row(r) for r in rows]; n = max(map(len, P)); P = [r + [""] * (n - len(r)) for r in P]
    w = [max(3, *(width(r[i]) for j, r in enumerate(P) if j != 1)) for i in range(n)]
    return ["| " + " | ".join(("-" * w[i]) if j == 1 else r[i] + " " * (w[i] - width(r[i])) for i in range(n)) + " |" for j, r in enumerate(P)]

doc = open(IMPL + "DASHBOARD.md").read()
if "## Entity inventory\n" in doc:
    doc = doc[: doc.index("## Entity inventory\n")]
doc = doc.rstrip("\n") + "\n" + "\n".join(inventory()) + "\n"
src, out, i, fence = doc.split("\n"), [], 0, False
while i < len(src):
    l = src[i]
    if l.startswith("```"): fence = not fence
    if not fence and l.startswith("|"):
        blk = []
        while i < len(src) and src[i].startswith("|"): blk.append(src[i]); i += 1
        out += fmt(blk); continue
    out.append(l); i += 1
open(IMPL + "DASHBOARD.md", "w").write("\n".join(out))
print("inventory regenerated, tables aligned")
