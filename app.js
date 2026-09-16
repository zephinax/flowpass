const registration = {
  id: 'flow-helper',
  matches: ['https://flow.google.com/*'],
  js: ['engine.js'],
  runAt: 'document_start',
  world: 'MAIN',
  persistAcrossSessions: true,
};
const REGISTRATIONS = [registration];
const REGISTRATION_IDS = REGISTRATIONS.map(a => a.id);

const LOCAL_SPEC = {
  v: 1,
  origin: 'https://flow.google.com',
  path: '/_/AiSandboxAngularFrontend/data/batchexecute',
  rpcids: 'cPZSdc',
  tag: 'wrb.fr',
  flagIndex: 30,
  minLength: 32,
};

chrome.runtime.onInstalled.addListener(async ({ reason }) => {
  if (reason !== 'install') return;
  try {
    await chrome.scripting.registerContentScripts(REGISTRATIONS);
  } catch (err) {
    console.error('FlowPass setup failed:', err.message);
  }
});

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (sender.id !== chrome.runtime.id) return;
  if (message?.type === 'getSpec') {
    sendResponse({ ok: true, spec: LOCAL_SPEC });
    return;
  }
  if (!sender.tab && message?.type === 'setEnabled') {
    (async () => {
      const registered = await chrome.scripting.getRegisteredContentScripts({
        ids: REGISTRATION_IDS,
      });
      if (message.enabled && registered.length === 0) {
        await chrome.scripting.registerContentScripts(REGISTRATIONS);
      } else if (!message.enabled && registered.length > 0) {
        await chrome.scripting.unregisterContentScripts({
          ids: REGISTRATION_IDS,
        });
      }
      sendResponse({ ok: true });
    })().catch(err => sendResponse({ ok: false, error: err.message }));
    return true;
  }
});