# ROS Monitor — Flutter desktop app

Multi-robot ROS 2 topic monitor. Connect via ROSBridge WebSocket and watch
multiple topic streams side-by-side in a resizable panel grid.

---

## Prerequisites

| tool | version |
|------|---------|
| Flutter | ≥ 3.10 (stable) |
| Dart | ≥ 3.0 |
| ROS 2 + rosbridge | any distro |

---

## ROS side — start rosbridge

```bash
sudo apt install ros-$ROS_DISTRO-rosbridge-suite

# launch WebSocket server (default port 9090)
ros2 launch rosbridge_server rosbridge_websocket_launch.xml
```

---

## Run in dev

```bash
# from project root
flutter pub get
flutter run -d linux        # or macos / windows
```

---

## Build standalone executable

```bash
# Linux
flutter build linux --release
# output: build/linux/x64/release/bundle/ros_monitor

# macOS
flutter build macos --release

# Windows
flutter build windows --release
```

Distribute the entire `bundle/` folder — no Flutter install needed on target machine.

---

## Usage

1. Enter your machine IP and port (default `localhost:9090`) → **connect**
2. Topics appear in the left sidebar, grouped by namespace
3. Click any topic to add a panel, or use **add panel** button
4. Panels auto-scroll and show live Hz rate
5. Use column selector (1–4) to control grid layout
6. Per-panel controls:
   - **mode** — `latest` (only newest msg) / `streaming` (all msgs) / `history`
   - **pause/resume** — freeze the panel
   - **clear** — wipe the buffer
   - **copy** — copy latest message JSON to clipboard
7. Multiple workspace tabs — `Ctrl+T` new tab, `Ctrl+W` close tab
8. Layout saves automatically to disk

---

## Keyboard shortcuts

| key | action |
|-----|--------|
| `Ctrl+T` | new workspace tab |
| `Ctrl+W` | close current tab |
| `Ctrl+\` | toggle sidebar |

---

## Architecture overview

```
lib/
├── main.dart                   entry point
├── theme/app_theme.dart        dark theme tokens
├── models/
│   ├── rosbridge.dart          protocol message types
│   ├── panel.dart              PanelConfig / PanelState
│   └── workspace.dart          WorkspaceTab / ConnectionConfig
├── services/
│   └── rosbridge_service.dart  WebSocket client + Riverpod providers
├── providers/
│   ├── panel_provider.dart     per-panel subscription + ring buffer
│   └── workspace_provider.dart tab/panel CRUD + SharedPreferences persistence
├── widgets/
│   ├── connection_bar.dart     top host/port/status bar
│   ├── topic_sidebar.dart      namespace-grouped topic list
│   └── topic_panel.dart        one subscribed topic pane
└── screens/
    └── dashboard_screen.dart   tab bar + panel grid + add dialog
```

---

## What to build next

- [ ] Topic statistics panel (Hz graph, drop counter, latency)
- [ ] Cross-robot comparison view (diff two topics by timestamp)
- [ ] Recording / export to JSONL or ROS bag
- [ ] Image topic viewer (`sensor_msgs/Image`)
- [ ] Point cloud basic viewer
- [ ] Local ROS bridge auto-launch (no separate terminal needed)
- [ ] `.msg` schema importer for annotated JSON tree
