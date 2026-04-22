import 'dart:async';
import 'dart:io';
import 'package:puppeteer/puppeteer.dart';
import 'package:flutter/foundation.dart';
import '../../../core/utils/logger_service.dart';

/// Service to control a real Chrome instance via Chrome DevTools Protocol (CDP).
class ChromeAutomationService {
  Browser? _browser;
  Page? _page;
  late final StreamController<String> _logController;
  Stream<String> get logStream => _logController.stream;
  bool _isAborted = false;
  int _appliedCount = 0;
  final Set<String> _processedJobs = {};

  ChromeAutomationService() {
    _logController = StreamController<String>.broadcast();
    _initLogFile();
  }

  File? _sessionLogFile;

  void _initLogFile() {
    try {
      final logDir = Directory('d:\\SMARTAPPLY\\Frontend');
      if (!logDir.existsSync()) logDir.createSync(recursive: true);
      _sessionLogFile = File('${logDir.path}\\mission_history.log');
      _sessionLogFile!.writeAsStringSync('--- NEW MISSION SESSION: ${DateTime.now()} ---\n', mode: FileMode.append);
    } catch (e) {
      debugPrint('Failed to init log file: $e');
    }
  }

  /// Launches Chrome with remote debugging enabled.
  Future<void> launchBrowser({
    bool useDefaultProfile = true,
    int port = 9222,
  }) async {
    _log('🚀 Launching Chrome Engine...');

    try {
      final chromePath = _findChromePath();
      if (chromePath == null) {
        throw Exception('Chrome not found. Please ensure Google Chrome is installed.');
      }

      // Create a dedicated profile directory for Smart Apply to avoid conflicts with existing Chrome instances
      final appData = Platform.environment['LOCALAPPDATA'];
      final automationDataDir = '$appData\\SmartApply\\AutomationProfile';
      final dir = Directory(automationDataDir);
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }

      final List<String> args = [
        '--remote-debugging-port=$port',
        '--user-data-dir=$automationDataDir',
        '--no-first-run',
        '--no-default-browser-check',
        '--start-maximized',
        '--new-window',
        // STEALTH FLAGS:
        '--disable-blink-features=AutomationControlled',
        '--excludeSwitches=enable-automation',
        '--use-fake-ui-for-media-stream',
        '--disable-infobars',
        // BACKGROUND POWER FLAGS:
        '--disable-background-timer-throttling',
        '--disable-backgrounding-occluded-windows',
        '--disable-renderer-backgrounding',
        '--no-sandbox',
      ];

      _log('📁 Using profile: $automationDataDir');

      // Launch process
      await Process.start(
        chromePath, 
        args, 
        mode: ProcessStartMode.detached,
        runInShell: false,
      );
      
      _log('📡 Connecting to CDP on port $port...');
      
      // Retry connection
      for (int i = 0; i < 5; i++) {
        try {
          await Future.delayed(Duration(seconds: 1 + i));
          _browser = await puppeteer.connect(
            browserUrl: 'http://localhost:$port',
            defaultViewport: null,
          );
          break;
        } catch (e) {
          if (i == 4) rethrow;
          _log('⏳ Waiting for Chrome to stabilize...');
        }
      }

      _log('✅ Chrome Connected (Stealth Active)');

      // Apply stealth and Glass Shield to every new page
      _browser!.onTargetCreated.listen((target) async {
        if (target.type == 'page') {
          final page = await target.page;
          await _applyShieldAndStealth(page);
        }
      });

      // Also apply to current pages
      // Close redundant "New Tab" pages if they exist
      final pages = await _browser!.pages;
      if (pages.length > 1) {
        for (var p in pages.skip(1)) {
          final url = p.url;
          if (url == 'about:blank' || url == 'chrome://newtab/') {
            await p.close().catchError((_) => null);
          }
        }
      }

      for (var p in await _browser!.pages) {
        await _applyShieldAndStealth(p);
      }

      _browser!.disconnected.then((_) {
        _log('❌ Chrome Disconnected');
        _browser = null;
        _page = null;
      });

    } catch (e) {
      _log('❌ Failed to launch Chrome: $e');
      rethrow;
    }
  }

  /// Navigates to a URL and returns the page.
  Future<Page> getPage(String url) async {
    if (_browser == null) throw Exception('Browser not started');
    
    final pages = await _browser!.pages;
    if (pages.isNotEmpty) {
      _page = pages.first;
    } else {
      _page = await _browser!.newPage();
    }

    await _page!.bringToFront();
    await _page!.goto(url, wait: Until.domContentLoaded);
    return _page!;
  }

  /// Example automation task: Apply to jobs
  Future<void> startLinkedInAutomation({
    required Map<String, dynamic> profile,
    required Map<String, dynamic> jobPrefs,
    List<String> searchUrls = const [],
  }) async {
    if (_browser == null) await launchBrowser();
    
    _log('🚀 Starting Targeted Mission...');
    _log('📊 Profile Data: ${profile.keys.join(", ")}');
    _log('📍 User City: ${profile['current_city'] ?? 'NOT FOUND'}');
    _log('📍 User Location: ${profile['location'] ?? 'NOT FOUND'}');
    _isAborted = false;
    _processedJobs.clear();

    // ── MANDATORY LOGIN GUARD ──
    _log('🔐 Verifying LinkedIn Session...');
    await _updateAgentStatus('Verifying Session...');
    _page = await getPage('https://www.linkedin.com/feed/');
    
    bool loggedIn = false;
    while (!loggedIn && !_isAborted) {
      // Give page a moment to load/redirect
      await Future.delayed(const Duration(seconds: 3));
      
      final currentUrl = _page?.url ?? '';
      final title = await _page?.title ?? 'No Title';
      _log('🧐 Checking access: $currentUrl (Title: $title)');

      final loginState = await _page?.evaluate('''() => {
        const hasNav = !!document.querySelector('.global-nav') || 
                       !!document.querySelector('#global-nav') ||
                       !!document.querySelector('.nav-main__item--me') ||
                       !!document.querySelector('.feed-identity-module') ||
                       !!document.querySelector('.search-global-typeahead') ||
                       !!document.querySelector('[data-test-global-nav]');
        
        const url = window.location.href;
        const isAuthPage = url.includes('/login') || 
                           url.includes('/checkpoint/') ||
                           url.includes('/uas/login') ||
                           url.includes('/signup');
        
        const onFeed = url.endsWith('/feed/') || url.includes('/feed/?');
        
        return { hasNav, isAuthPage, onFeed };
      }''');

      final hasNav = loginState?['hasNav'] == true;
      final isAuthPage = loginState?['isAuthPage'] == true;
      final onFeed = loginState?['onFeed'] == true;

      // If we see the nav bar OR we are clearly on the feed and not an auth page
      if ((hasNav || onFeed) && !isAuthPage) {
        loggedIn = true;
        _log('✅ Session Verified. Proceeding to Mission...');
      } else {
        _log('⚠️ Not Logged In. Waiting for user to authenticate...');
        await _updateAgentStatus('PLEASE LOG IN TO LINKEDIN');
        
        // Ensure the page is visible and alert the user
        await _page?.bringToFront();
        await _page?.evaluate('() => { window.focus(); }');
        
        // If the shield is up, we need to hide it temporarily so user can login
        // But let's leave a small notice so they know the AI is waiting
        await _page?.evaluate('''() => { 
          const s = document.getElementById("ai-glass-shield"); 
          if(s) {
            s.style.background = "rgba(0,0,0,0.4)"; // Dim only
            s.style.backdropFilter = "none";
            s.style.pointerEvents = "none"; // Allow clicks through
            const hud = document.getElementById("hud-main-container");
            if(hud) {
               hud.style.justifyContent = "flex-start";
               hud.style.paddingTop = "20px";
            }
          }
        }''');
        
        await Future.delayed(const Duration(seconds: 5));
      }
    }
    
    // 1. Generate URLs based on Search Terms from Profile
    _log('🔍 Analyzing profile keywords...');
    List<String> finalUrls = [];
    final rawTerms = profile['search_terms'] ?? profile['searchTerms'] ?? '';
    final searchTerms = rawTerms.toString();
    
    _log('📊 Raw Keywords from Profile: "$searchTerms"');
    
    List<String> terms = [];
    if (searchTerms.trim().isNotEmpty) {
      terms = searchTerms.split(RegExp(r'[,;\n]')).map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    }

    if (terms.isEmpty) {
      _log('⚠️ No search terms found. Falling back to defaults.');
      terms = ['Junior Software Developer', 'Entry Level Developer'];
    }

    _log('🚀 Final Mission Keywords: ${terms.join(" | ")}');

    for (var term in terms) {
      final encodedTerm = Uri.encodeComponent(term);
      finalUrls.add('https://www.linkedin.com/jobs/search/?keywords=$encodedTerm&f_AL=true');
    }
    
    final urls = finalUrls;
    
    if (_isAborted) return;
    
    bool running = true;
    while (running && !_isAborted) {
      for (var searchUrl in urls) {
        if (_isAborted) break;
        
        try {
          String keywords = 'Jobs';
          if (searchUrl.contains('keywords=')) {
            keywords = Uri.decodeComponent(searchUrl.split('keywords=').last.split('&').first);
          }
          await _updateAgentStatus('Searching: $keywords');
          _log('📍 Navigating to search: $searchUrl');
          
          await _page?.goto(searchUrl, wait: Until.domContentLoaded);
          await Future.delayed(const Duration(seconds: 4));

          await _updateAgentStatus('Scanning for $keywords...');
          
          // PROCESS SEARCH PAGE
          final cards = await _page?.$$('li.scaffold-layout__list-item, .job-card-container, .base-card, [data-job-id]');
          if (cards == null || cards.isEmpty) {
            _log('📭 No jobs found for "$keywords".');
            
            // Double check if we were logged out
            final stillIn = await _page?.evaluate('''() => {
              return !!document.querySelector('.global-nav') || !!document.querySelector('.nav-main__item--me');
            }''') ?? false;
            
            if (!stillIn) {
               _log('🚨 SESSION LOST: Aborting current search to re-verify login.');
               break; // Break the terms loop to hit the login guard again
            }
            continue;
          }

          _log('Found ${cards.length} jobs. Processing...');

          for (int i = 0; i < cards.length; i++) {
            if (_isAborted) break;
            
            try {
              // Re-fetch to avoid stale handles
              final currentCards = await _page?.$$('li.scaffold-layout__list-item, .job-card-container');
              if (currentCards == null || i >= currentCards.length) break;
              final card = currentCards[i];

              final cardText = await card.evaluate('el => el.innerText');
              final title = cardText.split('\n').first.trim();

              // De-duplication check
              final jobId = await card.evaluate('el => el.getAttribute("data-job-id") || el.getAttribute("data-entity-urn")') ?? title;
              if (_processedJobs.contains(jobId)) continue;
              _processedJobs.add(jobId);

              if (cardText.contains('Applied') || !cardText.contains('Easy Apply')) {
                _log('  ⏭ Skipping: Already applied or No Easy Apply ($title)');
                continue;
              }

              // Bad Words Filter
              if (profile['bad_words'] != null && (profile['bad_words'] as String).isNotEmpty) {
                final badWords = profile['bad_words'].toString().toLowerCase().split(',').map((e) => e.trim());
                if (badWords.any((w) => title.toLowerCase().contains(w))) {
                   _log('  ⏭ Skipping (Bad Word): $title');
                   continue;
                }
              }

              await _updateAgentStatus('Analyzing: $title');
              _log('▶ Processing: $title');

              // GHOST CLICK (Use evaluate to bypass some event blockers)
              await card.evaluate('el => el.click()');
              await Future.delayed(const Duration(seconds: 3));

              final applied = await _handleEasyApplyModal(title, profile);
              if (applied) {
                _appliedCount++;
                _log('  🚀 Application Submitted Successfully! [Mission Count: $_appliedCount]');
              }
              
              await Future.delayed(const Duration(seconds: 2));
            } catch (e) {
              _log('  ⚠️ Error processing job: $e');
            }
          }
        } catch (e) {
          _log('⚠️ Error in search mission: $e');
          await Future.delayed(const Duration(seconds: 5));
        }
        
        if (_isAborted) break;
        await Future.delayed(const Duration(seconds: 5));
      }
      
      if (_isAborted) break;
      _log('🔄 Completed all search terms. Resting for 10 minutes...');
      await _updateAgentStatus('Cooldown: Resting...');
      await Future.delayed(const Duration(minutes: 10));
    }
    
    if (_isAborted) {
      await _updateAgentStatus('MISSION ABORTED');
      _log('⏹ Automation Stopped.');
    }
  }

  Future<bool> _handleEasyApplyModal(String jobTitle, Map<String, dynamic> profile) async {
    _log('  🎯 Handling Easy Apply modal...');
    
    try {
      // 1. Wait for the Apply button to appear in the details pane
      ElementHandle? applyButton;
      for (int i = 0; i < 5; i++) {
        // Try to find the button specifically in the details pane first
        applyButton = await _page?.$('.jobs-details__main-content .jobs-apply-button, .jobs-details-module button[aria-label*="Easy Apply"]');
        // Fallback to global
        applyButton ??= await _page?.$('.jobs-apply-button, button[aria-label*="Easy Apply"]');
        
        if (applyButton != null) break;
        await Future.delayed(const Duration(seconds: 1));
      }

      if (applyButton == null) {
        _log('  ⏭ Easy Apply button missing in details pane.');
        return false;
      }
      
      // Ensure it's the right button
      final btnText = await applyButton.evaluate('el => el.innerText');
      if (!btnText.toLowerCase().contains('easy apply')) {
        _log('  ⏭ Found Apply button but not Easy Apply. Skipping.');
        return false;
      }

      _log('  🖱 Clicking Easy Apply button...');
      await applyButton.evaluate('el => { el.scrollIntoView(); el.click(); }');
      
      // 2. Patiently wait for modal to appear
      bool opened = false;
      for (int i = 0; i < 10; i++) {
        final modalExists = await _page?.evaluate('() => !!document.querySelector(".artdeco-modal, .jobs-easy-apply-modal")');
        if (modalExists == true) {
          opened = true;
          break;
        }
        await Future.delayed(const Duration(seconds: 1));
      }
      
      if (!opened) {
        _log('  ⚠️ Modal did not open.');
        return false;
      }

      int steps = 0;
      bool submitted = false;
      String? lastStepHash;
      int repeatCount = 0;

      while (steps < 15 && !_isAborted) {
        steps++;
        _log('  📝 Processing form step $steps');
        
        // A. Clear any "Safety" or "Discard" popups that block the view
        await _page?.evaluate('''() => {
          const confirmBtn = document.querySelector('button[data-control-name="discard_application_confirm_btn"]');
          if (confirmBtn) confirmBtn.click();
        }''');

        // RECURSION DETECTION
        final currentFieldsHash = await _page?.evaluate('() => Array.from(document.querySelectorAll("input, select, textarea")).map(i => (i.id || "") + (i.name || "")).join("|")');
        if (currentFieldsHash == lastStepHash && currentFieldsHash != null && currentFieldsHash.isNotEmpty) {
          repeatCount++;
        } else {
          repeatCount = 0;
          lastStepHash = currentFieldsHash;
        }

        if (repeatCount >= 2) {
          _log('    ⚠️ RECURSION DETECTED at Step $steps. Capturing debug data...');
          await _captureDebugState('recursion_step_$steps');
          if (repeatCount >= 4) {
             _log('    🚫 HARD STUCK: Skipping this job to prevent infinite loop.');
             await _dismissModal();
             return false;
          }
        }

        // B. Autofill fields
        final isQualified = await _fillFormFields(jobTitle, profile);
        if (!isQualified) {
          _log('  🚫 DISQUALIFIED: Job requirements (CTC/Exp) not met.');
          await _dismissModal();
          return false;
        }

        // C. Scroll to ensure buttons are interactive
        await _page?.evaluate('''() => {
          const content = document.querySelector('.artdeco-modal__content');
          if (content) content.scrollTop = content.scrollHeight;
        }''');
        await Future.delayed(const Duration(seconds: 1));

        // CHECK FOR ERRORS
        final error = await _page?.evaluate('''() => {
          const err = document.querySelector('.artdeco-inline-feedback--error, .fb-dash-form-element__error-field');
          return err ? err.textContent.trim() : null;
        }''');
        if (error != null) {
          _log('    ⚠️ Form Error Detected: $error');
          // If we see an error and it's the same step, we might be stuck.
        }

        // D. Look for action buttons
        final nextBtn = await _page?.evaluateHandle('() => document.querySelector(\'button[aria-label*="next"], button[aria-label*="Review"], button[data-easy-apply-next-button]\')');
        final submitBtn = await _page?.evaluateHandle('() => document.querySelector(\'button[aria-label*="Submit"], button[data-easy-apply-submit-btn]\')');

        final nextHandle = nextBtn is ElementHandle ? nextBtn : null;
        final submitHandle = submitBtn is ElementHandle ? submitBtn : null;

        if (submitHandle != null) {
          _log('  🚀 Clicking Submit...');
          await submitHandle.evaluate('el => el.click()');
          await Future.delayed(const Duration(seconds: 4));
          
          // VERIFY SUCCESS: Look for "Application Sent" or the post-apply screen
          final success = await _page?.evaluate('''() => {
            const text = document.body.innerText;
            return text.includes('Application sent') || text.includes('successfully applied') || !!document.querySelector('.jobs-post-apply-post-apply-card');
          }''');
          
          if (success == true) {
            _log('  ✨ CONFIRMED: Application submitted successfully!');
            submitted = true;
          } else {
            _log('  ⚠️ Submit clicked but confirmation not found. Manual check recommended.');
            submitted = true; // Still mark as success as Submit was clicked
          }
          break;
        } else if (nextHandle != null) {
          await nextHandle.evaluate('el => el.click()');
          await Future.delayed(const Duration(seconds: 2));
        } else {
          // Check if it closed itself (some simple 1-step forms do this)
          final modalCheck = await _page?.evaluateHandle('() => document.querySelector(".artdeco-modal")');
          final modalHandle = modalCheck is ElementHandle ? modalCheck : null;
          if (modalHandle == null) {
            _log('  🏁 Modal closed. Assuming completion.');
            submitted = true;
            break;
          }
          _log('  ❓ Stuck on step $steps. No Next/Submit button found.');
          break;
        }
      }

      // Final Cleanup
      if (submitted) {
        final closeBtn = await _page?.evaluateHandle('() => document.querySelector(".artdeco-modal__dismiss, button[aria-label*=\"Dismiss\"]")');
        final closeHandle = closeBtn is ElementHandle ? closeBtn : null;
        if (closeHandle != null) await closeHandle.evaluate('el => el.click()');
      } else {
        await _dismissModal();
      }
      
      return submitted;
    } catch (e) {
      _log('  ❌ Error in modal handler: $e');
      return false;
    }
  }

  Future<void> _dismissModal() async {
    try {
      await _page?.evaluate('''() => {
        const x = document.querySelector('.artdeco-modal__dismiss, button[aria-label*="Dismiss"]');
        if (x) {
          x.click();
          setTimeout(() => {
            const discard = Array.from(document.querySelectorAll('button')).find(b => b.innerText.includes('Discard'));
            if (discard) discard.click();
          }, 500);
        }
      }''');
      await Future.delayed(const Duration(seconds: 1));
    } catch (_) {}
  }

  Future<bool> _fillFormFields(String jobTitle, Map<String, dynamic> profile) async {
    _log('    🤖 AI is filling fields...');
    try {
      final result = await _page?.evaluate(r'''
        function(profile) {
          const modal = document.querySelector('.artdeco-modal, .jobs-easy-apply-modal');
          const inputs = modal ? modal.querySelectorAll('input, select, textarea') : document.querySelectorAll('input, select, textarea');
          const isFresher = (parseInt(profile.work_experience_years) || 0) === 0;
          let isQualified = true;
          
          const getLabel = async (el) => {
            let label = el.getAttribute('aria-label') || el.placeholder || el.name || el.id || '';
            if (el.id) {
              const l = document.querySelector(`label[for="${el.id}"]`);
              if (l) label += ' ' + l.textContent;
            }
            // Look for question text in parent fieldset or groupings
            const parent = el.closest('fieldset, .fb-dash-form-element, .jobs-easy-apply-form-section__grouping, div');
            if (parent) {
              const legend = parent.querySelector('legend, .fb-dash-form-element__label, p');
              if (legend) label += ' ' + legend.textContent;
              else label += ' ' + parent.textContent.substring(0, 200);
            }
            return label.toLowerCase();
          };

          const setVal = async (input, val) => {
            if (val === undefined || val === null || val === '') return;
            const fieldName = input.getAttribute('name') || input.id || 'unknown';
            if (window.reportField) window.reportField(fieldName, val);

            if (input.tagName === 'SELECT') {
              const options = Array.from(input.options);
              const targetVal = String(val).trim();
              const lowerTarget = targetVal.toLowerCase();
              
              // 1. Try exact or partial text match
              let match = options.find(o => o.text.toLowerCase().includes(lowerTarget) || o.value.toLowerCase().includes(lowerTarget));
              
              // 2. Numerical Match (High Priority for 0, 1, 2...)
              if (!match && !isNaN(targetVal)) {
                // Look for options starting with the number (e.g., "0 year") or containing it as a word
                match = options.find(o => {
                  const text = o.text.trim();
                  return text.startsWith(targetVal) || text.match(new RegExp(`\\b${targetVal}\\b`));
                });
              }
              
              // 3. Failsafe: if val is 0, pick the first valid non-placeholder option
              if (!match && targetVal === '0' && options.length > 1) {
                match = options[1]; 
              }

              if (match) {
                input.value = match.value;
                input.dispatchEvent(new Event('change', { bubbles: true }));
                input.dispatchEvent(new Event('input', { bubbles: true }));
              }
            } else {
              input.focus();
              // Programmatic value set + events
              const nativeInputValueSetter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, "value").set;
              const nativeTextAreaValueSetter = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, "value").set;
              
              if (input.tagName === 'TEXTAREA') {
                nativeTextAreaValueSetter.call(input, val);
              } else {
                nativeInputValueSetter.call(input, val);
              }

              input.dispatchEvent(new Event('input', { bubbles: true }));
              input.dispatchEvent(new Event('change', { bubbles: true }));
              input.dispatchEvent(new KeyboardEvent('keydown', { bubbles: true }));
              input.dispatchEvent(new KeyboardEvent('keyup', { bubbles: true }));
              input.blur();
            }
          };

          const run = async () => {
            for (const input of inputs) {
              const text = await getLabel(input);
              const lowerText = text.toLowerCase();

              // IMMEDIATE DISQUALIFICATION CHECK
              if (isFresher && lowerText.includes('current ctc')) {
                isQualified = false;
                return; 
              }

              if (input.value && input.value.length > 1 && input.type !== 'radio' && input.type !== 'checkbox') continue;

              if (lowerText.includes('experience') || lowerText.includes('years')) {
                await setVal(input, profile.work_experience_years || '0');
              } else if (lowerText.includes('phone') || lowerText.includes('mobile') || lowerText.includes('contact')) {
                await setVal(input, profile.phone || '');
              } else if (lowerText.includes('city') || lowerText.includes('location') || lowerText.includes('address')) {
                const cityVal = profile.current_city ? `${profile.current_city}, ${profile.state}, ${profile.country}` : (profile.location || 'Anaparthi, Andhra Pradesh, India');
                await setVal(input, cityVal);
                
                if (input.getAttribute('role') === 'combobox' || input.getAttribute('aria-autocomplete')) {
                  await new Promise(r => setTimeout(r, 1500));
                  
                  // Try to find and click any suggestion
                  const suggestion = document.querySelector('.basic-typeahead__triggered-content div[role="option"], .typeahead-suggestion, .jobs-vicinity-typeahead__result, [id*="typeahead-item"]');
                  if (suggestion) {
                    suggestion.click();
                    if (window.reportField) window.reportField('suggestion', 'Clicked: ' + suggestion.textContent.trim());
                  } else {
                    // Fallback: Simulate ArrowDown + Enter
                    input.dispatchEvent(new KeyboardEvent('keydown', { key: 'ArrowDown', keyCode: 40, bubbles: true }));
                    await new Promise(r => setTimeout(r, 200));
                    input.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', keyCode: 13, bubbles: true }));
                  }
                }
              } else if (lowerText.includes('notice') || lowerText.includes('availability')) {
                await setVal(input, profile.notice_period_days !== undefined ? String(profile.notice_period_days) : '0');
              } else if (lowerText.includes('ctc') || lowerText.includes('salary') || lowerText.includes('compensation')) {
                if (lowerText.includes('expected')) {
                  const expected = profile.expected_ctc || profile.current_ctc || '0';
                  await setVal(input, String(expected));
                } else {
                  await setVal(input, String(profile.current_ctc || '0'));
                }
                
                if (window.reportField && (profile.current_ctc || 0) < 100) {
                  window.reportField('CTC-Warning', 'Value is 0. Job requires > 100. Please update profile.');
                }
              } else if (lowerText.includes('linkedin')) {
                await setVal(input, profile.linkedin_url || '');
              } else if (lowerText.includes('github')) {
                await setVal(input, profile.github_url || '');
              }
              
              if (input.type === 'radio' || input.type === 'checkbox') {
                const isAuthQuestion = lowerText.includes('authorized') || lowerText.includes('work in');
                const isSponsorshipQuestion = lowerText.includes('sponsorship') || lowerText.includes('visa');
                
                if (isAuthQuestion) {
                  const val = profile.is_authorized_to_work == true || profile.is_authorized_to_work == 'true';
                  if ((val && text.includes('yes')) || (!val && text.includes('no'))) {
                    input.click();
                  }
                } else if (isSponsorshipQuestion) {
                  const val = profile.requires_sponsorship == true || profile.requires_sponsorship == 'true';
                  if ((val && text.includes('yes')) || (!val && text.includes('no'))) {
                    input.click();
                  }
                } else if (text.includes('yes') || text.includes('agree') || text.includes('consent')) {
                  input.click();
                }
              }
            }

            // SAFETY NET: Ensure every radio group has a selection
            const radioGroups = {};
            inputs.forEach(i => {
              if (i.type === 'radio' && i.name) {
                if (!radioGroups[i.name]) radioGroups[i.name] = { items: [], hasChecked: false };
                radioGroups[i.name].items.push(i);
                if (i.checked) radioGroups[i.name].hasChecked = true;
              }
            });

            for (const name in radioGroups) {
              if (!radioGroups[name].hasChecked) {
                const group = radioGroups[name].items;
                const yesOpt = group.find(i => i.parentElement.innerText.toLowerCase().includes('yes'));
                if (yesOpt) yesOpt.click();
                else group[0].click();
              }
            }

            // SAFETY NET: Ensure every select has a selection
            inputs.forEach(i => {
              if (i.tagName === 'SELECT' && (i.value === 'Select an option' || i.value === '')) {
                const options = Array.from(i.options);
                const yesOpt = options.find(o => o.text.toLowerCase().includes('yes'));
                if (yesOpt) {
                  i.value = yesOpt.value;
                  i.dispatchEvent(new Event('change', { bubbles: true }));
                } else if (options.length > 1) {
                  i.selectedIndex = 1; // Pick the first real option
                  i.dispatchEvent(new Event('change', { bubbles: true }));
                }
              }
            });

            return isQualified;
          };

          return run();
        }
      ''', args: [profile]);
      return result == true;
    } catch (e) {
      _log('    ⚠️ Autofill error: $e');
      return true; // Proceed on error
    }
  }
  Future<void> _applyShieldAndStealth(Page page) async {
    try {
      // 1. Expose the stop function so the browser button can talk to Dart
      await page.exposeFunction('stopMission', () {
        _log('🛑 MISSION ABORTED BY USER via Browser Overlay');
        _isAborted = true;
      });

      await page.exposeFunction('reportField', (field, value) {
        _log('    🤖 Filling $field -> $value');
      });

      const shieldScript = r'''
        (function() {
          const ID = 'ai-glass-shield';
          
          const inject = () => {
            if (document.getElementById(ID)) return;
            
            const shield = document.createElement('div');
            shield.id = ID;
            
            const updateVisibility = () => {
              const url = window.location.href;
              const isAuth = url.includes('login') || 
                             url.includes('checkpoint') || 
                             url.includes('signup') || 
                             url.includes('auth') || 
                             url.includes('challenge');
              shield.style.display = isAuth ? 'none' : 'flex';
            };

            shield.style.cssText = `
              position: fixed !important;
              top: 0 !important;
              left: 0 !important;
              width: 100vw !important;
              height: 100vh !important;
              z-index: 2147483647 !important;
              background: rgba(0, 10, 20, 0.2) !important;
              backdrop-filter: blur(3px) !important;
              pointer-events: all !important;
              display: flex;
              flex-direction: column;
              align-items: center;
              justify-content: center;
              font-family: 'Segoe UI', Roboto, sans-serif !important;
              user-select: none !important;
              color: white !important;
              box-shadow: inset 0 0 150px rgba(0, 255, 204, 0.4) !important;
              border: 10px solid rgba(0, 255, 204, 0.3) !important;
              transition: all 0.5s ease;
            `;
            updateVisibility();

            shield.innerHTML = `
              <div id="hud-main-container" style="
                display: flex;
                flex-direction: column;
                align-items: center;
                justify-content: center;
                width: 100%;
                height: 100%;
                position: relative;
              ">
                <div id="interaction-warning" style="
                  position: absolute;
                  top: 50px;
                  background: rgba(255, 50, 50, 0.95);
                  color: white;
                  padding: 15px 40px;
                  border-radius: 50px;
                  font-weight: bold;
                  font-size: 18px;
                  letter-spacing: 1px;
                  box-shadow: 0 10px 40px rgba(255, 0, 0, 0.4);
                  opacity: 0;
                  transform: translateY(-20px);
                  transition: all 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275);
                  pointer-events: none;
                  z-index: 2147483648;
                  border: 2px solid white;
                  white-space: nowrap;
                ">
                  ⚠️ SYSTEM LOCKED - AI PILOT IN CONTROL
                </div>

                <div style="
                  background: rgba(10, 15, 25, 0.98);
                  padding: 50px;
                  border-radius: 30px;
                  border: 1px solid rgba(0, 255, 204, 0.5);
                  box-shadow: 0 30px 70px rgba(0, 0, 0, 0.9), 0 0 50px rgba(0, 255, 204, 0.3);
                  text-align: center;
                  min-width: 500px;
                  position: relative;
                  overflow: hidden;
                ">
                  <div id="aurora-bg" style="position: absolute; top: -50%; left: -50%; width: 200%; height: 200%; background: radial-gradient(circle, rgba(0, 255, 204, 0.08) 0%, transparent 70%); z-index: -1;"></div>
                  <div style="font-size: 12px; color: #00ffcc; letter-spacing: 6px; margin-bottom: 25px; font-weight: bold; opacity: 0.8;">SMART APPLY INDUSTRIAL v3.1</div>
                  <div id="ai-status-text" style="font-size: 28px; margin-bottom: 40px; font-weight: 300; min-height: 40px; text-shadow: 0 0 15px rgba(0, 255, 204, 0.6); color: #e0fdf9;">Initializing AI Pilot...</div>
                  <div style="display: flex; gap: 25px; justify-content: center;">
                     <button onclick="window.stopMission()" style="background: rgba(255, 50, 50, 0.1); color: #ff5555; border: 2px solid #ff5555; padding: 16px 36px; border-radius: 16px; cursor: pointer; font-weight: bold; font-size: 16px; transition: all 0.3s; text-transform: uppercase; letter-spacing: 2px;">Abort Mission</button>
                  </div>
                  <div style="margin-top: 45px; display: flex; justify-content: center; gap: 15px;">
                    <div class="pulse-dot" style="width: 10px; height: 10px; background: #00ffcc; border-radius: 50%;"></div>
                    <div class="pulse-dot" style="width: 10px; height: 10px; background: #00ffcc; border-radius: 50%; animation-delay: 0.2s;"></div>
                    <div class="pulse-dot" style="width: 10px; height: 10px; background: #00ffcc; border-radius: 50%; animation-delay: 0.4s;"></div>
                  </div>
                </div>
              </div>
            `;
            
            // Inject styles separately to avoid them being rendered as text
            const style = document.createElement('style');
            style.textContent = `
              #aurora-bg { animation: aurora-spin 12s linear infinite; }
              @keyframes aurora-spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
              .pulse-dot { animation: dot-pulse 1.5s infinite; }
              @keyframes dot-pulse { 0% { opacity: 0.3; transform: scale(1); } 50% { opacity: 1; transform: scale(1.5); } 100% { opacity: 0.3; transform: scale(1); } }
              #ai-glass-shield { animation: border-glow 4s infinite alternate; }
              @keyframes border-glow { from { border-color: rgba(0, 255, 204, 0.2); box-shadow: inset 0 0 60px rgba(0, 255, 204, 0.1); } to { border-color: rgba(0, 255, 204, 0.6); box-shadow: inset 0 0 200px rgba(0, 255, 204, 0.4); } }
            `;
            shield.appendChild(style);
            
            document.documentElement.appendChild(shield);
            
            const showWarning = () => {
              const warning = document.getElementById('interaction-warning');
              if (!warning) return;
              warning.style.opacity = '1';
              warning.style.transform = 'translateY(0)';
              setTimeout(() => {
                warning.style.opacity = '0';
                warning.style.transform = 'translateY(-20px)';
              }, 2500);
            };

            const lockEvents = ['click', 'mousedown', 'mouseup', 'keydown', 'keyup', 'keypress', 'contextmenu'];
            lockEvents.forEach(evt => {
              window.addEventListener(evt, (e) => {
                if (!e.isTrusted) return; // Allow programmatic/AI events
                if (shield.style.display === 'none') return; // Allow login/auth interaction
                const isAbortButton = e.target.closest('button') && e.target.innerText.includes('Abort');
                if (!isAbortButton) {
                  e.stopImmediatePropagation();
                  e.preventDefault();
                  showWarning();
                }
              }, true);
            });

            const observer = new MutationObserver(updateVisibility);
            observer.observe(document.documentElement, { childList: true, subtree: true });
          };

          // HEARTBEAT: Ensure shield is always present and top-most
          setInterval(() => {
            const shield = document.getElementById(ID);
            if (!shield) {
              inject();
            } else if (shield.nextElementSibling) {
              // Someone tried to put something over us, move back to end
              document.documentElement.appendChild(shield);
            }
          }, 500);

          if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', inject);
          } else {
            inject();
          }
        })();
      ''';

      await page.evaluateOnNewDocument(shieldScript);
      try {
        await page.evaluate(shieldScript);
      } catch (e) {}
    } catch (e) {
      _log('⚠️ Error applying Agent HUD: $e');
    }
  }

  Future<void> _updateAgentStatus(String status) async {
    try {
      await _page?.evaluate('''
        function(status) {
          const el = document.getElementById('ai-status-text');
          if (el) el.textContent = status;
        }
      ''', args: [status]);
    } catch (e) {
      // Ignore if page is navigating
    }
  }

  String? _findChromePath() {
    final paths = [
      'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
      'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
      '${Platform.environment['USERPROFILE']}\\AppData\\Local\\Google\\Chrome\\Application\\chrome.exe',
    ];

    for (var path in paths) {
      if (File(path).existsSync()) return path;
    }
    return null;
  }

  void _log(String message) {
    debugPrint('[ChromeService] $message');
    _logController.add(message);
    LocalLogger.log('[ChromeService] $message');
    try {
      _sessionLogFile?.writeAsStringSync('[$_timestamp] $message\n', mode: FileMode.append);
    } catch (_) {}
  }

  String get _timestamp => DateTime.now().toIso8601String().split('T').last.split('.').first;

  Future<void> _captureDebugState(String label) async {
    try {
      final debugDir = Directory('d:\\SMARTAPPLY\\Frontend\\debug_mission');
      if (!debugDir.existsSync()) debugDir.createSync(recursive: true);
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // Screenshot
      final bytes = await _page?.screenshot();
      if (bytes != null) {
        final screenshotFile = File('${debugDir.path}\\${label}_$timestamp.png');
        await screenshotFile.writeAsBytes(bytes);
      }
      
      // DOM
      final html = await _page?.content;
      if (html != null) {
        final domFile = File('${debugDir.path}\\${label}_$timestamp.html');
        await domFile.writeAsString(html);
      }
      
      _log('📸 Debug Snapshot Saved: ${debugDir.path}\\${label}_$timestamp');
    } catch (e) {
      _log('⚠️ Failed to capture debug state: $e');
    }
  }

  Future<void> dispose() async {
    await _browser?.close();
    await _logController.close();
  }
}
