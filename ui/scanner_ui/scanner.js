/* =========================================================================
   Scanner DUI Test — Vanilla JS
   Porta standalone do ScannerApp.tsx + Debug Panel integrado
   ========================================================================= */

// =========================================================================
// SVG Icons (inline from lucide)
// =========================================================================

const ICONS = {
    activity: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/></svg>',
    car: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-.6 0-1 .4-1 1v11"/><circle cx="7.5" cy="17.5" r="2.5"/><circle cx="16.5" cy="17.5" r="2.5"/></svg>',
    user: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>',
    checkCircle: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>',
    x: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>',
    refreshCw: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="23 4 23 10 17 10"/><polyline points="1 20 1 14 7 14"/><path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"/></svg>',
};

// =========================================================================
// State
// =========================================================================

let appState = 'waiting'; // 'waiting' | 'loading' | 'idle' | 'parts'

// Veículo linkado ao abrir o scanner — nunca muda até fechar
let linkedVehicle = null; // { plate, model }

// Dados das peças
let linkedParts     = []; // array de { label, percent } — tela de status
let linkedPartLabels = []; // só labels — para o loading animation

// Dados do loading
let scanningDuration    = 10;
let scanningAnimTimeout = null;
let loadingDoneTimeout  = null;

// Modo de exibição das peças: 'progress' (barra + %) ou 'stats' (label de status)
let displayMode = 'progress';

// Scroll da lista de peças
let partsScrollOffset = 0;
const PARTS_PER_PAGE  = 4;

// CSS Transform state
let cssTransform = {
    scaleX: 1.0,
    scaleY: 1.5,
    rotate: 0,
    translateX: 0,
    translateY: -16,
};

// =========================================================================
// DOM References
// =========================================================================

const $root = () => document.getElementById('scanner-root');
const $debug = () => document.getElementById('debug-overlay');

// =========================================================================
// Render Engine
// =========================================================================

function render() {
    const root = $root();
    if (!root) return;

    // Apply CSS transform
    root.style.transform = `scaleX(${cssTransform.scaleX}) scaleY(${cssTransform.scaleY}) rotate(${cssTransform.rotate}deg) translate(${cssTransform.translateX}%, ${cssTransform.translateY}%)`;
    root.style.transformOrigin = 'center center';

    // Sincroniza os textos do painel de debug (caso esteja aberto na mão)
    syncDebugSliders();

    const body = root.querySelector('.scanner-body');
    if (!body) return;

    // Clear states container
    const statesEl = body.querySelector('.scanner-states');
    if (!statesEl) return;
    statesEl.innerHTML = '';

    switch (appState) {
        case 'waiting':
            statesEl.innerHTML = renderWaiting();
            break;
        case 'loading':
            statesEl.innerHTML = renderLoading();
            setTimeout(() => startLoadingAnimation(), 0);
            break;
        case 'idle':
            statesEl.innerHTML = renderIdle();
            break;
        case 'parts':
            statesEl.innerHTML = renderParts();
            break;
    }
}

function renderWaiting() {
    return `
        <div class="scanner-state active state-waiting">
            <div class="icon">${ICONS.activity}</div>
            <div class="label">SEM ALVO</div>
        </div>
    `;
}

function renderLoading() {
    return `
        <div class="scanner-state active state-scanning" id="loading-container">
            <div class="spinner-container">
                <div class="spinner-ring"></div>
                <div class="icon">${ICONS.activity}</div>
            </div>
            <div class="scanning-label">ANALISANDO</div>
            <div class="progress-track">
                <div class="progress-fill" id="scan-progress-fill"></div>
            </div>
            <div class="scanning-log" id="scanning-log"></div>
        </div>
    `;
}

function renderIdle() {
    const plate = linkedVehicle?.plate || '---';
    const model = linkedVehicle?.model || '---';
    const count = linkedParts.length;

    let partsSummary = '';
    if (count > 0) {
        partsSummary = linkedParts.map(p => {
            const cls = p.percent < 30 ? 'danger' : p.percent < 60 ? 'warn' : 'ok';
            let valueDisplay = '';
            if (displayMode === 'stats') {
                const statusText = p.status || (p.percent >= 60 ? 'Boa' : p.percent >= 30 ? 'Razoável' : 'Ruim');
                valueDisplay = `<span class="idle-part-pct ${cls}">${statusText}</span>`;
            } else {
                valueDisplay = `<span class="idle-part-pct ${cls}">${p.percent}%</span>`;
            }
            return `
                <div class="idle-part-row">
                    <span class="idle-part-label">${p.label}</span>
                    ${valueDisplay}
                </div>
            `;
        }).join('');
    } else {
        partsSummary = `<div class="idle-no-parts">Nenhuma peça instalada</div>`;
    }

    return `
        <div class="scanner-state active" style="flex:1;display:flex;flex-direction:column;">
            <div class="status-bar">
                <span class="label">VEÍCULO CONECTADO</span>
                <div class="dot"></div>
            </div>
            <div class="info-bar" style="margin-bottom:12px;">
                <div class="type-label">MODELO</div>
                <div class="type-value">${model}</div>
                <div class="type-label" style="margin-top:6px;">PLACA</div>
                <div class="type-value" style="font-size:26px;">${plate}</div>
            </div>
            <div class="idle-parts-list">
                ${partsSummary}
            </div>
            <div class="key-hints">
                <span>[E] Ver status das peças</span>
                <span>[BSP/ESC] Fechar</span>
            </div>
        </div>
    `;
}

function renderParts() {
    const parts = linkedParts;
    if (parts.length === 0) {
        return `
            <div class="scanner-state active" style="flex:1;display:flex;flex-direction:column;">
                <div class="status-bar">
                    <span class="label">STATUS DAS PEÇAS</span>
                    <div class="dot"></div>
                </div>
                <div class="state-waiting" style="flex:1;">
                    <div class="label" style="margin-top:40px;">Nenhuma peça instalada</div>
                </div>
                <div class="key-hints">
                    <span>[Q] Voltar</span>
                    <span>[↑↓] Rolar</span>
                </div>
            </div>
        `;
    }

    const visible = parts.slice(partsScrollOffset, partsScrollOffset + PARTS_PER_PAGE);
    const canUp   = partsScrollOffset > 0;
    const canDown = partsScrollOffset + PARTS_PER_PAGE < parts.length;

    const rows = visible.map(p => {
        const pct = Math.max(0, Math.min(100, p.percent));
        const cls = pct < 30 ? 'danger' : pct < 60 ? 'warn' : 'ok';

        let valueCol = '';
        if (displayMode === 'stats') {
            // Modo stats: exibe label de status textual (Boa / Razoável / Ruim)
            const statusText = p.status || (pct >= 60 ? 'Boa' : pct >= 30 ? 'Razoável' : 'Ruim');
            valueCol = `<span class="parts-bar-pct ${cls}" style="min-width:70px;text-align:right;">${statusText}</span>`;
        } else {
            // Modo progress: barra de blocos + percentual (comportamento original)
            const filled = Math.round(pct / 100 * 20);
            const empty  = 20 - filled;
            const bar    = '█'.repeat(filled) + '░'.repeat(empty);
            valueCol = `
                <span class="parts-bar-fill ${cls}">${bar}</span>
                <span class="parts-bar-pct ${cls}">${pct}%</span>
            `;
        }

        return `
            <div class="parts-row">
                <div class="parts-row-label">${p.label}</div>
                <div class="parts-row-bar">
                    ${valueCol}
                </div>
            </div>
        `;
    }).join('');

    const scrollIndicator = `
        <div class="parts-scroll-indicator">
            <span class="${canUp ? 'active' : 'dim'}">▲ ${canUp ? partsScrollOffset : '—'}</span>
            <span style="color:#475569;">${partsScrollOffset + 1}–${Math.min(partsScrollOffset + PARTS_PER_PAGE, parts.length)} / ${parts.length}</span>
            <span class="${canDown ? 'active' : 'dim'}">${canDown ? parts.length - partsScrollOffset - PARTS_PER_PAGE : '—'} ▼</span>
        </div>
    `;

    return `
        <div class="scanner-state active" style="flex:1;display:flex;flex-direction:column;">
            <div class="status-bar">
                <span class="label">STATUS DAS PEÇAS</span>
                <div class="dot"></div>
            </div>
            <div class="parts-list">
                ${rows}
            </div>
            ${scrollIndicator}
            <div class="key-hints">
                <span>[Q] Voltar</span>
                <span>[↑↓] Rolar</span>
                <span>[BSP/ESC] Fechar</span>
            </div>
        </div>
    `;
}

// =========================================================================
// Loading Animation
// =========================================================================

function startLoadingAnimation() {
    if (scanningAnimTimeout) { clearTimeout(scanningAnimTimeout); scanningAnimTimeout = null; }
    if (loadingDoneTimeout)  { clearTimeout(loadingDoneTimeout);  loadingDoneTimeout  = null; }

    const logEl      = document.getElementById('scanning-log');
    const progressEl = document.getElementById('scan-progress-fill');
    if (!logEl || !progressEl) return;

    const model   = linkedVehicle?.model || '---';
    const parts   = linkedPartLabels || [];
    const totalMs = (scanningDuration || 10) * 1000;

    // Sequência de mensagens
    const messages = [];
    messages.push({ text: `Iniciando leitura de veículo "${model}"`, color: '#60a5fa' });
    messages.push({ text: 'Iniciando leitura de sensores do carro',  color: '#94a3b8' });
    messages.push({ text: 'Escaneando sensores',                     color: '#94a3b8' });
    for (const part of parts) {
        messages.push({ text: `Escaneando ${part}`,        color: '#facc15' });
        messages.push({ text: `Lendo sensores de ${part}`, color: '#94a3b8' });
    }

    // Barra de progresso
    progressEl.style.animation  = 'none';
    progressEl.style.width      = '0%';
    progressEl.style.transition = `width ${totalMs}ms linear`;
    void progressEl.offsetWidth;
    progressEl.style.width = '100%';

    // Mensagens distribuídas no tempo
    const interval = Math.max(300, Math.floor(totalMs / (messages.length + 1)));
    let index = 0;

    const addNext = () => {
        const el = document.getElementById('scanning-log');
        if (!el) return;

        if (index < messages.length) {
            const msg  = messages[index];
            const line = document.createElement('div');
            line.className   = 'scanning-log-line';
            line.style.color = msg.color;
            line.textContent = '> ' + msg.text;
            el.appendChild(line);
            el.scrollTop = el.scrollHeight;
            const lines = el.querySelectorAll('.scanning-log-line');
            if (lines.length > 5) lines[0].remove();
            index++;
            scanningAnimTimeout = setTimeout(addNext, interval);
        }
    };
    scanningAnimTimeout = setTimeout(addNext, 400);

    // Ao terminar o loading, vai para idle automaticamente
    loadingDoneTimeout = setTimeout(() => {
        if (appState === 'loading') {
            appState = 'idle';
            render();
        }
    }, totalMs);
}

// =========================================================================
// Actions
// =========================================================================

function closeScannerClean() {
    linkedVehicle    = null;
    linkedParts      = [];
    linkedPartLabels = [];
    displayMode      = 'progress';
    partsScrollOffset = 0;
    if (scanningAnimTimeout) { clearTimeout(scanningAnimTimeout); scanningAnimTimeout = null; }
    if (loadingDoneTimeout)  { clearTimeout(loadingDoneTimeout);  loadingDoneTimeout  = null; }
    appState = 'waiting';
    render();
}

// =========================================================================
// Message Handler
// =========================================================================

window.addEventListener('message', function (event) {
    let msg = null;
    if (typeof event.data === 'string') {
        try { msg = JSON.parse(event.data); } catch { return; }
    } else if (event.data && event.data.action) {
        msg = event.data;
    }
    if (!msg || !msg.action) return;
    const p = msg.data;

    switch (msg.action) {

        // Lua enviou dados do veículo + peças — inicia loading automaticamente
        case 'startLoading':
            if (!p) return;
            linkedVehicle    = { plate: p.plate || '---', model: p.model || '---' };
            linkedPartLabels = p.parts     || [];
            linkedParts      = p.partsData || [];
            scanningDuration = p.duration  || 10;
            displayMode      = p.displayMode || 'progress';
            partsScrollOffset = 0;
            appState = 'loading';
            render();
            break;

        // Fecha tudo
        case 'hideScannerApp':
            closeScannerClean();
            break;

        // Teclas vindas do Lua
        case 'keyPress':
            if (!p) return;
            if (p.key === 'E' && appState === 'idle') {
                partsScrollOffset = 0;
                appState = 'parts';
                render();
            } else if (p.key === 'Q' && appState === 'parts') {
                appState = 'idle';
                render();
            } else if (p.key === 'UP' && appState === 'parts') {
                if (partsScrollOffset > 0) {
                    partsScrollOffset--;
                    render();
                }
            } else if (p.key === 'DOWN' && appState === 'parts') {
                if (partsScrollOffset + PARTS_PER_PAGE < linkedParts.length) {
                    partsScrollOffset++;
                    render();
                }
            }
            break;

        case 'applyTransform':
            if (p) { Object.assign(cssTransform, p); render(); syncDebugSliders(); }
            break;
    }
});

// =========================================================================
// Debug Panel Logic
// =========================================================================

function initDebugPanel() {
    const panel = $debug();
    if (!panel) return;

    // Close button
    panel.querySelector('.debug-close-btn').addEventListener('click', () => {
        panel.classList.remove('visible');
        fetch('https://scanner-dui-test/closeDebugPanel', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        }).catch(() => { });
    });

    // Slider events
    const sliders = {
        'slider-scaleX': { prop: 'scaleX', display: (v) => Number(v).toFixed(1) },
        'slider-scaleY': { prop: 'scaleY', display: (v) => Number(v).toFixed(1) },
        'slider-rotate': { prop: 'rotate', display: (v) => Number(v).toFixed(0) + '°' },
        'slider-translateX': { prop: 'translateX', display: (v) => Number(v).toFixed(0) + '%' },
        'slider-translateY': { prop: 'translateY', display: (v) => Number(v).toFixed(0) + '%' },
    };

    Object.entries(sliders).forEach(([id, config]) => {
        const slider = document.getElementById(id);
        const valueEl = document.getElementById(id + '-val');
        if (!slider) return;

        slider.addEventListener('input', () => {
            const val = parseFloat(slider.value);
            cssTransform[config.prop] = val;
            if (valueEl) valueEl.textContent = config.display(slider.value);
            render();
            sendTransformToLua();
        });
    });

    // Quick flip buttons
    document.getElementById('btn-flip-x')?.addEventListener('click', () => {
        cssTransform.scaleX *= -1;
        syncDebugSliders();
        render();
        sendTransformToLua();
    });

    document.getElementById('btn-flip-y')?.addEventListener('click', () => {
        cssTransform.scaleY *= -1;
        syncDebugSliders();
        render();
        sendTransformToLua();
    });

    document.getElementById('btn-rotate-180')?.addEventListener('click', () => {
        cssTransform.rotate = (cssTransform.rotate + 180) % 360;
        syncDebugSliders();
        render();
        sendTransformToLua();
    });

    document.getElementById('btn-reset')?.addEventListener('click', () => {
        cssTransform = { scaleX: 1, scaleY: 1, rotate: 0, translateX: 0, translateY: 0 };
        syncDebugSliders();
        render();
        sendTransformToLua();
    });

    // State simulation buttons
    document.getElementById('dbg-state-idle-veh')?.addEventListener('click', () => {
        dispatchState('showScannerApp', { type: 'vehicle', distance: '1.2', plate: 'BRA2E19', model: 'SULTAN' });
    });

    document.getElementById('dbg-state-idle-ped')?.addEventListener('click', () => {
        dispatchState('showScannerApp', { type: 'person', distance: '0.5', targetId: 104 });
    });

    document.getElementById('dbg-state-scanning')?.addEventListener('click', () => {
        dispatchState('setScannerState', { state: 'scanning' });
    });

    document.getElementById('dbg-state-result-pos')?.addEventListener('click', () => {
        dispatchState('setScannerResult', { type: 'person', gsr: true, targetName: 'John Doe', dateTime: new Date().toLocaleString('pt-BR') });
    });

    document.getElementById('dbg-state-result-neg')?.addEventListener('click', () => {
        dispatchState('setScannerResult', { type: 'person', gsr: false, targetName: 'Jane Doe', dateTime: new Date().toLocaleString('pt-BR') });
    });

    document.getElementById('dbg-state-result-veh')?.addEventListener('click', () => {
        dispatchState('setScannerResult', { type: 'vehicle', dna: 'DNA-MATCH', plate: 'BRA2E19', model: 'SULTAN', dateTime: new Date().toLocaleString('pt-BR') });
    });

    document.getElementById('dbg-state-error')?.addEventListener('click', () => {
        dispatchState('setScannerResult', { type: 'vehicle', error: 'Veículo não sincronizado', dateTime: new Date().toLocaleString('pt-BR') });
    });

    document.getElementById('dbg-state-hide')?.addEventListener('click', () => {
        dispatchState('hideScannerApp');
    });

    // Copy config button
    document.getElementById('btn-copy-config')?.addEventListener('click', () => {
        const config = {
            css_transform: `scaleX(${cssTransform.scaleX}) scaleY(${cssTransform.scaleY}) rotate(${cssTransform.rotate}deg) translate(${cssTransform.translateX}%, ${cssTransform.translateY}%)`,
            values: { ...cssTransform }
        };
        const text = JSON.stringify(config, null, 2);

        // Print to console too (F8)
        console.log("------------------------------------------");
        console.log("SCANNER CALIBRATION CONFIG:");
        console.log(text);
        console.log("------------------------------------------");

        // Update output display and scroll to it
        const outputEl = document.getElementById('config-output');
        if (outputEl) {
            outputEl.textContent = text;
            outputEl.style.display = 'block';
            outputEl.scrollIntoView({ behavior: 'smooth' });
        }

        // Copy to clipboard
        navigator.clipboard?.writeText(text).then(() => {
            const btn = document.getElementById('btn-copy-config');
            btn.textContent = '✓ COPIADO!';
            btn.classList.add('copied');
            setTimeout(() => {
                btn.textContent = '📋 COPIAR CONFIG';
                btn.classList.remove('copied');
            }, 2000);
        }).catch(() => { });
    });
}

function syncDebugSliders() {
    const mapping = {
        'slider-scaleX': { val: cssTransform.scaleX, display: (v) => Number(v).toFixed(1) },
        'slider-scaleY': { val: cssTransform.scaleY, display: (v) => Number(v).toFixed(1) },
        'slider-rotate': { val: cssTransform.rotate, display: (v) => Number(v).toFixed(0) + '°' },
        'slider-translateX': { val: cssTransform.translateX, display: (v) => Number(v).toFixed(0) + '%' },
        'slider-translateY': { val: cssTransform.translateY, display: (v) => Number(v).toFixed(0) + '%' },
    };

    Object.entries(mapping).forEach(([id, config]) => {
        const slider = document.getElementById(id);
        const valueEl = document.getElementById(id + '-val');
        if (slider) slider.value = config.val;
        if (valueEl) valueEl.textContent = config.display(config.val);
    });
}

function sendTransformToLua() {
    fetch('https://scanner-dui-test/updateDuiTransform', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(cssTransform)
    }).catch(() => { });
}

function dispatchState(action, data) {
    // Dispatch as local message event (works both in browser and DUI)
    window.dispatchEvent(new MessageEvent('message', {
        data: { action, data }
    }));

    // Also send to Lua to forward to DUI if in NUI context
    fetch('https://scanner-dui-test/debugSetState', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action, data })
    }).catch(() => { });
}

// =========================================================================
// Auto-detect browser mode
// =========================================================================

// Detect if we are running inside the DUI texture (has ?dui=1) or as NUI overlay
const isDui = window.location.href.includes('dui=1');

function isBrowser() {
    return !window.invokeNative;
}

// =========================================================================
// Init
// =========================================================================

document.addEventListener('DOMContentLoaded', function () {
    const root = $root();

    if (!isDui) {
        // NUI context: hide scanner entirely, only debug panel lives here
        if (root) root.style.display = 'none';
    }

    // Render initial state
    render();
    initDebugPanel();

    // Se aberto no browser diretamente, mostra debug e idle state
    if (isBrowser()) {
        if (root) root.style.display = '';
        const overlay = $debug();
        if (overlay) overlay.classList.add('visible');

        linkedVehicle    = { plate: 'BRA2E19', model: 'SULTAN' };
        linkedPartLabels = ['Vela de Ignição', 'Kit Freios lv4', 'Bateria 60amp'];
        linkedParts      = [
            { label: 'Vela de Ignição', percent: 78 },
            { label: 'Kit Freios lv4',  percent: 37 },
            { label: 'Bateria 60amp',   percent: 91 },
        ];
        scanningDuration = 10;
        appState = 'loading';
        render();
    }
});
