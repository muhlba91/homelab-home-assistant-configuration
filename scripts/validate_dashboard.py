#!/usr/bin/env python3
"""Validate the Home Dashboard against the rules in DASHBOARD.md.

Usage (from the repository root):

    python3 scripts/validate_dashboard.py
    python3 scripts/validate_dashboard.py --entities entities.json

`--entities` takes a JSON list of entity IDs (or of objects with an
`entity_id` key). Produce it in Home Assistant under Developer Tools >
Template with:

    {{ states | map(attribute='entity_id') | list | to_json }}

Disabled entities are not in that list, so they are reported as missing.

Requires PyYAML. If Jinja2 is installed, all templates are also compiled.
Exit code 0 means no errors; warnings do not fail the run.
"""
import argparse
import glob
import json
import os
import re
import sys

import yaml

SITE = "sites/vie/configuration"
VIEWS = f"{SITE}/dashboards/views"
ENTITY_RE = re.compile(
    r"\b(?:sensor|binary_sensor|switch|cover|climate|lock|alarm_control_panel|"
    r"camera|vacuum|weather|sun|light|fan|media_player)\.[a-z0-9_]+")
HEX_RE = re.compile(r"#[0-9a-fA-F]{6}\b")
# Action names (`action: weather.get_forecasts`) look like entity IDs but are not.
ACTION_RE = re.compile(r"^\s*-?\s*(?:action|service):\s*\S+\s*$", re.M)
# YAML comments may mention entities and actions freely.
COMMENT_RE = re.compile(r"(^|\s)#.*$", re.M)

errors, warnings = [], []


def err(where, msg):
    errors.append(f"ERROR   {where}: {msg}")


def warn(where, msg):
    warnings.append(f"WARNING {where}: {msg}")


class Loader(yaml.SafeLoader):
    """SafeLoader that tolerates Home Assistant tags."""


for tag in ("!include", "!include_dir_merge_named", "!include_dir_merge_list",
            "!include_dir_named", "!include_dir_list", "!secret", "!env_var"):
    Loader.add_constructor(tag, lambda loader, node: getattr(node, "value", None))


def load(path):
    with open(path, encoding="utf-8") as handle:
        return yaml.load(handle, Loader=Loader)


def all_strings(obj):
    if isinstance(obj, dict):
        for value in obj.values():
            yield from all_strings(value)
    elif isinstance(obj, list):
        for value in obj:
            yield from all_strings(value)
    elif isinstance(obj, str):
        yield obj


def check_views():
    room_views = 0
    for path in sorted(glob.glob(f"{VIEWS}/*.yaml")):
        name = os.path.basename(path)
        text = open(path, encoding="utf-8").read()
        if HEX_RE.search(text):
            err(name, "hex colour in a view; use palette tokens or var(--x-color)")
        view = load(path)
        if view.get("type") != "sections" or view.get("theme") != "family_dashboard":
            err(name, "view must be type: sections with theme: family_dashboard")
        heads = []
        for index, section in enumerate(view.get("sections", [])):
            cards = section.get("cards", [])
            where = f"{name} section {index + 1}"
            if not cards or cards[0].get("type") != "heading":
                err(where, "first card must be a heading card")
                heads.append(None)
                continue
            head = cards[0].get("heading", "")
            heads.append(head)
            where = f"{name} {head}"
            if head != head.upper() or cards[0].get("heading_style") != "subtitle":
                err(where, "heading must be capitals with heading_style: subtitle")
            if "grid_options" in cards[0]:
                err(where, "heading must not have grid_options (pill goes on its own row)")
            pills = [i for i, card in enumerate(cards)
                     if card.get("type") == "custom:mushroom-chips-card" and card.get("alignment") == "start"]
            if pills and pills != [1]:
                err(where, "status pill row must be the second card")
            for i in pills:
                if cards[i].get("grid_options", {}).get("columns") != "full":
                    err(where, "status pill row must have columns: full")
            for card in cards:
                columns = card.get("grid_options", {}).get("columns")
                if columns in (8, 9):
                    err(where, f"width {columns} breaks on phones; use 6, 12 or full")
                if head == "SAFETY" and card.get("type") == "tile" and columns != 12:
                    err(where, f"safety tiles must be width 12 (found {columns})")
            if head == "SAFETY" and not pills:
                err(where, "Safety section needs a status pill row")
        if name == "overview.yaml":
            continue
        room_views += 1
        sections = view.get("sections", [])
        if heads and (heads[-1] != "BATTERY LEVELS" or sections[-1].get("column_span") != 3):
            err(name, "Battery levels must be the last section, full width (column_span: 3)")
        if "SAFETY" in heads:
            i = heads.index("SAFETY")
            left = heads[i - 1] if i else None
            if (left not in ("SHUTTERS", "FRONT DOOR") or sections[i - 1].get("column_span") != 1
                    or sections[i].get("column_span") != 2):
                err(name, "slot rule: Safety (span 2) must follow Shutters or Front door (span 1)")
        else:
            err(name, "room view without a Safety section")
    return room_views


def template_blocks():
    """Yield (file, block, kind, entity) for every template entity."""
    files = sorted(glob.glob(f"{SITE}/template/*.yaml"))
    for path in files:
        data = load(path) or []
        if isinstance(data, dict):
            data = [data]
        for block in data:
            for kind in ("sensor", "binary_sensor", "switch"):
                for entity in block.get(kind, []) or []:
                    yield path, block, kind, entity


def check_templates():
    ids, defined = {}, set()
    for path, block, kind, entity in template_blocks():
        name = os.path.basename(path)
        uid = entity.get("unique_id")
        eid = entity.get("default_entity_id")
        if eid:
            defined.add(eid)
        if not uid:
            err(name, f"{eid}: missing unique_id")
        elif uid in ids:
            err(name, f"{eid}: unique_id duplicates {ids[uid]}")
        else:
            ids[uid] = eid
        text = "\n".join(all_strings(entity))
        triggered = "triggers" in block or "trigger" in block
        if f"states.{kind}" in text and not triggered:
            err(name, f"{eid}: iterates its own domain (states.{kind}) without triggers: template loop")
        if "this." in text:
            warn(name, f"{eid}: uses `this`, which lags one update behind")
        if eid and eid.endswith("_safety_status"):
            summary = entity.get("attributes", {}).get("summary", "")
            if "All clear" not in summary:
                err(name, f"{eid}: summary must fall back to exactly 'All clear'")
    for path in sorted(glob.glob(f"{SITE}/packages/*.yaml")):
        package = load(path) or {}
        for key, meter in (package.get("utility_meter") or {}).items():
            defined.add(f"sensor.{key}")
            if not meter.get("unique_id"):
                err(os.path.basename(path), f"utility meter {key}: missing unique_id")
    return defined


def check_entities(defined, export):
    with open(export, encoding="utf-8") as handle:
        data = json.load(handle)
    known = set()
    for item in data:
        if isinstance(item, str):
            known.add(item)
        elif isinstance(item, dict) and not item.get("disabled_by"):
            known.add(item.get("entity_id"))
    files = (glob.glob(f"{VIEWS}/*.yaml") + glob.glob(f"{SITE}/template/*.yaml")
             + glob.glob(f"{SITE}/packages/*.yaml"))
    for path in sorted(files):
        text = COMMENT_RE.sub(r"\1", ACTION_RE.sub("", open(path, encoding="utf-8").read()))
        for eid in sorted(set(ENTITY_RE.findall(text))):
            if eid not in known and eid not in defined:
                err(os.path.basename(path), f"unknown or disabled entity {eid}")


def check_jinja():
    try:
        import jinja2
    except ImportError:
        warn("jinja", "Jinja2 not installed; template syntax not checked")
        return
    env = jinja2.Environment()
    for flt in ("is_number", "timestamp_custom", "as_timestamp", "to_json", "from_json", "regex_replace"):
        env.filters[flt] = lambda value, *args, **kwargs: value
    for test in ("is_state", "match", "search", "is_number"):
        env.tests[test] = lambda value, *args, **kwargs: True
    files = (glob.glob(f"{VIEWS}/*.yaml") + glob.glob(f"{SITE}/template/*.yaml")
             + glob.glob(f"{SITE}/packages/*.yaml"))
    for path in sorted(files):
        for text in all_strings(load(path)):
            if "{{" in text or "{%" in text:
                try:
                    env.parse(text)
                except jinja2.TemplateSyntaxError as exc:
                    err(os.path.basename(path), f"Jinja syntax error: {exc.message}")


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--entities", help="JSON list of entity IDs from Home Assistant")
    args = parser.parse_args()
    if not os.path.isdir(VIEWS):
        sys.exit("run this script from the repository root")
    rooms = check_views()
    defined = check_templates()
    if args.entities:
        check_entities(defined, args.entities)
    else:
        warn("entities", "no --entities export given; entity IDs not checked")
    check_jinja()
    for line in warnings + errors:
        print(line)
    print(f"\nChecked {rooms} room views + overview, {len(defined)} defined entities: "
          f"{len(errors)} error(s), {len(warnings)} warning(s).")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()