# FlowPass

FlowPass is a Chrome extension that enables seamless access to Google Flow without requiring you to change your Google account region.

## Overview & Architecture

- **Manifest V3 Extension**: Built with minimal required permissions (`scripting` and host permission for `https://flow.google.com/*`).
- **MAIN World Execution**: Uses `chrome.scripting.registerContentScripts` to run `engine.js` directly within the page context at `document_start`.
- **Client-Side Region Adaptation**: Intercepts Google Flow RPC responses in-memory to prevent unsupported country redirections.
- **Core Stability**: Core operational scripts (`app.js`, `engine.js`, `link.js`, `panel.js`, `stat.js`) remain preserved and intact.

## Local Installation in Chrome

1. Extract the extension files to a folder.
2. In Google Chrome, go to `chrome://extensions`.
3. Toggle on **Developer mode** in the top-right corner.
4. Click **Load unpacked** and select the extension directory.
5. Open the FlowPass popup, turn on the access switch, and reload your Google Flow tab.

## Publishing to Chrome Web Store

To build a clean zip archive for uploading to the Chrome Developer Dashboard:

```bash
zip -r flowpass.zip . -x "*.git*" "*.DS_Store*" "*.zip"
```
