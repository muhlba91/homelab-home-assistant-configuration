# Home Dashboard

This document describes the Home Assistant home dashboard: how it looks,
how it is built, and how to extend it. It is written so that a person, or an
AI assistant given only this file plus an export of all entities, can adapt
the dashboard correctly without guessing.

The YAML files are the source of truth. There is no build step: every view is
plain, hand-editable YAML that follows the patterns described below.

## Contents

- [Goals and principles](#goals-and-principles)
- [Working on this dashboard](#working-on-this-dashboard)
- [Files and loading](#files-and-loading)
- [Dependencies](#dependencies)
- [Design system](#design-system)
- [Layout rules](#layout-rules)
- [Component catalogue](#component-catalogue)
- [Views](#views)
- [Safety status sensors](#safety-status-sensors)
- [Dashboard status sensors](#dashboard-status-sensors)
- [Energy sensors](#energy-sensors)
- [Washing machine](#washing-machine)
- [Selecting entities from an entity list](#selecting-entities-from-an-entity-list)
- [Recipes](#recipes)
- [Hard-coded entity lists](#hard-coded-entity-lists)
- [Deploying and reloading](#deploying-and-reloading)
- [Validation checklist](#validation-checklist)
- [Known pitfalls](#known-pitfalls)
- [Decision log](#decision-log)
- [Open topics](#open-topics)
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

## Working on this dashboard

This section is for anyone continuing the work: a person, a fresh chat with an
AI assistant, or an agent such as Claude Code. Together with the repository,
this file is meant to be enough context; nothing else is required.

### Inputs to ask for

| Input                    | Why                                          | How to get it                                                                                                                                                                                             |
| ------------------------ | -------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Entity list              | Entity IDs change; never guess them          | In Home Assistant, Developer Tools, Template: `{{ states \| map(attribute='entity_id') \| list \| to_json }}`. Save the output as `entities.json` (disabled entities are not included, which is intended) |
| Screenshots              | Layout problems only show on real screens    | Desktop and phone, light and dark, of the tabs that changed                                                                                                                                               |
| Home Assistant version   | Options and defaults change between releases | Settings, About                                                                                                                                                                                           |
| Design canvas (optional) | Earlier drafts and the rules card            | `https://claude.ai/artifact/3KUkasKywFM6q8rLmuCige`, readable from the owner's Claude account                                                                                                             |

### Working agreements

- **Native first.** Prefer built-in cards and features. Add a custom card only
  when nothing native can do the job, and check that it is actively
  maintained. No `card-mod`, no custom CSS.
- **Discuss, then sketch, then implement.** For design changes, present
  options with pros and cons, then sketch them (desktop 1280 px and phone
  390 px; light and dark when colours change) before touching the YAML.
- **Measure instead of guessing.** Check contrast ratios, sizes and text
  lengths with numbers; verify options in the current Home Assistant and card
  documentation rather than from memory (for example, `lovelace: mode: yaml`
  was removed in 2026.8).
- **Consistency over filling space.** The same element sits in the same place
  and has the same size in every tab; an empty area is better than a tab that
  looks different.
- **Logic in the backend.** Anything combining several entities is a template
  sensor; the dashboard only displays it.
- **Validate before delivering**, then deliver complete files with a list of
  what changed and which reload or restart is needed (see
  [Deploying and reloading](#deploying-and-reloading)).
- **Keep this file current** in the same change: rules, decision log, open
  topics and the generated inventory.

### Tools in the repository

| Command                                                          | Purpose                                                                                                                                 |
| ---------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| `python3 scripts/validate_dashboard.py --entities entities.json` | Checks every layout rule in this file, template safety (unique IDs, template loops, `this`), Jinja syntax, and that every entity exists |
| `python3 scripts/dashboard_inventory.py`                         | Regenerates the [Entity inventory](#entity-inventory) and aligns all tables in this file                                                |
| `yamllint -c .yamllint.yml .`                                    | YAML style, as used by the repository's CI                                                                                              |
| `markdownlint -c .markdownlint.yaml DASHBOARD.md`                | This file's style, including aligned tables                                                                                             |

Both scripts need PyYAML; the validator also compiles templates when Jinja2
is installed.

## Files and loading

| Path                                                     | Purpose                                                                                              |
| -------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `common/configuration/configuration.yaml`                | Loads `lovelace: !include_dir_merge_named lovelace` and `template: !include_dir_merge_list template` |
| `common/configuration/frontend/themes.yaml`              | Themes `family_dashboard` and `family_dashboard_chips` (light and dark)                              |
| `sites/vie/configuration/lovelace/dashboards.yaml`       | Registers the dashboard under the key `lovelace`: it replaces the built-in Overview                  |
| `sites/vie/configuration/ui-lovelace.yaml`               | Dashboard root: title and the ordered `!include` list of views                                       |
| `sites/vie/configuration/dashboards/views/*.yaml`        | One file per tab (view)                                                                              |
| `sites/vie/configuration/template/safety_status.yaml`    | Template binary sensors behind the safety pills                                                      |
| `sites/vie/configuration/template/dashboard_status.yaml` | Template sensors behind the A/C and battery summaries                                                |
| `sites/vie/configuration/packages/energy.yaml`           | Daily utility meters behind the Solar & Energy panel                                                 |
| `sites/vie/configuration/template/energy.yaml`           | Own-use and produced-today template sensors                                                          |
| `sites/vie/configuration/template/washing_machine.yaml`  | Phase, status, end time and active sensors behind the washing machine panel                          |
| `scripts/validate_dashboard.py`                          | Checks the layout rules, templates and entity IDs                                                    |
| `scripts/dashboard_inventory.py`                         | Regenerates the entity inventory in this file                                                        |

`common/` and `sites/vie/` are merged into one Home Assistant configuration
directory at deploy time by `lifecycle/configuration.sh`.

### Why the folders are split

`!include_dir_merge_named` is recursive: every YAML file below `lovelace/` is
merged into the `lovelace:` key. View files must therefore **never** live
below `lovelace/`, which is why they are in `dashboards/views/`.

### Registration and default dashboard

The dashboard is registered in `lovelace/dashboards.yaml` as a YAML dashboard
under the key `lovelace`. That key is reserved for the built-in Overview and
is allowed for backward compatibility, so this dashboard **replaces** the
Overview at `/lovelace`. The old storage-mode Overview is not deleted: its
configuration stays in `.storage/lovelace` and returns if the key is renamed.

Do not use the top-level `lovelace: mode: yaml`. It was removed in Home
Assistant 2026.8; YAML dashboards are only defined under `dashboards:`.

Which dashboard opens first is a UI setting, not YAML:

1. Settings, Dashboards, open the menu of this dashboard, **Set as default**.
   This sets the default for all users.
2. Each user can still choose a personal default in their profile.

The built-in Home dashboard only appears in the sidebar while it is the
default, so it disappears once this dashboard is set as default.

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

These fractions are desktop maths. Which of them to actually use is decided
by the [Width rule](#width-rule): only 6, 12 and full.

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
| `purple` | `#7658e0` | `#a394e3` | Media, special modes (presence simulation)           |
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

Every room tab follows the same shape, so the same things sit in the same
places in every tab:

1. **Row 1**: **Lighting**, then **Air conditioner**, then **Climate** where
   present (Garden: **Weather station**). Rooms without either use a
   full-width Lighting row with the lights side by side.
2. Extra controls, only where they exist, as a full-width row: **Devices**
   (Living Room: media system and vacuum), **Washing machine** (Utility).
3. **The slot row**: **Shutters** (left, span 1) and **Safety** (right,
   span 2). Rooms without a shutter put their other room control in the left
   slot (Hallways: **Front door**, with the lock, the keypad chirps and the
   presence simulation switch). Multiple shutters stack in the slot.
4. **Battery levels**: always its own full-width last row, always chip theme.

Controls come first, status last. Safety is what people act on; batteries are
maintenance that is glanced at now and then, so they are never mixed into the
Safety row.

Row layout per room (numbers are `column_span` values):

| Room            | Row 1                         | Row 2                  | Row 3                                | Row 4     |
| --------------- | ----------------------------- | ---------------------- | ------------------------------------ | --------- |
| Office, Bedroom | Lighting 1, A/C 1, Climate 1  | Shutters 1, Safety 2   | Battery 3                            |           |
| Tea Room        | Lighting 1, Climate 2         | Shutters 1, Safety 2   | Battery 3                            |           |
| Living Room     | Lighting 1, A/C 1, Climate 1  | Devices 3              | Shutters 1 (three stacked), Safety 2 | Battery 3 |
| Bathrooms       | Lighting 3                    | Shutters 1, Safety 2   | Battery 3                            |           |
| Utility         | Lighting 3                    | Washing machine 3      | Shutters 1, Safety 2                 | Battery 3 |
| Hallways        | Lighting 3                    | Front door 1, Safety 2 | Battery 3                            |           |
| Garden          | Lighting 1, Weather station 2 | Shutters 1, Safety 2   | Battery 3                            |           |

Panels end where their content ends; Home Assistant does not stretch panels
in a row to equal height.

### Width rule

On phones every section collapses into one column with a **12-unit** grid,
whatever its `column_span`. Card widths then behave differently:

- Widths of 12 or more (`12`, `24`, `36`, `full`) become one full row.
- Widths below 12 keep their absolute size.

Therefore only use widths that also work on a 12-unit grid:

- `6`: two per row on phones.
- `12` or `full`: one per row on phones.
- Anything of 12 or more that should span the whole phone width.

Never use `8` or `9`; they leave ragged rows on phones. Width 6 is used for
compact strips such as the Overview's four Security summaries (one row on
desktop, 2×2 on phones); sensor tiles use 12 (see
[Card widths inside sections](#card-widths-inside-sections)).

### Card widths inside sections

Tile widths are **consistent across tabs**: the same kind of tile has the same
size in every room. Panels wrap rather than stretch tiles, and a single tile
keeps its standard width.

| Card                                                        | Width                                                                         |
| ----------------------------------------------------------- | ----------------------------------------------------------------------------- |
| Lights in a span-1 Lighting panel; A/C; Climate; Front door | `columns: full` (stacked)                                                     |
| Lights in a full-width Lighting row; Devices                | 12 (a third of the page)                                                      |
| Shutters                                                    | 12 (full in the span-1 slot, stacked when several)                            |
| Safety sensors                                              | **always 12** (two per row in the span-2 Safety panel, one per row on phones) |
| Security alarm and front door (Overview)                    | 12                                                                            |
| Security summaries (Overview)                               | 6 (four in one row on desktop, 2×2 on phones)                                 |
| Temperature rings                                           | 6 (12 in Garden)                                                              |
| Battery levels                                              | 6 (six per row, two on phones)                                                |

### Status pill row

A section's status pill sits on its **own full-width row directly under the
heading**, left-aligned, on every device: heading, then status, then content.
The pill is a `mushroom-chips-card` with `alignment: start` and
`columns: full`; the heading has no `grid_options`.

This keeps the pill correct on phones and aligns all headings on desktop.
Sections placed side by side on desktop either both have a pill row or both
have none, so their heights stay equal (Security and Forecast, Indoor climate
and Weather station).

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

### Status pill card

```yaml
      - type: heading
        heading: SAFETY
        heading_style: subtitle
      - type: custom:mushroom-chips-card
        alignment: start
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
          columns: full
```

Colour logic: red when the sensor is `on`; orange when it is `off` but the
summary is not "All clear"; green otherwise. The pill itself only reads the
sensor; all logic lives in `safety_status.yaml`.

Pill text is always neutral; only the icon is coloured. Coloured text fails
contrast on the pill background (green 3.1:1, blue 4.2:1; 4.5:1 is needed).

### Temperature ring (Overview and Garden)

```yaml
      - type: custom:modern-circular-gauge
        entity: sensor.office_office_temperature_humidity_temperature
        name: >-
          {%- set m = states('climate.office_air_conditioner') -%}
          {%- set w = {'cool': 'Cooling', 'heat': 'Heating', 'dry': 'Drying',
          'fan_only': 'Fan only', 'heat_cool': 'Auto', 'auto': 'Auto'} -%}
          Office{{ ' · ' ~ w[m] if m in w else '' }}
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

The templated `name` is the ring label: the room name while the room's air
conditioner is off, "Office · Cooling" while it runs. Because it is part of
the ring, it can never detach from it. Rooms without an air conditioner use a
plain `name: Tea Room`.

Ranges: indoor 15 to 28 °C and 30 to 70 %; outdoor 5 to 35 °C and 20 to 80 %.
The solar gauge uses `var(--amber-color)`, 0 to 5000 W, and no secondary.

### A/C summary pill (Indoor climate)

```yaml
      - type: custom:mushroom-chips-card
        alignment: start
        chips:
          - type: template
            entity: sensor.house_ac_status
            content: "{{ state_attr('sensor.house_ac_status', 'summary') }}"
            icon: "{{ state_attr('sensor.house_ac_status', 'icon') }}"
            icon_color: "{{ 'blue' if states('sensor.house_ac_status') | int(0) > 0 else 'grey' }}"
            tap_action:
              action: more-info
        grid_options:
          columns: full
```

Division of labour: the pill says **what** is happening overall (counts per
mode, never room names), the ring labels say **where**. Icon shape carries
the mode (snowflake: cooling only, flame: heating only, A/C icon: mixed or
off); colour carries the state (grey: all off, blue: anything running). The
worst case with three units is 34 characters and always fits a phone.

### Battery summary (Security)

```yaml
      - type: custom:mushroom-template-card
        entity: sensor.house_battery_status
        primary: Batteries
        secondary: "{{ state_attr('sensor.house_battery_status', 'summary') }}"
        icon: "{{ 'mdi:battery-alert' if states('sensor.house_battery_status') | int(0) > 0 else 'mdi:battery' }}"
        icon_color: "{{ 'orange' if states('sensor.house_battery_status') | int(0) > 0 else 'green' }}"
        tap_action:
          action: more-info
        grid_options:
          columns: 6
```

### Conditional banner (presence simulation)

```yaml
  - type: grid
    background:
      color: purple
      opacity: 25
    column_span: 3
    visibility:
      - condition: state
        entity: switch.presence_simulation
        state: "on"
    cards:
      - type: heading
        heading: PRESENCE SIMULATION
        heading_style: subtitle
      - type: tile
        entity: switch.presence_simulation
        name: Presence simulation is on
        icon: mdi:account-clock
        color: purple
        state_content:
          - state
          - last_changed
        features_position: inline
        features:
          - type: toggle
        grid_options:
          columns: full
```

- **Section visibility** shows the whole row only while the switch is on;
  when it is off, the row disappears without leaving a gap.
- **Tinted section background** (`color` plus `opacity`) instead of a
  gradient: gradients would need custom CSS. The colour is a palette token,
  so it follows light and dark mode.
- **Purple** marks a special mode. It is not one of the status colours
  (green, orange, red), so the band never reads as an alarm.
- `state_content: [state, last_changed]` shows how long the simulation has
  been running; the inline toggle switches it off.
- The banner is the first section of the Overview. Use the same pattern for
  any future mode that should be impossible to overlook while it is active.

### Status pills with conditional chips (washing machine)

```yaml
      - type: custom:mushroom-chips-card
        alignment: start
        chips:
          - type: template
            entity: sensor.washing_machine_status
            content: "{{ states('sensor.washing_machine_status') }}"
            icon: "{{ state_attr('sensor.washing_machine_status', 'icon') }}"
            icon_color: "{{ state_attr('sensor.washing_machine_status', 'color') }}"
          - type: conditional
            conditions:
              - condition: state
                entity: binary_sensor.washing_machine_active
                state: "on"
              - condition: state
                entity: sensor.lg_washer_temperature
                state_not: unknown
            chip:
              type: template
              icon: mdi:thermometer
              icon_color: grey
              content: "{{ states('sensor.lg_washer_temperature') | int }} °C"
          # further conditional chips: Done at, spin, course, Pre-wash, Intensive
        grid_options:
          columns: full
```

- A device panel can consist of **only a pill row**: one line on desktop,
  wrapping on phones, and the same height whether idle or running.
- **The first pill is the coloured status**; data pills are neutral
  (`icon_color: grey`), so the status always leads.
- Conditional chips use the current `condition: state` format. They are
  evaluated by Home Assistant's own conditional logic.

### Solar half block (Now and Today)

```yaml
      - type: vertical-stack
        grid_options:
          columns: 18
        cards:
          - type: heading
            heading: NOW
            heading_style: subtitle
          - type: horizontal-stack
            cards:
              - type: markdown
                content: " "
              - type: custom:modern-circular-gauge
                entity: sensor.pv_power_photovoltaics_fronius_power_flow
                name: Solar
                min: 0
                max: 5000
                show_icon: false
                gauge_foreground_style:
                  color: 'var(--amber-color)'
                gauge_background_style:
                  color: var(--divider-color)
              - type: markdown
                content: " "
          - type: horizontal-stack
            cards:
              - type: tile
                entity: sensor.solar_own_use_power
                name: Own use
                icon: mdi:home-lightning-bolt
                color: amber
                vertical: true
              # Exporting and Importing tiles follow the same pattern
```

Why it is built like this:

- **One stacked card per half** keeps each block together: on phones the
  whole Now block comes before the whole Today block. Separate cards in the
  section grid would interleave on phones.
- **The gauge sits between two empty Markdown cards**, one on each side. The
  gauge sizes itself by width and has no size option; inside a stack nothing
  limits it, so on its own it would fill the whole half. A horizontal stack
  splits its width equally, so the gauge gets one third. One fifth was tried
  and rejected: the gauges became too small on phones and their names were
  cut off. The empty cards are invisible because cards have no border and the
  panel's background.
- **Gauge names are short** ("Solar", "Produced"): the NOW and TODAY headings
  already carry the time range, and longer names get cut off on phones.
- **Vertical tiles** fit three items side by side, even on phones. Keep tile
  names short ("Own use", not "Used at home"): on phones each tile is about
  115 px wide.

## Views

Tabs in order (defined in `ui-lovelace.yaml`): Overview, Living Room, Office,
Tea Room, Bedroom, Bathrooms, Hallways, Garden, Utility. Combined tabs:
Living Room includes the kitchen, Bathrooms includes the toilet, Hallways
includes the entrance room, Utility includes the storage room.

### Overview

| Row | Sections (`column_span`)                         | Content                                                                                                                                                                                                         |
| --- | ------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 0   | Presence simulation (3), only while it is on     | Purple band with one tile: "Presence simulation is on", time since it started, inline toggle to switch it off                                                                                                   |
| 1   | Security and safety (2), Outdoor forecast (1)    | Status pill `binary_sensor.house_safety_status`; alarm and front door tiles; smoke, water leak, doors and batteries summaries. Forecast: sunrise or sunset pill, condition row, humidity, pressure and wind row |
| 1a  | Washing machine (3), only during an active cycle | One row: status, end time, temperature and spin; tapping it opens the Utility tab                                                                                                                               |
| 2   | Indoor climate (2), Weather station (1)          | A/C summary pill `sensor.house_ac_status`; one ring per room sensor with a templated A/C label. Temperature difference pill; South and North rings                                                              |
| 3   | Solar and energy (3)                             | Two half blocks, **Now** and **Today**: each a gauge (solar power in W, produced today in kWh) and one row of three vertical tiles (own use, exported, imported)                                                |
| 4   | Energy flow (3)                                  | Sankey: Solar and Grid import into House and Grid export                                                                                                                                                        |

Smoke, water leak and doors summaries are Mushroom template cards with a
hard-coded entity list each (see
[Hard-coded entity lists](#hard-coded-entity-lists)). The batteries summary
reads `sensor.house_battery_status` and needs no list.

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
`bathrooms`, `hallways`, `utility`, `garden`. Every room tab has one, so every
Safety section carries a status pill.

A sensor with only attention items and no alarms (Garden: the garden door)
uses `state: "{{ false }}"`: it never turns red, only orange through its
`summary`.

An entity may appear in more than one tab when it physically belongs to both.
The garden door (shutter, contact and battery) is shown in the Living Room and
in the Garden; each room's safety sensor lists it.

## Dashboard status sensors

`sites/vie/configuration/template/dashboard_status.yaml` defines two sensors
that summarise the whole house. Both discover their entities automatically,
so new devices are included without editing any list.

| Sensor                        | State                              | Attributes                                                               | Discovers                                                       |
| ----------------------------- | ---------------------------------- | ------------------------------------------------------------------------ | --------------------------------------------------------------- |
| `sensor.house_ac_status`      | Number of running air conditioners | `summary` (for example `1 cooling · 1 heating`, or `All AC off`), `icon` | Every `climate` entity                                          |
| `sensor.house_battery_status` | Number of low batteries            | `summary` (`All OK (38)` or `2 low`)                                     | Every `sensor` and `binary_sensor` with `device_class: battery` |

Rules:

- A unit counts as running in any state except `off`, `unavailable` and
  `unknown`. `heat_cool` is reported as "auto".
- A battery is low at **20 % or less**, or when a binary battery sensor is
  `on`. Unavailable batteries are ignored, not counted as low.
- Every field computes from live states. Never use `this` in these templates:
  it refers to the sensor's previous value and lags one update behind.
- `sensor.house_battery_status` is a **trigger-based** template sensor: it
  recalculates every 5 minutes, at Home Assistant start, and on template
  reload. It must stay trigger-based: it reads every sensor and is a sensor
  itself, so as a state-tracking template it re-triggers on its own changes.
  Home Assistant then logs "Template loop detected" and skips renders, which
  leaves state and summary out of sync.
- `sensor.house_ac_status` can stay state-tracking: it reads `climate`
  entities and is not one itself.
- General rule: a template entity must never iterate over its own domain
  unless it is trigger-based.

## Energy sensors

The Solar & Energy panel's backend is split by type, following the
repository's layout:

- `sites/vie/configuration/packages/energy.yaml`: the three daily utility
  meters. `utility_meter` has no include folder in `configuration.yaml`, so it
  lives in a package (loaded by `homeassistant: packages:`), the same as
  `auth_oidc`. If more meters are added later, consider a dedicated
  `utility_meter/` folder instead.
- `sites/vie/configuration/template/energy.yaml`: the three derived template
  sensors, next to all other template entities.

| Entity                        | What                            | Source                                             |
| ----------------------------- | ------------------------------- | -------------------------------------------------- |
| `sensor.solar_energy_today`   | Daily utility meter, Wh         | `sensor.pv_inverter_energy_total_fronius_inverter` |
| `sensor.grid_import_today`    | Daily utility meter, kWh        | `sensor.energy_meter_tpi`                          |
| `sensor.grid_export_today`    | Daily utility meter, kWh        | `sensor.energy_meter_tpo`                          |
| `sensor.grid_exported_today`  | Exported today for display, kWh | `sensor.grid_export_today` (unknown counts as 0)   |
| `sensor.grid_imported_today`  | Imported today for display, kWh | `sensor.grid_import_today` (unknown counts as 0)   |
| `sensor.solar_produced_today` | Produced today in kWh           | `sensor.solar_energy_today` / 1000                 |
| `sensor.solar_own_use_power`  | Own use now, W                  | solar power − export power, never below 0          |
| `sensor.solar_own_use_today`  | Own use today, kWh              | produced today − exported today, never below 0     |

Rules:

- The meters use the **same sources as the Energy dashboard**, so the values
  match it (own use = Energy dashboard's self-consumed solar).
- Use the daily utility meters, not the devices' own day counters: the
  inverter's counter is unavailable at night (about 19:30 to 06:30), and the
  inverter and the grid meter reset at slightly different times. The utility
  meters keep their value overnight and reset together at local midnight.
- "Own use" is the solar energy consumed in the house (*Eigenverbrauch*). The
  house's total consumption is own use plus import.
- The Today gauge's maximum is 35 kWh, a long summer day for 5 kWp.
- **Values survive restarts.** Utility meters restore their state and keep
  counting; a reset missed while Home Assistant was down is caught up at
  start. They only start from zero when first created or when their
  `unique_id` changes, so never change these IDs.
- **Missing values:** `unknown` means nothing has been counted yet and is shown
  as 0; `unavailable` means a fault and stays unavailable, so a broken meter is
  never hidden behind a 0. The dashboard reads the display sensors, never the
  raw meters.
- **First deploy:** new meters count only from that moment. To fill in the
  current day once, run `utility_meter.calibrate` on each meter with the
  Energy dashboard's values (`sensor.solar_energy_today` is in Wh).

## Washing machine

The LG washer integration provides the raw entities (`sensor.lg_washer_status`,
`sensor.lg_washer_remaining_time` and so on).
`sites/vie/configuration/template/washing_machine.yaml` turns them into what
the dashboard shows.

| Entity                                 | What                                                                                                                        |
| -------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `sensor.washing_machine_phase`         | The raw status grouped into one of six phases (below). The **only** place the status values are listed                      |
| `sensor.washing_machine_status`        | Pill text as its state ("Washing · 11 min left"); attributes `color`, and `overview` (the Overview row text); icon by phase |
| `sensor.washing_machine_end_time`      | Timestamp when the cycle ends; trigger-based                                                                                |
| `binary_sensor.washing_machine_active` | On while running, paused or in error; shows the Overview row                                                                |

| Phase     | Raw status values                                                                                         | Pill                           | Overview row |
| --------- | --------------------------------------------------------------------------------------------------------- | ------------------------------ | ------------ |
| running   | Measuring, Pre-wash, Washing, Rinsing, Spinning, Drying, Cooling, Rinse hold, Refreshing, Steam softening | blue, "Washing · 11 min left"  | shown        |
| paused    | Paused, Auto DT Open Pause                                                                                | orange, "Paused · 11 min left" | shown        |
| error     | Error, or `binary_sensor.lg_washer_error` on                                                              | red, the error message         | shown        |
| scheduled | Delayed                                                                                                   | grey, "Starts in 3 h"          | hidden       |
| finished  | End                                                                                                       | green, "Finished"              | hidden       |
| idle      | Off, Ready, Demo, unknown, unavailable                                                                    | grey, "Off" or "Ready"         | hidden       |

Rules:

- **Stale values are never shown.** Course, doses and initial time keep the
  last run's values; spin and temperature become unknown after a run. The
  panel shows settings only while a cycle is active, and leaves out any value
  that is unknown.
- **Pill order: status, time, settings, markers**: status and minutes left;
  "Done at"; temperature; spin; course (rarely changed, so last); Pre-wash and
  Intensive only when on. Other flags (extra rinse, steam, TurboWash) are not
  shown on purpose.
- **"Done at" and "min left" never repeat each other**: minutes left are in
  the status pill, the end time in its own pill.
- **The end time is trigger-based.** It is recalculated only when the remaining
  time or the phase changes, so it stays steady while the countdown runs and
  still follows the machine's re-estimates (up or down). Computing
  "now + remaining" on every render would shift by a minute as time passes.
- **The Overview row** appears only during an active cycle (running, paused,
  error), directly below the Security row, and leaves out the course. Paused
  and error count as active because they need someone; a finished cycle does
  not appear.
- **New status values** from an integration update fall into "idle" until
  they are added to the phase sensor.

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

| Kind                | Pattern in this installation                                                                                                                                       | Where it goes                                                 |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------- |
| Lights              | `switch.fs*_1`, `switch.fds*_*` (relay switches, not `light.*`)                                                                                                    | Lighting                                                      |
| Kitchen light       | Use proxy `switch.fs12_1`, never the physical `switch.fs9_1` (an automation mirrors them)                                                                          | Living Room lighting                                          |
| Shutters            | `cover.*`                                                                                                                                                          | Shutters                                                      |
| Air conditioners    | `climate.*_air_conditioner`                                                                                                                                        | A/C section, Overview A/C pill                                |
| Room climate        | `sensor.<room>_<room>_temperature_humidity_temperature` and `_humidity`                                                                                            | Climate section, Overview ring                                |
| Smoke               | `binary_sensor.ass<N>_smoke_detected`, battery `sensor.ass<N>_battery`                                                                                             | Safety, Battery, safety status (alarm)                        |
| Water leak          | `binary_sensor.ffs1_water_alarm_water_leak_detected`, `binary_sensor.ffs2_water_leak_detected`, battery `sensor.ffs<N>_battery_level`                              | Safety, Battery, safety status (alarm)                        |
| Motion              | `binary_sensor.fms<N>_home_security_motion_detection`, `binary_sensor.ring_rms1`, `binary_sensor.living_room_ring_motion_sensor`                                   | Safety, Battery                                               |
| Contacts            | `binary_sensor.ring_rcs<N>`, battery `sensor.ring_rcs<N>_*_battery`                                                                                                | Safety, Battery, safety status (attention)                    |
| Weather station     | `sensor.ecowitt_temp<N>`, `sensor.ecowitt_humidity<N>`, `binary_sensor.ecowitt_batt<N>` (1 is South, 2 is North)                                                   | Garden, Overview                                              |
| Forecast            | `weather.home` (met.no)                                                                                                                                            | Overview forecast                                             |
| Solar and grid      | `sensor.pv_power_photovoltaics_fronius_power_flow`, `sensor.pv_energy_day_fronius_power_flow`, `sensor.energy_meter_po` (export), `sensor.energy_meter_p` (import) | Overview                                                      |
| Presence simulation | `switch.presence_simulation` (custom integration `slashback100/presence_simulation`)                                                                               | Overview banner while on; switched on in Hallways, Front door |
| Washing machine     | `sensor.lg_washer_*`, `binary_sensor.lg_washer_*` (LG washer integration); the dashboard reads the `washing_machine_*` template sensors                            | Utility panel; Overview row while active                      |

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
2. Overview: add a ring to Indoor climate. If the room has an air
   conditioner, template its `name` as in
   [Temperature ring](#temperature-ring-overview-and-garden); otherwise use the
   plain room name. With more than four rooms the ring row wraps; keep
   `columns: 6`.
3. If the room has an air conditioner, add the A/C section between Lighting
   and Climate. `sensor.house_ac_status` picks the new unit up
   automatically.

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
   header from [Views and sections](#views-and-sections), sections in the
   order from [Layout rules](#layout-rules), and widths following the
   [Width rule](#width-rule).
2. Add `- !include dashboards/views/<room>.yaml` to `ui-lovelace.yaml` at the
   right position.
3. If the room has safety-relevant sensors, add a room safety status sensor
   with a new UUID4 and a [status pill row](#status-pill-row) under the
   Safety heading.
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

| Location                                           | Contents                                                            |
| -------------------------------------------------- | ------------------------------------------------------------------- |
| `template/safety_status.yaml`, house sensor        | Smoke (7), leak (2), contacts (3), alarm panel                      |
| `template/safety_status.yaml`, room sensors        | That room's alarms and contacts                                     |
| `views/overview.yaml`, "Smoke" summary             | Smoke sensors                                                       |
| `views/overview.yaml`, "Water leaks" summary       | Leak sensors                                                        |
| `views/overview.yaml`, "Doors and windows" summary | Contacts                                                            |
| `views/overview.yaml`, Indoor climate              | One ring per room; each ring label names its room's air conditioner |
| `template/washing_machine.yaml`, phase sensor      | Raw status values per phase; add new ones after integration updates |

Air conditioners and batteries are **not** listed anywhere: the
[dashboard status sensors](#dashboard-status-sensors) discover them.

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

1. `python3 scripts/validate_dashboard.py --entities entities.json` reports no
   errors. It covers the layout rules (headings, pill rows, widths, slot rule,
   battery row), template safety (unique IDs, template loops, `this`, the
   "All clear" fallback), Jinja syntax, hex colours in views, and entity IDs.
2. `yamllint -c .yamllint.yml .` passes.
3. Templates with new logic are tested with realistic states, including
   `unknown` and `unavailable`.
4. `python3 scripts/dashboard_inventory.py` has regenerated the inventory, and
   `markdownlint -c .markdownlint.yaml DASHBOARD.md` passes.
5. Screenshots of the changed tabs (desktop and phone; light and dark when
   colours changed) look as designed.

## Known pitfalls

Each of these happened during development. Check here first when something
looks wrong.

| Symptom                                                            | Cause                                                                          | Fix                                                                    |
| ------------------------------------------------------------------ | ------------------------------------------------------------------------------ | ---------------------------------------------------------------------- |
| No dashboard loads at all, not even the default                    | A custom card registers a frontend element twice (`vacuum-card`)               | Remove it from `extra_module_url.yaml`; add custom cards one at a time |
| New template entities never appear                                 | `template:` included with `!include_dir_merge_named`, which ignores list files | Use `!include_dir_merge_list`                                          |
| `lovelace: mode: yaml` has no effect                               | Removed in Home Assistant 2026.8                                               | Register the dashboard under `dashboards:` with the key `lovelace`     |
| Dashboard edits do not show                                        | Included view files are cached, or an old copy is deployed                     | Dashboard menu, Refresh; compare checksums of the deployed files       |
| Cards scattered in odd positions                                   | Masonry view reorders by height                                                | Use `type: sections`                                                   |
| "Template loop detected" in the log, state and attributes disagree | A template sensor iterates its own domain (`states.sensor`)                    | Make it trigger-based                                                  |
| A value lags one update behind                                     | Template reads `this`                                                          | Compute every field from live states                                   |
| Pills float or rows look ragged on phones                          | Widths below 12 keep their size on the phone's 12-unit grid                    | Use only 6, 12 or `full`                                               |
| Info under rings detaches from its ring on phones                  | Grid order pairs cards by position, which changes when wrapping                | Put the info into the ring (templated `name`) or into one stacked card |
| Gauge huge inside a stack                                          | The gauge sizes itself by width                                                | Put it between invisible spacer cards                                  |
| Pill background invisible                                          | Chip background equals card background                                         | Set `mush-chip-background` in the theme                                |
| Panels blend into the page                                         | Section background equals page background                                      | Set `ha-section-background-color`                                      |
| Heading badge cannot show three states                             | Badges have no templates or visibility                                         | Use a Mushroom template chip in a pill row                             |
| Sankey shows only one branch                                       | `remaining_parent_state` misbehaves                                            | Give the node explicit `add_entities` and `subtract_entities`          |
| Today values `unknown` after deploying                             | New utility meters have no reading yet                                         | Display sensors treat unknown as 0; `utility_meter.calibrate` once     |
| Daily solar value lost at night                                    | The inverter's day counter is unavailable while it sleeps                      | Use a daily utility meter on the inverter's total                      |
| `as_timestamp got invalid input 'None'`                            | A sun attribute is missing at startup                                          | Pass a default: `as_timestamp(value, none)`                            |
| Coloured text hard to read                                         | Palette colours on the pill background stay below 4.5:1                        | Keep text neutral; colour only icons                                   |

## Decision log

| Decision                                                    | Reason                                                                                                                           |
| ----------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `sections` views instead of masonry                         | Masonry reorders cards by height; sections keep the designed order                                                               |
| Native `tile` cards                                         | Consistent shape, real toggles and cover controls                                                                                |
| Flat rows and chip sections via two themes                  | Native way to group items without custom CSS                                                                                     |
| No shadows on section panels                                | Needs `card-mod` targeting frontend internals, which breaks on updates; depth comes from surface contrast                        |
| Status pill on its own row under the heading                | Correct on phones and keeps all headings aligned on desktop; replaced pills sharing the heading row                              |
| Status logic in template sensors                            | Reusable in automations; the dashboard stays declarative                                                                         |
| Gauge icons hidden                                          | The gauge offers no palette-safe icon colour; the mockups had no icon                                                            |
| A/C shown as ring label plus summary pill                   | Pills under rings detached from their rings on phones; the label is part of the ring, the pill carries counts per mode           |
| Camera removed from Living Room                             | Too dominant for its value                                                                                                       |
| `vacuum-card` not loaded                                    | Breaks the whole frontend (duplicate `ha-icon-button`)                                                                           |
| Shutter position and tilt only in the dialog                | Keeps rows compact; sliders are rarely needed                                                                                    |
| Dark mode uses its own desaturated palette                  | Saturated colours glare on dark surfaces                                                                                         |
| Widths limited to 6, 12 and full                            | Phones use a 12-unit grid; 8 and 9 left ragged rows                                                                              |
| Batteries summary on Overview                               | Low batteries are the most common silent failure; auto-discovered, no list to maintain                                           |
| Battery status sensor is trigger-based                      | It reads all sensors and is one itself; state tracking caused a template loop                                                    |
| Solar & Energy split into Now and Today                     | Same values in two time ranges, compared side by side                                                                            |
| Daily utility meters for today's values                     | The inverter's day counter is unavailable at night; all meters reset together at midnight                                        |
| Gauge between invisible spacer cards (one third)            | The gauge has no size option and would fill its stack; one fifth was too small on phones; spacers use only native cards          |
| Unknown shown as 0, unavailable kept                        | Unknown means nothing counted yet; unavailable means a fault that must stay visible                                              |
| No stack-in-card for chip-styled halves                     | Unmaintained dependency; the flat halves are separated by subtitles and spacing                                                  |
| Presence simulation banner on the Overview                  | Visible only while active, as the first row; impossible to overlook, gone when off                                               |
| Presence simulation switch in Hallways, Front door          | Rarely needed; placed where you leave the house, next to the lock and the alarm keypad, costing no Overview space                |
| Washing machine panel as pills only                         | A tile row with three large items protruded and looked sparse; pills keep the panel one line high, idle or running               |
| Washing machine on the Overview only during an active cycle | Below Security: Security stays first, and the row is still on a phone's first screen                                             |
| Temperature and spin before course                          | Course is rarely changed; temperature and spin change often. The course is left out on the Overview                              |
| Washing machine end time trigger-based                      | Stays steady during the countdown and follows real re-estimates                                                                  |
| Media and vacuum share a Devices panel                      | Keeps the Living Room's extra controls in one full-width row                                                                     |
| Neutral pill text, coloured icons                           | Coloured text fails contrast; green is reserved for all clear                                                                    |
| Shutters left of Safety in every room                       | Same place in every tab; Living Room's three shutters stack in the slot next to its 2×2 Safety grid                              |
| Living Room devices above the slot row                      | Controls first, status last; every tab ends with Shutters and Safety, then Batteries                                             |
| Batteries always their own full-width last row              | Safety is acted on, batteries only glanced at; rejected a compact battery panel beside Safety because it blurred that separation |
| Safety tiles always width 12                                | Consistent tile sizes across tabs; panels wrap instead of stretching tiles                                                       |
| Garden door shown in Garden and Living Room                 | The door belongs to both spaces; the Garden tab now follows the same slot row as every room                                      |

## Open topics

Ideas that were discussed but are not implemented. Check here before proposing
something new: it may already have been weighed.

| Topic                                                 | Status              | Notes                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| ----------------------------------------------------- | ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Sidebar collapsed to icons by default for all users   | Parked              | Home Assistant stores the sidebar mode per browser, with no server default. Plan: a small own frontend module via `extra_module_url` that collapses the sidebar only when no preference is stored, using the `hass-dock-sidebar` event. Needs the stored value for "collapsed" (browser DevTools, Local Storage, key `dockedSidebar`). The `custom-sidebar` plugin enforces the mode on every reload and has broken with several Home Assistant releases |
| Climate on the left (phones show it first)            | Open                | Rooms: lighting first because it is the most used control. Overview: Security first because its pill can be urgent. No decision yet                                                                                                                                                                                                                                                                                                                      |
| Solar gauges smaller than other rings on phones       | Accepted limitation | Possible fix: gauges directly in the section grid (sized by rows) plus screen-size visibility rules to keep the phone order. Risk: medium widths (tablet portrait) can interleave Now and Today. Test on real devices at several widths first                                                                                                                                                                                                            |
| Energy Flow with individual consumers                 | Future              | Candidates: plug energy sensors and the switches' consumption sensors. Option: Home Assistant's native energy cards (energy sankey with devices and a period selector), which need the devices added to the Energy dashboard                                                                                                                                                                                                                             |
| `utility_meter/` include folder                       | Future              | Worth it once there are more than the three energy meters                                                                                                                                                                                                                                                                                                                                                                                                |
| Start presence simulation automatically               | Idea                | An automation could turn it on when the alarm is armed away and off when disarmed, making the switch mostly unnecessary                                                                                                                                                                                                                                                                                                                                  |
| Washing machine automations                           | To do               | `automation.utility_room_washing_machine_started` and `..._completed` still use the old, disabled `washing_machine_*` entities and are silently broken. Migrate them to the `lg_washer` entities or to `sensor.washing_machine_phase`                                                                                                                                                                                                                    |
| Washing machine energy per run                        | Untested            | `sensor.lg_washer_energy` increases; whether it resets per run is unknown. Check before showing it                                                                                                                                                                                                                                                                                                                                                       |
| Default dashboard occasionally opens `/home/overview` | Unresolved          | The registration (key `lovelace`), the default setting and the user profile are correct. Suspected client-side caching; next step is a test in a private browser window                                                                                                                                                                                                                                                                                  |

## Entity inventory

Generated from the view and template files at the time of writing. Regenerate
or update it when views change.

### Overview (`overview.yaml`)

| Section                     | Span | Name                       | Entities                                                                                                                                                                                                                                                          |
| --------------------------- | ---- | -------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Presence Simulation         | 3    | Presence simulation is on  | `switch.presence_simulation`                                                                                                                                                                                                                                      |
| Security and Safety (chips) | 2    | Pill row                   | `binary_sensor.house_safety_status`                                                                                                                                                                                                                               |
| Security and Safety (chips) | 2    | Alarm                      | `alarm_control_panel.ring_control_panel`                                                                                                                                                                                                                          |
| Security and Safety (chips) | 2    | Front Door                 | `lock.entrance_door_lock`                                                                                                                                                                                                                                         |
| Security and Safety (chips) | 2    | Smoke                      | `binary_sensor.ass1_smoke_detected`, `binary_sensor.ass2_smoke_detected`, `binary_sensor.ass3_smoke_detected`, `binary_sensor.ass4_smoke_detected`, `binary_sensor.ass5_smoke_detected`, `binary_sensor.ass6_smoke_detected`, `binary_sensor.ass7_smoke_detected` |
| Security and Safety (chips) | 2    | Water leaks                | `binary_sensor.ffs1_water_alarm_water_leak_detected`, `binary_sensor.ffs2_water_leak_detected`                                                                                                                                                                    |
| Security and Safety (chips) | 2    | Doors & windows            | `binary_sensor.ring_rcs1`, `binary_sensor.ring_rcs2`, `binary_sensor.ring_rcs3`                                                                                                                                                                                   |
| Security and Safety (chips) | 2    | Batteries                  | `sensor.house_battery_status`                                                                                                                                                                                                                                     |
| Outdoor (forecast)          | 1    | Pill row                   | `sun.sun`                                                                                                                                                                                                                                                         |
| Outdoor (forecast)          | 1    | Condition                  | `weather.home`                                                                                                                                                                                                                                                    |
| Outdoor (forecast)          | 1    | Humidity · Pressure · Wind | `weather.home`                                                                                                                                                                                                                                                    |
| Washing Machine             | 3    | Washing machine            | `sensor.washing_machine_status`                                                                                                                                                                                                                                   |
| Indoor Climate              | 2    | Pill row                   | `sensor.house_ac_status`                                                                                                                                                                                                                                          |
| Indoor Climate              | 2    | Living Room (+ A/C mode)   | `sensor.living_room_living_room_temperature_humidity_temperature`, `sensor.living_room_living_room_temperature_humidity_humidity`, `climate.living_room_air_conditioner`                                                                                          |
| Indoor Climate              | 2    | Bedroom (+ A/C mode)       | `sensor.bedroom_bedroom_temperature_humidity_temperature`, `sensor.bedroom_bedroom_temperature_humidity_humidity`, `climate.bedroom_air_conditioner`                                                                                                              |
| Indoor Climate              | 2    | Office (+ A/C mode)        | `sensor.office_office_temperature_humidity_temperature`, `sensor.office_office_temperature_humidity_humidity`, `climate.office_air_conditioner`                                                                                                                   |
| Indoor Climate              | 2    | Tea Room                   | `sensor.tea_room_tea_room_temperature_humidity_temperature`, `sensor.tea_room_tea_room_temperature_humidity_humidity`                                                                                                                                             |
| Weather Station             | 1    | Pill row                   | `sensor.ecowitt_temp1`, `sensor.ecowitt_temp2`                                                                                                                                                                                                                    |
| Weather Station             | 1    | South                      | `sensor.ecowitt_temp1`, `sensor.ecowitt_humidity1`                                                                                                                                                                                                                |
| Weather Station             | 1    | North                      | `sensor.ecowitt_temp2`, `sensor.ecowitt_humidity2`                                                                                                                                                                                                                |
| Solar and Energy            | 3    | Solar                      | `sensor.pv_power_photovoltaics_fronius_power_flow`                                                                                                                                                                                                                |
| Solar and Energy            | 3    | Own use                    | `sensor.solar_own_use_power`                                                                                                                                                                                                                                      |
| Solar and Energy            | 3    | Exporting                  | `sensor.energy_meter_po`                                                                                                                                                                                                                                          |
| Solar and Energy            | 3    | Importing                  | `sensor.energy_meter_p`                                                                                                                                                                                                                                           |
| Solar and Energy            | 3    | Produced                   | `sensor.solar_produced_today`                                                                                                                                                                                                                                     |
| Solar and Energy            | 3    | Own use                    | `sensor.solar_own_use_today`                                                                                                                                                                                                                                      |
| Solar and Energy            | 3    | Exported                   | `sensor.grid_exported_today`                                                                                                                                                                                                                                      |
| Solar and Energy            | 3    | Imported                   | `sensor.grid_imported_today`                                                                                                                                                                                                                                      |
| Energy Flow                 | 3    | Sankey                     | `sensor.pv_power_photovoltaics_fronius_power_flow`, `sensor.energy_meter_p`, `sensor.energy_meter_po`                                                                                                                                                             |

### Living Room (`living_room.yaml`)

| Section                | Span | Name         | Entities                                                          |
| ---------------------- | ---- | ------------ | ----------------------------------------------------------------- |
| Lighting               | 1    | Living Room  | `switch.fds1_1`                                                   |
| Lighting               | 1    | Kitchen      | `switch.fs12_1`                                                   |
| Air Conditioner        | 1    | Living Room  | `climate.living_room_air_conditioner`                             |
| Climate                | 1    | Temperature  | `sensor.living_room_living_room_temperature_humidity_temperature` |
| Climate                | 1    | Humidity     | `sensor.living_room_living_room_temperature_humidity_humidity`    |
| Devices                | 3    | Media System | `switch.living_room_media_system`                                 |
| Devices                | 3    | Roborock     | `vacuum.tea_room_roborock`                                        |
| Shutters (chips)       | 1    | Kitchen      | `cover.living_room_kitchen`                                       |
| Shutters (chips)       | 1    | Garden Door  | `cover.garden_door`                                               |
| Shutters (chips)       | 1    | TV           | `cover.living_room_tv`                                            |
| Safety (chips)         | 2    | Pill row     | `binary_sensor.living_room_safety_status`                         |
| Safety (chips)         | 2    | Smoke        | `binary_sensor.ass3_smoke_detected`                               |
| Safety (chips)         | 2    | Kitchen leak | `binary_sensor.ffs1_water_alarm_water_leak_detected`              |
| Safety (chips)         | 2    | Motion       | `binary_sensor.living_room_ring_motion_sensor`                    |
| Safety (chips)         | 2    | Garden door  | `binary_sensor.ring_rcs3`                                         |
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
| Safety (chips)         | 2    | Pill row    | `binary_sensor.office_safety_status`                    |
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
| Safety (chips)         | 2    | Pill row    | `binary_sensor.tea_room_safety_status`                      |
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
| Safety (chips)         | 2    | Pill row    | `binary_sensor.bedroom_safety_status`                     |
| Safety (chips)         | 2    | Smoke       | `binary_sensor.ass2_smoke_detected`                       |
| Battery Levels (chips) | 3    | Smoke       | `sensor.ass2_battery`                                     |
| Battery Levels (chips) | 3    | Climate     | `sensor.bedroom_bedroom_temperature_humidity_battery`     |

### Bathrooms (`bathrooms.yaml`)

| Section                | Span | Name          | Entities                                            |
| ---------------------- | ---- | ------------- | --------------------------------------------------- |
| Lighting               | 3    | Bathroom      | `switch.fds2_2`                                     |
| Lighting               | 3    | Mirror        | `switch.fds2_1`                                     |
| Lighting               | 3    | Toilet        | `switch.fs1_1`                                      |
| Shutters (chips)       | 1    | Bathroom      | `cover.bathroom`                                    |
| Safety (chips)         | 2    | Pill row      | `binary_sensor.bathrooms_safety_status`             |
| Safety (chips)         | 2    | Toilet motion | `binary_sensor.fms1_home_security_motion_detection` |
| Battery Levels (chips) | 3    | Toilet motion | `sensor.fms1_battery_level`                         |

### Hallways (`hallways.yaml`)

| Section                | Span | Name                | Entities                                            |
| ---------------------- | ---- | ------------------- | --------------------------------------------------- |
| Lighting               | 3    | Hallway             | `switch.fs4_1`                                      |
| Lighting               | 3    | Hallway 2           | `switch.fds1_2`                                     |
| Lighting               | 3    | Entrance            | `switch.fs2_1`                                      |
| Front Door             | 1    | Front Door          | `lock.entrance_door_lock`                           |
| Front Door             | 1    | Keypad chirps       | `switch.alarm_keypad_chirps`                        |
| Front Door             | 1    | Presence simulation | `switch.presence_simulation`                        |
| Safety (chips)         | 2    | Pill row            | `binary_sensor.hallways_safety_status`              |
| Safety (chips)         | 2    | Hallway smoke       | `binary_sensor.ass7_smoke_detected`                 |
| Safety (chips)         | 2    | Entrance smoke      | `binary_sensor.ass4_smoke_detected`                 |
| Safety (chips)         | 2    | Front door          | `binary_sensor.ring_rcs1`                           |
| Safety (chips)         | 2    | Ring motion         | `binary_sensor.ring_rms1`                           |
| Safety (chips)         | 2    | Fibaro motion       | `binary_sensor.fms2_home_security_motion_detection` |
| Battery Levels (chips) | 3    | Hallway smoke       | `sensor.ass7_battery`                               |
| Battery Levels (chips) | 3    | Entrance smoke      | `sensor.ass4_battery`                               |
| Battery Levels (chips) | 3    | Front door          | `sensor.ring_rcs1_front_door_battery`               |
| Battery Levels (chips) | 3    | Ring motion         | `sensor.ring_rms1_entrance_room_battery`            |
| Battery Levels (chips) | 3    | Fibaro motion       | `sensor.fms2_battery_level`                         |
| Battery Levels (chips) | 3    | Keypad              | `sensor.ring_keypad_battery`                        |
| Battery Levels (chips) | 3    | Door lock           | `sensor.entrance_room_entrance_door_lock_battery`   |

### Garden (`garden.yaml`)

| Section                | Span | Name         | Entities                                           |
| ---------------------- | ---- | ------------ | -------------------------------------------------- |
| Lighting               | 1    | Pergola      | `switch.fds4_2`                                    |
| Weather Station        | 2    | Pill row     | `sensor.ecowitt_temp1`, `sensor.ecowitt_temp2`     |
| Weather Station        | 2    | South        | `sensor.ecowitt_temp1`, `sensor.ecowitt_humidity1` |
| Weather Station        | 2    | North        | `sensor.ecowitt_temp2`, `sensor.ecowitt_humidity2` |
| Shutters (chips)       | 1    | Garden Door  | `cover.garden_door`                                |
| Safety (chips)         | 2    | Pill row     | `binary_sensor.garden_safety_status`               |
| Safety (chips)         | 2    | Garden door  | `binary_sensor.ring_rcs3`                          |
| Battery Levels (chips) | 3    | South sensor | `binary_sensor.ecowitt_batt1`                      |
| Battery Levels (chips) | 3    | North sensor | `binary_sensor.ecowitt_batt2`                      |
| Battery Levels (chips) | 3    | Garden door  | `sensor.ring_rcs3_garden_door_battery`             |

### Utility (`utility.yaml`)

| Section                | Span | Name           | Entities                                                                         |
| ---------------------- | ---- | -------------- | -------------------------------------------------------------------------------- |
| Lighting               | 3    | Utility Room   | `switch.fs10_1`                                                                  |
| Lighting               | 3    | Storage Room   | `switch.fs3_1`                                                                   |
| Washing Machine        | 3    | Pill row       | `sensor.washing_machine_status`                                                  |
| Washing Machine        | 3    | Pill row       | `binary_sensor.washing_machine_active`, `sensor.washing_machine_end_time`        |
| Washing Machine        | 3    | Pill row       | `binary_sensor.washing_machine_active`, `sensor.lg_washer_temperature`           |
| Washing Machine        | 3    | Pill row       | `binary_sensor.washing_machine_active`, `sensor.lg_washer_spin`                  |
| Washing Machine        | 3    | Pill row       | `binary_sensor.washing_machine_active`, `sensor.lg_washer_course`                |
| Washing Machine        | 3    | Pill row       | `binary_sensor.lg_washer_pre_wash`, `binary_sensor.washing_machine_active`       |
| Washing Machine        | 3    | Pill row       | `binary_sensor.lg_washer_intensive_wash`, `binary_sensor.washing_machine_active` |
| Shutters (chips)       | 1    | Storage Room   | `cover.storage_room`                                                             |
| Safety (chips)         | 2    | Pill row       | `binary_sensor.utility_safety_status`                                            |
| Safety (chips)         | 2    | Smoke          | `binary_sensor.ass5_smoke_detected`                                              |
| Safety (chips)         | 2    | Leak           | `binary_sensor.ffs2_water_leak_detected`                                         |
| Safety (chips)         | 2    | Storage motion | `binary_sensor.fms3_home_security_motion_detection`                              |
| Safety (chips)         | 2    | Storage window | `binary_sensor.ring_rcs2`                                                        |
| Battery Levels (chips) | 3    | Storage motion | `sensor.fms3_battery_level`                                                      |
| Battery Levels (chips) | 3    | Storage window | `sensor.ring_rcs2_front_window_battery`                                          |
| Battery Levels (chips) | 3    | Leak           | `sensor.ffs2_battery_level`                                                      |
| Battery Levels (chips) | 3    | Smoke          | `sensor.ass5_battery`                                                            |

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
| `binary_sensor.garden_safety_status`      | none                                                                                                                                                                                                                                                                                                                                                                                                        | `binary_sensor.ring_rcs3`                                                       |

### Dashboard status sensors (`template/dashboard_status.yaml`)

| Entity                        | Discovers                                         | Used by                              |
| ----------------------------- | ------------------------------------------------- | ------------------------------------ |
| `sensor.house_ac_status`      | All `climate` entities                            | Overview, Indoor climate pill row    |
| `sensor.house_battery_status` | All battery `sensor` and `binary_sensor` entities | Overview, Security batteries summary |
