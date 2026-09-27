# Home Dashboard

This document describes the Home Assistant home dashboard: how it looks,
how it is built, and how to extend it. It is written so that a person, or an
AI assistant given only this file plus an export of all entities, can adapt
the dashboard correctly without guessing.

The YAML files are the source of truth. There is no build step: every view is
plain, hand-editable YAML that follows the patterns described below.

## Contents

- [Goals and principles](#goals-and-principles)
- [Files and loading](#files-and-loading)
- [Dependencies](#dependencies)
- [Design system](#design-system)
- [Layout rules](#layout-rules)
- [Component catalogue](#component-catalogue)
- [Views](#views)
- [Safety status sensors](#safety-status-sensors)
- [Selecting entities from an entity list](#selecting-entities-from-an-entity-list)
- [Recipes](#recipes)
- [Hard-coded entity lists](#hard-coded-entity-lists)
- [Deploying and reloading](#deploying-and-reloading)
- [Validation checklist](#validation-checklist)
- [Decision log](#decision-log)
- [Entity inventory](#entity-inventory)

## Goals and principles

- **Family first.** Everyone in the household must understand every tile at a
  glance. Names are short and human ("Kitchen", "Smoke"), never entity IDs.
- **Room per tab.** One Overview tab plus one tab per room or room group.
- **Controls first, status last.** Within a room: lighting, climate control,
  shutters, other devices, safety, and battery levels always last.
- **Colour means something.** Colour is used for state and meaning, never for
  decoration. Neutral grey is the calm default.
- **Native first.** Prefer built-in Home Assistant cards and features. Custom
  cards are used only where native cards cannot do the job (see
  [Dependencies](#dependencies)). No `card-mod`, no custom CSS.
- **Logic in the backend.** Anything that combines several entities into one
  status is a template entity (see
  [Safety status sensors](#safety-status-sensors)), not dashboard templating.
  Automations and notifications can reuse it.

## Files and loading

| Path                                                  | Purpose                                                                                              |
| ----------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `common/configuration/configuration.yaml`             | Loads `lovelace: !include_dir_merge_named lovelace` and `template: !include_dir_merge_list template` |
| `common/configuration/frontend/themes.yaml`           | Themes `family_dashboard` and `family_dashboard_chips` (light and dark)                              |
| `sites/vie/configuration/lovelace/dashboards.yaml`    | Stage 1: registers the dashboard as an additional dashboard                                          |
| `sites/vie/configuration/lovelace/mode.yaml`          | Stage 2 (optional): `mode: yaml`, makes it the default dashboard                                     |
| `sites/vie/configuration/ui-lovelace.yaml`            | Dashboard root: title and the ordered `!include` list of views                                       |
| `sites/vie/configuration/dashboards/views/*.yaml`     | One file per tab (view)                                                                              |
| `sites/vie/configuration/template/safety_status.yaml` | Template binary sensors behind the safety pills                                                      |

`common/` and `sites/vie/` are merged into one Home Assistant configuration
directory at deploy time by `lifecycle/configuration.sh`.

### Why the folders are split

`!include_dir_merge_named` is recursive: every YAML file below `lovelace/` is
merged into the `lovelace:` key. View files must therefore **never** live
below `lovelace/`, which is why they are in `dashboards/views/`.

The default dashboard (`mode: yaml`) always reads `ui-lovelace.yaml` from the
configuration root; it has no `filename` option. That is why
`ui-lovelace.yaml` stays at the root in both stages, so promotion is a pure
file swap.

### Promotion from additional to default dashboard

1. Add `sites/vie/configuration/lovelace/mode.yaml` containing `mode: yaml`.
2. Delete `sites/vie/configuration/lovelace/dashboards.yaml`.
3. Restart Home Assistant.

### Template include format

Every file in `template/` is a YAML **list** (it starts with `- binary_sensor:`
or `- switch:`). This requires `template: !include_dir_merge_list template`.
With `!include_dir_merge_named`, list files are ignored silently and the
entities never appear.

## Dependencies

Custom cards are loaded via `common/configuration/frontend/extra_module_url.yaml`
and downloaded according to `common/components/www_components.txt`. Keep both
files in sync.

| Card                                                                     | Used for                                           | Why not native                                          |
| ------------------------------------------------------------------------ | -------------------------------------------------- | ------------------------------------------------------- |
| Mushroom (`custom:mushroom-template-card`, `custom:mushroom-chips-card`) | Status pills, Overview summary rows, forecast rows | Native cards cannot template text, icon and icon colour |
| Modern Circular Gauge (`custom:modern-circular-gauge`)                   | Temperature rings with humidity dot                | Native gauge has no secondary value                     |
| HA Sankey Chart (`custom:sankey-chart`)                                  | Energy Flow                                        | No native equivalent                                    |

Everything else is native: `sections` views, `grid` sections, `heading` cards,
`tile` cards with features.

Do **not** load these:

- `vacuum-card` (denysdovhan): it registers `ha-icon-button` a second time and
  breaks the whole frontend, including other dashboards (upstream issue #699).
- `bubble-card`, `tabbed-card`, `custom-sidebar`: not used, removed.

`advanced-camera-card` is loaded but currently not used by any view.

## Design system

### Views and sections

Every view uses:

```yaml
theme: family_dashboard
type: sections
max_columns: 3
```

Every group of cards is a **section** (a white panel) with a **heading** as
its first card:

```yaml
  - type: grid
    background:
      opacity: 100
    column_span: 1
    cards:
      - type: heading
        heading: LIGHTING
        heading_style: subtitle
      # ... cards
```

- Heading text is written in **capitals**; `heading_style: subtitle` makes it
  small and grey. Do not use the section `title:` key.
- `background: opacity: 100` is required; without it the white panel is not
  drawn.
- `column_span` is 1, 2 or 3 (a third, two thirds or full width).

### Grid units

Each unit of `column_span` provides 12 grid columns. Card widths are set with
`grid_options.columns`:

| Section `column_span` | Grid columns | Full width   | Half | Third | Quarter | Sixth |
| --------------------- | ------------ | ------------ | ---- | ----- | ------- | ----- |
| 1                     | 12           | `full` or 12 | 6    | 4     | 3       | 2     |
| 2                     | 24           | `full` or 24 | 12   | 8     | 6       | 4     |
| 3                     | 36           | `full` or 36 | 18   | 12    | 9       | 6     |

On narrow screens Home Assistant collapses sections to one column
automatically; nothing extra is needed for mobile.

### Two themes: panels and chips

| Theme                                      | Card background                      | Use for                                                                                                 |
| ------------------------------------------ | ------------------------------------ | ------------------------------------------------------------------------------------------------------- |
| `family_dashboard` (view default)          | Same as the panel: rows look flat    | Lighting, air conditioner, climate, media, vacuum, forecast, gauges, solar, energy flow                 |
| `family_dashboard_chips` (set per section) | Slightly darker: each card is a chip | Sections with several peer items that must read as separate: security, shutters, safety, battery levels |

Apply the chip theme on the section:

```yaml
  - type: grid
    theme: family_dashboard_chips
    # ...
```

### Colour palette

The palette is defined **once** in `themes.yaml`, per mode. Each colour is
emitted twice because two systems read it: Home Assistant uses
`<name>-color` (hex) and Mushroom uses `rgb-<name>` (comma-separated RGB).
Both must always carry the same colour.

| Token    | Light     | Dark      | Meaning                                              |
| -------- | --------- | --------- | ---------------------------------------------------- |
| `blue`   | `#3b73c4` | `#78a0dc` | Temperature, shutters, house consumption, primary    |
| `green`  | `#1f9d68` | `#5dba8f` | Good, all clear, humidity, grid export               |
| `amber`  | `#c98a1d` | `#c29a5e` | Lights, solar, sun                                   |
| `orange` | `#d97a2b` | `#d98c5f` | Attention (something open), medium battery           |
| `red`    | `#d1404b` | `#e07a82` | Alert (smoke, leak, alarm), grid import, low battery |
| `purple` | `#7658e0` | `#a394e3` | Media                                                |
| `grey`   | `#8a8e97` | `#7d828c` | Neutral, inactive                                    |

`yellow` and `deep-orange` are mapped to amber and orange, so Home Assistant's
default battery colours also follow the palette.

Rules:

- In views, use colour **tokens** (`color: amber`, `icon_color: green`) for
  tiles and Mushroom, and `var(--<name>-color)` for custom cards that take CSS
  colours (gauge, sankey). **Never** put hex colours into views.
- Dark mode uses softer, desaturated tones; saturated colours glare on dark
  backgrounds.

### Surfaces and contrast

| Surface                                                                  | Light     | Dark      |
| ------------------------------------------------------------------------ | --------- | --------- |
| Page (`primary-background-color`)                                        | `#e6e9ee` | `#121418` |
| Panel (`ha-section-background-color`)                                    | `#ffffff` | `#23262c` |
| Chip (`card-background-color` in the chip theme, `mush-chip-background`) | `#f1f3f6` | `#30333b` |

The top bar (`app-header-background-color`) uses the panel colour, so it never
looks lighter than the page.

Target contrast ratios (WCAG formula): page to panel about 1.22, panel to chip
between 1.11 and 1.20 and always **below** page to panel, so chips never
outshine their panel. Text stays at least 4.5:1 on every surface. Re-check
these ratios after changing any surface colour.

Global theme settings: `ha-card-border-width: 0px`, `ha-card-box-shadow: none`
(flat rows) and `ha-section-border-radius: 20px`.

## Layout rules

### Room views

Sections appear in this order. Omit a section when the room has nothing for
it. Adjacent sections may share a row (that is what `column_span` is for), but
the order is always kept.

1. **Lighting**, then **Air conditioner**, then **Climate** (first row).
2. **Shutters**.
3. Room-specific devices: **Front door**, **Media system**, **Vacuum**,
   **Weather station**.
4. **Safety** (with a status pill when the room has a safety status sensor).
5. **Battery levels**: always the last row, always full width
   (`column_span: 3`), always chip theme.

Row packing used today:

| Situation                                  | Row 1                        | Row 2                | Row 3             | Row 4                    |
| ------------------------------------------ | ---------------------------- | -------------------- | ----------------- | ------------------------ |
| Lights, A/C, climate, one shutter          | Lighting 1, A/C 1, Climate 1 | Shutters 1, Safety 2 | Battery 3         |                          |
| Lights, climate, no A/C, one shutter       | Lighting 1, Climate 2        | Shutters 1, Safety 2 | Battery 3         |                          |
| Several shutters and devices (Living Room) | Lighting 1, A/C 1, Climate 1 | Shutters 3           | Media 2, Vacuum 1 | Safety 3, then Battery 3 |
| Lights and one shutter, no climate         | Lighting 2, Shutters 1       | Safety 3             | Battery 3         |                          |

Numbers are `column_span` values; each row sums to 3.

### Card widths inside sections

| Section                                           | Card width                                       |
| ------------------------------------------------- | ------------------------------------------------ |
| Lighting, A/C, Climate, Media, Vacuum, Front door | `columns: full` (one per row, stacked)           |
| Shutters (span 3)                                 | 12 (three per row)                               |
| Shutters (span 1)                                 | 12 (full)                                        |
| Safety sensors (span 3)                           | 9 (four per row); 12 when there are five or more |
| Safety sensors (span 2)                           | 12 (two per row)                                 |
| Battery levels                                    | 6 (six per row)                                  |

### Heading with status pill

A heading with a pill shares its row with a `mushroom-chips-card`. Split the
section's grid columns between them:

| Section `column_span` | Heading `columns` | Pill `columns` |
| --------------------- | ----------------- | -------------- |
| 1                     | 6                 | 6              |
| 2                     | 16                | 8              |
| 3                     | 27                | 9              |

Known and accepted: a heading next to a pill sits about 15 px lower than a
heading without one (see [Decision log](#decision-log)).

## Component catalogue

Copy these patterns exactly; only change entity, name and width.

### Light or switch with toggle

```yaml
      - type: tile
        entity: switch.fs7_1
        name: Office
        icon: mdi:lightbulb
        color: amber
        features_position: inline
        features:
          - type: toggle
        grid_options:
          columns: full
```

For non-light switches, change `icon` and `color` (media uses
`mdi:television-play` and `purple`).

### Shutter

```yaml
      - type: tile
        entity: cover.office
        name: Office
        color: blue
        features_position: inline
        features:
          - type: cover-open-close
        grid_options:
          columns: 12
```

Only open, stop and close are shown. Position and tilt sliders open in the
more-info dialog on tap, for every cover, whether or not it supports tilt.

### Air conditioner

```yaml
      - type: tile
        entity: climate.office_air_conditioner
        name: Office
        features:
          - type: climate-hvac-modes
            style: icons
          - type: climate-fan-modes
            style: dropdown
          - type: target-temperature
        grid_options:
          columns: full
```

The fan-mode row makes the A/C tile exactly as tall as the two climate tiles
next to it. Only add `climate-fan-modes` if the entity supports fan modes
(`supported_features` bit 8).

### Climate (temperature and humidity)

```yaml
      - type: tile
        entity: sensor.office_office_temperature_humidity_temperature
        name: Temperature
        icon: mdi:thermometer
        color: blue
        features:
          - type: trend-graph
            hours_to_show: 24
            detail: false
        grid_options:
          columns: full
```

The humidity tile is identical with `name: Humidity`,
`icon: mdi:water-percent` and `color: green`. Use a dedicated room sensor,
never the temperature reported by an air conditioner or a leak sensor.

### Safety sensor

```yaml
      - type: tile
        entity: binary_sensor.ass1_smoke_detected
        name: Smoke
        grid_options:
          columns: 12
```

No `color`: binary sensors are coloured by Home Assistant from their device
class (red for smoke or moisture when triggered, neutral when clear).

### Battery

```yaml
      - type: tile
        entity: sensor.ass1_battery
        name: Smoke
        grid_options:
          columns: 6
```

Use percentage battery sensors. For devices that only expose a binary battery
sensor (`device_class: battery`, `on` means low), use the binary sensor; it
shows "Normal" or "Low".

### Status pill in a section heading

```yaml
      - type: heading
        heading: SAFETY
        heading_style: subtitle
        grid_options:
          columns: 16
      - type: custom:mushroom-chips-card
        alignment: end
        chips:
          - type: template
            entity: binary_sensor.office_safety_status
            content: "{{ state_attr('binary_sensor.office_safety_status', 'summary') }}"
            icon: "{{ state_attr('binary_sensor.office_safety_status', 'icon') }}"
            icon_color: >-
              {% if is_state('binary_sensor.office_safety_status', 'on') %}red
              {% elif state_attr('binary_sensor.office_safety_status', 'summary') != 'All clear' %}orange
              {% else %}green{% endif %}
            tap_action:
              action: more-info
        grid_options:
          columns: 8
```

Colour logic: red when the sensor is `on`; orange when it is `off` but the
summary is not "All clear"; green otherwise. The pill itself only reads the
sensor; all logic lives in `safety_status.yaml`.

### Temperature ring (Overview and Garden)

```yaml
      - type: custom:modern-circular-gauge
        entity: sensor.office_office_temperature_humidity_temperature
        name: Office
        min: 15
        max: 28
        show_icon: false
        gauge_foreground_style:
          color: 'var(--blue-color)'
        gauge_background_style:
          color: var(--divider-color)
        secondary:
          entity: sensor.office_office_temperature_humidity_humidity
          show_gauge: outer
          min: 30
          max: 70
          gauge_foreground_style:
            color: 'var(--green-color)'
        grid_options:
          columns: 6
          rows: 3
```

Ranges: indoor 15 to 28 °C and 30 to 70 %; outdoor 5 to 35 °C and 20 to 80 %.
The solar gauge uses `var(--amber-color)`, 0 to 5000 W, and no secondary.

### Informational pill (under a ring)

```yaml
      - type: custom:mushroom-chips-card
        alignment: center
        chips:
          - type: template
            entity: climate.office_air_conditioner
            icon: mdi:air-conditioner
            icon_color: "{{ 'grey' if is_state('climate.office_air_conditioner', 'off') else 'blue' }}"
            content: "{{ 'AC ' ~ (states('climate.office_air_conditioner') | replace('_', ' ') | title) }}"
            tap_action:
              action: more-info
        grid_options:
          columns: 6
```

Rooms without an air conditioner get a static "No AC" pill with
`icon_color: disabled` so the ring row stays aligned. Pills are placed after
all rings of a section; the grid puts each pill under its ring.

## Views

Tabs in order (defined in `ui-lovelace.yaml`): Overview, Living Room, Office,
Tea Room, Bedroom, Bathrooms, Hallways, Garden, Utility. Combined tabs:
Living Room includes the kitchen, Bathrooms includes the toilet, Hallways
includes the entrance room, Utility includes the storage room.

### Overview

| Row | Sections (`column_span`)                      | Content                                                                                                                                                                                              |
| --- | --------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Security and safety (2), Outdoor forecast (1) | Status pill `binary_sensor.house_safety_status`; alarm and front door tiles; smoke, water leak and doors summaries. Forecast: sunrise or sunset pill, condition row, humidity, pressure and wind row |
| 2   | Indoor climate (2), Weather station (1)       | One ring per room sensor with an A/C pill under each; South and North rings with a temperature difference pill                                                                                       |
| 3   | Solar and energy (3)                          | Solar gauge (12 columns, 3 rows) and three stacked stat tiles (24 columns each)                                                                                                                      |
| 4   | Energy flow (3)                               | Sankey: Solar and Grid import into House and Grid export                                                                                                                                             |

Summary rows ("Smoke: All clear (7)") are Mushroom template cards with a
hard-coded entity list each (see
[Hard-coded entity lists](#hard-coded-entity-lists)).

The sankey's House node is computed as solar plus import minus export
(`add_entities` and `subtract_entities`). Do not replace it with
`remaining_parent_state`; that rendered only the export branch.

### Room tabs

See [Layout rules](#layout-rules) for the order and the
[Entity inventory](#entity-inventory) for the exact content of each tab.
Office is the smallest complete example of the pattern.

## Safety status sensors

`sites/vie/configuration/template/safety_status.yaml` defines one template
binary sensor per scope: one for the whole house (used on Overview) and one
per room that has safety-relevant sensors. Each drives one status pill.

### Contract

Every safety status sensor has:

| Field                | Value                                                                                    |
| -------------------- | ---------------------------------------------------------------------------------------- |
| `name`               | `"<Scope>: Safety Status"`                                                               |
| `default_entity_id`  | `binary_sensor.<scope>_safety_status`                                                    |
| `unique_id`          | A random UUID4, generated once and **never changed**                                     |
| `device_class`       | `safety` (`on` means unsafe; Home Assistant colours it red)                              |
| `state`              | `on` when any **alarm** entity is `on`                                                   |
| `icon`               | `mdi:alert` for an alarm, `mdi:door-open` for an attention item, else `mdi:shield-check` |
| `attributes.summary` | Human text: the first matching item in priority order, else exactly `All clear`          |

The pill turns orange whenever the sensor is `off` and `summary` is not
exactly `All clear`, so this text must stay byte-identical.

### Classification of entities

| Class     | Entities                                 | Effect                                     |
| --------- | ---------------------------------------- | ------------------------------------------ |
| Alarm     | Smoke, water leak, triggered alarm panel | `state: on`, red pill, `mdi:alert`         |
| Attention | Door or window contacts (open)           | `state: off`, orange pill, `mdi:door-open` |
| Ignored   | Motion, occupancy, tamper, batteries     | Not part of the status                     |

Motion counts only in the special case where it is a security signal: the
Bathrooms sensor raises an alarm for motion while the alarm panel is
`armed_away`. Motion in normal use must never colour a pill.

Priority of `summary` texts: alarm panel triggered, then smoke, then leak,
then open contacts, then `All clear`.

### Room sensor template

```yaml
    - unique_id: 5d0e9f0a-3a41-4f7e-9d0b-0f6c1f5e2a11
      name: "Office: Safety Status"
      default_entity_id: binary_sensor.office_safety_status
      device_class: safety
      state: >-
        {{ ['binary_sensor.ass1_smoke_detected'] | select('is_state', 'on') | list | count > 0 }}
      icon: >-
        {% if ['binary_sensor.ass1_smoke_detected'] | select('is_state', 'on') | list | count > 0 %}mdi:alert
        {% else %}mdi:shield-check{% endif %}
      attributes:
        summary: >-
          {% if is_state('binary_sensor.ass1_smoke_detected', 'on') %}Smoke detected
          {% else %}All clear{% endif %}
```

For a room with contacts, add the contacts to the `summary` chain after the
alarms (`{% elif is_state('binary_sensor.ring_rcs2', 'on') %}Storage window
open`) and add an `elif` branch returning `mdi:door-open` to `icon`. Hallways
and Utility are complete examples.

The house sensor aggregates all smoke and leak sensors as alarms, the alarm
panel's `triggered` state as an alarm, and all door and window contacts as
attention items, with counts in the text (`2 door/window open`).

Current sensors: `house`, `living_room`, `office`, `tea_room`, `bedroom`,
`bathrooms`, `hallways`, `utility`. Garden has none on purpose: it has no
safety sensors, and an always-green pill would be decoration.

## Selecting entities from an entity list

Use these rules when mapping an entity export to the dashboard.

General:

- Skip every entity with `disabled_by` set.
- Assign rooms by the entity's `area`; fall back to the friendly-name prefix
  (`"Office: …"`).
- Skip technical entities: tamper, bypass mode, chirp tone, info, firmware,
  signal strength, diagnostics, identify buttons, configuration selects and
  numbers.
- Keep entities whose integration is temporarily `unavailable` (for example
  the Roborock) if the device exists; tiles show "Unavailable" gracefully.

By entity type:

| Kind             | Pattern in this installation                                                                                                                                       | Where it goes                              |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------ |
| Lights           | `switch.fs*_1`, `switch.fds*_*` (relay switches, not `light.*`)                                                                                                    | Lighting                                   |
| Kitchen light    | Use proxy `switch.fs12_1`, never the physical `switch.fs9_1` (an automation mirrors them)                                                                          | Living Room lighting                       |
| Shutters         | `cover.*`                                                                                                                                                          | Shutters                                   |
| Air conditioners | `climate.*_air_conditioner`                                                                                                                                        | A/C section, Overview A/C pill             |
| Room climate     | `sensor.<room>_<room>_temperature_humidity_temperature` and `_humidity`                                                                                            | Climate section, Overview ring             |
| Smoke            | `binary_sensor.ass<N>_smoke_detected`, battery `sensor.ass<N>_battery`                                                                                             | Safety, Battery, safety status (alarm)     |
| Water leak       | `binary_sensor.ffs1_water_alarm_water_leak_detected`, `binary_sensor.ffs2_water_leak_detected`, battery `sensor.ffs<N>_battery_level`                              | Safety, Battery, safety status (alarm)     |
| Motion           | `binary_sensor.fms<N>_home_security_motion_detection`, `binary_sensor.ring_rms1`, `binary_sensor.living_room_ring_motion_sensor`                                   | Safety, Battery                            |
| Contacts         | `binary_sensor.ring_rcs<N>`, battery `sensor.ring_rcs<N>_*_battery`                                                                                                | Safety, Battery, safety status (attention) |
| Weather station  | `sensor.ecowitt_temp<N>`, `sensor.ecowitt_humidity<N>`, `binary_sensor.ecowitt_batt<N>` (1 is South, 2 is North)                                                   | Garden, Overview                           |
| Forecast         | `weather.home` (met.no)                                                                                                                                            | Overview forecast                          |
| Solar and grid   | `sensor.pv_power_photovoltaics_fronius_power_flow`, `sensor.pv_energy_day_fronius_power_flow`, `sensor.energy_meter_po` (export), `sensor.energy_meter_p` (import) | Overview                                   |

Never use for room climate: temperatures reported by air conditioners, leak
detectors or smoke detectors.

## Recipes

### Add a light

1. Add a light tile to the room's Lighting section.
2. If the room had no Lighting section, create it as the first section.

### Add a shutter

1. Add a shutter tile to the room's Shutters section (chip theme).
2. With three or more shutters, make the section `column_span: 3` and cards
   `columns: 12`.

### Add a temperature and humidity sensor

1. Room view: add or update the Climate section with both trend tiles.
2. Overview: add a ring to Indoor climate and a matching pill (A/C state, or
   "No AC"). Keep rings and pills in the same order. With more than four
   rooms, the ring row wraps; keep `columns: 6`.
3. If the room has an air conditioner, add the A/C section between Lighting
   and Climate.

### Add a motion sensor

1. Add a safety sensor tile to the room's Safety section.
2. Add its battery tile.
3. Do **not** add it to any safety status sensor (see
   [Classification of entities](#classification-of-entities)).

### Add a smoke or water leak sensor

1. Add a safety sensor tile and a battery tile to the room.
2. Add it as an alarm to the room's safety status sensor; create the room
   sensor (and the heading pill) if the room had none.
3. Add it to the house sensor's smoke or leak list.
4. Add it to the Overview "Smoke" or "Water leaks" summary list.

### Add a door or window contact

1. Add a safety sensor tile and a battery tile to the room.
2. Add it as an attention item to the room's safety status sensor.
3. Add it to the house sensor's contact list and to the Overview
   "Doors and windows" summary list.

### Add a room (new tab)

1. Create `sites/vie/configuration/dashboards/views/<room>.yaml` with the view
   header from [Views and sections](#views-and-sections) and sections in the
   order from [Layout rules](#layout-rules).
2. Add `- !include dashboards/views/<room>.yaml` to `ui-lovelace.yaml` at the
   right position.
3. If the room has safety-relevant sensors, add a room safety status sensor
   with a new UUID4 and a Safety heading pill.
4. Update the Overview (ring, summaries, house sensor lists).

### Add devices to the energy flow

Individual consumers (for example smart plugs with power sensors) become
children of the House node in a new sankey section 2:

```yaml
          - id: sensor.office_plug_power
            section: 2
            name: Office plug
        # and under links:
          - source: house_consumption
            target: sensor.office_plug_power
```

Keep `house_consumption` as the computed node; add a
`remaining_parent_state` node named "Other" in section 2 to show unmeasured
consumption.

## Hard-coded entity lists

These places contain explicit entity lists. Update all of them when adding,
removing or renaming a safety-relevant entity.

| Location                                           | Contents                                       |
| -------------------------------------------------- | ---------------------------------------------- |
| `template/safety_status.yaml`, house sensor        | Smoke (7), leak (2), contacts (3), alarm panel |
| `template/safety_status.yaml`, room sensors        | That room's alarms and contacts                |
| `views/overview.yaml`, "Smoke" summary             | Smoke sensors                                  |
| `views/overview.yaml`, "Water leaks" summary       | Leak sensors                                   |
| `views/overview.yaml`, "Doors and windows" summary | Contacts                                       |
| `views/overview.yaml`, Indoor climate              | One ring and one pill per room                 |

After renaming entities in Home Assistant, search the whole repository for the
old entity ID.

## Deploying and reloading

| Changed                                   | Action                                                                                      |
| ----------------------------------------- | ------------------------------------------------------------------------------------------- |
| Any view file or `ui-lovelace.yaml`       | Dashboard menu, then Refresh (a browser reload alone may serve cached included files)       |
| `themes.yaml`                             | Developer Tools, YAML, reload Themes                                                        |
| `template/*.yaml`                         | Developer Tools, YAML, reload Template entities                                             |
| `lovelace/*.yaml` or `configuration.yaml` | Check configuration, then restart                                                           |
| Custom card versions                      | Update both `www_components.txt` and `extra_module_url.yaml`, then hard-refresh the browser |

If the whole frontend fails to load after adding a custom card, remove the
card from `extra_module_url.yaml` first; a duplicate custom element
registration breaks every dashboard.

## Validation checklist

Before committing:

1. `yamllint -c .yamllint.yml .` passes.
2. Every entity ID in views and templates exists in a current entity export
   and is not disabled.
3. Every view: first card of each section is a `heading` in capitals with
   `heading_style: subtitle`; Battery levels is the last section.
4. No hex colours in view files (`grep -rn "#[0-9a-fA-F]\{6\}" views/` finds
   nothing).
5. All `unique_id` values in `template/` are unique; existing ones unchanged.
6. Every `summary` falls back to exactly `All clear`.
7. `markdownlint DASHBOARD.md` passes after editing this document.

## Decision log

| Decision                                      | Reason                                                                                                    |
| --------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `sections` views instead of masonry           | Masonry reorders cards by height; sections keep the designed order                                        |
| Native `tile` cards                           | Consistent shape, real toggles and cover controls                                                         |
| Flat rows and chip sections via two themes    | Native way to group items without custom CSS                                                              |
| No shadows on section panels                  | Needs `card-mod` targeting frontend internals, which breaks on updates; depth comes from surface contrast |
| Heading next to a pill sits about 15 px lower | Only fix is inline heading badges, which support two colours only; the orange state was more valuable     |
| Status logic in template sensors              | Reusable in automations; the dashboard stays declarative                                                  |
| Gauge icons hidden                            | The gauge offers no palette-safe icon colour; the mockups had no icon                                     |
| A/C state as a pill under each ring           | Matches the mockup; the gauge's text slot could not render a pill                                         |
| Camera removed from Living Room               | Too dominant for its value                                                                                |
| `vacuum-card` not loaded                      | Breaks the whole frontend (duplicate `ha-icon-button`)                                                    |
| Shutter position and tilt only in the dialog  | Keeps rows compact; sliders are rarely needed                                                             |
| Dark mode uses its own desaturated palette    | Saturated colours glare on dark surfaces                                                                  |

## Entity inventory

Generated from the view files at the time of writing. Regenerate or update it
when views change.

### Overview (`overview.yaml`)

| Section                     | Span | Name                       | Entities                                                                                                                                                                                                                                                          |
| --------------------------- | ---- | -------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Security and Safety (chips) | 2    | Pill                       | `binary_sensor.house_safety_status`                                                                                                                                                                                                                               |
| Security and Safety (chips) | 2    | Alarm                      | `alarm_control_panel.ring_control_panel`                                                                                                                                                                                                                          |
| Security and Safety (chips) | 2    | Front Door                 | `lock.entrance_door_lock`                                                                                                                                                                                                                                         |
| Security and Safety (chips) | 2    | Smoke                      | `binary_sensor.ass1_smoke_detected`, `binary_sensor.ass2_smoke_detected`, `binary_sensor.ass3_smoke_detected`, `binary_sensor.ass4_smoke_detected`, `binary_sensor.ass5_smoke_detected`, `binary_sensor.ass6_smoke_detected`, `binary_sensor.ass7_smoke_detected` |
| Security and Safety (chips) | 2    | Water leaks                | `binary_sensor.ffs1_water_alarm_water_leak_detected`, `binary_sensor.ffs2_water_leak_detected`                                                                                                                                                                    |
| Security and Safety (chips) | 2    | Doors & windows            | `binary_sensor.ring_rcs1`, `binary_sensor.ring_rcs2`, `binary_sensor.ring_rcs3`                                                                                                                                                                                   |
| Outdoor (forecast)          | 1    | Pill                       | `sun.sun`                                                                                                                                                                                                                                                         |
| Outdoor (forecast)          | 1    | Condition                  | `weather.home`                                                                                                                                                                                                                                                    |
| Outdoor (forecast)          | 1    | Humidity · Pressure · Wind | `weather.home`                                                                                                                                                                                                                                                    |
| Indoor Climate              | 2    | Living Room                | `sensor.living_room_living_room_temperature_humidity_temperature`, `sensor.living_room_living_room_temperature_humidity_humidity`                                                                                                                                 |
| Indoor Climate              | 2    | Bedroom                    | `sensor.bedroom_bedroom_temperature_humidity_temperature`, `sensor.bedroom_bedroom_temperature_humidity_humidity`                                                                                                                                                 |
| Indoor Climate              | 2    | Office                     | `sensor.office_office_temperature_humidity_temperature`, `sensor.office_office_temperature_humidity_humidity`                                                                                                                                                     |
| Indoor Climate              | 2    | Tea Room                   | `sensor.tea_room_tea_room_temperature_humidity_temperature`, `sensor.tea_room_tea_room_temperature_humidity_humidity`                                                                                                                                             |
| Indoor Climate              | 2    | Pill                       | `climate.living_room_air_conditioner`                                                                                                                                                                                                                             |
| Indoor Climate              | 2    | Pill                       | `climate.bedroom_air_conditioner`                                                                                                                                                                                                                                 |
| Indoor Climate              | 2    | Pill                       | `climate.office_air_conditioner`                                                                                                                                                                                                                                  |
| Indoor Climate              | 2    | Pill (No AC)               | none                                                                                                                                                                                                                                                              |
| Weather Station             | 1    | South                      | `sensor.ecowitt_temp1`, `sensor.ecowitt_humidity1`                                                                                                                                                                                                                |
| Weather Station             | 1    | North                      | `sensor.ecowitt_temp2`, `sensor.ecowitt_humidity2`                                                                                                                                                                                                                |
| Weather Station             | 1    | Difference pill            | `sensor.ecowitt_temp1`, `sensor.ecowitt_temp2`                                                                                                                                                                                                                    |
| Solar and Energy            | 3    | Solar power                | `sensor.pv_power_photovoltaics_fronius_power_flow`                                                                                                                                                                                                                |
| Solar and Energy            | 3    | Produced today             | `sensor.pv_energy_day_fronius_power_flow`                                                                                                                                                                                                                         |
| Solar and Energy            | 3    | Exporting to grid          | `sensor.energy_meter_po`                                                                                                                                                                                                                                          |
| Solar and Energy            | 3    | Importing from grid        | `sensor.energy_meter_p`                                                                                                                                                                                                                                           |
| Energy Flow                 | 3    | Sankey                     | `sensor.pv_power_photovoltaics_fronius_power_flow`, `sensor.energy_meter_p`, `sensor.energy_meter_po`                                                                                                                                                             |

### Living Room (`living_room.yaml`)

| Section                | Span | Name         | Entities                                                          |
| ---------------------- | ---- | ------------ | ----------------------------------------------------------------- |
| Lighting               | 1    | Living Room  | `switch.fds1_1`                                                   |
| Lighting               | 1    | Kitchen      | `switch.fs12_1`                                                   |
| Air Conditioner        | 1    | Living Room  | `climate.living_room_air_conditioner`                             |
| Climate                | 1    | Temperature  | `sensor.living_room_living_room_temperature_humidity_temperature` |
| Climate                | 1    | Humidity     | `sensor.living_room_living_room_temperature_humidity_humidity`    |
| Shutters (chips)       | 3    | Kitchen      | `cover.living_room_kitchen`                                       |
| Shutters (chips)       | 3    | Garden Door  | `cover.garden_door`                                               |
| Shutters (chips)       | 3    | TV           | `cover.living_room_tv`                                            |
| Media System           | 2    | Media System | `switch.living_room_media_system`                                 |
| Vacuum                 | 1    | Roborock     | `vacuum.tea_room_roborock`                                        |
| Safety (chips)         | 3    | Pill         | `binary_sensor.living_room_safety_status`                         |
| Safety (chips)         | 3    | Smoke        | `binary_sensor.ass3_smoke_detected`                               |
| Safety (chips)         | 3    | Kitchen leak | `binary_sensor.ffs1_water_alarm_water_leak_detected`              |
| Safety (chips)         | 3    | Motion       | `binary_sensor.living_room_ring_motion_sensor`                    |
| Safety (chips)         | 3    | Garden door  | `binary_sensor.ring_rcs3`                                         |
| Battery Levels (chips) | 3    | Smoke        | `sensor.ass3_battery`                                             |
| Battery Levels (chips) | 3    | Climate      | `sensor.living_room_living_room_temperature_humidity_battery`     |
| Battery Levels (chips) | 3    | Motion       | `sensor.living_room_ring_motion_sensor_battery`                   |
| Battery Levels (chips) | 3    | Kitchen leak | `sensor.ffs1_battery_level`                                       |
| Battery Levels (chips) | 3    | Garden door  | `sensor.ring_rcs3_garden_door_battery`                            |
| Battery Levels (chips) | 3    | Roborock     | `sensor.tea_room_roborock_battery`                                |

### Office (`office.yaml`)

| Section                | Span | Name        | Entities                                                |
| ---------------------- | ---- | ----------- | ------------------------------------------------------- |
| Lighting               | 1    | Office      | `switch.fs7_1`                                          |
| Air Conditioner        | 1    | Office      | `climate.office_air_conditioner`                        |
| Climate                | 1    | Temperature | `sensor.office_office_temperature_humidity_temperature` |
| Climate                | 1    | Humidity    | `sensor.office_office_temperature_humidity_humidity`    |
| Shutters (chips)       | 1    | Office      | `cover.office`                                          |
| Safety (chips)         | 2    | Pill        | `binary_sensor.office_safety_status`                    |
| Safety (chips)         | 2    | Smoke       | `binary_sensor.ass1_smoke_detected`                     |
| Battery Levels (chips) | 3    | Smoke       | `sensor.ass1_battery`                                   |
| Battery Levels (chips) | 3    | Climate     | `sensor.office_office_temperature_humidity_battery`     |

### Tea Room (`tea_room.yaml`)

| Section                | Span | Name        | Entities                                                    |
| ---------------------- | ---- | ----------- | ----------------------------------------------------------- |
| Lighting               | 1    | Tea Room    | `switch.fs5_1`                                              |
| Climate                | 2    | Temperature | `sensor.tea_room_tea_room_temperature_humidity_temperature` |
| Climate                | 2    | Humidity    | `sensor.tea_room_tea_room_temperature_humidity_humidity`    |
| Shutters (chips)       | 1    | Tea Room    | `cover.tea_room`                                            |
| Safety (chips)         | 2    | Pill        | `binary_sensor.tea_room_safety_status`                      |
| Safety (chips)         | 2    | Smoke       | `binary_sensor.ass6_smoke_detected`                         |
| Battery Levels (chips) | 3    | Smoke       | `sensor.ass6_battery`                                       |
| Battery Levels (chips) | 3    | Climate     | `sensor.tea_room_tea_room_temperature_humidity_battery`     |

### Bedroom (`bedroom.yaml`)

| Section                | Span | Name        | Entities                                                  |
| ---------------------- | ---- | ----------- | --------------------------------------------------------- |
| Lighting               | 1    | Bedroom     | `switch.fs6_1`                                            |
| Air Conditioner        | 1    | Bedroom     | `climate.bedroom_air_conditioner`                         |
| Climate                | 1    | Temperature | `sensor.bedroom_bedroom_temperature_humidity_temperature` |
| Climate                | 1    | Humidity    | `sensor.bedroom_bedroom_temperature_humidity_humidity`    |
| Shutters (chips)       | 1    | Bedroom     | `cover.bedroom`                                           |
| Safety (chips)         | 2    | Pill        | `binary_sensor.bedroom_safety_status`                     |
| Safety (chips)         | 2    | Smoke       | `binary_sensor.ass2_smoke_detected`                       |
| Battery Levels (chips) | 3    | Smoke       | `sensor.ass2_battery`                                     |
| Battery Levels (chips) | 3    | Climate     | `sensor.bedroom_bedroom_temperature_humidity_battery`     |

### Bathrooms (`bathrooms.yaml`)

| Section                | Span | Name          | Entities                                            |
| ---------------------- | ---- | ------------- | --------------------------------------------------- |
| Lighting               | 2    | Bathroom      | `switch.fds2_2`                                     |
| Lighting               | 2    | Mirror        | `switch.fds2_1`                                     |
| Lighting               | 2    | Toilet        | `switch.fs1_1`                                      |
| Shutters (chips)       | 1    | Bathroom      | `cover.bathroom`                                    |
| Safety (chips)         | 3    | Pill          | `binary_sensor.bathrooms_safety_status`             |
| Safety (chips)         | 3    | Toilet motion | `binary_sensor.fms1_home_security_motion_detection` |
| Battery Levels (chips) | 3    | Toilet motion | `sensor.fms1_battery_level`                         |

### Hallways (`hallways.yaml`)

| Section                | Span | Name           | Entities                                            |
| ---------------------- | ---- | -------------- | --------------------------------------------------- |
| Lighting               | 2    | Hallway        | `switch.fs4_1`                                      |
| Lighting               | 2    | Hallway 2      | `switch.fds1_2`                                     |
| Lighting               | 2    | Entrance       | `switch.fs2_1`                                      |
| Front Door             | 1    | Front Door     | `lock.entrance_door_lock`                           |
| Front Door             | 1    | Keypad chirps  | `switch.alarm_keypad_chirps`                        |
| Safety (chips)         | 3    | Pill           | `binary_sensor.hallways_safety_status`              |
| Safety (chips)         | 3    | Hallway smoke  | `binary_sensor.ass7_smoke_detected`                 |
| Safety (chips)         | 3    | Entrance smoke | `binary_sensor.ass4_smoke_detected`                 |
| Safety (chips)         | 3    | Front door     | `binary_sensor.ring_rcs1`                           |
| Safety (chips)         | 3    | Ring motion    | `binary_sensor.ring_rms1`                           |
| Safety (chips)         | 3    | Fibaro motion  | `binary_sensor.fms2_home_security_motion_detection` |
| Battery Levels (chips) | 3    | Hallway smoke  | `sensor.ass7_battery`                               |
| Battery Levels (chips) | 3    | Entrance smoke | `sensor.ass4_battery`                               |
| Battery Levels (chips) | 3    | Front door     | `sensor.ring_rcs1_front_door_battery`               |
| Battery Levels (chips) | 3    | Ring motion    | `sensor.ring_rms1_entrance_room_battery`            |
| Battery Levels (chips) | 3    | Fibaro motion  | `sensor.fms2_battery_level`                         |
| Battery Levels (chips) | 3    | Keypad         | `sensor.ring_keypad_battery`                        |
| Battery Levels (chips) | 3    | Door lock      | `sensor.entrance_room_entrance_door_lock_battery`   |

### Garden (`garden.yaml`)

| Section                | Span | Name            | Entities                                           |
| ---------------------- | ---- | --------------- | -------------------------------------------------- |
| Lighting               | 1    | Pergola         | `switch.fds4_2`                                    |
| Weather Station        | 2    | South           | `sensor.ecowitt_temp1`, `sensor.ecowitt_humidity1` |
| Weather Station        | 2    | North           | `sensor.ecowitt_temp2`, `sensor.ecowitt_humidity2` |
| Weather Station        | 2    | Difference pill | `sensor.ecowitt_temp1`, `sensor.ecowitt_temp2`     |
| Battery Levels (chips) | 3    | South sensor    | `binary_sensor.ecowitt_batt1`                      |
| Battery Levels (chips) | 3    | North sensor    | `binary_sensor.ecowitt_batt2`                      |

### Utility (`utility.yaml`)

| Section                | Span | Name           | Entities                                            |
| ---------------------- | ---- | -------------- | --------------------------------------------------- |
| Lighting               | 2    | Utility Room   | `switch.fs10_1`                                     |
| Lighting               | 2    | Storage Room   | `switch.fs3_1`                                      |
| Shutters (chips)       | 1    | Storage Room   | `cover.storage_room`                                |
| Safety (chips)         | 3    | Pill           | `binary_sensor.utility_safety_status`               |
| Safety (chips)         | 3    | Smoke          | `binary_sensor.ass5_smoke_detected`                 |
| Safety (chips)         | 3    | Leak           | `binary_sensor.ffs2_water_leak_detected`            |
| Safety (chips)         | 3    | Storage motion | `binary_sensor.fms3_home_security_motion_detection` |
| Safety (chips)         | 3    | Storage window | `binary_sensor.ring_rcs2`                           |
| Battery Levels (chips) | 3    | Storage motion | `sensor.fms3_battery_level`                         |
| Battery Levels (chips) | 3    | Storage window | `sensor.ring_rcs2_front_window_battery`             |
| Battery Levels (chips) | 3    | Leak           | `sensor.ffs2_battery_level`                         |
| Battery Levels (chips) | 3    | Smoke          | `sensor.ass5_battery`                               |

### Safety status sensors (`template/safety_status.yaml`)

| Entity                                    | Alarm entities (red)                                                                                                                                                                                                                                                                                                                                                                                        | Attention entities (orange)                                                     |
| ----------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| `binary_sensor.house_safety_status`       | `alarm_control_panel.ring_control_panel`, `binary_sensor.ass1_smoke_detected`, `binary_sensor.ass2_smoke_detected`, `binary_sensor.ass3_smoke_detected`, `binary_sensor.ass4_smoke_detected`, `binary_sensor.ass5_smoke_detected`, `binary_sensor.ass6_smoke_detected`, `binary_sensor.ass7_smoke_detected`, `binary_sensor.ffs1_water_alarm_water_leak_detected`, `binary_sensor.ffs2_water_leak_detected` | `binary_sensor.ring_rcs1`, `binary_sensor.ring_rcs2`, `binary_sensor.ring_rcs3` |
| `binary_sensor.living_room_safety_status` | `binary_sensor.ass3_smoke_detected`, `binary_sensor.ffs1_water_alarm_water_leak_detected`                                                                                                                                                                                                                                                                                                                   | `binary_sensor.ring_rcs3`                                                       |
| `binary_sensor.office_safety_status`      | `binary_sensor.ass1_smoke_detected`                                                                                                                                                                                                                                                                                                                                                                         | none                                                                            |
| `binary_sensor.tea_room_safety_status`    | `binary_sensor.ass6_smoke_detected`                                                                                                                                                                                                                                                                                                                                                                         | none                                                                            |
| `binary_sensor.bedroom_safety_status`     | `binary_sensor.ass2_smoke_detected`                                                                                                                                                                                                                                                                                                                                                                         | none                                                                            |
| `binary_sensor.hallways_safety_status`    | `binary_sensor.ass4_smoke_detected`, `binary_sensor.ass7_smoke_detected`                                                                                                                                                                                                                                                                                                                                    | `binary_sensor.ring_rcs1`                                                       |
| `binary_sensor.utility_safety_status`     | `binary_sensor.ass5_smoke_detected`, `binary_sensor.ffs2_water_leak_detected`                                                                                                                                                                                                                                                                                                                               | `binary_sensor.ring_rcs2`                                                       |
| `binary_sensor.bathrooms_safety_status`   | `alarm_control_panel.ring_control_panel`, `binary_sensor.fms1_home_security_motion_detection`                                                                                                                                                                                                                                                                                                               | none                                                                            |
