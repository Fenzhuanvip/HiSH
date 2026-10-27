// Initialize xterm.js
// The Terminal instance is created lazily in initialize() (see createTerminal),
// because renderer options depend on native preferences (ligatures / italic).
var term = null;

// Tracks the currently selected font family so user fonts can re-apply it
// once their FontFace finishes loading asynchronously.
var currentFontFamily = 'Default';

// Initialize Addons (constructed upfront; attached to term in createTerminal)
const fitAddon = new FitAddon.FitAddon();
const webglAddon = new WebglAddon.WebglAddon();

// Initialize exports for ArkTS to call
window.exports = {};

// Helper for decoding Latin1/Binary string from ArkTS to UTF-8
const decoder = new TextDecoder('utf-8');
const encoder = new TextEncoder();

function setupImeGuard() {
    if (!term.textarea) {
        return;
    }
    const textarea = term.textarea;
    textarea.setAttribute('autocomplete', 'off');
    textarea.setAttribute('autocorrect', 'off');
    textarea.setAttribute('spellcheck', 'false');
    textarea.setAttribute('autocapitalize', 'off');
}

// Detects which monospace fonts are actually available in the WebView.
// Uses Canvas measureText: compares "CandidateFont, monospace" against
// pure "monospace" baseline. If a font doesn't exist, the browser falls
// back to monospace and the widths match → it gets filtered out.
function detectAvailableMonospaceFonts() {
    var testNarrow = 'iiiiilllll';
    var testWide = 'WWWWWmmmmm';
    var baseFont = 'monospace';

    // Comprehensive list of monospace fonts commonly available across
    // HarmonyOS / Android / Linux systems
    var candidates = [
        'Droid Sans Mono',
        'Noto Sans Mono',
        'Roboto Mono',
        'Source Code Pro',
        'Cascadia Code',
        'Fira Code',
        'JetBrains Mono',
        'Courier New',
        'Courier',
        'Consolas',
        'Menlo',
        'DejaVu Sans Mono',
        'Liberation Mono',
        'Ubuntu Mono',
        'Monaco',
    ];

    var canvas = document.createElement('canvas');
    var ctx = canvas.getContext('2d');
    var testFontSize = '16px';

    function measure(fontStack, text) {
        ctx.font = testFontSize + ' ' + fontStack;
        return ctx.measureText(text).width;
    }

    // Baseline with pure monospace (the browser's default monospace font)
    var monoNarrow = measure(baseFont, testNarrow);
    var monoWide = measure(baseFont, testWide);

    return candidates.filter(function(font) {
        // Measure with candidate + monospace fallback.
        // If the candidate font does NOT exist, the browser falls back
        // to monospace → same metrics as baseline → detected as unavailable.
        // If it DOES exist → different metrics → detected as available.
        var fontStack = '"' + font + '", ' + baseFont;
        var narrow = measure(fontStack, testNarrow);
        var wide = measure(fontStack, testWide);

        // Font is distinct from default monospace (it actually exists and differs)
        var narrowDiff = Math.abs(narrow - monoNarrow);
        var wideDiff = Math.abs(wide - monoWide);
        var isDistinct = narrowDiff > 0.5 || wideDiff > 0.5;

        // Font is monospace: narrow and wide chars have equal width
        // (1px tolerance for sub-pixel rendering differences)
        var monoDiff = Math.abs(narrow - wide);
        var isMonospace = monoDiff <= 1;

        return isDistinct && isMonospace;
    });
}

// Maps user-friendly font family name to CSS font-family stack.
// 'Default' uses the system monospace fallback chain;
// named fonts include a monospace fallback for safety.
function mapFontFamily(family) {
    if (!family || family === 'Default') {
        return 'monospace, "Droid Sans Mono", "Courier New", "Courier", monospace';
    }
    return '"' + family + '", monospace';
}

// Function to convert "binary string" (where charCode < 256) to Uint8Array
// ArkTS sends data as a string where each char is a byte.
function strToUint8Array(str) {
    const buf = new Uint8Array(str.length);
    for (let i = 0; i < str.length; i++) {
        buf[i] = str.charCodeAt(i);
    }
    return buf;
}

// Creates the xterm.js Terminal instance.
// NOTE: This xterm.js build ships with the DOM renderer only (no
// canvas/WebGL/rendererType option), so ligature and italic suppression
// are both handled purely via CSS classes on <body> — see term.css.
function createTerminal() {
    var ligatures = false;
    var italic = true;
    try {
        if (window.native && native.getLigatures) {
            ligatures = !!native.getLigatures();
        }
        if (window.native && native.getItalic) {
            italic = !!native.getItalic();
        }
    } catch (e) {
        console.warn('Failed to read renderer prefs', e);
    }

    if (!ligatures) {
        document.body.classList.add('ligatures-off');
    }
    if (!italic) {
        document.body.classList.add('italics-off');
    }

    var options = {
        cursorBlink: true,
        allowProposedApi: true, // Needed for some addons
        allowTransparency: true, // User preference: Transparency supported
        fontFamily: 'monospace, "Droid Sans Mono", "Courier New", "Courier", monospace',
        fontSize: 14, // Default, will be overridden by native.getFontSize()
        theme: {
            background: 'rgba(0, 0, 0, 0)', // Transparent by default to show effects behind
            foreground: '#ffffff',
            cursor: '#ffffff'
        },
        screenReaderMode: false, // Disabled to fix touch scrolling issues (was conflicting with native selection)
        scrollback: 3000, // [Optimization] Limit scrollback to 3000 lines (Ring Buffer) to prevent memory overflow
    };

    term = new Terminal(options);
    term.loadAddon(fitAddon);

    // Link clicks
    term.options.linkHandler = {
        activate: (e, text) => {
            if (native && native.openLink) native.openLink(text);
        }
    };

    // Setup global term object for debugging if needed
    window.term = term;
}

// Main initialization function
window.onload = function () {
    // Retry mechanism for native object injection
    let retryCount = 0;
    const maxRetries = 10;

    function initialize() {
        // WebGL 渲染开关(实验)：由设置页"GPU Render"控制，默认关。
        // 关闭时用 DOM 渲染器(兼容性好)；开启走 GPU 绘制，大量输出时更流畅，
        // 但部分手机触屏坐标可能错位，需实测后再常开。
        let shouldEnableWebGL = !!(window.native && native.getWebglRenderer && native.getWebglRenderer());

        // Check if native is ready
        if (!window.native && retryCount < maxRetries) {
            console.log(`Waiting for native object... (${retryCount + 1}/${maxRetries})`);
            retryCount++;
            setTimeout(initialize, 200);
            return;
        }

        // Initial fit with a slight delay to ensure container is ready
        setTimeout(() => {
            // 0. Create terminal and open it
            try {
                createTerminal();
                term.open(document.getElementById('terminal'));
                setupImeGuard();
            } catch (e) {
                console.error("Failed to create terminal", e);
                return;
            }

            // 1. Setup event listeners and sync preferences FIRST
            //    确保 term.onResize 在 fitAddon.fit() 之前设置好，
            //    这样首次 fit 的 resize 事件才能触发 native.resize() 发送给 VM 内核
            try {
                syncPrefs();
                setupEventListeners();
            } catch (e) {
                console.error("Error during setup", e);
            }

            // 2. Detect available monospace fonts
            //    Preload bundled fonts first to ensure they're detected
            try {
                // Bundled fonts — always available, loaded via fonts.css @font-face
                var bundledFonts = ['JetBrains Mono', 'Fira Code', 'Source Code Pro'];
                var preloadPromises = [];
                if (document.fonts && document.fonts.load) {
                    for (var b = 0; b < bundledFonts.length; b++) {
                        preloadPromises.push(
                            document.fonts.load('14px "' + bundledFonts[b] + '"')
                                .catch(function() { /* ignore individual load failures */ })
                        );
                    }
                }
                // Run detection after preload (with timeout fallback)
                var doDetection = function() {
                    var availableFonts = detectAvailableMonospaceFonts();
                    // Ensure bundled fonts are always present (their woff2 files are baked in)
                    for (var k = 0; k < bundledFonts.length; k++) {
                        if (availableFonts.indexOf(bundledFonts[k]) === -1) {
                            availableFonts.push(bundledFonts[k]);
                        }
                    }
                    console.log('Detected monospace fonts: ' + availableFonts.join(', '));
                    if (native.onAvailableFontsDetected) {
                        native.onAvailableFontsDetected(JSON.stringify(availableFonts));
                    }
                };
                if (preloadPromises.length > 0) {
                    // Wait up to 2s for fonts to load, then run detection
                    Promise.race([
                        Promise.all(preloadPromises),
                        new Promise(function(r) { setTimeout(r, 2000); })
                    ]).then(doDetection);
                } else {
                    doDetection();
                }
            } catch (e) {
                console.warn('Font detection failed', e);
            }

            // 3. Fit Terminal (now onResize listener is ready to capture this)
            try {
                fitAddon.fit();
                console.log(`Terminal size after fit: ${term.cols}x${term.rows}`);
                if (typeof forceFit === 'function') forceFit();
                var tc = document.getElementById('terminal-container');
                var te = document.getElementById('terminal');
                var xt = document.querySelector('.xterm');
                console.log('DIAG container=' + (tc ? tc.clientWidth : 'null') + ' terminal=' + (te ? te.clientWidth : 'null') + ' xterm=' + (xt ? xt.clientWidth : 'null') + ' window=' + window.innerWidth + ' screen=' + screen.width + ' dpr=' + window.devicePixelRatio + ' cols=' + term.cols + ' charW=' + measureCharWidth().toFixed(3));

                // If fit failed (size 0), force a default size
                if (term.cols < 2 || term.rows < 2) {
                    var cw = document.getElementById('terminal-container');
                    var w = (cw && cw.clientWidth) || window.innerWidth || 800;
                    var h = (cw && cw.clientHeight) || window.innerHeight || 600;
                    var estCols = Math.max(Math.floor(w / 7.5), 80);
                    var estRows = Math.max(Math.floor(h / 15), 24);
                    term.resize(estCols, estRows);
                    console.log("Estimated size: " + estCols + "x" + estRows + " (container: " + w + "x" + h + ")");
                }
            } catch (e) {
                console.error("Fit failed", e);
                var w2 = window.innerWidth || 800; var h2 = window.innerHeight || 600;
                    term.resize(Math.max(Math.floor(w2 / 7.5), 80), Math.max(Math.floor(h2 / 15), 24)); // Estimate from screen
            }

            // 3b. Re-fit once web fonts are ready. Bundled fonts (woff2) load
            //     asynchronously; the fit above may have measured a fallback
            //     font and computed the wrong column count, leaving a blank
            //     strip on the right. document.fonts.ready resolves when all
            //     pending fonts have loaded (or failed).
            //     forceFit 用探针实测真实字符步进，能纠正 fitAddon 用陈旧
            //     cell.width 算出的偏小列数。ArkWeb 上 fonts.ready 偶尔在字体
            //     真正解码前就 resolve，故再按几个延时复测兜底。
            var refitOnce = function () {
                try {
                    fitAddon.fit();
                    if (typeof forceFit === 'function') forceFit();
                    console.log(`Terminal size after font-ready fit: ${term.cols}x${term.rows}`);
                } catch (e) { /* ignore */ }
            };
            if (document.fonts && document.fonts.ready) {
                document.fonts.ready.then(refitOnce).catch(function () { /* ignore */ });
            }
            // 延时复测：覆盖 fonts.ready 提前 resolve / 字体解码滞后于 ready 的情况。
            [600, 1200, 2000, 3000].forEach(function (d) {
                setTimeout(function () {
                    if (typeof forceFit === 'function') forceFit();
                }, d);
            });

            // 4. Load WebGL (unavailable in this DOM-renderer-only build)
            if (shouldEnableWebGL) {
                try {
                    webglAddon.onContextLoss(e => {
                        webglAddon.dispose();
                    });
                    term.loadAddon(webglAddon);
                    console.log("WebGL renderer loaded");
                } catch (e) {
                    console.warn("WebGL renderer failed to load, falling back to canvas", e);
                }
            }

            // 5. Initialize and Start Shell
            try {
                // Restore HiSH Startup Logo
                term.writeln(
                    'HiSH is starting...\r\n\r\n' +
                    '     |  | _)   __|  |  |\r\n' +
                    '     __ |  | \\__ \\  __ |\r\n' +
                    '    _| _| _| ____/ _| _|\r\n'
                );

                // Notify native that we are ready
                if (window.native && native.load) {
                    native.load();
                } else {
                    console.error("Native object still missing after retries");
                    term.writeln('\r\nError: Native bridge failed to initialize.\r\n');
                }

                // High-throughput write port (structured clone, no base64/eval).
                // Official delivery: ets calls controller.postMessage('__init_port__', [port], '*')
                // and we receive the port via window message event.ports[0].
                // Safety: native only switches to the port after our echo of its
                // handshake string. Until then (and forever if the handshake
                // fails) data keeps flowing via exports.writeBase64.
                window.addEventListener('message', function (event) {
                    try {
                        if (event.data !== '__init_port__') return;
                        var port = event.ports && event.ports[0];
                        if (!port) return;
                        var lastReportedAppMode = null;
                        var reportAppMode = function () {
                            try {
                                var m = term.modes.applicationCursorKeysMode;
                                if (m !== lastReportedAppMode) {
                                    lastReportedAppMode = m;
                                    if (window.native && native.setApplicationMode) {
                                        native.setApplicationMode(m);
                                    }
                                }
                            } catch (err) { /* ignore */ }
                        };
                        port.onmessage = function (e) {
                            try {
                                var d = e && e.data;
                                if (typeof d === 'string') {
                                    if (d === '__hish_port_ok__') {
                                        port.postMessage('__hish_port_ok__'); // echo handshake
                                        return;
                                    }
                                    term.write(d);
                                    reportAppMode();
                                } else if (d instanceof ArrayBuffer) {
                                    term.write(new Uint8Array(d));
                                    reportAppMode();
                                }
                            } catch (err) {
                                console.error('port write failed', err);
                            }
                        };
                        console.log('write port received, handshake armed');
                    } catch (err) {
                        console.error('port setup failed', err);
                    }
                });
            } catch (e) {
                console.error("Error during init/load", e);
            }

        }, 300); // 300ms delay to ensure container is ready
    }

    // Start initialization
    initialize();
};

function syncPrefs() {
    try {
        if (native.getFontSize) {
            const fs = native.getFontSize();
            if (fs) term.options.fontSize = fs;
        }
        if (native.getFontFamily) {
            const ff = native.getFontFamily();
            if (ff) exports.setFontFamily(ff);
        }
        if (native.getCursorBlink) {
            const blink = native.getCursorBlink();
            if (blink) term.options.cursorBlink = blink;
        }
        if (native.getCursorShape) {
            const shape = native.getCursorShape();
            if (shape) exports.setCursorShape(shape); // Use our adapter logic
        }
        if (native.getBackgroundColor) {
            const bg = native.getBackgroundColor();
            if (bg) exports.setBackgroundColor(bg);
        }
        if (native.getBackgroundImage) {
            const img = native.getBackgroundImage();
            if (img) exports.setBackgroundImage(img);
        }
        if (native.getBackgroundBlur) {
            const blur = native.getBackgroundBlur();
            if (blur) exports.setBackgroundBlur(blur);
        }
        if (native.getUserFonts) {
            const fontsJson = native.getUserFonts();
            if (fontsJson) registerUserFonts(fontsJson);
        }
    } catch (e) {
        console.warn("Failed to sync prefs", e);
    }
}

// Registers user-uploaded fonts (JSON array of {name, dataUrl}) via FontFace.
function registerUserFonts(json) {
    try {
        var fonts = JSON.parse(json);
        for (var i = 0; i < fonts.length; i++) {
            exports.addUserFont(fonts[i].name, fonts[i].dataUrl);
        }
    } catch (e) {
        console.warn('registerUserFonts failed', e);
    }
}
exports.registerUserFonts = registerUserFonts;

function setupEventListeners() {
    // 1. Input from User (Keyboard/Mouse) -> Send to VM
    term.onData(data => {
        // Pass data directly to native (matching original hterm behavior)
        if (native && native.sendInput) {
            native.sendInput(data);
        }
    });

    // 2. Resize -> Notify Native
    term.onResize(size => {
        if (native && native.resize) {
            native.resize(size.cols, size.rows);
        }
    });

    // 3. Selection Change -> Notify Native
    term.onSelectionChange(() => {
        const text = term.getSelection();
        if (native && native.onSelectionChange) {
            native.onSelectionChange(text);
        }
    });

    // 4. Handle Window Resize
    window.addEventListener('resize', () => {
        setTimeout(() => {
            fitAddon.fit();
            if (typeof forceFit === 'function') forceFit();
        }, 100);
    });

    // 4b. Observe container size changes that do NOT fire window resize
    //     (ArkUI layout changes, drawer/panel animations, soft keyboard).
    //     Guards against the terminal being too narrow: whenever the
    //     container grows/shrinks by more than 1px, re-fit.
    var termContainer = document.getElementById('terminal-container');
    if (termContainer && typeof ResizeObserver !== 'undefined') {
        var lastFitW = -1;
        var lastFitH = -1;
        var ro = new ResizeObserver(function (entries) {
            var entry = entries && entries[0];
            var w = entry ? entry.contentRect.width : termContainer.clientWidth;
            var h = entry ? entry.contentRect.height : termContainer.clientHeight;
            if (Math.abs(w - lastFitW) <= 1 && Math.abs(h - lastFitH) <= 1) return;
            lastFitW = w;
            lastFitH = h;
            setTimeout(function () {
                try {
                    fitAddon.fit();
                    if (typeof forceFit === 'function') forceFit();
                } catch (e) { /* ignore */ }
            }, 50);
        });
        ro.observe(termContainer);
    }

    // 5. Prevent default browser behaviors that might interfere
    document.addEventListener('keydown', (e) => {
        // Allow some system shortcuts if needed, but generally intercept
        if (e.ctrlKey || e.altKey || (e.keyCode >= 112 && e.keyCode <= 123)) {
            // Let xterm handle it or prevent default
        }
    }, { passive: false });

    // --- Touch gesture arbitration + fling (momentum) scrolling ---
    // Terminal content is not natively scrollable: the visible layers are
    // fixed and xterm emulates scrolling by writing viewport.scrollTop in its
    // own touchmove handler on #terminal. When the drag starts on selectable
    // text (user-select: text, kept for long-press copy), the WebView may
    // claim the gesture for text selection and cancel the touch stream —
    // which made swiping over text feel stuck.
    //
    // Arbitration:
    //   - Swipe past the slop threshold → claim the gesture via
    //     preventDefault() so the browser never turns it into a selection or
    //     pan gesture; xterm's handler still receives the events and scrolls.
    //   - Selection appearing mid-gesture (long-press) → hand the stream back
    //     to the browser so word selection + copy keep working.
    //   - Multi-touch (pinch zoom) is left untouched.
    //
    // Fling: while a scroll gesture is active, sample touch positions and on
    // release keep scrolling with an exponentially decaying velocity (rAF).
    // Buffer/render sync needs no extra work — xterm's 'scroll' listener on
    // .xterm-viewport fires for every scrollTop change (same path as wheel).
    var touchStartX = 0;
    var touchStartY = 0;
    var touchHadSelection = false;
    var gestureDecided = false;
    var isScrollGesture = false;
    var TOUCH_SLOP = 8;

    var touchSamples = []; // [{y, t}] recent scroll-gesture positions
    var flingRafId = 0;
    var FLING_SAMPLE_MS = 100;    // velocity estimation window
    var FLING_MIN_VELOCITY = 0.1; // px/ms; slower release counts as a stop
    var FLING_MAX_VELOCITY = 5;   // px/ms safety cap
    var FLING_FRICTION_MS = 350;  // decay time constant (Android-like feel)
    var FLING_MIN_SPEED = 0.01;   // px/ms stop threshold

    function stopFling() {
        if (flingRafId) {
            cancelAnimationFrame(flingRafId);
            flingRafId = 0;
        }
    }

    function startFling(velocity) {
        var vp = document.querySelector('#terminal .xterm-viewport');
        if (!vp) return;
        stopFling();
        var v = velocity;
        var lastTime = performance.now();
        var step = function (now) {
            var dt = now - lastTime;
            lastTime = now;
            var before = vp.scrollTop;
            vp.scrollTop = before + v * dt;
            // Unchanged scrollTop → hit the top/bottom bound (or no scrollback)
            if (vp.scrollTop === before) {
                flingRafId = 0;
                return;
            }
            v *= Math.exp(-dt / FLING_FRICTION_MS);
            if (Math.abs(v) > FLING_MIN_SPEED) {
                flingRafId = requestAnimationFrame(step);
            } else {
                flingRafId = 0;
            }
        };
        flingRafId = requestAnimationFrame(step);
    }

    function nativeSelectionActive() {
        var s = window.getSelection();
        return !!(s && !s.isCollapsed);
    }

    document.addEventListener('touchstart', (e) => {
        stopFling();
        touchSamples = [];
        if (e.touches.length !== 1) {
            gestureDecided = true;
            isScrollGesture = false;
            return;
        }
        touchStartX = e.touches[0].clientX;
        touchStartY = e.touches[0].clientY;
        touchHadSelection = nativeSelectionActive();
        gestureDecided = false;
        isScrollGesture = false;
    }, { passive: true });

    document.addEventListener('touchmove', (e) => {
        if (e.touches.length !== 1) return; // Allow pinch zoom if not handled by CSS
        var x = e.touches[0].clientX;
        var y = e.touches[0].clientY;
        if (!gestureDecided) {
            if (Math.abs(x - touchStartX) < TOUCH_SLOP && Math.abs(y - touchStartY) < TOUCH_SLOP) {
                return;
            }
            gestureDecided = true;
            if (!touchHadSelection && nativeSelectionActive()) {
                // A long-press selection engaged during this touch: let the
                // browser keep the stream for selection dragging.
                isScrollGesture = false;
                return;
            }
            isScrollGesture = true;
        }
        if (isScrollGesture) {
            // Claim the gesture before the browser can classify it as a text
            // selection drag. xterm's bubble-phase touchmove handler on
            // #terminal still receives this event and does the scrolling.
            e.preventDefault();
            touchSamples.push({ y: y, t: e.timeStamp });
            while (touchSamples.length > 2 && e.timeStamp - touchSamples[0].t > FLING_SAMPLE_MS) {
                touchSamples.shift();
            }
        }
    }, { passive: false });

    var resetTouchGesture = function () {
        gestureDecided = false;
        isScrollGesture = false;
        touchSamples = [];
    };

    document.addEventListener('touchend', () => {
        // Fling on release, using the velocity of the last ~100ms of dragging.
        // Finger up (y decreases) → (first.y - last.y) > 0 → scroll down.
        if (isScrollGesture && touchSamples.length > 1) {
            var first = touchSamples[0];
            var last = touchSamples[touchSamples.length - 1];
            if (last.t > first.t) {
                var v = (first.y - last.y) / (last.t - first.t);
                v = Math.max(-FLING_MAX_VELOCITY, Math.min(FLING_MAX_VELOCITY, v));
                if (Math.abs(v) > FLING_MIN_VELOCITY) {
                    startFling(v);
                }
            }
        }
        resetTouchGesture();
    }, { passive: true });
    document.addEventListener('touchcancel', resetTouchGesture, { passive: true });

    // --- EVENT SHIELD: Force Native Context Menu (Global Capture) ---
    // This listener runs in the CAPTURE phase on the DOCUMENT.
    // It intercepts the 'contextmenu' event BEFORE it reaches xterm.js.
    // We stop it from propagating to xterm, but allow the default browser behavior (menu).

    document.addEventListener('contextmenu', (e) => {
        // Only intercept if inside the terminal
        if (e.target.closest('#terminal')) {
            e.stopImmediatePropagation(); // Kill it before xterm sees it
            // e.preventDefault(); // DO NOT CALL THIS! We want the menu!
            return true;
        }
    }, true); // true = Capture Phase

    console.log("Global ContextMenu Interceptor activated");
}

// Fix for mouse/touch coordinates when the terminal is visually flipped
function setupMirroredInputFix(termEl) {
    const fixEvent = (e) => {
        if (!termEl.classList.contains('webgl-mobile-fix')) return;

        // If the event was already fixed, skip
        if (e._fixed) return;

        const rect = termEl.getBoundingClientRect();
        let clientY = e.clientY;
        if (e.touches && e.touches.length > 0) {
            clientY = e.touches[0].clientY;
        }

        // Calculate relative Y and flip it
        const relativeY = clientY - rect.top;
        const flippedY = rect.height - relativeY;
        const newClientY = rect.top + flippedY;

        // We can't easily modify clientY of a native event, 
        // but xterm.js uses offsetX/offsetY or calculates from clientX/Y.
        // This is a complex area. A simpler way is to use a proxy element or 
        // just warn the user that touch selection might be inverted.
        console.log("Input coordinates might need inversion due to WebGL fix");
    };

    // termEl.addEventListener('mousedown', fixEvent, true);
    // termEl.addEventListener('touchstart', fixEvent, true);
}

// --- Implementation of exports matching term.js.bak ---

// exports.write(data) - Write data from VM to terminal
exports.write = (data, applicationMode) => {
    // legacy hterm code imply data is Binary String (UTF-8/Latin1 bytes)
    try {
        const uint8 = strToUint8Array(data);
        term.write(uint8);
        if (term.modes.applicationCursorKeysMode !== applicationMode) {
            native.setApplicationMode(term.modes.applicationCursorKeysMode)
        }
    } catch (e) {
        console.error("exports.write failed", e);
    }
};

exports.writeBase64 = (base64Data, applicationMode) => {
    try {
        let binaryString = atob(base64Data);

        const uint8 = new Uint8Array(binaryString.length);
        for (let i = 0; i < binaryString.length; i++) {
            uint8[i] = binaryString.charCodeAt(i);
        }
        term.write(uint8);

        // Sync Application Cursor Mode using xterm.js state
        if (term.modes.applicationCursorKeysMode !== applicationMode) {
            if (native && native.setApplicationMode) {
                native.setApplicationMode(term.modes.applicationCursorKeysMode);
            }
        }
    } catch (e) {
        console.error("exports.writeBase64 failed", e);
    }
};

exports.paste = (data) => {
    if (native && native.sendInput) {
        // data: proper Unicode string (paste path); ArkTS sendInput performs the single UTF-8 encode
        native.sendInput(data);
    }
};

exports.copy = () => {
    // xmm.js selection API
    return term.getSelection();
};

exports.setFontSize = (size) => {
    term.options.fontSize = size;
    fitAddon.fit();
};

exports.setFontFamily = (family) => {
    currentFontFamily = family || 'Default';
    var newFamily = mapFontFamily(family);
    term.options.fontFamily = newFamily;

    // Resize to current dimensions to force xterm.js to
    // re-layout with the new font metrics, then re-fit.
    if (term.cols > 0 && term.rows > 0) {
        term.resize(term.cols, term.rows);
    }
    fitAddon.fit();
};

// Exposed for the ArkTS host (WebTerminal.ets onAreaChange) to request a
// re-fit when the Web component's area changes outside this page's control.
exports.fit = () => {
    if (term) {
        try { fitAddon.fit() } catch (e) { console.error('exports.fit failed', e) }
        forceFit();
    }
};

// Ground-truth monospace advance for the terminal's CURRENT font.
// 用隐藏探针按 term 当前的 font-family + font-size 实测真实字符步进，
// 独立于 xterm 内部缓存的 cell.width —— 后者在 term.open() 时若网页字体
// 尚未加载完成，会拿更宽的回退字体量出一个偏大的 cell.width 并缓存，
// 导致 fitAddon 把列数算少（例如 51 而非 63），右侧长期留黑边 + 省略号。
function measureCharWidth() {
    try {
        if (!term) return 0;
        var font = term.options.fontFamily || 'monospace';
        var size = term.options.fontSize || 14;
        var probe = document.createElement('span');
        probe.style.fontFamily = font;
        probe.style.fontSize = size + 'px';
        probe.style.position = 'absolute';
        probe.style.visibility = 'hidden';
        probe.style.left = '-9999em';
        probe.style.top = '0';
        probe.style.whiteSpace = 'pre';
        probe.style.lineHeight = 'normal';
        probe.textContent = 'MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM';
        (document.body || document.documentElement).appendChild(probe);
        var w = probe.getBoundingClientRect().width / probe.textContent.length;
        probe.parentNode.removeChild(probe);
        return w > 0 ? w : 0;
    } catch (e) {
        return 0;
    }
}

function forceFit() {
    if (!term || term.cols < 1) return;
    // 真实可用宽度 = 实际布局后的容器宽度（CSS px）。
    // 不用 window.innerWidth：ArkWeb 上它常滞后 Web 组件真实尺寸或缩放不一致，
    // 这是之前几版按比例反推始终改不动列数的根本原因。
    var container = document.getElementById('terminal-container');
    var availW = container ? container.clientWidth : 0;
    if (!(availW > 0)) availW = window.innerWidth || document.documentElement.clientWidth || 800;

    // 真实字符步进（地面真值，非 xterm 缓存的 cell.width）。
    var charW = measureCharWidth();
    if (!(charW > 0)) {
        // 兜底：从已渲染的 rows 元素反推（仅在探针失败时）。
        var rows = term.element ? term.element.querySelector('.xterm-rows') : null;
        if (rows && rows.offsetWidth > 0) charW = rows.offsetWidth / term.cols;
    }
    if (!(charW > 0)) return;

    var newCols = Math.max(2, Math.floor(availW / charW));
    if (newCols !== term.cols) {
        // term.resize 到不同列数会触发 xterm 渲染器重新测量字体，
        // 把之前用回退字体量出的陈旧 cell.width 一并修正，
        // 光标 / 选区几何与文本对齐才不会错位。
        console.log('forceFit: ' + term.cols + ' -> ' + newCols +
            ' (availW=' + availW + ' charW=' + charW.toFixed(3) + ')');
        term.resize(newCols, term.rows);
    }
}

exports.setCursorBlink = (blink) => {
    term.options.cursorBlink = blink;
};

// Ligature / italic toggles: this build always uses the DOM renderer,
// so both are pure CSS switches applied live without reloading.
exports.setLigatures = (enabled) => {
    document.body.classList.toggle('ligatures-off', !enabled);
};

exports.setItalic = (enabled) => {
    document.body.classList.toggle('italics-off', !enabled);
};

// --- Terminal appearance: background color / image / gaussian blur ---

exports.setBackgroundColor = (color) => {
    if (!color) return;
    document.body.style.backgroundColor = color;
};

exports.setBackgroundImage = (dataUrl) => {
    var bg = document.getElementById('terminal-bg');
    if (!bg) return;
    bg.style.backgroundImage = dataUrl ? 'url("' + dataUrl + '")' : 'none';
};

exports.setBackgroundBlur = (px) => {
    var bg = document.getElementById('terminal-bg');
    if (!bg) return;
    var radius = parseInt(px, 10) || 0;
    if (radius > 0) {
        bg.style.filter = 'blur(' + radius + 'px)';
        // Slightly upscale so the blurred edges stay covered
        bg.style.transform = 'scale(' + (1 + radius / 100) + ')';
    } else {
        bg.style.filter = 'none';
        bg.style.transform = 'none';
    }
};

// Registers a user-uploaded font into the document via the FontFace API.
// dataUrl is a base64 data URL of the font file (ttf/otf/woff/woff2).
exports.addUserFont = (name, dataUrl) => {
    if (!name || !dataUrl || typeof FontFace === 'undefined') return;
    try {
        var face = new FontFace(name, 'url("' + dataUrl + '")');
        face.load().then(function (loaded) {
            document.fonts.add(loaded);
            console.log('User font loaded: ' + name);
            // Re-apply in case this font is the currently selected one
            if (currentFontFamily === name) {
                exports.setFontFamily(name);
            }
        }).catch(function (e) {
            console.error('User font load failed: ' + name, e);
        });
    } catch (e) {
        console.error('addUserFont failed: ' + name, e);
    }
};

exports.setFocused = (focus) => {
    if (focus) {
        setupImeGuard();
        term.focus();
    } else {
        term.blur();
    }
};

// Mock hterm.openUrl for compatibility if something calls it directly
window.hterm = {
    openUrl: (url) => {
        if (native && native.openLink) native.openLink(url);
    }
};

exports.selectAll = () => {
    term.selectAll();
};

// Clears the whole terminal buffer (viewport + scrollback)
exports.clearScreen = () => {
    term.clear();
};
