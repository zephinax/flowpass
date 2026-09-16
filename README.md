<p align="center">
  <img src="assets/icon.png" alt="FlowPass Logo" width="80" height="92" />
</p>

<p align="center">
  <img src="assets/logo-type.png" alt="FlowPass" height="36" />
</p>

<p align="center">
  <strong>Autonomous client-side region adaptation extension for Google Flow.</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#how-it-works">How It Works</a> •
  <a href="#installation">Installation</a> •
  <a href="#usage">Usage</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#packaging--publishing">Publishing</a> •
  <a href="#privacy--security">Privacy</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Manifest-V3-06b6d4?style=flat-square" alt="Manifest V3" />
  <img src="https://img.shields.io/badge/Platform-Chrome%20%7C%20Edge%20%7C%20Brave-10b981?style=flat-square" alt="Chromium" />
  <img src="https://img.shields.io/badge/Privacy-Zero%20Telemetry-3b82f6?style=flat-square" alt="Zero Telemetry" />
  <img src="https://img.shields.io/badge/Mode-100%25%20Local-8b5cf6?style=flat-square" alt="100% Local" />
</p>

---

## Highlights

FlowPass is a lightweight Chromium extension (Manifest V3) designed to grant access to [Google Flow](https://flow.google.com) from any location without needing to modify your primary Google account country or reroute web traffic through remote VPNs/proxies.

- **Zero Remote Relays**: All intercepting and patching occurs entirely in-memory within your browser sandbox.
- **Zero Telemetry**: No tracking, no external configuration servers, no analytics.
- **Non-Destructive**: Leaves your Google account region, profile settings, and payment profiles unchanged.
- **Obsidian Dark Control Panel**: Built-in HUD matrix showing engine state, target gateway, and tab status at a glance.

---

## Features

- **In-Memory RPC Interception**: Intercepts and adapts batchexecute response payloads on `flow.google.com` before the page router triggers region fallback.
- **One-Click Protection Switch**: Easily arm or disarm the protection engine directly from the extension popup.
- **Live State HUD**: Displays real-time status across states (`ACTIVE`, `READY`, `ENABLED`, `DISABLED`, `RELOAD`).
- **Deep Chromium Integration**: Built on standard `chrome.scripting.registerContentScripts` and `MAIN` world script execution.
- **Ultra Lightweight**: Minimal bundle size (~290 KB), no heavy third-party framework overhead.

---

## How It Works

```
flow.google.com/
   ├── batchexecute RPC request
   └── Response intercepted by FlowPass Engine (MAIN World)
          ├── Analyzes schema & response tokens
          ├── Adapts regional capability flag in-memory
          └── Page renders fully enabled interface (Bypasses /unsupported-country)
```

1. When `flow.google.com` initializes, Google sends batchexecute RPCs verifying region availability and feature eligibility.
2. FlowPass runs an in-memory hook at `document_start` inside the page's execution context (`MAIN` world).
3. The hook inspects the batchexecute response structure and sets the regional allowance flag.
4. The web application receives the patched response and allows you to enter the application smoothly instead of redirecting to `/unsupported-country`.

---

## Installation

### Method: Load Unpacked (Developer Mode)

1. Clone or download this repository:
   ```bash
   git clone https://github.com/zephinax/flowpass.git
   ```
2. Open Google Chrome (or any Chromium browser: Brave, Edge, Opera, Arc, Vivaldi).
3. Navigate to `chrome://extensions`.
4. Turn on **Developer mode** using the toggle in the upper-right corner.
5. Click **Load unpacked** in the top-left toolbar.
6. Select the `flowpass` project folder.
7. The FlowPass icon will now appear in your browser extension tray.

---

## Usage

1. **Activate the Engine**: Click the FlowPass extension icon in your browser toolbar and ensure the **Protection Engine** toggle is switched **ON**.
2. **Open Google Flow**: Navigate to [flow.google.com](https://flow.google.com) or click **Open Flow** from the popup.
3. **Check Status**: The popup will indicate **Protection Active** with a green pulse beacon when the tab is patched.
4. **Reload Tab**: If you opened Flow before activating the extension, click **Reload Tab** inside the popup to apply the hook.

---

## Project Structure

```
flowpass/
├── manifest.json       # Manifest V3 extension definition & permissions
├── app.js              # Background service worker (dynamic script lifecycle)
├── engine.js           # Core in-memory RPC interceptor (MAIN world)
├── link.js             # Bridge content script (document_start)
├── stat.js             # Diagnostic state reader content script (document_idle)
├── panel.html          # Extension popup UI
├── panel.js            # Popup state manager & messaging controller
├── panel.css           # Obsidian dark luminous theme styles
├── info.html           # Standalone offline guide & documentation
├── assets/             # Extension icon set (16, 32, 48, 128) & brand logotype
└── .gitignore          # Repository ignore rules
```

---

## Packaging & Publishing

To create a clean release archive ready for publishing or submitting to the [Chrome Developer Dashboard](https://chrome.google.com/webstore/devconsole):

```bash
zip -r flowpass.zip . -x "*.git*" "*.DS_Store*" "*.zip"
```

The resulting `flowpass.zip` archive contains only the required extension files, strictly adhering to Chrome Web Store packaging standards.

### Automated GitHub Release Helper

To package and publish a new GitHub release in one command:

```bash
# Interactive mode (reads current or prompts version)
./scripts/release.sh

# Or specify a target version
./scripts/release.sh 1.2.0

# Create draft release
./scripts/release.sh 1.2.0 --draft
```

The script automatically bumps `manifest.json`, commits and pushes the version change, packages the extension archive, and publishes the release on GitHub with release notes.

---

## Privacy & Security

- **100% Local**: Operates exclusively within your client's browser environment.
- **No Third-Party Connections**: Does not connect to external servers, APIs, or telemetry backends.
- **Minimal Permissions**: Requests only `scripting` and `flow.google.com/*` host permission—strictly scoped to where it operates.

---

## Author & Community

- **Creator**: [Zephinax](https://zephinax.com)
- **Telegram**: [@FlowPass](https://t.me/FlowPass)

---

## License

This project is licensed under the [MIT License](LICENSE).
