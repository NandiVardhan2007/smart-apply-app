import 'dart:convert';

/// Production-grade LinkedIn Auto Applier Engine.
/// Sanitized version with NO backticks to avoid Dart/JS interpolation conflicts.
class AutomationScript {

  static const String bridgeProbeScript = '''
(function() {
  try {
    const msg = JSON.stringify({ type: "__bridge_ack__", ts: Date.now() });
    if (window.ApplierChannel && window.ApplierChannel.postMessage) {
      window.ApplierChannel.postMessage(msg);
    } else if (window.chrome && window.chrome.webview && window.chrome.webview.postMessage) {
      window.chrome.webview.postMessage(msg);
    }
  } catch(e) {}
})();
''';

  static String buildEngineScript({
    required Map<String, dynamic> profile,
    required Map<String, dynamic> jobPrefs,
    required String serverUrl,
    required String token,
    bool humanMode = true,
    bool coverLetter = true,
    int maxApps = 20,
    String? resumeUrl,
  }) {
    final profileJson = jsonEncode(profile);
    final prefsJson = jsonEncode(jobPrefs);
    final escapedServer = serverUrl.replaceAll("'", "\\'");
    final escapedToken = token.replaceAll("'", "\\'");

    return '''
(function() {
  try {
    if (window.__SA_ENGINE_RUNNING) return;
    window.__SA_ENGINE_RUNNING = true;

    function sendToFlutter(obj) {
      try {
        const msg = JSON.stringify(obj);
        if (window.chrome && window.chrome.webview && window.chrome.webview.postMessage) {
          window.chrome.webview.postMessage(msg);
        } else if (window.ApplierChannel && window.ApplierChannel.postMessage) {
          window.ApplierChannel.postMessage(msg);
        }
      } catch (e) {}
    }

    sendToFlutter({ type: 'log', message: '🚀 Engine initializing...', state: 'info' });

    const CONFIG = {
      serverUrl: '$escapedServer',
      token: '$escapedToken',
      profile: $profileJson,
      jobPrefs: $prefsJson,
      humanMode: $humanMode,
      coverLetter: $coverLetter,
      maxApps: $maxApps,
      resumeUrl: ${resumeUrl != null ? "'${resumeUrl.replaceAll("'", "\\'")}'" : 'null'},
      _currentJobId: null,
      _generation: Date.now(),
    };

    sendToFlutter({
      type: 'bot_started',
      message: 'Engine booted',
      generation: CONFIG._generation,
    });

    let BOT_RUNNING = true;
    let STATS = { applied: 0, skipped: 0, errors: 0, letters: 0 };

    function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

    function log(msg, level = 'info') {
      const entry = '[' + new Date().toLocaleTimeString('en-US', { hour12: false }) + '] ' + msg;
      sendToFlutter({ type: 'log', message: entry, state: level });
    }

    function updateStats() {
      sendToFlutter({ type: 'stats_update', stats: STATS });
    }

    function setNative(el, val) {
      const proto = el.tagName === 'TEXTAREA' ? window.HTMLTextAreaElement.prototype : window.HTMLInputElement.prototype;
      const setter = Object.getOwnPropertyDescriptor(proto, 'value')?.set;
      if (setter) setter.call(el, val); else el.value = val;
      el.dispatchEvent(new Event('input', { bubbles: true }));
      el.dispatchEvent(new Event('change', { bubbles: true }));
    }

    function getLabel(el) {
      if (el.getAttribute('aria-label')) return el.getAttribute('aria-label');
      if (el.id) {
        const l = document.querySelector('label[for="' + el.id + '"]');
        if (l) return l.textContent.trim();
      }
      return el.getAttribute('placeholder') || '';
    }

    async function getAnswer(rawLabel, type, opts, jobTitle, company) {
      const lbl = (rawLabel || '').toLowerCase();
      const p = CONFIG.profile || {};
      if (lbl.includes('first name')) return p.first_name || '';
      if (lbl.includes('last name')) return p.last_name || '';
      if (lbl.includes('email')) return p.email || '';
      if (lbl.includes('phone')) return p.phone_number || '';
      if (lbl.match(/years.{0,10}experience/)) return String(p.years_of_experience || '0');
      
      return new Promise((resolve) => {
        const requestId = Math.random().toString(36).substring(7);
        const timeout = setTimeout(() => resolve(''), 8000);
        const listener = (event) => {
          try {
            const data = JSON.parse(event.data);
            if (data.type === 'ai_answer' && data.requestId === requestId) {
              window.removeEventListener('message', listener);
              clearTimeout(timeout);
              resolve(data.answer || '');
            }
          } catch(e) {}
        };
        window.addEventListener('message', listener);
        sendToFlutter({
          type: 'ask_ai',
          requestId: requestId,
          question: rawLabel,
          questionType: type,
          options: opts,
          jobTitle: jobTitle,
          companyName: company
        });
      });
    }

    async function fillStep(modal, jobTitle, company) {
      const inputs = modal.querySelectorAll('input[type="text"], textarea');
      for (let i=0; i<inputs.length; i++) {
        const el = inputs[i];
        if (el.readOnly || el.disabled) continue;
        const lbl = getLabel(el); if (!lbl) continue;
        const ans = await getAnswer(lbl, el.tagName === 'TEXTAREA' ? 'textarea' : 'text', [], jobTitle, company);
        if (ans) setNative(el, ans);
      }
    }

    async function applyToJob(card) {
      const title = card.querySelector('a.job-card-container__link')?.textContent?.trim() || 'Job';
      log('▶ Processing: ' + title);
      const tgt = card.querySelector('a.job-card-container__link');
      if (!tgt) return false;
      tgt.click();
      await sleep(2000);
      const eBtn = document.querySelector('button.jobs-apply-button');
      if (!eBtn) return false;
      eBtn.click();
      await sleep(2000);
      const modal = document.querySelector('.artdeco-modal');
      if (!modal) return false;

      for (let step = 0; step < 8 && BOT_RUNNING; step++) {
        await fillStep(modal, title, '');
        await sleep(1000);
        const nextBtn = modal.querySelector('button[data-easy-apply-next-button]');
        const submitBtn = modal.querySelector('button[data-easy-apply-submit-btn]');
        if (submitBtn) {
          log('  ✅ Submitting...');
          submitBtn.click();
          await sleep(2000);
          STATS.applied++; updateStats();
          return true;
        } else if (nextBtn) {
          nextBtn.click();
          await sleep(1500);
        } else break;
      }
      return false;
    }

    async function runBotLoop() {
      log('🤖 Engine Operational', 'ok');
      while (BOT_RUNNING) {
        const cards = Array.from(document.querySelectorAll('li.scaffold-layout__list-item'));
        for (let i=0; i<cards.length; i++) {
          if (!BOT_RUNNING) break;
          await applyToJob(cards[i]);
          await sleep(3000);
        }
        await sleep(5000);
      }
    }

    runBotLoop();
  } catch (e) {
    sendToFlutter({ type: 'automation_error', message: 'Engine Init Failed: ' + e.message });
  }
})();
''';
  }

  static const String stopBotScript = "if (window.SA_StopBot) window.SA_StopBot();";
  
  static const String confirmSubmitScript = "(function(){ const b = document.querySelector('button[data-easy-apply-submit-btn]'); if(b) b.click(); })();";
  
  static String fillAnswerScript(String q, String a, String t) {
    final escapedQ = q.replaceAll("'", "\\'");
    final escapedA = a.replaceAll("'", "\\'");
    
    return """
(function() {
  try {
    const question = '$escapedQ'.toLowerCase();
    const answer = '$escapedA';
    const type = '$t';
    
    function setNative(el, val) {
      const proto = el.tagName === 'TEXTAREA' ? window.HTMLTextAreaElement.prototype : window.HTMLInputElement.prototype;
      const setter = Object.getOwnPropertyDescriptor(proto, 'value')?.set;
      if (setter) setter.call(el, val); else el.value = val;
      el.dispatchEvent(new Event('input', { bubbles: true }));
      el.dispatchEvent(new Event('change', { bubbles: true }));
    }

    const inputs = document.querySelectorAll('input[type="text"], textarea');
    for (let el of inputs) {
      let lbl = '';
      if (el.getAttribute('aria-label')) lbl = el.getAttribute('aria-label');
      else if (el.id) {
        const l = document.querySelector('label[for="' + el.id + '"]');
        if (l) lbl = l.textContent;
      }
      
      if (lbl.toLowerCase().includes(question)) {
        setNative(el, answer);
        console.log('[SmartApply] Filled field: ' + lbl);
        return;
      }
    }
  } catch(e) { console.error(e); }
})();
""";
  }

  static const String detectorScript = """
(function() {
  function sendToFlutter(obj) {
    try {
      const msg = JSON.stringify(obj);
      if (window.chrome && window.chrome.webview && window.chrome.webview.postMessage) {
        window.chrome.webview.postMessage(msg);
      } else if (window.ApplierChannel && window.ApplierChannel.postMessage) {
        window.ApplierChannel.postMessage(msg);
      }
    } catch (e) {}
  }

  const isLoggedIn = document.body.classList.contains('boot-complete') || 
                     !!document.querySelector('.global-nav') || 
                     !!document.querySelector('.feed-identity-module');
  
  sendToFlutter({ type: 'login_detected', loggedIn: isLoggedIn });
  console.log('[SmartApply] Detector active, loggedIn: ' + isLoggedIn);
})();
""";
}
