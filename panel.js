const FLOW_URL = 'https://flow.google.com/';
const CONTENT_SCRIPT_ID = 'flow-helper';
const UNSUPPORTED_COUNTRY_PATH = '/unsupported-country';

const STATES = {
  active: {
    dot: 'ok',
    badge: 'ACTIVE',
    title: 'Protection Active',
    desc: 'Helper is active on this tab — region check patched.',
    interceptor: 'Active & Patched',
    strong: true,
    text: 'Helper is active on this tab — region check patched.'
  },
  armed: {
    dot: 'armed',
    badge: 'READY',
    title: 'Ready & Waiting',
    desc: 'Armed and waiting for Flow’s config response…',
    interceptor: 'Armed',
    strong: false,
    text: 'Armed and waiting for Flow’s config response…'
  },
  enabled: {
    dot: 'ok',
    badge: 'ENABLED',
    title: 'Protection Enabled',
    desc: 'Helper is enabled. Open or reload Flow to apply.',
    interceptor: 'Armed',
    strong: true,
    text: 'Helper is on. Reload your Flow tabs to apply.'
  },
  disabled: {
    dot: 'idle',
    badge: 'DISABLED',
    title: 'Protection Off',
    desc: 'Helper is off. Flow will show unsupported country.',
    interceptor: 'Disabled',
    strong: false,
    text: 'Helper is off. Flow may show the unsupported-country page.'
  },
  reloadTab: {
    dot: 'warn',
    badge: 'RELOAD',
    title: 'Reload Required',
    desc: 'Reload this Flow tab to activate the helper.',
    interceptor: 'Pending Reload',
    strong: false,
    text: 'Reload this Flow tab to activate the helper.'
  },
  saved: {
    dot: 'ok',
    badge: 'SAVED',
    title: 'Settings Saved',
    desc: 'Saved. Reload any open Flow tabs to apply.',
    interceptor: 'Armed',
    strong: true,
    text: 'Saved. Reload any open Flow tabs to apply.'
  },
  schemaMismatch: {
    dot: 'bad',
    badge: 'UPDATE',
    title: 'Update Needed',
    desc: 'Flow config changed — helper needs an update.',
    interceptor: 'Schema Mismatch',
    strong: true,
    text: 'Flow may have changed — the helper needs an update.'
  },
  specUnavailable: {
    dot: 'warn',
    badge: 'WARNING',
    title: 'Check Config',
    desc: 'Specification check failed. Try reloading tab.',
    interceptor: 'Check Failed',
    strong: true,
    text: 'Couldn’t reach FlowPass server. Check your connection and reload.'
  },
  awaitingSpec: {
    dot: 'armed',
    badge: 'STARTING',
    title: 'Starting Up',
    desc: 'Initializing local configuration… almost ready.',
    interceptor: 'Initializing',
    strong: false,
    text: 'Connecting to FlowPass… almost ready.'
  }
};

const MSG_PICK_FLOW_TAB = 'Switch to a Flow tab first.';
const MSG_SAVE_FAILED = 'The setting could not be saved.';

const toggle = document.getElementById('toggle');
const statusEl = document.getElementById('status');
const statusCard = document.getElementById('status-card');
const statusTitle = document.getElementById('status-title');
const statusDesc = document.getElementById('status-desc');
const statusPill = document.querySelector('.status-pill');
const statusPillText = document.querySelector('.status-pill-text');
const interceptorState = document.getElementById('interceptor-state');
const errorEl = document.getElementById('error');
const errorBox = document.getElementById('error-box');
const reload = document.getElementById('reload');
const openBtn = document.getElementById('open');

let tab;

function setStatus(stateKey) {
  const s = STATES[stateKey] || STATES.enabled;
  
  if (statusCard) {
    statusCard.setAttribute('data-state', s.dot);
  }

  if (statusPill) {
    statusPill.className = 'status-pill status-pill--' + s.dot;
  }
  if (statusPillText) {
    statusPillText.textContent = s.badge;
  }
  if (statusTitle) {
    statusTitle.textContent = s.title;
  }
  if (statusDesc) {
    statusDesc.textContent = s.desc;
  }
  if (interceptorState) {
    interceptorState.textContent = s.interceptor;
    interceptorState.className = 'matrix-value info-val info-val--' + s.dot;
  }

  if (statusEl) {
    statusEl.classList.toggle('is-strong', !!s.strong);
    const legacyDot = statusEl.querySelector('.status-dot');
    if (legacyDot) legacyDot.className = 'status-dot status-dot--' + s.dot;
    const legacyText = statusEl.querySelector('.status-text');
    if (legacyText) legacyText.textContent = s.desc;
  }
}

function setEnabled(enabled) {
  toggle.setAttribute('aria-checked', String(enabled));
  toggle.classList.toggle('is-checked', !!enabled);
}

function showError(msg) {
  if (errorEl) errorEl.textContent = msg || '';
  if (errorBox) errorBox.hidden = !msg;
}

async function init() {
  showError('');
  const registered = await chrome.scripting.getRegisteredContentScripts({
    ids: [CONTENT_SCRIPT_ID]
  });
  const isEnabled = registered.length > 0;
  setEnabled(isEnabled);

  [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  const isFlowTab = tab?.url?.startsWith(FLOW_URL);

  if (reload) reload.hidden = !isFlowTab;
  setStatus(isEnabled ? 'enabled' : 'disabled');

  if (isFlowTab && isEnabled) {
    try {
      const diag = await chrome.tabs.sendMessage(tab.id, { type: 'status' });
      if (diag?.applied) {
        setStatus('active');
      } else if (diag?.state === 'armed') {
        setStatus('armed');
      } else if (diag?.state === 'awaiting-spec') {
        setStatus('awaitingSpec');
      } else if (diag?.state?.startsWith('spec unavailable') || diag?.state?.startsWith('spec invalid')) {
        setStatus('specUnavailable');
      } else if (diag?.state?.startsWith('schema mismatch')) {
        setStatus('schemaMismatch');
      } else {
        setStatus('reloadTab');
      }
    } catch {
      setStatus('reloadTab');
    }
  }
  toggle.disabled = false;
}

toggle.addEventListener('click', async () => {
  const nextState = toggle.getAttribute('aria-checked') !== 'true';
  toggle.disabled = true;
  showError('');

  try {
    const res = await chrome.runtime.sendMessage({
      type: 'setEnabled',
      enabled: nextState
    });
    if (!res?.ok) {
      throw new Error(res?.error || MSG_SAVE_FAILED);
    }
    setEnabled(nextState);
    setStatus(nextState ? 'saved' : 'disabled');
  } catch (err) {
    setEnabled(!nextState);
    showError(err.message);
  } finally {
    toggle.disabled = false;
  }
});

if (openBtn) {
  openBtn.onclick = () => chrome.tabs.create({ url: FLOW_URL });
}

if (reload) {
  reload.onclick = async () => {
    try {
      const currentTab = await chrome.tabs.get(tab.id);
      if (!currentTab?.url?.startsWith(FLOW_URL)) {
        throw new Error(MSG_PICK_FLOW_TAB);
      }
      const url = new URL(currentTab.url);
      if (url.pathname.endsWith(UNSUPPORTED_COUNTRY_PATH)) {
        url.pathname = url.pathname.replace(/\/unsupported-country$/, '');
        await chrome.tabs.update(tab.id, { url: url.href });
      } else {
        await chrome.tabs.reload(tab.id);
      }
      window.close();
    } catch (err) {
      showError(err.message);
    }
  };
}

init().catch(err => {
  showError(err.message);
});