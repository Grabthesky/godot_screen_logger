# 🖥️ GodotScreenLogger

A lightweight Godot 4.6+ addon that displays custom debug logs directly on screen during Play mode — no more squinting at the Output panel.

![Godot 4.6+](https://img.shields.io/badge/Godot-4.6%2B-478cbf?logo=godotengine&logoColor=white)
![GDScript](https://img.shields.io/badge/GDScript-blue)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

---

## ✨ Features

- 📋 **Ephemeral logs** — messages that fade out automatically after a configurable duration
- 📌 **Persistent watches** — live values that update in place every frame, perfect for position, velocity, HP, etc.
- 🔁 **Message grouping** — repeated messages are collapsed into a single line with a `×N` counter instead of flooding the screen
- ❓ **Conditional logging** — only log when a condition is met, keeping noise to a minimum
- 📐 **Resolution scaling** — all UI elements scale automatically with the viewport size
- 📍 **Configurable corners** — place each panel in any of the four corners, with automatic collision detection between them
- 🎨 **Color-coded log levels** — `info`, `success`, `warning`, `error`, `debug`

---

## 📦 Installation

1. Download or clone this repository.
2. Copy the `addons/screen_logger/` folder into your project's `addons/` directory.
3. Open **Project → Project Settings → Plugins**.
4. Enable **Screen Logger**.

That's it. The `ScreenLog` autoload is now available in every script without any imports.

---

## 🚀 Quick Start

```gdscript
extends CharacterBody2D

func _ready() -> void:
    ScreenLog.success("Player initialized")
    ScreenLog.log("Start position", position)

func _physics_process(delta: float) -> void:
    # Live values — update in place, never create new lines
    ScreenLog.watch("Position", position)
    ScreenLog.watch("Velocity", velocity)
    ScreenLog.watch("On floor", is_on_floor())

func take_damage(amount: int) -> void:
    ScreenLog.error("Damage received: %d" % amount)
```

---

## 📖 Full API

### Ephemeral logs

Messages appear with a fade-in, stay for `MESSAGE_DURATION` seconds, then fade out.

```gdscript
ScreenLog.info("Simple message")
ScreenLog.success("Everything went fine")
ScreenLog.warning("Something looks off")
ScreenLog.error("Something went wrong")
ScreenLog.debug("Low-level detail")
ScreenLog.log("Label", value)      # Accepts any Variant — int, float, Vector2, bool…
ScreenLog.clear_logs()             # Remove all ephemeral messages immediately
```

### Persistent watches

Values update in place. Call them every frame inside `_process` or `_physics_process`.

```gdscript
ScreenLog.watch("HP", health)               # Basic watch
ScreenLog.watch("HP", health, "❤")          # With an icon prefix
ScreenLog.unwatch("HP")                     # Remove a single watch
ScreenLog.clear_watches()                   # Remove all watches
```

`Vector2` and `Vector3` values are automatically formatted to two decimal places:
```
Position   (120.00, 48.50)
Direction  (0.00, -1.00, 0.00)
```

### Conditional logs

Only log when a condition is true — great for avoiding per-frame noise.

```gdscript
ScreenLog.log_if(velocity.length() > 500.0, "Moving fast")
ScreenLog.info_if(is_on_floor(), "Grounded")
ScreenLog.warning_if(ammo < 5, "Low ammo")
ScreenLog.error_if(health <= 0, "Dead")
ScreenLog.debug_if(Input.is_action_pressed("ui_accept"), "Jumping")
```

Two convenience methods that pick the color based on the condition result:

```gdscript
# Green if true, red if false
ScreenLog.log_ok(is_on_floor(), "Floor collision")

# Green if true, yellow if false
ScreenLog.log_warn(ammo > 5, "Ammo OK")
```

### Panel positioning

Each panel can be placed independently in any corner.

```gdscript
# Available corners
ScreenLog.Corner.TOP_LEFT
ScreenLog.Corner.TOP_RIGHT
ScreenLog.Corner.BOTTOM_LEFT
ScreenLog.Corner.BOTTOM_RIGHT

# Move individual panels
ScreenLog.set_log_corner(ScreenLog.Corner.BOTTOM_LEFT)
ScreenLog.set_watch_corner(ScreenLog.Corner.BOTTOM_RIGHT)

# Move both at once
ScreenLog.set_corners(ScreenLog.Corner.TOP_LEFT, ScreenLog.Corner.TOP_RIGHT)
```

If both panels are assigned the same corner they are placed side by side automatically. If they share the same row but would overlap on narrow screens, they are pushed apart so neither is hidden.

---

## ⚙️ Configuration

Constants at the top of `screen_log.gd` that you can tweak to suit your project:

| Constant | Default | Description |
|---|---|---|
| `MAX_MESSAGES` | `15` | Maximum simultaneous ephemeral messages |
| `MESSAGE_DURATION` | `5.0` | Seconds each message stays visible |
| `BASE_RESOLUTION` | `Vector2(1920, 1080)` | Reference resolution for UI scaling |
| `BASE_FONT_SIZE` | `16` | Font size at the base resolution |
| `BASE_PANEL_WIDTH_LOG` | `340` | Width of the log panel at base resolution |
| `BASE_PANEL_WIDTH_WATCH` | `280` | Width of the watch panel at base resolution |
| `BASE_PANEL_OFFSET` | `10` | Distance from the screen edge |

---

## 📁 File Structure

```
addons/
└── screen_logger/
    ├── plugin.cfg
    ├── plugin.gd
    └── screen_log.gd
```

---

## 📄 License

MIT — free to use in personal and commercial projects.