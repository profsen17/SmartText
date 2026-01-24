# SmartText

SmartText is a lightweight, tab-based desktop text editor built with **Python** and **Qt/QML (PySide6)**. It delivers a clean writing surface, quick-access action overlays, and a customizable shortcuts/settings panel, all wrapped in a modern frameless window UI.

## Features

- **Multi-tab editing** with a clear modified indicator per tab.
- **Open / Save / Save As** flows with a persistent session restore on next launch.
- **Hover-activated quick actions** (new/open/save/save as/settings) and a slim left sidebar of editor commands.
- **Settings window** for font size and keyboard shortcut customization.
- **Cross-platform storage** using Qt’s AppData location for settings and sessions.

## Tech stack

- **Python 3.10+**
- **PySide6** (Qt 6 / QML)

## Getting started

### 1) Install dependencies

```bash
python -m venv .venv
source .venv/bin/activate
pip install -e .
```

### 2) Run the app

```bash
smarttext
```

> Alternatively, you can run the module directly:
>
> ```bash
> python -m smarttext.main
> ```

## Usage basics

- **Create a new file**: Click **New** (sidebar or overlay) or use the shortcut (default: `Ctrl+N`).
- **Open a file**: Use **Open** (sidebar or overlay) or `Ctrl+O`.
- **Save**: Use **Save** or `Ctrl+S`.
- **Save As**: Use **Save As** or `Ctrl+Shift+S`.
- **Switch tabs**: Click tabs along the top bar.

## Default shortcuts

| Action   | Shortcut      |
|----------|---------------|
| New      | `Ctrl+N`       |
| Open     | `Ctrl+O`       |
| Save     | `Ctrl+S`       |
| Save As  | `Ctrl+Shift+S` |

You can update these in **Settings → Shortcuts**, which validates entries to ensure they include at least one modifier (Ctrl/Alt/Shift/Meta).

## Settings & data storage

SmartText persists:

- **User settings** (font size + shortcuts)
- **Session state** (open tabs + active tab index)

Both are stored under the OS-specific **Qt AppData location** for the application.

## Project structure

```
src/
  smarttext/
    app.py               # QML bootstrap & context wiring
    main.py              # App entry point
    core/                # Document model + settings store
    bridge/              # QML bridge/controller + session storage
    qml/                 # UI (QML), components, and icons
```

## Contributing

Issues and PRs are welcome. If you’re making UI changes, please include a screenshot in the PR and describe any UX changes.

## License

No license has been specified yet.
