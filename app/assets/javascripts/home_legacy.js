function autoResize(el) {
  if (!el) return;
  el.style.height = 'auto';
  const newHeight = el.scrollHeight;
  const maxHeight = parseInt(window.getComputedStyle(el).maxHeight) || 800;

  if (newHeight >= maxHeight) {
    el.style.height = maxHeight + 'px';
    el.style.overflowY = 'auto';
  } else {
    el.style.height = newHeight + 'px';
    el.style.overflowY = 'hidden';
  }

}

// Currency Data & Helpers
const currenciesData = CURRENCIES;
const activeCurrencyCode_legacy = activeCurrencyCode;

function getCurrencyFormat(amount, code) {
  const c = CURRENCIES.find(x => x.c === (code || activeCurrencyCode)) || CURRENCIES.find(x => x.c === 'USD'); // Fallback to USD
  const sym = c ? c.s : "$";
  const pos = c ? (c.p || 'pre') : 'pre';
  const val = cleanNum(amount); // cleanNum returns a string

  if (pos === 'suf') {
    return `${val} ${sym}`;
  } else {
    return `${sym}${val}`;
  }
}

// Helper to get symbol only (for icons or specific placements)
function getCurrencySym(code) {
  const c = CURRENCIES.find(x => x.c === (code || activeCurrencyCode)) || CURRENCIES.find(x => x.c === 'USD'); // Fallback to USD
  return c ? c.s : "$";
}

function resizeInput(el) {
  if (!el) return;
  const style = window.getComputedStyle(el);
  const span = document.getElementById('widthMeasureSpan') || document.createElement('span');
  if (!span.id) {
    span.id = 'widthMeasureSpan';
    span.style.visibility = 'hidden';
    span.style.position = 'absolute';
    span.style.whiteSpace = 'pre';
    document.body.appendChild(span);
  }
  span.style.font = style.font;
  span.style.fontSize = style.fontSize;
  span.style.fontWeight = style.fontWeight;
  span.style.letterSpacing = style.letterSpacing;
  span.textContent = el.value || el.placeholder || "";
  el.style.width = Math.max(40, span.offsetWidth + 12) + 'px';
}

function resizeQtyInput(el) {
  if (!el) return;
  const span = document.getElementById('qtyMeasureSpan') || document.createElement('span');
  if (!span.id) {
    span.id = 'qtyMeasureSpan';
    span.style.visibility = 'hidden';
    span.style.position = 'absolute';
    span.style.whiteSpace = 'pre';
    document.body.appendChild(span);
  }
  const style = window.getComputedStyle(el);
  span.style.font = style.font;
  span.style.fontSize = style.fontSize;
  span.style.fontWeight = style.fontWeight;
  span.textContent = el.value || el.placeholder || "1";

  const textWidth = span.offsetWidth;
  const newWidth = Math.max(15, textWidth + 2);
  el.style.width = newWidth + 'px';

  const container = el.closest('.group\\/qty');
  if (container) {
    // 35px is the base width for 'x' and padding. We add the extra text width.
    // Base desktop width was 45px. 
    const isMobile = window.innerWidth < 768;
    const baseWidth = isMobile ? 32 : 40;
    container.style.width = (baseWidth + textWidth) + 'px';
  }
}

function cleanNum(val) {
  if (val === null || val === undefined || val === "") return "";
  let f = parseFloat(val);
  if (isNaN(f)) return val;
  return (f % 1 === 0) ? f.toString() : f.toFixed(2).replace(/\.?0+$/, "");
}

function formatMoney(amount) {
  // This function is being replaced by getCurrencyFormat for consistency.
  // Keeping it for now to avoid breaking other parts if they still use it.
  // New code should use getCurrencyFormat.
  const code = typeof activeCurrencyCode !== 'undefined' ? activeCurrencyCode : "USD";
  const currency = (typeof CURRENCIES !== 'undefined' ? CURRENCIES : []).find(c => c.c === code);
  const sym = currency ? currency.s : "$";
  const pos = currency ? (currency.p || 'pre') : 'pre';
  const num = parseFloat(amount) || 0;
  const val = num.toFixed(2);
  return pos === 'suf' ? `${val} ${sym}` : `${sym}${val}`;
}

window.toggleGlobalDiscountPanel = function (btn) {
  const panel = document.getElementById('discountInputsPanel');
  // If no btn passed, try finding it
  if (!btn) btn = document.getElementById('discountToggleBtn');

  if (!panel || !btn) return;
  const isHidden = panel.classList.contains('hidden');

  if (isHidden) {
    panel.classList.remove('hidden');
    btn.classList.add('pop-active');
  } else {
    panel.classList.add('hidden');
    btn.classList.remove('pop-active');

    const flat = parseFloat(document.getElementById('globalDiscountFlat')?.value) || 0;
    const pct = parseFloat(document.getElementById('globalDiscountPercent')?.value) || 0;
    if (flat > 0 || pct > 0) {
      btn.classList.add('border-green-600', 'bg-green-50', 'text-green-600');
      btn.classList.remove('border-black', 'text-black');
    } else {
      btn.classList.remove('border-green-600', 'bg-green-50', 'text-green-600');
      btn.classList.add('border-black', 'text-black');
    }
  }
}

// --- Global Control Handlers ---

window.toggleGlobalCurrencyMenu = function (e) {
  e.stopPropagation();
  const menu = document.getElementById('globalCurrencyMenu');
  menu.classList.toggle('hidden');
  if (!menu.classList.contains('hidden')) {
    document.getElementById('globalCurrencySearch').focus();
    renderGlobalCurrencyList("");
  }
}

window.renderGlobalCurrencyList = function (filter = "") {
  const list = document.getElementById('globalCurrencyList');
  if (!list) return;
  list.innerHTML = "";

  const filtered = CURRENCIES.filter(c =>
    c.n.toLowerCase().includes(filter.toLowerCase()) ||
    c.c.toLowerCase().includes(filter.toLowerCase())
  );

  filtered.forEach(c => {
    const div = document.createElement('div');
    div.className = "px-4 py-3 hover:bg-orange-50 cursor-pointer flex items-center justify-between border-b border-gray-100 last:border-0 transition-colors";
    div.innerHTML = `
        <div class="flex items-center gap-3">
          <span class="fi fi-${c.i} rounded-sm shadow-sm w-5 h-4 scale-90"></span>
          <span class="text-xs font-bold text-black">${c.n}</span>
        </div>
        <span class="text-[10px] font-black text-orange-600 bg-orange-50 px-2 py-1 rounded-md border border-orange-100">${c.s}</span>
      `;
    div.onclick = (e) => {
      e.stopPropagation();
      activeCurrencyCode = c.c;
      activeCurrencySymbol = c.s;

      // Update UI Display
      document.getElementById('globalCurrencyDisplay').innerHTML = `
          <span class="fi fi-${c.i} rounded-sm shadow-sm scale-90"></span> 
          <span>${c.c} (${c.s})</span>
        `;

      // Update price indicators globally
      document.querySelectorAll('.credit-unit-indicator').forEach(el => el.innerText = c.s);
      document.getElementById('discountCurrencySymbol').innerText = c.s;

      // Update any existing price-input-symbol in generic items
      document.querySelectorAll('.price-input-symbol').forEach(el => el.innerText = c.s);
      document.querySelectorAll('.price-menu-icon').forEach(el => el.innerText = c.s);
      document.querySelectorAll('.discount-flat-symbol').forEach(el => el.innerText = c.s);
      document.querySelectorAll('.labor-currency-symbol').forEach(el => el.innerText = c.s);

      document.getElementById('globalCurrencyMenu').classList.add('hidden');

      // Force update all badges/labels
      document.querySelectorAll('.item-row').forEach(row => updateBadge(row));
      updateTotalsSummary();
    };
    list.appendChild(div);
  });
}

// Close menus when clicking outside
document.addEventListener('click', (e) => {
  // Global Currency Menu
  const menu = document.getElementById('globalCurrencyMenu');
  if (menu && !e.target.closest('#globalCurrencyBtn') && !e.target.closest('#globalCurrencyMenu')) {
    menu.classList.add('hidden');
  }

  // Language Menu
  const langMenu = document.getElementById('languageMenu');
  if (langMenu && !e.target.closest('#languageSelectorBtn') && !e.target.closest('#languageMenu')) {
    langMenu.classList.add('hidden');
    document.getElementById('langChevron')?.classList.remove('rotate-180');
  }

  // PDF Selectors in Modal
  if (!e.target.closest('#pdfStatusBadge') && !e.target.closest('#pdfStatusDropdown') &&
    !e.target.closest('#pdfCategoryBadge') && !e.target.closest('#pdfCategoryDropdown')) {
    if (typeof closeAllPdfSelectors === 'function') closeAllPdfSelectors();
  }
});

// --- Language Selector Logic ---
window.setTranscriptLanguage = function (lang) {
  const normalizedLang = lang === 'ka' ? 'ge' : lang;
  localStorage.setItem('transcriptLanguage', normalizedLang);
  updateLanguageUI(normalizedLang);
  document.getElementById('languageMenu')?.classList.add('hidden');
  document.getElementById('langChevron')?.classList.remove('rotate-180');

  // Restart live recognition with new language if currently active
  if (window.liveRecognition) {
    const targetInput = document.getElementById('mainTranscript');
    try { window.liveRecognition.stop(); } catch (e) { }
    window.liveRecognition = null;
    if (targetInput) startLiveTranscription(targetInput);
  }

  // Sync with server (document_language) to prevent flickering on reload
  fetch('/set_transcript_language?language=' + normalizedLang, {
    method: 'POST',
    headers: { 'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content }
  });
};

function updateLanguageUI(lang) {
  const normalizedLang = lang === 'ka' ? 'ge' : lang;
  const flag = document.getElementById('currentLangFlag');
  const text = document.getElementById('currentLangText');
  const checkEn = document.getElementById('check-en');
  const checkGe = document.getElementById('check-ge');

  if (normalizedLang === 'ge') {
    if (flag) flag.className = 'fi fi-ge scale-90 rounded-sm';
    // Use localized string from server (window.APP_LANGUAGES.ka)
    if (text) text.innerText = window.APP_LANGUAGES.ka;
    checkEn?.classList.add('hidden');
    checkGe?.classList.remove('hidden');
  } else {
    if (flag) flag.className = 'fi fi-us scale-90 rounded-sm';
    // Use localized string from server (window.APP_LANGUAGES.en)
    if (text) text.innerText = window.APP_LANGUAGES.en;
    checkEn?.classList.remove('hidden');
    checkGe?.classList.add('hidden');
  }
}

// Inlined DOMContentLoaded logic for language
document.addEventListener('DOMContentLoaded', () => {
  const savedLang = localStorage.getItem('transcriptLanguage') || window.profileSystemLanguage || 'en';
  updateLanguageUI(savedLang);

  const langBtn = document.getElementById('languageSelectorBtn');
  if (langBtn) {
    langBtn.onclick = (e) => {
      e.stopPropagation();
      const menu = document.getElementById('languageMenu');
      const isHidden = menu?.classList.contains('hidden');
      menu?.classList.toggle('hidden');
      document.getElementById('langChevron')?.classList.toggle('rotate-180', isHidden);
    };
  }
});

// PDF Modal Selectors
window.togglePdfStatusSelector = function (btn, e) {
  if (e) e.stopPropagation();
  const dropdown = document.getElementById('pdfStatusDropdown');
  const isVisible = dropdown.classList.contains('active');
  closeAllPdfSelectors();
  if (!isVisible) {
    dropdown.classList.add('active');
    btn.querySelector('.status-chevron').classList.add('rotate-180');
  }
};

window.setPdfStatus = function (status) {
  const input = document.getElementById('pdfLogStatus');
  const badge = document.getElementById('pdfStatusBadge');
  const dot = badge.querySelector('div');
  const text = document.getElementById('pdfStatusText');

  if (!input || !badge || !dot || !text) return;

  input.value = status;
  text.innerText = window.APP_LANGUAGES[status] || (status.charAt(0).toUpperCase() + status.slice(1));

  // Reset classes
  badge.className = "flex items-center gap-1.5 px-3.5 py-1.5 border-2 rounded-lg text-[10px] font-black uppercase tracking-widest transition-all shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] active:translate-x-[1px] active:translate-y-[1px] active:shadow-none";
  dot.className = "w-1.5 h-1.5 rounded-full";

  if (status === 'draft') {
    badge.classList.add('bg-gray-50', 'border-gray-300', 'text-gray-500');
    dot.classList.add('bg-gray-500');
  } else if (status === 'sent') {
    badge.classList.add('bg-blue-50', 'border-blue-400', 'text-blue-600');
    dot.classList.add('bg-blue-600');
  } else if (status === 'paid') {
    badge.classList.add('bg-green-50', 'border-green-400', 'text-green-600');
    dot.classList.add('bg-green-600');
  }

  closeAllPdfSelectors();
};

window.togglePdfCategorySelector = function (btn, e) {
  if (e) e.stopPropagation();
  const dropdown = document.getElementById('pdfCategoryDropdown');
  const isVisible = dropdown.classList.contains('active');
  closeAllPdfSelectors();
  if (!isVisible) {
    dropdown.classList.add('active');
    btn.querySelector('.status-chevron').classList.add('rotate-180');
  }
};

window.setPdfCategory = function (id, name, color, icon = '', iconType = '', customUrl = '') {
  const input = document.getElementById('pdfLogCategory');
  const badge = document.getElementById('pdfCategoryBadge');
  const text = document.getElementById('pdfCategoryText');
  const iconSpan = document.getElementById('pdfCategoryIcon');

  if (!input || !badge || !text || !iconSpan) return;

  input.value = id;
  text.innerText = name;

  if (id === '') {
    badge.style.borderColor = 'black';
    badge.style.color = 'black';
    iconSpan.innerHTML = '';
    iconSpan.classList.add('hidden');
    text.classList.add('text-gray-400');
    text.classList.remove('italic');
  } else {
    badge.style.borderColor = color;
    badge.style.color = color;
    text.classList.remove('italic', 'text-gray-400');
    iconSpan.classList.remove('hidden');

    // Update icon display by cloning if via click, or fallback
    if (window.event && window.event.currentTarget && window.event.currentTarget.querySelector('.w-6')) {
      const srcIcon = window.event.currentTarget.querySelector('.w-6');
      iconSpan.innerHTML = srcIcon.innerHTML;
      const svg = iconSpan.querySelector('svg');
      if (svg) { svg.classList.remove('h-3', 'w-3'); svg.classList.add('h-3.5', 'w-3.5'); }
      const img = iconSpan.querySelector('img');
      if (img) { img.classList.remove('w-3', 'h-3'); img.classList.add('w-3.5', 'h-3.5'); }
    } else {
      // Direct set (e.g. from setupSaveButton)
      if (iconType === 'custom' && customUrl) {
        iconSpan.innerHTML = `<img src="${customUrl}" class="w-3.5 h-3.5 object-cover rounded-sm">`;
      } else if (icon) {
        // We'd need to rebuild the SVG here or just leave blank until interactive
        // For now, let's just use a simple dot if direct set happens (rare for reset)
        iconSpan.innerHTML = `<div class="w-1.5 h-1.5 rounded-full" style="background-color: ${color}"></div>`;
      }
    }
  }
  closeAllPdfSelectors();
};

window.closeAllPdfSelectors = function () {
  const drops = document.querySelectorAll('.pdf-selector-dropdown');
  drops.forEach(d => d.classList.remove('active'));
  const arrows = document.querySelectorAll('#pdfModalContent .status-chevron');
  arrows.forEach(c => c.classList.remove('rotate-180'));
};

window.setGlobalBillingMode = function (mode) {
  if (!mode) return;
  const modeLower = mode.toLowerCase();
  currentLogBillingMode = modeLower;

  // Update Button UI
  const hourlyBtn = document.getElementById('billingModelHourly');
  const fixedBtn = document.getElementById('billingModelFixed');
  const mixedBtn = document.getElementById('billingModelMixed');

  const shadowClass = 'shadow-[3px_3px_0px_0px_rgba(0,0,0,1)]';
  const inactiveClasses = ['bg-white', 'text-black', 'hover:bg-orange-50', shadowClass];
  const activeClasses = ['bg-orange-600', 'text-white', 'shadow-none', 'translate-x-[2px]', 'translate-y-[2px]'];
  const translateInactive = ['translate-x-0', 'translate-y-0'];

  [hourlyBtn, fixedBtn, mixedBtn].forEach(btn => {
    if (btn) {
      btn.classList.remove(...activeClasses);
      btn.classList.add(...inactiveClasses, ...translateInactive);
    }
  });

  let targetBtn = null;
  if (modeLower === 'hourly') targetBtn = hourlyBtn;
  else if (modeLower === 'fixed') targetBtn = fixedBtn;
  else if (modeLower === 'mixed') targetBtn = mixedBtn;

  if (targetBtn) {
    targetBtn.classList.remove(...inactiveClasses, ...translateInactive);
    targetBtn.classList.add(...activeClasses);

    const laborRows = document.querySelectorAll('.labor-item-row');

    if (modeLower !== 'mixed') {
      updateAllLaborRowsMode(modeLower);
    } else {
      // --- SMART MIXED LOGIC ---
      if (laborRows.length === 1) {
        // If only 1 exists, add a 2nd one with the opposite model
        const currentMode = laborRows[0].dataset.billingMode || 'hourly';
        const oppositeMode = (currentMode === 'hourly' ? 'fixed' : 'hourly');
        addLaborItem('', '', oppositeMode);
      } else if (laborRows.length >= 2) {
        // If 2 or more exist, ensure they alternate
        laborRows.forEach((row, index) => {
          if (index === 0) return; // Keep first one as is
          const prevMode = laborRows[index - 1].dataset.billingMode || 'hourly';
          const nextMode = (prevMode === 'hourly' ? 'fixed' : 'hourly');
          updateLaborRowModelUI(row, nextMode);
        });
      }
    }
  }

  updateTotalsSummary();
}

window.setGlobalTaxRule = function (rule) {
  if (!rule) return;
  currentLogDiscountTaxRule = rule;
  updateTotalsSummary();
}



function updateAllLaborRowsMode(forceMode) {
  document.querySelectorAll('.labor-item-row').forEach(row => {
    let mode = forceMode || row.dataset.billingMode || currentLogBillingMode || 'hourly';
    if (mode === 'mixed') mode = 'hourly'; // Individual rows cannot be 'mixed'
    updateLaborRowModelUI(row, mode);
  });
}

function updateLaborRowModelUI(row, mode) {
  const oldMode = row.dataset.billingMode || 'hourly';
  row.dataset.billingMode = mode;
  const labelText = mode === 'hourly' ? (window.APP_LANGUAGES?.labor_hours_caps || 'LABOR HOURS') : (window.APP_LANGUAGES?.labor_price_caps || 'LABOR PRICE');
  const rateLabel = window.APP_LANGUAGES?.rate || 'RATE';

  const target = row.querySelector('.labor-inputs-target');
  if (!target) return;

  const currencySymbol = activeCurrencySymbol;
  const defaultRate = profileHourlyRate;

  // Get old values
  const oldPriceInput = target.querySelector('.labor-price-input');
  const oldPriceStr = oldPriceInput ? oldPriceInput.value : "";
  const oldPrice = parseFloat(oldPriceStr) || 0;

  const oldRateInput = target.querySelector('.rate-menu-input');
  const oldRate = oldRateInput ? parseFloat(oldRateInput.value) : defaultRate;

  let newPriceValue = "";
  let newRateValue = "";

  if (oldMode === mode) {
    newPriceValue = oldPriceStr;
    newRateValue = oldRateInput ? oldRateInput.value : defaultRate;
  } else if (oldMode === 'fixed' && mode === 'hourly') {
    newPriceValue = "1";
    newRateValue = cleanNum(oldPrice) || defaultRate;
  } else if (oldMode === 'hourly' && mode === 'fixed') {
    newPriceValue = cleanNum(oldPrice * oldRate);
    newRateValue = defaultRate;
  } else {
    newPriceValue = oldPriceStr;
    newRateValue = oldRate || defaultRate;
  }

  // Preserve tax value before removing price group
  const oldPriceGroup = target.querySelector('.labor-price-group');
  const oldTaxWrapper = oldPriceGroup ? oldPriceGroup.querySelector('.labor-tax-wrapper') : null;
  const oldTaxInput = oldTaxWrapper ? oldTaxWrapper.querySelector('.tax-menu-input') : null;
  const taxVal = oldTaxInput ? oldTaxInput.value : '';
  if (oldPriceGroup) oldPriceGroup.remove();

  const taxLabel = window.APP_LANGUAGES?.tax || 'TAX';

  // Build new price group (includes tax on same row)
  const discountGroup = target.querySelector('.labor-discount-group');
  const frag = document.createRange().createContextualFragment(
    mode === 'hourly' ? `
      <div class="flex flex-col labor-price-group">
        <div class="flex items-start gap-2">
          <div class="flex flex-col">
            <span class="text-[8px] font-black text-black uppercase tracking-wider ml-2 mb-0.5 labor-label-price">${labelText}</span>
            <div class="flex items-center gap-1.5 px-2.5 h-10 border-2 border-black bg-white rounded-xl labor-price-container">
              <div class="flex items-center justify-center bg-orange-600 text-white border-2 border-black rounded-lg h-6 w-6 shrink-0 select-none">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="3">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
              <input type="number" step="0.1" class="labor-price-input bg-transparent border-none p-0 font-black text-black focus:ring-0 outline-none text-left min-w-0 text-sm placeholder:text-gray-300 w-9" 
                     value="${newPriceValue}" placeholder="0" oninput="updateTotalsSummary()">
            </div>
          </div>
          <div class="flex flex-col" style="margin-left: -1px; margin-right: -2px;">
            <div class="text-[8px] mb-0.5">&nbsp;</div>
            <div class="flex items-center h-10">
              <span class="text-black font-black text-sm select-none">×</span>
            </div>
          </div>
          <div class="flex flex-col">
            <span class="text-[8px] font-black text-black uppercase tracking-wider ml-2 mb-0.5">${rateLabel}</span>
            <div class="flex items-center gap-1.5 px-2.5 h-10 border-2 border-black bg-white rounded-xl labor-rate-container">
              <div class="flex items-center justify-center bg-orange-600 text-white font-black border-2 border-black rounded-lg h-6 w-6 shrink-0 select-none text-[10px] labor-currency-symbol">
                ${currencySymbol}
              </div>
              <input type="number" step="0.01" class="rate-menu-input bg-transparent border-none p-0 font-black text-black focus:ring-0 outline-none text-left min-w-0 text-sm placeholder:text-gray-300 w-12" 
                     value="${newRateValue}" placeholder="0.00" oninput="updateTotalsSummary()">
            </div>
          </div>
          <div class="flex flex-col labor-tax-wrapper">
            <span class="text-[8px] font-black text-black uppercase tracking-wider ml-2 mb-0.5">${taxLabel}</span>
            <div class="flex items-center gap-1.5 px-2.5 h-10 border-2 border-black rounded-xl tax-wrapper" style="background-color: white;">
              <div class="flex items-center justify-center bg-gray-700 text-white font-black border-2 border-black rounded-lg h-6 w-6 shrink-0 select-none text-[10px]">
                <span>%</span>
              </div>
              <input type="number" step="0.1" class="tax-menu-input bg-transparent border-none p-0 font-black text-black focus:ring-0 outline-none text-left min-w-0 text-sm placeholder:text-gray-300 w-9"
                     value="${taxVal}" placeholder="0" oninput="updateTotalsSummary()">
            </div>
          </div>
        </div>
      </div>
    ` : `
      <div class="flex flex-col labor-price-group">
        <div class="flex items-start gap-2">
          <div class="flex flex-col">
            <span class="text-[8px] font-black text-black uppercase tracking-wider ml-2 mb-0.5 labor-label-price">${labelText}</span>
            <div class="flex items-center gap-1.5 px-2.5 h-10 border-2 border-black bg-white rounded-xl labor-price-container">
              <div class="flex items-center justify-center bg-orange-600 text-white font-black border-2 border-black rounded-lg h-6 w-6 shrink-0 select-none text-[10px] labor-currency-symbol">
                ${currencySymbol}
              </div>
              <input type="number" step="0.01" class="labor-price-input bg-transparent border-none p-0 font-black text-black focus:ring-0 outline-none text-left min-w-0 text-sm placeholder:text-gray-300 w-20" 
                     value="${newPriceValue}" placeholder="0.00" oninput="updateTotalsSummary()">
            </div>
          </div>
          <div class="flex flex-col labor-tax-wrapper">
            <span class="text-[8px] font-black text-black uppercase tracking-wider ml-2 mb-0.5">${taxLabel}</span>
            <div class="flex items-center gap-1.5 px-2.5 h-10 border-2 border-black rounded-xl tax-wrapper" style="background-color: white;">
              <div class="flex items-center justify-center bg-gray-700 text-white font-black border-2 border-black rounded-lg h-6 w-6 shrink-0 select-none text-[10px]">
                <span>%</span>
              </div>
              <input type="number" step="0.1" class="tax-menu-input bg-transparent border-none p-0 font-black text-black focus:ring-0 outline-none text-left min-w-0 text-sm placeholder:text-gray-300 w-9"
                     value="${taxVal}" placeholder="0" oninput="updateTotalsSummary()">
            </div>
          </div>
        </div>
      </div>
    `
  );

  // Insert before discount group
  if (discountGroup) {
    target.insertBefore(frag, discountGroup);
  } else {
    target.prepend(frag);
  }

  // Update the toggle pills
  const pills = row.querySelectorAll('.billing-pill-btn');
  pills.forEach(btn => {
    btn.classList.toggle('active', btn.dataset.mode === mode);
  });
}

window.setLaborRowBillingMode = function (btn, mode) {
  const row = btn.closest('.labor-item-row');
  if (!row) return;
  updateLaborRowModelUI(row, mode);
  updateTotalsSummary();
}

function setLaborDiscountButtonState(btn, active) {
  if (!btn) return;
  if (active) {
    btn.style.backgroundColor = '#00A63E';
    btn.style.borderColor = '#00A63E';
    btn.style.color = 'white';
  } else {
    btn.style.backgroundColor = 'white';
    btn.style.borderColor = '#00A63E';
    btn.style.color = '#00A63E';
  }
}

function laborDiscountIsActive(row) {
  if (!row) return false;
  const pctWrap = row.querySelector('.labor-discount-percent-wrapper');
  const flatWrap = row.querySelector('.labor-discount-flat-wrapper');
  const pctVisible = pctWrap && !pctWrap.classList.contains('hidden');
  const flatVisible = flatWrap && !flatWrap.classList.contains('hidden');
  const pctVal = parseFloat(row.querySelector('.discount-percent-input')?.value) || 0;
  const flatVal = parseFloat(row.querySelector('.discount-flat-input')?.value) || 0;
  return pctVisible || flatVisible || pctVal > 0 || flatVal > 0;
}

window.toggleLaborDiscountDropdown = function (btn) {
  const row = btn.closest('.labor-item-row');
  const dropdown = btn.parentElement.querySelector('.labor-discount-dropdown');
  if (!dropdown) return;
  const isOpening = dropdown.classList.contains('hidden');
  dropdown.classList.toggle('hidden');

  if (isOpening) {
    setLaborDiscountButtonState(btn, true);
  } else if (!laborDiscountIsActive(row)) {
    setLaborDiscountButtonState(btn, false);
  }

  // Close on outside click
  if (!dropdown.classList.contains('hidden')) {
    const close = (e) => {
      if (!btn.parentElement.contains(e.target)) {
        dropdown.classList.add('hidden');
        if (!laborDiscountIsActive(row)) {
          setLaborDiscountButtonState(btn, false);
        }
        document.removeEventListener('click', close);
      }
    };
    setTimeout(() => document.addEventListener('click', close), 0);
  }
}

window.showLaborDiscount = function (btn, type) {
  const row = btn.closest('.labor-item-row');
  if (!row) return;

  // Close dropdown
  const dropdown = btn.closest('.labor-discount-dropdown');
  if (dropdown) dropdown.classList.add('hidden');

  if (type === 'percent') {
    // Hide flat, clear its value
    const flatWrapper = row.querySelector('.labor-discount-flat-wrapper');
    if (flatWrapper) {
      flatWrapper.classList.add('hidden');
      const flatInput = flatWrapper.querySelector('.discount-flat-input');
      if (flatInput) flatInput.value = '';
    }
    const wrapper = row.querySelector('.labor-discount-percent-wrapper');
    if (wrapper) wrapper.classList.remove('hidden');
  } else if (type === 'flat') {
    // Hide percent, clear its value
    const pctWrapper = row.querySelector('.labor-discount-percent-wrapper');
    if (pctWrapper) {
      pctWrapper.classList.add('hidden');
      const pctInput = pctWrapper.querySelector('.discount-percent-input');
      if (pctInput) pctInput.value = '';
    }
    const wrapper = row.querySelector('.labor-discount-flat-wrapper');
    if (wrapper) wrapper.classList.remove('hidden');
  }
  // Set discount button to active state
  const discBtn = row.querySelector('.labor-add-discount-btn');
  setLaborDiscountButtonState(discBtn, true);
  updateTotalsSummary();
}

window.removeLaborDiscount = function (btn, type) {
  const row = btn.closest('.labor-item-row');
  if (!row) return;

  if (type === 'percent') {
    const wrapper = row.querySelector('.labor-discount-percent-wrapper');
    if (wrapper) {
      wrapper.classList.add('hidden');
      const input = wrapper.querySelector('.discount-percent-input');
      if (input) input.value = '';
    }
  } else if (type === 'flat') {
    const wrapper = row.querySelector('.labor-discount-flat-wrapper');
    if (wrapper) {
      wrapper.classList.add('hidden');
      const input = wrapper.querySelector('.discount-flat-input');
      if (input) input.value = '';
    }
  }
  // Check if any discount is still visible, if not reset button
  const pctVisible = row.querySelector('.labor-discount-percent-wrapper') && !row.querySelector('.labor-discount-percent-wrapper').classList.contains('hidden');
  const flatVisible = row.querySelector('.labor-discount-flat-wrapper') && !row.querySelector('.labor-discount-flat-wrapper').classList.contains('hidden');
  if (!pctVisible && !flatVisible) {
    const discBtn = row.querySelector('.labor-add-discount-btn');
    setLaborDiscountButtonState(discBtn, false);
  }
  updateTotalsSummary();
}

// === ITEM (Products/Reimbursements/Fees) Tax & Discount Functions ===

function setItemDiscountButtonState(btn, active) {
  if (!btn) return;
  if (active) {
    btn.style.backgroundColor = '#00A63E';
    btn.style.borderColor = '#00A63E';
    btn.style.color = 'white';
  } else {
    btn.style.backgroundColor = 'white';
    btn.style.borderColor = '#00A63E';
    btn.style.color = '#00A63E';
  }
}

function setItemPriceButtonState(btn, active) {
  if (!btn) return;
  if (active) {
    btn.style.backgroundColor = '#EA580C';
    btn.style.borderColor = '#EA580C';
    btn.style.color = 'white';
  } else {
    btn.style.backgroundColor = 'white';
    btn.style.borderColor = '#EA580C';
    btn.style.color = '#EA580C';
  }
}

function isProductsExpensesFeesTaxScope(scopeValue, sectionType = "") {
  const scopeTokens = (scopeValue || "")
    .toLowerCase()
    .split(',')
    .map(t => t.trim())
    .filter(Boolean);

  if (scopeTokens.length === 0) return false;

  const hasProducts = scopeTokens.some(t => t.includes('material') || t.includes('part') || t.includes('product'));
  const hasExpenses = scopeTokens.some(t => t.includes('expense') || t.includes('reimburse'));
  const hasFees = scopeTokens.some(t => t.includes('fee') || t.includes('surcharge'));
  const isAllScope = scopeTokens.some(t => t === 'total' || t === 'all') || scopeTokens.length >= 4;

  if (isAllScope) return true;

  const normalizedSection = (sectionType || "").toLowerCase();
  if (normalizedSection === 'materials') return hasProducts;
  if (normalizedSection === 'expenses') return hasExpenses;
  if (normalizedSection === 'fees') return hasFees;

  return false;
}

function applyItemAddPriceDefaults(row) {
  if (!row || row.dataset.priceToggleEligible !== 'true') return;

  const sectionType = row.closest('.dynamic-section')?.dataset?.protected || '';
  if (!isProductsExpensesFeesTaxScope(currentLogTaxScope, sectionType)) return;

  const priceInput = row.querySelector('.price-menu-input');
  if (priceInput) {
    const currentPrice = parseFloat(priceInput.value);
    if (priceInput.value === '' || isNaN(currentPrice) || currentPrice === 0) {
      priceInput.value = '50';
    }
  }

  const taxInput = row.querySelector('.tax-menu-input');
  if (!taxInput) return;

  const defaultTaxRate = parseFloat(profileTaxRate);
  if (isNaN(defaultTaxRate) || defaultTaxRate <= 0) return;

  const currentTaxRaw = String(taxInput.value || '').trim();
  const currentTax = parseFloat(currentTaxRaw);
  if (currentTaxRaw === '' || isNaN(currentTax) || currentTax === 0) {
    taxInput.value = cleanNum(defaultTaxRate);
  }
}

function setItemPriceActive(row, active, options = {}) {
  if (!row) return;

  const clearValues = options.clearValues !== false;
  const suppressTotals = options.suppressTotals === true;

  row.dataset.priceActive = active ? 'true' : 'false';

  const priceBtn = row.querySelector('.item-add-price-btn');
  const priceWrapper = row.querySelector('.item-price-wrapper');
  const taxWrapper = row.querySelector('.item-tax-wrapper');
  const qtyWrapper = row.querySelector('.item-qty-wrapper');
  const discountWrap = row.querySelector('.item-add-discount-wrap');
  const discountGroup = row.querySelector('.item-discount-group');

  if (priceWrapper) priceWrapper.classList.toggle('hidden', !active);
  if (taxWrapper) taxWrapper.classList.toggle('hidden', !active);
  if (qtyWrapper) qtyWrapper.classList.toggle('hidden', !active);
  if (discountWrap) discountWrap.classList.toggle('hidden', !active);
  if (discountGroup) discountGroup.classList.toggle('hidden', !active);

  if (active) {
    applyItemAddPriceDefaults(row);
  }

  if (!active && clearValues) {
    const priceInput = row.querySelector('.price-menu-input');
    const taxInput = row.querySelector('.tax-menu-input');
    const qtyInput = row.querySelector('.qty-input');
    if (priceInput) priceInput.value = '';
    if (taxInput) taxInput.value = '';
    if (qtyInput) qtyInput.value = '1';
    row.dataset.qty = '1';

    const pctWrap = row.querySelector('.item-discount-percent-wrapper');
    const flatWrap = row.querySelector('.item-discount-flat-wrapper');
    if (pctWrap) {
      pctWrap.classList.add('hidden');
      const pctInput = pctWrap.querySelector('.discount-percent-input');
      if (pctInput) pctInput.value = '';
    }
    if (flatWrap) {
      flatWrap.classList.add('hidden');
      const flatInput = flatWrap.querySelector('.discount-flat-input');
      if (flatInput) flatInput.value = '';
    }

    const dropdown = row.querySelector('.item-discount-dropdown');
    if (dropdown) dropdown.classList.add('hidden');

    setItemDiscountButtonState(row.querySelector('.item-add-discount-btn'), false);
  }

  setItemPriceButtonState(priceBtn, active);

  if (!suppressTotals) {
    updateTotalsSummary();
  }
}

window.toggleItemPrice = function (btn) {
  const row = btn.closest('.item-row');
  if (!row || row.dataset.priceToggleEligible !== 'true') return;

  const isActive = row.dataset.priceActive === 'true';
  setItemPriceActive(row, !isActive);
}

window.toggleItemDiscountDropdown = function (btn) {
  const dropdown = btn.parentElement.querySelector('.item-discount-dropdown');
  if (!dropdown) return;
  const isHidden = dropdown.classList.contains('hidden');
  // Close all other item discount dropdowns
  document.querySelectorAll('.item-discount-dropdown').forEach(d => d.classList.add('hidden'));
  if (isHidden) {
    dropdown.classList.remove('hidden');
    const close = (e) => {
      if (!dropdown.contains(e.target) && !btn.contains(e.target)) {
        dropdown.classList.add('hidden');
        document.removeEventListener('click', close);
      }
    };
    setTimeout(() => document.addEventListener('click', close), 0);
  }
}

window.showItemDiscount = function (btn, type) {
  const row = btn.closest('.item-row');
  if (!row) return;
  const dropdown = btn.closest('.item-discount-dropdown');
  if (dropdown) dropdown.classList.add('hidden');

  if (type === 'percent') {
    const flatWrapper = row.querySelector('.item-discount-flat-wrapper');
    if (flatWrapper) {
      flatWrapper.classList.add('hidden');
      const flatInput = flatWrapper.querySelector('.discount-flat-input');
      if (flatInput) flatInput.value = '';
    }
    const wrapper = row.querySelector('.item-discount-percent-wrapper');
    if (wrapper) wrapper.classList.remove('hidden');
  } else if (type === 'flat') {
    const pctWrapper = row.querySelector('.item-discount-percent-wrapper');
    if (pctWrapper) {
      pctWrapper.classList.add('hidden');
      const pctInput = pctWrapper.querySelector('.discount-percent-input');
      if (pctInput) pctInput.value = '';
    }
    const wrapper = row.querySelector('.item-discount-flat-wrapper');
    if (wrapper) wrapper.classList.remove('hidden');
  }
  // Set discount button to active state
  const discBtn = row.querySelector('.item-add-discount-btn');
  setItemDiscountButtonState(discBtn, true);
  updateTotalsSummary();
}

window.removeItemDiscount = function (btn, type) {
  const row = btn.closest('.item-row');
  if (!row) return;

  if (type === 'percent') {
    const wrapper = row.querySelector('.item-discount-percent-wrapper');
    if (wrapper) {
      wrapper.classList.add('hidden');
      const input = wrapper.querySelector('.discount-percent-input');
      if (input) input.value = '';
    }
  } else if (type === 'flat') {
    const wrapper = row.querySelector('.item-discount-flat-wrapper');
    if (wrapper) {
      wrapper.classList.add('hidden');
      const input = wrapper.querySelector('.discount-flat-input');
      if (input) input.value = '';
    }
  }
  // Check if any discount is still visible, if not reset button
  const pctVisible = row.querySelector('.item-discount-percent-wrapper') && !row.querySelector('.item-discount-percent-wrapper').classList.contains('hidden');
  const flatVisible = row.querySelector('.item-discount-flat-wrapper') && !row.querySelector('.item-discount-flat-wrapper').classList.contains('hidden');
  if (!pctVisible && !flatVisible) {
    const discBtn = row.querySelector('.item-add-discount-btn');
    setItemDiscountButtonState(discBtn, false);
  }
  updateTotalsSummary();
}

function updateTotalsSummary() {
  try {
    let itemsGrossTotal = 0;
    let totalItemDiscounts = 0;
    let totalTax = 0;
    let invoiceDiscount = 0;
    let totalCredit = 0;

    const allItemPrices = []; // For Items Total breakdown
    const allItemDiscountsList = []; // For Item Discounts breakdown
    const allTaxesList = []; // For Tax breakdown
    const allCreditsList = []; // For Credit breakdown

    // Auto-detect Global Billing Mode
    const allLaborRows = document.querySelectorAll('.labor-item-row');
    const laborModes = Array.from(allLaborRows).map(row => row.dataset.billingMode || 'hourly');
    if (laborModes.length > 0) {
      const uniqueModes = [...new Set(laborModes)];
      let detectedMode = 'mixed';
      if (uniqueModes.length === 1) detectedMode = uniqueModes[0];

      if (currentLogBillingMode !== detectedMode) {
        currentLogBillingMode = detectedMode;
        const bts = ['Hourly', 'Fixed', 'Mixed'];
        bts.forEach(m => {
          const btn = document.getElementById('billingModel' + m);
          if (btn) {
            const isActive = m.toLowerCase() === detectedMode;
            btn.classList.toggle('bg-orange-600', isActive);
            btn.classList.toggle('text-white', isActive);
            btn.classList.toggle('bg-white', !isActive);
            btn.classList.toggle('text-black', !isActive);
            btn.classList.toggle('shadow-none', isActive);
            btn.classList.toggle('translate-x-[2px]', isActive);
            btn.classList.toggle('translate-y-[2px]', isActive);
            btn.classList.toggle('shadow-[3px_3px_0px_0px_rgba(0,0,0,1)]', !isActive);
          }
        });
      }
    }

    // 1. Calculate Post-Tax Credits
    const creditGroup = document.getElementById('creditGroup');
    if (creditGroup && !creditGroup.classList.contains('hidden')) {
      document.querySelectorAll('.credit-item-row').forEach(row => {
        const val = parseFloat(row.querySelector('.credit-amount-input').value) || 0;
        const rawReason = row.querySelector('.credit-reason-input').value;
        const reason = rawReason || (window.APP_LANGUAGES?.courtesy_credit || "Courtesy Credit");
        if (val > 0) {
          totalCredit += val;
          allCreditsList.push({ name: reason, amount: val });
        }
      });
    }

    // 2. Process Labor/Service Items
    const laborItemsContainer = document.getElementById('laborItemsContainer');
    const laborGroup = document.getElementById('laborGroup');
    if (laborItemsContainer && (!laborGroup || !laborGroup.classList.contains('hidden'))) {
      laborItemsContainer.querySelectorAll('.labor-item-row').forEach(item => {
        const priceVal = parseFloat(item.querySelector('.labor-price-input')?.value) || 0;
        let itemMode = item.dataset.billingMode || currentLogBillingMode || 'hourly';
        if (itemMode === 'mixed') itemMode = 'hourly';

        let rowGross = priceVal;
        if (itemMode === 'hourly') {
          const rateVal = parseFloat(item.querySelector('.rate-menu-input')?.value) || 0;
          rowGross = priceVal * rateVal;
        }

        const laborPctWrapper = item.querySelector('.labor-discount-percent-wrapper');
        const laborFlatWrapper = item.querySelector('.labor-discount-flat-wrapper');
        const laborPctVisible = laborPctWrapper && !laborPctWrapper.classList.contains('hidden');
        const laborFlatVisible = laborFlatWrapper && !laborFlatWrapper.classList.contains('hidden');
        // MUTUALLY EXCLUSIVE: only use the visible discount type
        let discPercent = laborPctVisible ? (parseFloat(item.querySelector('.discount-percent-input')?.value) || 0) : 0;
        let discFlat = laborFlatVisible ? (parseFloat(item.querySelector('.discount-flat-input')?.value) || 0) : 0;
        // Cap values + visual clamp (only during manual edits, not auto-update)
        if (discPercent > 100) {
          discPercent = 100;
          if (!window.isAutoUpdating) { const pctIn = item.querySelector('.discount-percent-input'); if (pctIn) pctIn.value = '100'; }
        }
        if (rowGross > 0 && discFlat > rowGross) {
          discFlat = rowGross;
          if (!window.isAutoUpdating) { const flatIn = item.querySelector('.discount-flat-input'); if (flatIn) flatIn.value = cleanNum(rowGross); }
        }
        const laborDiscBtn = item.querySelector('.labor-add-discount-btn');
        if (laborDiscBtn) {
          const isLaborDiscountActive = discFlat > 0 || discPercent > 0;
          setLaborDiscountButtonState(laborDiscBtn, isLaborDiscountActive || laborPctVisible || laborFlatVisible);
        }

        // Discount logic — only one type active at a time
        const rowDisc = Math.min(rowGross, discFlat + (rowGross * (discPercent / 100)));
        const rowNet = Math.max(0, rowGross - rowDisc);

        const desc = (item.querySelector('.labor-item-input')?.value || '').trim() || 'Labor';

        if (rowGross > 0) {
          itemsGrossTotal += rowGross;
          allItemPrices.push({ name: desc, amount: rowGross });
        }
        if (rowDisc > 0) {
          totalItemDiscounts += rowDisc;
          allItemDiscountsList.push({ name: desc, amount: rowDisc, percent: discPercent });
        }

        // Tax calculation — taxable if tax input is not empty and not 0
        let rowTax = 0;
        const taxRateInput = item.querySelector('.tax-menu-input');
        const taxRateVal = taxRateInput ? (parseFloat(taxRateInput.value) || 0) : 0;
        const isTaxable = taxRateVal > 0;
        item.dataset.taxable = isTaxable ? 'true' : 'false';
        if (isTaxable) {
          rowTax = rowNet * (taxRateVal / 100);
          if (rowTax > 0) {
            totalTax += rowTax;
            allTaxesList.push({ name: desc, amount: rowTax, rate: taxRateVal });
          }
        }
      });
    }

    // 3. Process Dynamic Section Items
    document.querySelectorAll('.dynamic-section .item-row').forEach(item => {
      const priceVal = parseFloat(item.querySelector('.price-menu-input')?.value) || 0;
      const qtyVal = parseFloat(item.querySelector('.qty-input')?.value) || parseFloat(item.dataset.qty) || 1;
      const rowGross = priceVal * qtyVal;

      const itemPctWrapper = item.querySelector('.item-discount-percent-wrapper');
      const itemFlatWrapper = item.querySelector('.item-discount-flat-wrapper');
      const itemPctVisible = itemPctWrapper && !itemPctWrapper.classList.contains('hidden');
      const itemFlatVisible = itemFlatWrapper && !itemFlatWrapper.classList.contains('hidden');
      // MUTUALLY EXCLUSIVE: only use the visible discount type
      let discPercent = itemPctVisible ? (parseFloat(item.querySelector('.discount-percent-input')?.value) || 0) : 0;
      let discFlat = itemFlatVisible ? (parseFloat(item.querySelector('.discount-flat-input')?.value) || 0) : 0;
      // Cap values + visual clamp (only during manual edits, not auto-update)
      if (discPercent > 100) {
        discPercent = 100;
        if (!window.isAutoUpdating) { const pctIn = item.querySelector('.discount-percent-input'); if (pctIn) pctIn.value = '100'; }
      }
      if (rowGross > 0 && discFlat > rowGross) {
        discFlat = rowGross;
        if (!window.isAutoUpdating) { const flatIn = item.querySelector('.discount-flat-input'); if (flatIn) flatIn.value = cleanNum(rowGross); }
      }
      const taxRateInput = item.querySelector('.tax-menu-input');
      const taxRateVal = taxRateInput ? (parseFloat(taxRateInput.value) || 0) : 0;
      const isTaxable = taxRateVal > 0;
      item.dataset.taxable = isTaxable ? 'true' : 'false';
      const itemDiscBtn = item.querySelector('.item-add-discount-btn');
      if (itemDiscBtn) {
        const isItemDiscountActive = discFlat > 0 || discPercent > 0;
        const isPriceEnabled = item.dataset.priceActive !== 'false';
        setItemDiscountButtonState(itemDiscBtn, isPriceEnabled && (isItemDiscountActive || itemPctVisible || itemFlatVisible));
      }

      // Discount logic — only one type active at a time
      const rowDisc = Math.min(rowGross, discFlat + (rowGross * (discPercent / 100)));
      const rowNet = Math.max(0, rowGross - rowDisc);

      const titleEl = item.closest('.dynamic-section')?.querySelector('.section-title');
      const category = (titleEl?.value || titleEl?.innerText || 'Item').trim();
      const desc = (item.querySelector('.item-input')?.value || '').trim();
      const displayName = desc ? `${category}: ${desc}` : category;

      if (rowGross > 0) {
        itemsGrossTotal += rowGross;
        allItemPrices.push({ name: displayName, amount: rowGross });
      }
      if (rowDisc > 0) {
        totalItemDiscounts += rowDisc;
        allItemDiscountsList.push({ name: displayName, amount: rowDisc, percent: discPercent });
      }

      let rowTax = 0;
      if (isTaxable) {
        rowTax = rowNet * (taxRateVal / 100);
        if (rowTax > 0) {
          totalTax += rowTax;
          allTaxesList.push({ name: displayName, amount: rowTax, rate: taxRateVal });
        }
      }

      // --- UPDATE BADGES (UI) ---
      const rowCurrencyCode = item.dataset.currencyCode || activeCurrencyCode;
      const rowCurrencySym = getCurrencySym(rowCurrencyCode);

      // 1. Discount Equation
      const origPriceBadge = item.querySelector('.badge-original-price');
      const minusOp = item.querySelector('.badge-minus');
      const discAmountBadge = item.querySelector('.badge-discount-amount');
      const equalsOpTop = item.querySelector('.badge-equals-top');
      const discountedPriceBadge = item.querySelector('.badge-discounted-price');
      if (rowDisc > 0) {
        if (origPriceBadge) {
          origPriceBadge.innerHTML = `<span style="transform: rotateX(180deg); display: flex;">${getCurrencyFormat(rowGross, rowCurrencyCode)}</span>`;
          origPriceBadge.classList.remove('hidden');
        }
        if (minusOp) minusOp.classList.remove('hidden');
        if (discAmountBadge) {
          discAmountBadge.innerHTML = `<span style="transform: rotateX(180deg); display: flex;">${getCurrencyFormat(rowDisc, rowCurrencyCode)}</span>`;
          discAmountBadge.classList.remove('hidden');
        }
        if (equalsOpTop) equalsOpTop.classList.remove('hidden');
        if (discountedPriceBadge) {
          discountedPriceBadge.innerHTML = `<span style="transform: rotateX(180deg); display: flex;">${getCurrencyFormat(rowNet, rowCurrencyCode)}</span>`;
          discountedPriceBadge.classList.remove('hidden');
        }
      } else {
        [origPriceBadge, minusOp, discAmountBadge, equalsOpTop, discountedPriceBadge].forEach(el => el?.classList.add('hidden'));
      }

      // 2. Multiplier/Price Badge
      const itemPriceBadge = item.querySelector('.badge-price');
      const itemMultiplierBadge = item.querySelector('.badge-multiplier');
      if (itemPriceBadge) {
        // Show if price > 0 AND (Tax is on OR Discount is off)
        if (rowNet > 0 && (isTaxable || rowDisc === 0)) {
          itemPriceBadge.innerText = getCurrencyFormat(rowNet, rowCurrencyCode);
          itemPriceBadge.classList.remove('hidden');
        } else {
          itemPriceBadge.classList.add('hidden');
        }
      }

      // 2. Multiplier Badge - Only show if taxable AND has a price
      if (isTaxable && rowNet > 0) {
        if (itemMultiplierBadge) itemMultiplierBadge.classList.remove('hidden');
      } else {
        if (itemMultiplierBadge) itemMultiplierBadge.classList.add('hidden');
      }


      // 3. Tax Equation - Only show if taxable AND has a price
      const itemTaxBadge = item.querySelector('.badge-tax');
      const itemEqualsBadge = item.querySelector('.badge-equals');
      const itemAfterTaxBadge = item.querySelector('.badge-after-tax');
      if (isTaxable && rowNet > 0) {
        const ctxTaxRate = taxRateVal;
        if (itemTaxBadge) {
          itemTaxBadge.innerText = `${cleanNum(ctxTaxRate)}%`;
          itemTaxBadge.classList.remove('hidden');
        }
        if (rowTax > 0) {
          if (itemEqualsBadge) itemEqualsBadge.classList.remove('hidden');
          if (itemAfterTaxBadge) {
            itemAfterTaxBadge.innerText = getCurrencyFormat(rowTax, rowCurrencyCode);
            itemAfterTaxBadge.classList.remove('hidden');
          }
        } else {
          if (itemEqualsBadge) itemEqualsBadge.classList.add('hidden');
          if (itemAfterTaxBadge) itemAfterTaxBadge.classList.add('hidden');
        }
      } else {
        [itemTaxBadge, itemEqualsBadge, itemAfterTaxBadge].forEach(el => el?.classList.add('hidden'));
        if (itemMultiplierBadge) itemMultiplierBadge.classList.add('hidden');
      }
    });

    // 4. Intermediate Totals
    const netSubtotal = Math.max(0, itemsGrossTotal - totalItemDiscounts);

    // Global Invoice Discount Capping
    let gDiscFlatInput = document.getElementById('globalDiscountFlat');
    let gDiscPercentInput = document.getElementById('globalDiscountPercent');

    let gDiscFlat = parseFloat(gDiscFlatInput?.value) || 0;
    let gDiscPercent = parseFloat(gDiscPercentInput?.value) || 0;

    // Enforce Global Caps (Only if not auto-updating to prevent destructive resets during recreation)
    if (!window.isAutoUpdating) {
      if (gDiscPercent > 100) {
        gDiscPercent = 100;
        if (gDiscPercentInput) gDiscPercentInput.value = 100;
      }
      if (gDiscFlat > netSubtotal) {
        gDiscFlat = netSubtotal;
        if (gDiscFlatInput) gDiscFlatInput.value = cleanNum(netSubtotal);
      }
    }

    invoiceDiscount = Math.min(netSubtotal, gDiscFlat + (netSubtotal * (gDiscPercent / 100)));

    const taxableTotal = Math.max(0, netSubtotal - invoiceDiscount);

    // Adjust tax for Pre-Tax rule (scale by invoice discount)
    let finalTax = totalTax;
    if (currentLogDiscountTaxRule === 'pre_tax' && itemsGrossTotal > 0) {
      finalTax = (taxableTotal / netSubtotal) * totalTax || 0;
    }

    const totalBeforeCredit = taxableTotal + finalTax;
    const balanceDue = totalBeforeCredit - totalCredit;

    // 5. UPDATE UI - ROW VISIBILITY & VALUES
    const setVal = (id, val, color) => {
      const el = document.getElementById(id);
      if (el) {
        el.innerText = getCurrencyFormat(val, activeCurrencyCode);
        if (color) el.className = `text-sm font-black ${color}`;
      }
    };

    const toggleRow = (id, show) => {
      const el = document.getElementById(id);
      if (el) {
        el.classList.toggle('hidden', !show);
        el.classList.toggle('flex', show);
      }
    };

    // Rule: If NO Item Discounts, "Items Total" hidden, "Subtotal" handles the breakdown
    const hasItemDiscounts = totalItemDiscounts > 0;
    toggleRow('itemsTotalRow', hasItemDiscounts);
    toggleRow('itemDiscountsRow', hasItemDiscounts);
    toggleRow('sepSubtotal', hasItemDiscounts);

    setVal('summaryItemsTotal', itemsGrossTotal);
    setVal('summaryItemDiscountsTotal', -totalItemDiscounts);

    // Subtotal always shown
    const subRow = document.getElementById('subtotalRow');
    if (subRow) {
      subRow.classList.remove('hidden');
      subRow.classList.add('flex');
    }
    setVal('summarySubtotal', netSubtotal);

    // Invoice Discount visibility
    const hasInvoiceDiscount = invoiceDiscount > 0;
    toggleRow('invoiceDiscountRow', hasInvoiceDiscount);
    toggleRow('taxableTotalRow', hasInvoiceDiscount);
    toggleRow('sepTaxable', hasInvoiceDiscount);

    const invDiscEl = document.getElementById('summaryInvoiceDiscount');
    if (invDiscEl) {
      let displayVal = `-${getCurrencyFormat(invoiceDiscount, activeCurrencyCode)}`;
      if (gDiscPercent > 0) {
        displayVal += ` (-${cleanNum(gDiscPercent)}%)`;
      }
      invDiscEl.innerText = displayVal;
    }

    setVal('summaryTaxableTotal', taxableTotal);

    // Tax visibility
    setVal('summaryTax', finalTax);

    // Credits visibility
    const hasCredits = totalCredit > 0;
    toggleRow('totalBeforeCreditRow', hasCredits);
    toggleRow('summaryCreditRow', hasCredits);
    toggleRow('sepCredit', hasCredits);
    setVal('summaryTotalBeforeCredit', totalBeforeCredit);
    setVal('summaryCreditTotal', -totalCredit);

    // Balance Due
    setVal('summaryTotal', balanceDue);

    // 6. RENDER BREAKDOWNS
    const renderBreakdown = (id, chevronId, items, colorClass, showPercent = false) => {
      const el = document.getElementById(id);
      const chev = document.getElementById(chevronId);
      if (!el) return;

      if (items.length > 0) {
        chev?.classList.remove('hidden');
        el.innerHTML = items.map(item => {
          let valStr = getCurrencyFormat(item.amount, activeCurrencyCode);
          if (id.includes('Discount') || id.includes('Credit')) valStr = `-${valStr}`;
          if (showPercent && item.percent > 0) valStr += ` (-${cleanNum(item.percent)}%)`;
          if (item.rate > 0) valStr += ` (${cleanNum(item.rate)}%)`;

          return `
                        <div class="flex justify-between items-center text-[10px] font-bold ${colorClass} italic">
                          <span class="truncate pr-2">${item.name}</span>
                          <span class="shrink-0">${valStr}</span>
                        </div>
                    `;
        }).join('');
      } else {
        chev?.classList.add('hidden');
        el.classList.add('hidden');
      }
    };

    // Decide where breakdown goes
    const subClickable = document.querySelector('#subtotalRow > div:first-child');
    const subBreakdownEl = document.getElementById('subtotalBreakdown');

    if (hasItemDiscounts) {
      renderBreakdown('itemsTotalBreakdown', 'itemsTotalChevron', allItemPrices, 'text-gray-500/70');
      renderBreakdown('itemDiscountsBreakdown', 'itemDiscountsChevron', allItemDiscountsList, 'text-green-600/70', true);

      // Disable subtotal breakdown interaction
      renderBreakdown('subtotalBreakdown', 'subtotalChevron', [], 'text-gray-500/70');

      // CRITICAL FIX: Explicitly remove cursor pointer and ensure it's hidden and empty
      if (subClickable) {
        subClickable.classList.remove('cursor-pointer');
        // Remove the onclick attribute to prevent any event firing defined in HTML
        subClickable.onclick = null;
      }
      if (subBreakdownEl) {
        subBreakdownEl.classList.add('hidden');
        subBreakdownEl.innerHTML = ''; // Clear it so checks for children fail
      }
      const subChevron = document.getElementById('subtotalChevron');
      if (subChevron) subChevron.classList.add('hidden');

    } else {
      // If multiple items, give breakdown to Subtotal row
      const hasMultipleItems = allItemPrices.length > 1;

      if (hasMultipleItems) {
        renderBreakdown('subtotalBreakdown', 'subtotalChevron', allItemPrices, 'text-gray-500/70');
        if (subClickable) {
          subClickable.classList.add('cursor-pointer');
          subClickable.onclick = window.toggleSubtotalBreakdown; // Restore handler
        }
      } else {
        renderBreakdown('subtotalBreakdown', 'subtotalChevron', [], 'text-gray-500/70');
        if (subClickable) {
          subClickable.classList.remove('cursor-pointer');
          subClickable.onclick = null;
        }
        if (subBreakdownEl) {
          subBreakdownEl.classList.add('hidden');
          subBreakdownEl.innerHTML = '';
        }
      }

      // Hide items total row items
      const itemTotalChev = document.getElementById('itemsTotalChevron');
      const itemTotalBreak = document.getElementById('itemsTotalBreakdown');
      if (itemTotalChev) itemTotalChev.classList.add('hidden');
      if (itemTotalBreak) itemTotalBreak.classList.add('hidden');
    }

    renderBreakdown('taxBreakdown', 'taxChevron', allTaxesList, 'text-orange-600/70');
    renderBreakdown('creditBreakdown', 'creditChevron', allCreditsList, 'text-red-600/70');

    // Toggle Invoice Discount button color
    const discBtn = document.getElementById('discountToggleBtn');
    if (discBtn) {
      if (hasInvoiceDiscount) {
        discBtn.classList.remove('border-black', 'text-black');
        discBtn.classList.add('border-green-600', 'bg-green-50', 'text-green-600');
      } else {
        discBtn.classList.add('border-black', 'text-black');
        discBtn.classList.remove('border-green-600', 'bg-green-50', 'text-green-600');
      }
    }

    requestAnimationFrame(adjustBadgeSpacing);
  } catch (e) {
    console.error("Totals calculation error:", e);
  }
}

function adjustBadgeSpacing() {
  // Check all item containers (Labor and Dynamic Sections)
  const containers = [
    document.getElementById('laborItemsContainer'),
    ...Array.from(document.querySelectorAll('#dynamicSections .dynamic-section > div[id]'))
  ];

  containers.forEach(container => {
    if (!container) return;

    const rows = Array.from(container.children).filter(child =>
      child.classList.contains('item-row') || child.classList.contains('labor-item-row')
    );

    rows.forEach((row, i) => {
      let isLabelShifted = false;

      // Internal Layout Adjustment (Labor only) — badges removed, minimal adjustment
      if (row.classList.contains('labor-item-row')) {
        // No badge overlap checks needed — inline layout handles spacing
      }

      // Standard Item Sub-category adjustment (Only if badges are visible)
      if (row.classList.contains('item-row') && !row.classList.contains('labor-item-row')) {
        const subCategories = row.querySelector('.sub-categories');
        const hasBottomBadges = row.querySelector('.badge-price:not(.hidden), .badge-tax:not(.hidden), .badge-after-tax:not(.hidden)');

        if (subCategories) {
          if (hasBottomBadges) {
            subCategories.style.marginTop = '28px';
          } else {
            subCategories.style.marginTop = '';
          }
        }
      }

      // Between-row adjustment (Spacing for badges of row N avoiding row N+1)
      if (i < rows.length - 1) {
        const currentRow = row;
        const nextRow = rows[i + 1];
        const nextRowHasShift = nextRow.querySelector('.labor-price-container > div:last-child')?.style.marginTop !== '';

        const hasBottomBadge = currentRow.querySelector('.badge-price:not(.hidden), .badge-tax:not(.hidden), .badge-after-tax:not(.hidden)');
        const hasDiscountBadge = nextRow.querySelector('.badge-original-price:not(.hidden), .badge-discount-amount:not(.hidden), .badge-discounted-price:not(.hidden), .badge-discount:not(.hidden)');

        let paddingValue = 0;
        if (hasBottomBadge) {
          if (hasDiscountBadge) {
            paddingValue = 24; // Was 40, user prefers standard extended gap (tight fit but no huge hole)
          } else {
            paddingValue = 24; // Clear bottom badges above regular input
          }
        } else if (hasDiscountBadge) {
          // Even if no bottom badge above, we typically don't need extra space if the label moved up (badges sit inside)
          // if (nextRowHasShift) paddingValue = 0; 
        }

        // Add extra buffer if the label is shifted and we have a collision
        if (nextRowHasShift && paddingValue > 18) paddingValue += 12;

        if (window.innerWidth >= 768) {
          // Use margin-top to move the divider line (border-top)
          // Base margin is 24px (mt-6), so we add paddingValue to it if it exists
          const baseMargin = 24;
          nextRow.style.marginTop = paddingValue > 0 ? `${baseMargin + paddingValue}px` : '';
          nextRow.style.paddingTop = ''; // Reset padding-top if it was set before
        } else {
          nextRow.style.marginTop = '';
          nextRow.style.paddingTop = '';
        }
        nextRow.style.transition = 'margin-top 0.3s ease, padding-top 0.3s ease';
      }
      // Adjust "Add Item" button spacing for the last row
      if (i === rows.length - 1) {
        const addBtnContainer = container.querySelector('.section-add-btn-container');
        if (addBtnContainer) {
          const hasBottomBadge = row.querySelector('.badge-price:not(.hidden), .badge-tax:not(.hidden), .badge-after-tax:not(.hidden)');
          if (window.innerWidth >= 768 && hasBottomBadge) {
            addBtnContainer.style.marginTop = '54px'; // 32px (mt-8) + 22px height adjustment
          } else {
            addBtnContainer.style.marginTop = '';
          }
        }
      }
    });
  });
}


document.addEventListener("DOMContentLoaded", () => {
  // Labor Section Initialization (Move to TOP for instant feel)
  const laborContInit = document.getElementById('laborItemsContainer');
  const hasRecreateData = localStorage.getItem('recreate_log_data');
  if (laborContInit && laborContInit.querySelectorAll('.labor-item-row').length === 0 && !hasRecreateData) {
    addLaborItem('', '', '', null, '', '', '', '', [], true); // noFocus=true on initial load
  }

  const recordBtn = document.getElementById("recordButton");
  const reParseBtn = document.getElementById("reParseBtn");
  const transcriptArea = document.getElementById("mainTranscript");
  const buttonText = document.getElementById("buttonText");
  const charLimit = window.profileCharLimit || 2000;

  window.updateCharCount = () => {
    const count = transcriptArea.value.length;
    document.getElementById("currentCharCount").innerText = count;
    const counter = document.getElementById("charCounter");
    if (count > charLimit) {
      counter.style.color = "#dc2626"; // red-600
    } else {
      counter.style.color = "#9ca3af"; // gray-400
    }
  };

  updateCharCount();

  // Initial resize for time input
  const editTimeInput = document.getElementById('editTime');
  if (editTimeInput) resizeInput(editTimeInput);

  let mediaRecorder = null;
  let audioChunks = [];
  let isRecording = false;
  let isAnalyzing = false;
  let analysisAbortController = null;
  let recordingStartTime = 0;
  let recordingInterval = null;
  const audioLimit = window.profileAudioLimit || 120;

  // Initialize recreation check
  checkRecreateData();


  // Close menus when clicking outside
  document.addEventListener('click', (e) => {
    if (!e.target.closest('.item-menu-container')) {
      document.querySelectorAll('.item-menu-dropdown.show').forEach(d => {
        d.classList.remove('show');
        const btn = d.previousElementSibling;
        if (btn) {
          btn.classList.remove('active', 'pop-active');
          randomizeIcon(btn);
        }

        const container = d.closest('.border-2.rounded-xl');
        if (container) {
          container.style.borderBottomLeftRadius = '';
          container.style.borderBottomRightRadius = '';
        }
      });
    }
    // Close global discount popup when clicking outside
    const gPanel = document.getElementById('discountInputsPanel');
    const gBtn = document.getElementById('discountToggleBtn');
    if (gPanel && gBtn && !gPanel.contains(e.target) && !gBtn.contains(e.target)) {
      if (!gPanel.classList.contains('hidden')) {
        gPanel.classList.add('hidden');
        gBtn.classList.remove('pop-active'); // Ensure pop-active is removed

        const flat = parseFloat(document.getElementById('globalDiscountFlat')?.value) || 0;
        const pct = parseFloat(document.getElementById('globalDiscountPercent')?.value) || 0;
        if (flat === 0 && pct === 0) {
          gBtn.classList.add('border-black', 'text-black');
          gBtn.classList.remove('border-green-600', 'bg-green-50', 'text-green-600');
        }
      }
    }
  });

  // Initial randomization for Labor Box
  const laborIconContainer = document.querySelector('#laborBox .item-menu-btn');
  if (laborIconContainer) randomizeIcon(laborIconContainer);
});

// --- Real-time Transcription Logic (Global Scope) ---
window.liveRecognition = null;
window.totalVoiceUsed = 0; // Tracks seconds spent in current session (since last main recording)
window.recordingStartTime = 0;

function startLiveTranscription(targetInput) {
  if (!targetInput) return;
  const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
  if (!SpeechRecognition) return console.warn("Speech Recognition not supported in this browser.");

  if (window.liveRecognition) {
    try { window.liveRecognition.stop(); } catch (e) { }
  }

  const recognition = new SpeechRecognition();
  recognition.continuous = true;
  recognition.interimResults = true;

  // Dynamic language based on selected transcription language
  const savedLang = localStorage.getItem('transcriptLanguage') || 'en';
  recognition.lang = (savedLang === 'ge' || savedLang === 'ka') ? 'ka-GE' : 'en-US';

  let typeTimer = null;

  recognition.onresult = (event) => {
    let fullTranscript = '';
    for (let i = 0; i < event.results.length; ++i) {
      fullTranscript += event.results[i][0].transcript;
    }
    if (!fullTranscript) return;

    // Typing animation for insertions and speech corrections
    if (typeTimer) { clearInterval(typeTimer); typeTimer = null; }

    const target = fullTranscript;
    let current = targetInput.value || '';

    const commonPrefixLen = (a, b) => {
      const max = Math.min(a.length, b.length);
      let i = 0;
      while (i < max && a[i] === b[i]) i += 1;
      return i;
    };

    if (current === target) return;

    typeTimer = setInterval(() => {
      if (current === target) {
        clearInterval(typeTimer);
        typeTimer = null;
        if (window.updateDynamicCountersCheck) {
          window.updateDynamicCountersCheck(targetInput);
        } else if (window.updateDynamicCounters) {
          window.updateDynamicCounters();
        }
        return;
      }

      const prefix = commonPrefixLen(current, target);

      if (current.length > target.length || prefix < current.length) {
        // Backspace animation for corrections/deletions
        const toDelete = Math.max(1, Math.ceil((current.length - prefix) / 3));
        current = current.slice(0, Math.max(prefix, current.length - toDelete));
      } else {
        // Type forward animation for additions
        const remaining = target.length - current.length;
        const toAdd = Math.max(1, Math.ceil(remaining / 8));
        current = target.slice(0, current.length + toAdd);
      }

      targetInput.value = current;
      autoResize(targetInput);
    }, 18);
  };

  recognition.onerror = (event) => {
    console.error("Speech recognition error:", event.error);
  };

  recognition.onend = () => {
    if (typeTimer) { clearInterval(typeTimer); typeTimer = null; }
    window.liveRecognition = null;
  };

  recognition.start();
  window.liveRecognition = recognition;
}

document.addEventListener("DOMContentLoaded", () => {
  const recordBtn = document.getElementById("recordButton");
  const transcriptArea = document.getElementById("mainTranscript");
  const enhanceTranscriptBtn = document.getElementById("enhanceTranscriptBtn");
  const buttonText = document.getElementById("buttonText");
  const charLimit = window.profileCharLimit || 2000;
  const audioLimit = window.profileAudioLimit || 120;
  let mediaRecorder = null;
  let audioChunks = [];
  let isRecording = false;
  let isAnalyzing = false;
  let analysisAbortController = null;
  let recordingInterval = null;

  if (!recordBtn) return;

  if (enhanceTranscriptBtn && transcriptArea) {
    enhanceTranscriptBtn.onclick = async () => {
      const labelEl = enhanceTranscriptBtn.querySelector("span");
      const originalLabel = enhanceTranscriptBtn.dataset.labelDefault || labelEl?.innerText || window.APP_LANGUAGES.enhance_text || "Enhance";
      const loadingLabel = enhanceTranscriptBtn.dataset.labelLoading || window.APP_LANGUAGES.enhancing_text || "Enhancing...";
      const sourceText = transcriptArea.value.trim();
      const limit = window.profileCharLimit || 2000;

      if (!sourceText) return;
      if (sourceText.length > limit) {
        showError((window.APP_LANGUAGES.limit_reached_upgrade || "Limit Reached (%{limit}). Upgrade to add more.").replace('%{limit}', limit));
        return;
      }

      enhanceTranscriptBtn.disabled = true;
      enhanceTranscriptBtn.classList.add("opacity-50", "cursor-not-allowed");
      if (labelEl) labelEl.innerText = loadingLabel;

      try {
        const res = await fetch("/enhance_transcript_text", {
          method: "POST",
          headers: {
            "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
            "Content-Type": "application/json"
          },
          body: JSON.stringify({
            manual_text: sourceText,
            language: localStorage.getItem('transcriptLanguage') || window.profileSystemLanguage || 'en'
          })
        });

        const data = await res.json();
        if (!res.ok || data.error) {
          showError(data.error || (window.APP_LANGUAGES.processing_error || "Failed to enhance text."));
        } else if (data.enhanced_text) {
          transcriptArea.value = data.enhanced_text.substring(0, limit);
          autoResize(transcriptArea);
          if (window.updateDynamicCountersCheck) {
            window.updateDynamicCountersCheck(transcriptArea);
          } else if (window.updateDynamicCounters) {
            window.updateDynamicCounters();
          }
        }
      } catch (e) {
        showError(window.APP_LANGUAGES.network_error || "Network error.");
      } finally {
        enhanceTranscriptBtn.disabled = false;
        enhanceTranscriptBtn.classList.remove("opacity-50", "cursor-not-allowed");
        if (labelEl) labelEl.innerText = originalLabel;
      }
    };
  }

  recordBtn.onclick = async () => {
    if (isAnalyzing) {
      if (analysisAbortController) analysisAbortController.abort();
      return;
    }

    if (!isRecording) {
      // Fix: Clear previous text when starting a new recording
      if (transcriptArea) {
        transcriptArea.value = "";
        window.previousClarificationAnswers = [];
        window.clarificationHistory = [];
        window._pendingAnswer = null;
        window._analysisSucceeded = false;
        window.lastAiResult = null;
        renderConversationHistory();
        const assistInput = document.getElementById('assistantInput');
        if (assistInput) { assistInput.value = ''; assistInput.disabled = false; }
        if (window.updateDynamicCounters) window.updateDynamicCounters();
        window.totalVoiceUsed = 0; // Reset bank on new main recording

        // Clear previous AI assistant section
        hidePostAnalysisSections();
        const questionsList = document.getElementById('assistantQuestionsList');
        if (questionsList) questionsList.innerHTML = '';
      }

      // Enforce Guest/Free Limits BEFORE starting
      if (typeof window.trackEvent === 'function') {
        const canProceed = await window.trackEvent('recording_started', window.currentUserId);
        if (!canProceed) return;
      }

      try {
        const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        mediaRecorder = new MediaRecorder(stream);
        audioChunks = [];
        mediaRecorder.ondataavailable = (e) => audioChunks.push(e.data);
        mediaRecorder.onstop = processAudio;

        mediaRecorder.start();
        startLiveTranscription(transcriptArea);
        window.recordingStartTime = Date.now();

        isRecording = true;
        buttonText.innerText = window.APP_LANGUAGES.stop || "STOP";
        document.getElementById("micIcon").innerHTML = '<rect x="7" y="7" width="10" height="10" rx="1" fill="currentColor" />';

        recordBtn.classList.add("recording");
        document.getElementById("recordingWave").classList.remove("hidden");
        document.getElementById("status").innerText = window.APP_LANGUAGES.recording || "RECORDING...";
        document.getElementById("status").classList.replace("text-orange-600", "text-red-600");
        document.getElementById("status").classList.replace("bg-orange-50", "bg-red-50");

        // Timer Logic
        const timerContainer = document.getElementById("recordingTimer");
        const timerDisplay = document.getElementById("currentAudioTime");
        timerContainer.classList.remove("hidden");
        timerDisplay.innerText = "0";

        recordingInterval = setInterval(() => {
          const elapsed = Math.floor((Date.now() - window.recordingStartTime) / 1000);
          timerDisplay.innerText = elapsed;

          if (audioLimit - elapsed <= 5) {
            timerDisplay.classList.add("text-red-600");
          } else {
            timerDisplay.classList.remove("text-red-600");
          }

          if (elapsed >= audioLimit) {
            recordBtn.onclick(); // Auto-stop
            if (window.showPremiumModal) window.showPremiumModal();
          }
        }, 1000);
      } catch (e) {
        showError(window.APP_LANGUAGES.microphone_access_denied || "Microphone access required.");
      }
    } else {
      if (recordingInterval) {
        clearInterval(recordingInterval);
        recordingInterval = null;
      }
      document.getElementById("recordingTimer").classList.add("hidden");
      const timerDisplay = document.getElementById("currentAudioTime");
      if (timerDisplay) timerDisplay.classList.remove("text-red-600");

      const duration = Date.now() - window.recordingStartTime;
      if (duration < 1000) {
        mediaRecorder.onstop = null;
        mediaRecorder.stop();
        mediaRecorder.stream.getTracks().forEach(t => t.stop());
        resetRecorderUI();
        showError(window.APP_LANGUAGES.hold_longer || "Hold longer to record");
        return;
      }
      mediaRecorder.stop();
      if (mediaRecorder.stream) {
        mediaRecorder.stream.getTracks().forEach(t => t.stop());
      }
      if (window.liveRecognition) {
        try { window.liveRecognition.stop(); } catch (e) { }
        window.liveRecognition = null;
      }
      isRecording = false;
      window.totalVoiceUsed = Math.floor(duration / 1000); // Set initial bank usage
      startAnalysisUI();
    }
  };

  function resetRecorderUI() {
    if (recordingInterval) {
      clearInterval(recordingInterval);
      recordingInterval = null;
    }
    if (mediaRecorder && mediaRecorder.stream) {
      mediaRecorder.stream.getTracks().forEach(t => t.stop());
    }
    document.getElementById("recordingTimer").classList.add("hidden");
    const timerDisplay = document.getElementById("currentAudioTime");
    if (timerDisplay) timerDisplay.classList.remove("text-red-600");

    if (window.liveRecognition) {
      try { window.liveRecognition.stop(); } catch (e) { }
      window.liveRecognition = null;
    }

    isRecording = false;
    isAnalyzing = false;
    // Restore Mic Icon
    const micIcon = document.getElementById("micIcon");
    if (micIcon) {
      micIcon.style.display = ""; // Ensure visible
      micIcon.innerHTML = `<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />`;
    }

    buttonText.innerText = window.APP_LANGUAGES.tap_to_record || "TAP TO RECORD";
    buttonText.classList.replace("text-xl", "text-[9px]"); // Restore size

    // Restore original orange button style
    recordBtn.style.background = "linear-gradient(145deg, #f97316, #ea580c)";
    recordBtn.style.boxShadow = "0 8px 32px rgba(249, 115, 22, 0.4), 0 4px 12px rgba(0,0,0,0.1), inset 0 2px 0 rgba(255,255,255,0.2)";

    recordBtn.classList.remove("recording");
    const statusEl = document.getElementById("status");
    statusEl.innerText = window.APP_LANGUAGES.ready || "READY";
    statusEl.classList.remove("text-red-600", "bg-red-50", "border-red-100", "text-yellow-600", "bg-yellow-50", "border-yellow-100");
    statusEl.classList.add("text-orange-600", "bg-orange-50", "border-orange-100");
    document.getElementById("recordingWave").classList.add("hidden");
  }

  async function processAudio() {
    try {
      const audioBlob = new Blob(audioChunks, { type: 'audio/webm' });
      const durationSec = (Date.now() - recordingStartTime) / 1000;
      const currentText = document.getElementById("mainTranscript").value;
      const limit = window.profileCharLimit || 2000;
      if (currentText.length >= limit) {
        if (window.showPremiumModal) {
          window.showPremiumModal();
        } else {
          showError((window.APP_LANGUAGES.limit_reached_upgrade || "Limit Reached (%{limit}). Upgrade to add more.").replace('%{limit}', limit));
        }
        stopAnalysisUI();
        return;
      }

      const formData = new FormData();
      formData.append("audio", audioBlob);
      formData.append("audio_duration", durationSec);
      formData.append("browser_transcript", currentText);
      formData.append("language", localStorage.getItem('transcriptLanguage') || window.profileSystemLanguage || 'en');

      const res = await fetch("/process_audio", {
        method: "POST",
        headers: { "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content },
        body: formData,
        signal: analysisAbortController?.signal
      });

      const data = await res.json();
      if (!res.ok || data.error) {
        showError(data.error || window.APP_LANGUAGES.speech_not_recognized || "Speech not recognized.");
        hidePostAnalysisSections();
      } else {
        updateUI(data);
      }
      stopAnalysisUI();
    } catch (e) {
      if (e.name === 'AbortError') {
        console.log("Analysis cancelled by user");
      } else {
        showError(window.APP_LANGUAGES.network_error || "Network error.");
        console.error(e);
      }
      stopAnalysisUI();
    }
  }

  function startAnalysisUI() {
    isAnalyzing = true;

    // UI: Big Text "CANCEL", No Icon
    buttonText.innerText = window.APP_LANGUAGES.cancel || "CANCEL";
    buttonText.classList.replace("text-[9px]", "text-xl");
    const micIcon = document.getElementById("micIcon");
    if (micIcon) micIcon.style.display = "none";

    // Light warm yellow cancel button
    recordBtn.style.background = "linear-gradient(145deg, #fbbf24, #f59e0b)";
    recordBtn.style.boxShadow = "0 8px 32px rgba(251, 191, 36, 0.4), 0 4px 12px rgba(0,0,0,0.1), inset 0 2px 0 rgba(255,255,255,0.3)";

    analysisAbortController = new AbortController();

    const statusEl = document.getElementById("status");
    statusEl.innerText = window.APP_LANGUAGES.processing || "PROCESSING...";
    statusEl.classList.remove("text-red-600", "bg-red-50", "text-orange-600", "bg-orange-50", "border-orange-100", "border-red-100");
    statusEl.classList.add("text-yellow-600", "bg-yellow-50", "border-yellow-100");
    recordBtn.classList.remove("recording");
    document.getElementById("recordingWave").classList.add("hidden");

    const transcriptCont = document.getElementById('transcriptContainer');
    const reviewCont = document.getElementById('reviewContainer');
    const overlay = document.getElementById('analyzingOverlay');

    if (transcriptCont) transcriptCont.classList.add('analyzing');
    if (reviewCont) reviewCont.classList.add('analyzing');
    if (overlay) overlay.classList.add('active');

    const refInput = document.getElementById('refinementInputContainer');
    const clarInput = document.getElementById('clarificationInputContainer');
    if (refInput) refInput.classList.add('analyzing');
    if (clarInput) clarInput.classList.add('analyzing');
  }

  function stopAnalysisUI() {
    isAnalyzing = false;
    analysisAbortController = null;
    const transcriptCont = document.getElementById('transcriptContainer');
    const reviewCont = document.getElementById('reviewContainer');
    const overlay = document.getElementById('analyzingOverlay');

    if (transcriptCont) transcriptCont.classList.remove('analyzing');
    if (reviewCont) reviewCont.classList.remove('analyzing');
    if (overlay) overlay.classList.remove('active');

    const refInput = document.getElementById('refinementInputContainer');
    const clarInput = document.getElementById('clarificationInputContainer');
    if (refInput) refInput.classList.remove('analyzing');
    if (clarInput) clarInput.classList.remove('analyzing');

    // Finalize or rollback pending Quick Questions / Change Details answer
    if (window._pendingAnswer) {
      if (window._analysisSucceeded) {
        if (window.finalizePendingAnswer) window.finalizePendingAnswer();
      } else {
        if (window.rollbackPendingAnswer) window.rollbackPendingAnswer();
      }
    }
    window._analysisSucceeded = false;

    resetRecorderUI();
  }

  function hidePostAnalysisSections() {
    const assistant = document.getElementById('aiAssistantSection');
    if (assistant) assistant.classList.add('hidden');
    window.pendingClarifications = [];
    // Re-enable input if it was disabled by a pending answer
    const assistIn = document.getElementById('assistantInput');
    if (assistIn) assistIn.disabled = false;
  }

  // Expose recorder functions to global scope for Object.assign(window, {...}) export
  window.resetRecorderUI = resetRecorderUI;
  window.processAudio = processAudio;
  window.startAnalysisUI = startAnalysisUI;
  window.stopAnalysisUI = stopAnalysisUI;

  reParseBtn.onclick = async () => {
    if (isAnalyzing) return; // Prevent spam clicks
    const text = transcriptArea.value;
    if (!text || text.trim().length < 2) return; // Ignore empty/barely legible input
    const limit = window.profileCharLimit || 2000;

    startAnalysisUI();

    try {
      const res = await fetch("/process_audio", {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          manual_text: text,
          language: localStorage.getItem('transcriptLanguage') || window.profileSystemLanguage || 'en'
        }),
        signal: analysisAbortController?.signal
      });
      const data = await res.json();

      if (data.error) {
        showError(data.error);
        hidePostAnalysisSections();
      } else {
        updateUI(data);
      }
    } catch (e) {
      if (e.name === 'AbortError') {
        console.log("Analysis cancelled by user");
      } else {
        showError(window.APP_LANGUAGES.network_error || "Network error.");
        console.error(e);
      }
    } finally {
      stopAnalysisUI();
    }
  };

  window.gatherLogData = function () {
    const client = document.getElementById("editClient")?.value || "";
    const date = window.selectedMainDate ?
      `${window.selectedMainDate.getFullYear()}-${String(window.selectedMainDate.getMonth() + 1).padStart(2, '0')}-${String(window.selectedMainDate.getDate()).padStart(2, '0')}` :
      (document.getElementById("dateDisplay")?.innerText || "");
    const sections = [];

    const laborContainer = document.getElementById("laborItemsContainer");
    const laborGroup = document.getElementById("laborGroup");
    let calculatedTotalTime = 0;

    if (laborContainer && (!laborGroup || !laborGroup.classList.contains('hidden'))) {
      const laborItems = [];
      laborContainer.querySelectorAll(".labor-item-row").forEach(row => {
        const desc = row.querySelector(".labor-item-input")?.value || "";
        const price = row.querySelector(".labor-price-input")?.value || "";
        const taxRate = row.querySelector(".tax-menu-input")?.value || "";
        const taxable = taxRate !== "" && parseFloat(taxRate) > 0;
        const discFlat = row.querySelector(".discount-flat-input")?.value || "";
        const discPercent = row.querySelector(".discount-percent-input")?.value || "";
        const rateVal = row.querySelector(".rate-menu-input")?.value || "";
        const discMessage = row.querySelector(".discount-message-input")?.value || "";

        calculatedTotalTime += parseFloat(price) || 0;
        const subs = [];
        row.querySelectorAll('.labor-sub-input').forEach(si => {
          if (si.value.trim() !== "") subs.push(si.value.trim());
        });

        const hasVal = desc.trim() !== "" || subs.length > 0;
        const hasPrice = (parseFloat(price) || 0) > 0;
        if (hasVal || hasPrice) {
          laborItems.push({
            desc: desc, price: price, rate: rateVal, taxable: taxable,
            mode: row.dataset.billingMode || "hourly",
            tax_rate: taxable ? taxRate : null,
            discount_flat: discFlat || "0", discount_percent: discPercent || "0",
            discount_message: discMessage, sub_categories: subs
          });
        }
      });
      if (laborItems.length > 0) sections.push({ title: "Labor/Service", items: laborItems });
    }

    document.querySelectorAll(".dynamic-section").forEach(sec => {
      const titleEl = sec.querySelector(".section-title");
      const title = titleEl ? (titleEl.value || titleEl.innerText || "").trim() : "";
      const items = [];
      sec.querySelectorAll(".item-row").forEach(row => {
        const desc = row.querySelector(".item-input")?.value || "";
        const price = row.querySelector(".price-menu-input")?.value || "";
        const taxRate = row.querySelector(".tax-menu-input")?.value || "";
        const taxable = taxRate !== "" && parseFloat(taxRate) > 0;
        const qty = row.querySelector(".qty-input")?.value || "1";
        const discFlat = row.querySelector(".discount-flat-input")?.value || "";
        const discPercent = row.querySelector(".discount-percent-input")?.value || "";
        const discMessage = row.querySelector(".discount-message-input")?.value || "";
        const subs = [];
        row.querySelectorAll('.sub-input').forEach(si => {
          if (si.value.trim() !== "") subs.push(si.value.trim());
        });
        const hasVal = desc.trim() !== "" || subs.length > 0;
        const hasPrice = (parseFloat(price) || 0) > 0;
        if (hasVal || hasPrice) {
          items.push({
            desc: desc, price: price, qty: qty, taxable: taxable,
            tax_rate: (taxable && taxRate) ? taxRate : null,
            discount_flat: discFlat || "0", discount_percent: discPercent || "0",
            discount_message: discMessage, sub_categories: subs
          });
        }
      });
      if (items.length > 0) sections.push({ title: title || "Items", items });
    });

    const globalDiscFlat = document.getElementById('globalDiscountFlat')?.value || "0";
    const globalDiscPercent = document.getElementById('globalDiscountPercent')?.value || "0";
    const globalDiscMessage = document.getElementById('globalDiscountMessage')?.value || "";
    const credits = [];
    let totalCreditValue = 0;
    const creditGroup = document.getElementById('creditGroup');
    if (!creditGroup || !creditGroup.classList.contains('hidden')) {
      document.querySelectorAll('.credit-item-row').forEach(row => {
        const amount = parseFloat(row.querySelector('.credit-amount-input')?.value) || 0;
        const reason = row.querySelector('.credit-reason-input')?.value?.trim() || (window.APP_LANGUAGES?.courtesy_credit || "Courtesy Credit");
        if (amount > 0) {
          credits.push({ amount, reason });
          totalCreditValue += amount;
        }
      });
    }

    return {
      client, time: calculatedTotalTime.toString(), date,
      due_date: window.selectedDueDate ?
        `${window.selectedDueDate.getFullYear()}-${String(window.selectedDueDate.getMonth() + 1).padStart(2, '0')}-${String(window.selectedDueDate.getDate()).padStart(2, '0')}` :
        (document.getElementById("dueDateValue")?.innerText || ""),
      tasks: JSON.stringify(sections), credits: JSON.stringify(credits),
      tax_scope: typeof currentLogTaxScope !== 'undefined' ? currentLogTaxScope : "total",
      labor_taxable: "false", global_discount_flat: globalDiscFlat,
      global_discount_percent: globalDiscPercent, global_discount_message: globalDiscMessage,
      credit_flat: totalCreditValue.toString(), credit_reason: credits.map(c => c.reason).join(", "),
      currency: typeof activeCurrencyCode !== 'undefined' ? activeCurrencyCode : "USD",
      billing_mode: typeof currentLogBillingMode !== 'undefined' ? currentLogBillingMode : "hourly",
      discount_tax_rule: typeof currentLogDiscountTaxRule !== 'undefined' ? currentLogDiscountTaxRule : "post_tax",
      hourly_rate: (typeof profileHourlyRate !== 'undefined' ? profileHourlyRate : 0).toString(),
      accent_color: currentLogAccentColor || "#EA580C",
      raw_summary: document.getElementById("mainTranscript")?.value || "",
      tax_rate: (typeof profileTaxRate !== 'undefined' ? profileTaxRate : (window.profileTaxRate || 0)).toString(),
      status: document.getElementById("pdfLogStatus")?.value || "draft",
      category_ids: document.getElementById("pdfLogCategory")?.value ? [document.getElementById("pdfLogCategory").value] : [],
      sender_info: window.invoiceSenderInfo ? JSON.stringify(window.invoiceSenderInfo) : "",
      recipient_info: window.invoiceRecipientInfo ? JSON.stringify(window.invoiceRecipientInfo) : ""
    };
  }

  window.setupSaveButton = async function () {

    const data = gatherLogData();
    const modal = document.getElementById('pdfModal');
    const overlay = document.getElementById('pdfModalOverlay');
    const content = document.getElementById('pdfModalContent');
    const iframe = document.getElementById('pdfFrame');
    const loading = document.getElementById('pdfLoading');
    const viewer = document.getElementById('pdfViewerContainer');
    const startTime = Date.now();

    if (viewer) {
      viewer.classList.add('locked'); // Lock scroll during generation
      viewer.scrollTo(0, 0);
    }

    // RESET BUTTONS TO INITIAL STATE IF NOT SAVED
    const saveBtn = document.getElementById('pdfModalSaveBtn');
    if (saveBtn && !logAlreadySaved) {
      saveBtn.disabled = false;
      saveBtn.style.pointerEvents = 'auto';
      const saveDiv = saveBtn.querySelector('div');
      const saveLabel = saveBtn.querySelector('span');
      if (saveDiv) {
        saveDiv.className = 'w-14 h-14 md:w-16 md:h-16 rounded-[1.25rem] md:rounded-3xl border-2 border-black bg-orange-600 shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] flex items-center justify-center group-active:translate-x-[2px] group-active:translate-y-[2px] group-active:shadow-none transition-all hover:bg-orange-700';
        saveDiv.style.boxShadow = '';
        saveDiv.style.transform = '';
      }
      if (saveLabel) {
        saveLabel.innerText = window.APP_LANGUAGES.save || 'Save';
        saveLabel.classList.add('text-gray-500');
        saveLabel.classList.remove('text-green-600');
      }

      // Reset Selectors
      if (typeof setPdfStatus === 'function') setPdfStatus('draft');
      if (typeof setPdfCategory === 'function') setPdfCategory('', window.APP_LANGUAGES.no_category || '- No Category -', '');

    } else if (saveBtn && logAlreadySaved) {
      updateSaveButtonToSavedState(saveBtn);
    }
    const shareBtn = document.getElementById('pdfModalShareBtn');
    if (shareBtn) {
      shareBtn.disabled = false;
      shareBtn.style.pointerEvents = 'auto';
    }

    const viewerContainer = document.getElementById('pdfViewerContainer');
    if (viewerContainer) {
      viewerContainer.scrollTo(0, 0);
      viewerContainer.classList.add('locked');
    }

    modal.classList.remove('hidden');
    modal.offsetHeight; // force reflow
    overlay.classList.add('opacity-100');
    content.classList.remove('translate-y-full');
    // PREVENT SCROLLING BACKGROUND without triggering browser toolbar changes
    if (document.activeElement && document.activeElement.blur) document.activeElement.blur();
    // On mobile, nudge scroll down 1px to collapse browser toolbar if visible
    if (window.innerWidth < 768 && document.documentElement.scrollHeight > window.innerHeight) {
        window.scrollBy(0, 1);
    }
    document.body.classList.add('overflow-hidden');
    document.documentElement.classList.add('overflow-hidden');
    // Block touchmove on background (most reliable mobile scroll lock)
    window._pdfPreventScroll = (e) => {
        if (!e.target.closest('#pdfModalContent')) e.preventDefault();
    };
    document.addEventListener('touchmove', window._pdfPreventScroll, { passive: false });

    iframe.classList.add('hidden');
    iframe.style.opacity = '0';
    loading.classList.remove('hidden');

    // Clear ID if we are opening a fresh modal and form has changed
    // (This is a safety check - the event listener usually handles this)
    if (!logAlreadySaved) {
      savedLogId = null;
      savedLogClient = null;
    }

    try {
      const formData = new FormData();
      for (const key in data) {
        if (Array.isArray(data[key])) {
          data[key].forEach(val => formData.append(`log[${key}][]`, val));
        } else {
          formData.append(`log[${key}]`, data[key]);
        }
      }
      formData.append('authenticity_token', document.querySelector('meta[name="csrf-token"]').content);
      formData.append('session_id', sessionStorage.getItem('tracking_session_id'));
      if (typeof savedLogId !== 'undefined' && savedLogId) {
        formData.append('log_id', savedLogId);
      }

      const response = await fetch('/logs/generate_preview', {
        method: 'POST',
        headers: { 'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content },
        body: formData
      });

      if (response.status === 429) {
        const errData = await response.json();
        showError(errData.errors ? errData.errors[0] : (window.APP_LANGUAGES.rate_limit_reached || 'Rate limit reached'));
        if (window.showPremiumModal) window.showPremiumModal(true);
        closePdfModal();
        return;
      }

      if (!response.ok) throw new Error('Preview generation failed');

      const pageCount = parseInt(response.headers.get('X-PDF-Pages')) || 1;
      const invNo = response.headers.get('X-INV-No');
      if (invNo) {
        savedLogDisplayNumber = invNo;
      }

      const canvas = document.getElementById('pdfCanvas');
      const iframe = document.getElementById('pdfFrame');

      // Clear previous iframe source to ensure clean reload
      if (iframe) iframe.src = 'about:blank';

      // Detect iOS (Safari, Chrome, etc on iPhone/iPad)
      const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent) ||
        (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);

      if (canvas) {
        const updateSizing = () => {
          const viewportWidth = window.innerWidth;
          const isMobile = viewportWidth < 768;

          let width;
          if (isMobile) {
            width = viewportWidth; // Full width on mobile (no padding)
          } else {
            const parent = canvas.parentElement;
            width = canvas.clientWidth || (parent ? parent.clientWidth - 80 : 0) || (viewportWidth - 80);
          }

          if (width > 50) {
            const isMobile = window.innerWidth < 768;

            if (isMobile) {
              const horizontalPadding = 32;
              const availableWidth = window.innerWidth - horizontalPadding;
              const calculatedHeight = Math.floor(pageCount * availableWidth * 1.4145);

              canvas.style.width = availableWidth + 'px';
              canvas.style.minWidth = availableWidth + 'px';
              canvas.style.maxWidth = availableWidth + 'px';
              canvas.style.height = calculatedHeight + 'px';

              // Remove centering hacks, use standard layout
              canvas.style.position = 'relative';
              canvas.style.left = '0';
              canvas.style.marginLeft = '0';
              canvas.style.transform = '';
              canvas.style.marginBottom = '20px'; // margin at bottom of list

              if (iframe) {
                iframe.style.height = '100%';
                iframe.style.width = '100%';
                iframe.style.opacity = (loading && !loading.classList.contains('hidden')) ? '0' : '1';
              }
            } else {
              // Desktop Standard
              canvas.style.position = 'relative';
              canvas.style.left = '0';
              canvas.style.marginLeft = 'auto';
              canvas.style.marginRight = 'auto';

              const calculatedHeight = Math.floor(pageCount * width * 1.4145);
              const hStr = Math.max(calculatedHeight, 600) + 'px';
              canvas.style.height = hStr;
              canvas.style.minHeight = hStr;
              canvas.style.width = '100%';
              canvas.style.maxWidth = width + 'px';
              canvas.style.transform = '';
              canvas.style.marginBottom = '40px';

              if (iframe) {
                iframe.style.height = '100%';
                iframe.style.width = '100%';
                iframe.style.opacity = (loading && !loading.classList.contains('hidden')) ? '0' : '1';
              }
            }

            console.log("PDF Resize:", { isIOS, isMobile, width, pageCount });
          }
        };

        updateSizing();
        setTimeout(updateSizing, 100);
        setTimeout(updateSizing, 300);
        setTimeout(updateSizing, 600);
        setTimeout(updateSizing, 1000);
        window.addEventListener('resize', updateSizing, { once: true });
      }

      const blob = await response.blob();
      const arrayBuffer = await blob.arrayBuffer(); // Get buffer directly to avoid fetch issues
      const url = URL.createObjectURL(blob);

      // Store in private scope (not easily visible in DevTools)
      if (!window._sl) window._sl = {};
      window._sl._u = url;
      window._sl._b = blob;
      window._sl._a = arrayBuffer;

      const showPdfContent = () => {
        if (loading) loading.classList.add('hidden');
        if (viewer) {
          viewer.classList.remove('locked');
          viewer.style.overflowY = 'auto';
          viewer.style.overflowX = 'hidden';
          viewer.scrollTo(0, 0);
        }
        const isMobile = window.innerWidth < 768;
        if (isMobile) {
          const jsContainer = document.getElementById('pdfJSContainer');
          if (jsContainer) jsContainer.classList.remove('hidden');
        } else if (iframe) {
          iframe.classList.remove('hidden');
          iframe.style.display = 'block';
          iframe.style.opacity = '1';
          if (typeof updateSizing === 'function') updateSizing();
        }
      };

      const renderPDFJS = async (data) => {
        try {
          if (!window.pdfjsLib) throw new Error("PDF Library not loaded");
          const pdfjsLib = window.pdfjsLib;

          const jsContainer = document.getElementById('pdfJSContainer');
          if (!jsContainer) return;
          jsContainer.innerHTML = ''; // Clear existing
          jsContainer.classList.add('hidden'); // Stay hidden until rendered

          const loadingTask = pdfjsLib.getDocument({ data: data });
          const pdf = await loadingTask.promise;

          const viewportWidth = window.innerWidth;
          const containerWidth = Math.min(viewportWidth - 32, 800);

          const pagesTotal = pdf.numPages;

          for (let pageNum = 1; pageNum <= pagesTotal; pageNum++) {
            const page = await pdf.getPage(pageNum);

            // Detect pixel ratio for sharp rendering (especially on retina mobile)
            const pixelRatio = window.devicePixelRatio || 1;

            const initialViewport = page.getViewport({ scale: 1 });
            const scale = containerWidth / initialViewport.width;
            const viewport = page.getViewport({ scale: scale * pixelRatio });

            const canvas = document.createElement('canvas');
            canvas.className = 'pdf-js-page';
            const context = canvas.getContext('2d', { alpha: false }); // Performance optimization

            // Set actual display size
            canvas.style.width = containerWidth + 'px';
            canvas.style.height = (initialViewport.height * scale) + 'px';

            // Set drawing surface size (high res)
            canvas.width = viewport.width;
            canvas.height = viewport.height;

            jsContainer.appendChild(canvas);

            await page.render({
              canvasContext: context,
              viewport: viewport
            }).promise;
          }

          return true;
        } catch (err) {
          console.error("Detailed PDF.js Render Error:", err);
          return false;
        }
      };

      const isMobile = window.innerWidth < 768;

      if (isMobile) {
        // MOBILE: PDF.js Path
        const iframe = document.getElementById('pdfFrame');
        const pdfCanvas = document.getElementById('pdfCanvas');
        if (iframe) iframe.src = 'about:blank';
        if (pdfCanvas) pdfCanvas.classList.add('hidden');

        const minTimePassed = new Promise(resolve => {
          const elapsed = Date.now() - startTime;
          setTimeout(resolve, Math.max(0, 600 - elapsed));
        });

        renderPDFJS(arrayBuffer).then(success => {
          if (success) {
            Promise.all([minTimePassed]).then(() => {
              setTimeout(showPdfContent, 50);
            });
          } else {
            throw new Error(window.APP_LANGUAGES.render_failed || "Render process failed");
          }
        }).catch(err => {
          console.error("PDF.js Error:", err);
          showError((window.APP_LANGUAGES.render_failed || "Render failed") + " (" + (err.message || "Unknown") + ")");
          showPdfContent();
        });

      } else if (iframe) {
        // DESKTOP: Iframe Path (Kept Original)
        const jsContainer = document.getElementById('pdfJSContainer');
        const pdfCanvas = document.getElementById('pdfCanvas');
        if (jsContainer) jsContainer.classList.add('hidden');
        if (pdfCanvas) pdfCanvas.classList.remove('hidden');

        const viewParams = '#toolbar=0&view=FitH';

        iframe.src = url + viewParams;
        iframe.style.display = 'block';

        const minTimePassed = new Promise(resolve => {
          const elapsed = Date.now() - startTime;
          setTimeout(resolve, Math.max(0, 600 - elapsed));
        });

        const iframeLoaded = new Promise(resolve => {
          iframe.onload = resolve;
          setTimeout(resolve, 3000);
        });

        Promise.all([minTimePassed, iframeLoaded]).then(() => {
          setTimeout(showPdfContent, 100);
        });
      }
    } catch (err) {
      console.error(err);
      showError(window.APP_LANGUAGES.render_failed || "Failed to generate preview");
      closePdfModal();
    }
  }

  window.closePdfModal = function () {
    const modal = document.getElementById('pdfModal');
    const overlay = document.getElementById('pdfModalOverlay');
    const content = document.getElementById('pdfModalContent');
    overlay.classList.remove('opacity-100');
    content.classList.add('translate-y-full');
    // RESTORE SCROLLING BACKGROUND
    document.body.classList.remove('overflow-hidden');
    document.documentElement.classList.remove('overflow-hidden');
    if (window._pdfPreventScroll) {
        document.removeEventListener('touchmove', window._pdfPreventScroll);
        window._pdfPreventScroll = null;
    }

    // Explicitly reset save state on close so changes can be re-saved
    logAlreadySaved = false;
    savedLogId = null;
    savedLogDisplayNumber = null;
    savedLogClient = null;
    shareTrackedThisSession = false; // Reset share tracking for next popup

    // Aggressive reset on close
    const viewer = document.getElementById('pdfViewerContainer');
    if (viewer) viewer.scrollTo(0, 0);

    // Clear content immediately to prevent ghosting or flickering of previous PDF
    const iframe = document.getElementById('pdfFrame');

    if (iframe) iframe.src = 'about:blank';

    setTimeout(() => {
      modal.classList.add('hidden');
      if (iframe) iframe.classList.add('hidden');

      // Revoke object URLs to free memory
      if (window._sl && window._sl._u) {
        URL.revokeObjectURL(window._sl._u);
        window._sl = null;
      }
    }, 500);
  }

  function updateSaveButtonToSavedState(btn) {
    const saveDiv = btn.querySelector('div');
    const saveLabel = btn.querySelector('span');
    btn.disabled = true;
    btn.style.pointerEvents = 'none';

    if (saveDiv) {
      saveDiv.classList.remove('bg-orange-600', 'hover:bg-orange-700', 'bg-black', 'hover:bg-gray-900');
      saveDiv.classList.add('bg-green-600');
      saveDiv.classList.remove('scale-105');
      saveDiv.style.boxShadow = 'none';
      saveDiv.style.transform = 'translate(2px, 2px)';
    }

    if (saveLabel) {
      saveLabel.innerText = window.APP_LANGUAGES.saved || 'Saved';
      saveLabel.classList.remove('text-gray-500');
      saveLabel.classList.add('text-green-600');
    }
  }

  function updateSaveButtonToLimitState(btn) {
    const saveDiv = btn.querySelector('div');
    const saveLabel = btn.querySelector('span');
    btn.disabled = true;
    btn.style.pointerEvents = 'none';

    if (saveDiv) {
      saveDiv.classList.remove('bg-orange-600', 'hover:bg-orange-700', 'bg-black', 'hover:bg-gray-900', 'bg-green-600');
      saveDiv.classList.add('bg-red-600');
      saveDiv.style.boxShadow = 'none';
      saveDiv.style.transform = 'translate(2px, 2px)';
    }

    if (saveLabel) {
      saveLabel.innerText = window.APP_LANGUAGES.limit_reached || 'LIMIT REACHED';
      saveLabel.classList.remove('text-gray-500', 'text-green-600');
      saveLabel.classList.add('text-red-600');
      saveLabel.classList.add('text-center');
    }
  }

  window.updateSaveButtonToSavedState = updateSaveButtonToSavedState;
  window.updateSaveButtonToLimitState = updateSaveButtonToLimitState;

  window.finalSaveLog = async function (options = { redirect: true }) {
    const saveBtn = document.getElementById('pdfModalSaveBtn');
    const shareBtn = document.getElementById('pdfModalShareBtn');

    if (!saveBtn || saveBtn.disabled) return { id: savedLogId, client: savedLogClient };
    if (logAlreadySaved) {
      updateSaveButtonToSavedState(saveBtn);
      if (options.redirect) window.location.href = '/history';
      return { id: savedLogId, client: savedLogClient };
    }

    const saveDiv = saveBtn.querySelector('div');
    const saveLabel = saveBtn.querySelector('span');
    const originalClasses = saveDiv ? saveDiv.className : '';
    const originalLabelText = saveLabel ? saveLabel.innerText : (window.APP_LANGUAGES.save || 'Save');

    // DISABLE BOTH IMMEDIATELY
    saveBtn.disabled = true;
    saveBtn.style.pointerEvents = 'none';
    if (shareBtn) {
      shareBtn.disabled = true;
      shareBtn.style.pointerEvents = 'none';
    }

    try {
      const data = gatherLogData();
      const formData = new FormData();
      for (const key in data) {
        if (Array.isArray(data[key])) {
          data[key].forEach(val => formData.append(`log[${key}][]`, val));
        } else {
          formData.append(`log[${key}]`, data[key]);
        }
      }
      formData.append('authenticity_token', document.querySelector('meta[name="csrf-token"]').content);
      formData.append('log[session_id]', sessionStorage.getItem('tracking_session_id'));

      const response = await fetch('/logs', {
        method: 'POST',
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: formData
      });

      const contentType = response.headers.get("content-type");
      if (!contentType || !contentType.includes("application/json")) {
        const text = await response.text();
        console.error("Expected JSON but got:", text.substring(0, 200));
        throw new Error(`Server returned ${response.status} ${response.statusText} (likely an error page or redirect).`);
      }

      const resData = await response.json();
      if (resData.success) {
        updateSaveButtonToSavedState(saveBtn);
        logAlreadySaved = true; // Mark as saved
        savedLogId = resData.id;
        savedLogDisplayNumber = resData.display_number;
        savedLogClient = resData.client;

        // Record the export event (saves count toward the export limit)
        window.trackEvent('invoice_exported', window.currentUserId, null, savedLogId);
        shareTrackedThisSession = true; // Mark as tracked so Share button won't double-count

        if (options.redirect) {
          window.location.href = '/history';
        } else if (!options.silent) {
          // Update preview only if NOT silent (to avoid flicker during share)
          const finalSrc = `/logs/${resData.id}/download_pdf#toolbar=0`;
          const iframe = document.getElementById('pdfFrame');

          if (iframe && !iframe.classList.contains('hidden')) {
            if (!iframe.src.includes(`/logs/${resData.id}/download_pdf`)) {
              iframe.src = finalSrc;
            }
          }
        }
        return {
          id: savedLogId,
          display_number: savedLogDisplayNumber,
          client: savedLogClient
        };
      } else {
        if (response.status === 429 || resData.message === 'Rate limit reached') {
          window.showPremiumModal?.();
          const err = new Error('Limit reached');
          err.isLimit = true;
          throw err;
        }
        throw new Error(resData.errors?.join(', ') || 'Save failed');
      }
    } catch (err) {
      if (err.isLimit || err.message === 'Limit reached' || err.message.toLowerCase().includes("limit reached")) {
        updateSaveButtonToLimitState(saveBtn);
        // Also disable share button and update its appearance
        if (shareBtn) {
          shareBtn.disabled = true;
          shareBtn.style.pointerEvents = 'none';
          const shareDiv = shareBtn.querySelector('div');
          const shareLabel = shareBtn.querySelector('span');
          if (shareDiv) {
            shareDiv.classList.remove('bg-black', 'hover:bg-gray-900');
            shareDiv.classList.add('bg-red-600');
            shareDiv.style.boxShadow = 'none';
            shareDiv.style.transform = 'translate(2px, 2px)';
          }
          if (shareLabel) {
            shareLabel.innerText = window.APP_LANGUAGES.limit_reached || 'LIMIT REACHED';
            shareLabel.classList.remove('text-gray-500');
            shareLabel.classList.add('text-red-600');
          }
        }
        window.showPremiumModal?.();
        return { error: 'Limit reached' };
      }

      // Revert states for normal errors
      saveBtn.disabled = false;
      saveBtn.style.pointerEvents = 'auto';
      if (shareBtn) {
        shareBtn.disabled = false;
        shareBtn.style.pointerEvents = 'auto';
      }

      if (saveDiv) {
        saveDiv.className = originalClasses;
        saveDiv.style.boxShadow = '';
        saveDiv.style.transform = '';
      }
      if (saveLabel) {
        saveLabel.innerText = originalLabelText;
        saveLabel.classList.remove('text-green-600', 'text-red-600');
        saveLabel.classList.add('text-gray-500');
      }

      console.error(err);
      showError(err.message);
    }
  }

  window.sharePdf = async function () {
    const iframe = document.getElementById('pdfFrame');

    // Check if we have ANY valid preview source (Blob URL or final saved URL)
    const currentSrc = window._sl?._u || iframe?.src;

    if (!currentSrc || currentSrc === "" || currentSrc === "about:blank") {
      showError(window.APP_LANGUAGES.pdf_loading || "PDF is still loading...");
      return;
    }

    const shareBtn = document.getElementById('pdfModalShareBtn');
    const saveBtn = document.getElementById('pdfModalSaveBtn');
    const shareLabel = shareBtn?.querySelector('span');
    const originalShareText = shareLabel?.innerText || "Share";

    // Track if limit was hit to prevent re-enabling buttons
    let limitWasHit = false;

    if (shareBtn) {
      shareBtn.disabled = true;
      shareBtn.style.pointerEvents = 'none';
    }

    if (window.userSignedIn) {
      // SIGNED-IN USER: Try to save first, then track
      if (!logAlreadySaved) {
        const saveResult = await finalSaveLog({ redirect: false, silent: true });

        if (saveResult?.error === 'Limit reached') {
          limitWasHit = true;
          return;
        }

        if (!logAlreadySaved) {
          // Save failed for some reason, re-enable and stop
          if (shareBtn) {
            shareBtn.disabled = false;
            shareBtn.style.pointerEvents = 'auto';
            if (shareLabel) shareLabel.innerText = originalShareText;
          }
          return;
        }
      } else {
        // Already saved, just track the share (once per session)
        if (!shareTrackedThisSession) {
          const canExport = await window.trackEvent('invoice_exported', window.currentUserId, null, savedLogId);
          if (canExport === false) {
            limitWasHit = true;
            if (saveBtn) updateSaveButtonToLimitState(saveBtn);
            return;
          }
          shareTrackedThisSession = true;
        }
      }
    } else {
      // GUEST: Skip save entirely, just track the export event (once per session)
      if (!shareTrackedThisSession) {
        const canExport = await window.trackEvent('invoice_exported', null, null, null);
        if (canExport === false) {
          limitWasHit = true;
          if (saveBtn) updateSaveButtonToLimitState(saveBtn);
          if (shareBtn) {
            const shareDiv = shareBtn.querySelector('div');
            const sLabel = shareBtn.querySelector('span');
            if (shareDiv) {
              shareDiv.classList.remove('bg-black', 'hover:bg-gray-900');
              shareDiv.classList.add('bg-red-600');
              shareDiv.style.boxShadow = 'none';
              shareDiv.style.transform = 'translate(2px, 2px)';
            }
            if (sLabel) {
              sLabel.innerText = window.APP_LANGUAGES.limit_reached || 'LIMIT REACHED';
              sLabel.classList.remove('text-gray-500');
              sLabel.classList.add('text-red-600');
            }
          }
          window.showPremiumModal?.();
          return;
        }
        shareTrackedThisSession = true;
      }
    }

    // Use cached numbers from preview header or fallback
    const logNo = savedLogDisplayNumber || "1001";
    const clientName = document.getElementById("editClient")?.value?.trim() || "Client";
    const fileName = `INV-${logNo}_${clientName}.pdf`;

    try {
      // Use cached blob if available (INSTANT)
      let blob = window._sl?._b;
      if (!blob) {
        const response = await fetch(iframe.src);
        blob = await response.blob();
      }
      const file = new File([blob], fileName, { type: 'application/pdf' });

      if (navigator.share && navigator.canShare && navigator.canShare({ files: [file] })) {
        await navigator.share({
          files: [file],
          title: 'Invoice',
          text: 'Here is your invoice.'
        });
      } else {
        // Fallback for browsers like Chrome on iOS: Open in new tab
        const url = URL.createObjectURL(blob);
        window.open(url, '_blank');

        // Also trigger a download as a backup
        const link = document.createElement('a');
        link.href = url;
        link.download = fileName;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);

        // Note: We don't revoke immediately to ensure window.open has time to load it
        setTimeout(() => URL.revokeObjectURL(url), 5000);
      }
    } catch (err) {
      if (err.isLimit || err.message === 'Limit reached' || err.message.toLowerCase().includes("limit reached")) {
        limitWasHit = true;
        if (saveBtn) updateSaveButtonToLimitState(saveBtn);
        window.showPremiumModal?.();
        return;
      }
      console.error('Sharing failed', err);
      showError(window.APP_LANGUAGES.draft_prepared || "Draft prepared. Click Share again to send.");
    } finally {
      // Only re-enable buttons if limit was NOT hit
      if (!limitWasHit) {
        if (window.userSignedIn) {
          if (saveBtn && !logAlreadySaved) {
            saveBtn.disabled = false;
            saveBtn.style.pointerEvents = 'auto';
          }
        }
        if (shareBtn) {
          shareBtn.disabled = false;
          shareBtn.style.pointerEvents = 'auto';
        }
      }
    }
  }


  document.addEventListener('turbo:load', () => {
    initGlobalVariables();
    checkRecreateData(); // Ensure this is called on every turbo:load
  });

  // Cleanup: Remove individual event calls if we want to centralize
  // But keeping turbo:load for navigation safety
  // document.addEventListener('turbo:load', checkRecreateData); // Removed duplicate call
  // document.addEventListener('turbo:render', checkRecreateData); // Removed duplicate call

  // Hydrate initial static items if any
  document.querySelectorAll('.item-row').forEach(row => {
    randomizeIcon(row);
    updateBadge(row);
    updateHamburgerGlow(row);
  });

  // Reset Save state if anything changes in the form
  const reviewCont = document.getElementById('reviewContainer');
  if (reviewCont) {
    reviewCont.addEventListener('input', () => {
      if (logAlreadySaved) {
        console.log("Form changed - resetting save state");
        logAlreadySaved = false;
        savedLogId = null;
        savedLogDisplayNumber = null;
        savedLogClient = null;

        // Also reset the save button if it was in 'Saved' state
        const saveBtn = document.getElementById('pdfModalSaveBtn');
        if (saveBtn) {
          saveBtn.disabled = false;
          saveBtn.style.pointerEvents = 'auto';
          const saveDiv = saveBtn.querySelector('div');
          const saveLabel = saveBtn.querySelector('span');
          if (saveDiv) {
            saveDiv.className = 'w-14 h-14 md:w-16 md:h-16 rounded-[1.25rem] md:rounded-3xl border-2 border-black bg-orange-600 shadow-[4px_4px_0px_0px_rgba(0,0,0,1)] flex items-center justify-center group-active:translate-x-[2px] group-active:translate-y-[2px] group-active:shadow-none transition-all hover:bg-orange-700';
          }
          if (saveLabel) {
            saveLabel.innerText = window.APP_LANGUAGES.save || 'Save';
            saveLabel.classList.remove('text-green-600');
            saveLabel.classList.add('text-gray-500');
          }
        }
      }
    });
  }

  // Initialize default due date (14 days)
  updateDueDate(null, null);
});

function updateDueDate(dueDays, dueDate) {
  const dueDateValue = document.getElementById('dueDateValue');
  const dueDaysLabel = document.getElementById('dueDaysLabel');

  let targetDate;
  let daysUntil;

  if (dueDate) {
    // Explicit date provided
    targetDate = new Date(dueDate);
    const baseDate = window.selectedMainDate ? new Date(window.selectedMainDate) : new Date();
    baseDate.setHours(0, 0, 0, 0);
    targetDate.setHours(0, 0, 0, 0);
    daysUntil = Math.ceil((targetDate - baseDate) / (1000 * 60 * 60 * 24));

    // Clear offset if hard date pick
    window.currentDueOffset = null;
  } else {
    // Use days (default to 14 if not provided)
    daysUntil = dueDays !== null && dueDays !== undefined ? parseInt(dueDays) : 14;

    // Store original offset
    window.currentDueOffset = daysUntil;

    // Use selected main date as base (not today)
    targetDate = window.selectedMainDate ? new Date(window.selectedMainDate) : new Date();
    targetDate.setDate(targetDate.getDate() + daysUntil);
  }

  // Format the date
  const lang = window.currentSystemLanguage || 'en';
  let formattedDate;
  if (lang === 'ka') {
    const monthsKa = [
      window.APP_LANGUAGES.jan, window.APP_LANGUAGES.feb, window.APP_LANGUAGES.mar,
      window.APP_LANGUAGES.apr, window.APP_LANGUAGES.may, window.APP_LANGUAGES.jun,
      window.APP_LANGUAGES.jul, window.APP_LANGUAGES.aug, window.APP_LANGUAGES.sep,
      window.APP_LANGUAGES.oct, window.APP_LANGUAGES.nov, window.APP_LANGUAGES.dec
    ];
    formattedDate = `${monthsKa[targetDate.getMonth()]} ${targetDate.getDate()}, ${targetDate.getFullYear()}`;
  } else {
    formattedDate = targetDate.toLocaleDateString('en-US', {
      month: 'short', day: 'numeric', year: 'numeric'
    });
  }

  dueDateValue.innerText = formattedDate;

  // Format the days label
  if (daysUntil === 0) {
    dueDaysLabel.innerText = `(${window.APP_LANGUAGES.due_today || 'due today'})`;
  } else if (daysUntil === 1) {
    dueDaysLabel.innerText = `(${window.APP_LANGUAGES.in_x_days.replace('%{count}', '1') || 'in 1 day'})`;
  } else if (daysUntil < 0) {
    dueDaysLabel.innerText = `(${window.APP_LANGUAGES.x_days_overdue.replace('%{count}', Math.abs(daysUntil)) || Math.abs(daysUntil) + ' days overdue'})`;
    dueDaysLabel.classList.add('text-red-500');
    dueDaysLabel.classList.remove('text-gray-400');
  } else {
    dueDaysLabel.innerText = `(${window.APP_LANGUAGES.in_x_days.replace('%{count}', daysUntil) || 'in ' + daysUntil + ' days'})`;
    dueDaysLabel.classList.remove('text-red-500');
    dueDaysLabel.classList.add('text-gray-400');
  }

  // Store the selected date for calendar
  window.selectedDueDate = targetDate;

  // Sync NET button selected state
  if (typeof updateNetButtonState === 'function') {
    const offset = window.currentDueOffset;
    // Only highlight if offset matches a standard NET value
    if (offset === 7 || offset === 14 || offset === 30) {
      updateNetButtonState(offset);
    } else {
      updateNetButtonState(null);
    }
  }
}

// Calendar State
let calendarViewDate = new Date();

function toggleCalendar(btn) {
  const popup = document.getElementById('calendarPopup');
  const isOpening = popup.classList.contains('hidden');

  if (isOpening) {
    // Initialize calendar to selected date or today
    calendarViewDate = window.selectedDueDate ? new Date(window.selectedDueDate) : new Date();
    renderCalendar();
    popup.classList.remove('hidden');
    if (btn) btn.classList.add('pop-active');
  } else {
    popup.classList.add('hidden');
    // If we don't have btn, find it
    const targetBtn = btn || document.querySelector('button[onclick*="toggleCalendar"]');
    if (targetBtn) targetBtn.classList.remove('pop-active');
  }
}

// Close calendars when clicking outside
document.addEventListener('click', (e) => {
  // Due Date Calendar
  const popup = document.getElementById('calendarPopup');
  const calendarBtn = e.target.closest('button[onclick*="toggleCalendar"]');
  if (popup && !popup.contains(e.target) && !calendarBtn) {
    if (!popup.classList.contains('hidden')) {
      popup.classList.add('hidden');
      const btn = document.querySelector('button[onclick*="toggleCalendar"]');
      if (btn) btn.classList.remove('pop-active');
    }
  }

  // Main Date Calendar
  const mainPopup = document.getElementById('mainCalendarPopup');
  const mainCalendarBtn = e.target.closest('button[onclick*="toggleMainCalendar"]');
  if (mainPopup && !mainPopup.contains(e.target) && !mainCalendarBtn) {
    if (!mainPopup.classList.contains('hidden')) {
      mainPopup.classList.add('hidden');
      const btn = document.querySelector('button[onclick*="toggleMainCalendar"]');
      if (btn) btn.classList.remove('pop-active');
    }
  }
});

function changeCalendarMonth(delta) {
  calendarViewDate.setMonth(calendarViewDate.getMonth() + delta);
  renderCalendar();
}

function renderCalendar() {
  const monthYear = document.getElementById('calendarMonthYear');
  const daysContainer = document.getElementById('calendarDays');

  const year = calendarViewDate.getFullYear();
  const month = calendarViewDate.getMonth();

  // Update header
  const lang = window.currentSystemLanguage || 'en';
  if (lang === 'ka') {
    const monthsKa = [
      window.APP_LANGUAGES.jan, window.APP_LANGUAGES.feb, window.APP_LANGUAGES.mar,
      window.APP_LANGUAGES.apr, window.APP_LANGUAGES.may, window.APP_LANGUAGES.jun,
      window.APP_LANGUAGES.jul, window.APP_LANGUAGES.aug, window.APP_LANGUAGES.sep,
      window.APP_LANGUAGES.oct, window.APP_LANGUAGES.nov, window.APP_LANGUAGES.dec
    ];
    monthYear.innerHTML = `<span class="font-black">${monthsKa[calendarViewDate.getMonth()]}</span> ${calendarViewDate.getFullYear()}`;
  } else {
    monthYear.innerText = calendarViewDate.toLocaleDateString('en-US', { month: 'short', year: 'numeric' });
  }

  // Get first day of month and total days
  const firstDay = new Date(year, month, 1).getDay();
  const daysInMonth = new Date(year, month + 1, 0).getDate();

  // Get today for highlighting
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  // Get invoice start date for minimum due date (due date cannot be before invoice date)
  const invoiceStartDate = window.selectedMainDate ? new Date(window.selectedMainDate) : new Date();
  invoiceStartDate.setHours(0, 0, 0, 0);

  // Get selected date for highlighting
  const selected = window.selectedDueDate ? new Date(window.selectedDueDate) : null;
  if (selected) selected.setHours(0, 0, 0, 0);

  let html = '';

  // Empty cells for days before first day of month
  for (let i = 0; i < firstDay; i++) {
    html += '<div class="w-9 h-8"></div>';
  }

  // Days of the month
  for (let day = 1; day <= daysInMonth; day++) {
    const date = new Date(year, month, day);
    date.setHours(0, 0, 0, 0);

    const isToday = date.getTime() === today.getTime();
    const isSelected = selected && date.getTime() === selected.getTime();
    // Due date cannot be before the invoice start date
    const isBeforeInvoiceDate = date < invoiceStartDate;

    const dateStr = `${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
    const onclick = isBeforeInvoiceDate ? '' : `onclick="selectCalendarDate('${dateStr}')"`;

    let classes = 'w-9 h-8 rounded-lg text-xs font-black flex items-center justify-center cursor-pointer transition-all active:scale-95 active:translate-x-[1px] active:translate-y-[1px] shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] active:shadow-none bg-white active:bg-orange-600 active:text-white ';

    if (isSelected) {
      classes += '!bg-orange-600 !text-white border-2 border-black !shadow-none translate-x-[1px] translate-y-[1px]';
    } else if (isToday) {
      classes += 'border-2 border-orange-600 text-orange-600 md:hover:bg-orange-50';
    } else if (isBeforeInvoiceDate) {
      classes += 'text-gray-300 cursor-not-allowed !shadow-none';
    } else {
      classes += 'md:hover:bg-orange-50 md:hover:text-orange-600 border-2 border-black';
    }

    html += `<button type="button" class="${classes}" ${onclick}>${day}</button>`;
  }

  daysContainer.innerHTML = html;
}

function selectCalendarDate(dateStr) {
  const parts = dateStr.split('-');
  const selectedDate = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]));

  // Use specific date pick (clears NET offset)
  updateDueDate(null, selectedDate);
  // Deselect all NET buttons (manual pick overrides)
  updateNetButtonState(null);
  setTimeout(() => renderCalendar(), 0); // Defer to prevent "click outside" close
}

function setQuickDue(days) {
  updateDueDate(days, null);
  // Highlight the active NET button
  updateNetButtonState(days);
  // Auto-scroll calendar view to show the new due date's month
  if (window.selectedDueDate) {
    calendarViewDate = new Date(window.selectedDueDate);
  }
  setTimeout(() => renderCalendar(), 0);
}

function updateNetButtonState(activeDays) {
  document.querySelectorAll('.net-btn').forEach(btn => {
    const net = parseInt(btn.getAttribute('data-net'));
    if (activeDays !== null && net === activeDays) {
      btn.classList.add('!bg-orange-600', '!text-white', '!shadow-none', 'translate-x-[1px]', 'translate-y-[1px]');
      btn.classList.remove('bg-white');
    } else {
      btn.classList.remove('!bg-orange-600', '!text-white', '!shadow-none', 'translate-x-[1px]', 'translate-y-[1px]');
      btn.classList.add('bg-white');
    }
  });
}

// Main Date Calendar State
let mainCalendarViewDate = new Date();
window.selectedMainDate = new Date(); // Default to today

function toggleMainCalendar(btn) {
  const popup = document.getElementById('mainCalendarPopup');
  const isHidden = popup.classList.contains('hidden');

  if (isHidden) {
    mainCalendarViewDate = new Date(window.selectedMainDate);
    renderMainCalendar();
    popup.classList.remove('hidden');
    if (btn) btn.classList.add('pop-active');
  } else {
    popup.classList.add('hidden');
    const targetBtn = btn || document.querySelector('button[onclick*="toggleMainCalendar"]');
    if (targetBtn) targetBtn.classList.remove('pop-active');
  }
}

function changeMainCalendarMonth(delta) {
  mainCalendarViewDate.setMonth(mainCalendarViewDate.getMonth() + delta);
  renderMainCalendar();
}

function renderMainCalendar() {
  const monthYear = document.getElementById('mainCalendarMonthYear');
  const daysContainer = document.getElementById('mainCalendarDays');
  const lang = window.currentSystemLanguage || 'en';

  if (lang === 'ka') {
    const monthsKa = [
      window.APP_LANGUAGES.jan, window.APP_LANGUAGES.feb, window.APP_LANGUAGES.mar,
      window.APP_LANGUAGES.apr, window.APP_LANGUAGES.may, window.APP_LANGUAGES.jun,
      window.APP_LANGUAGES.jul, window.APP_LANGUAGES.aug, window.APP_LANGUAGES.sep,
      window.APP_LANGUAGES.oct, window.APP_LANGUAGES.nov, window.APP_LANGUAGES.dec
    ];
    monthYear.innerHTML = `<span class="font-black">${monthsKa[mainCalendarViewDate.getMonth()]}</span> ${mainCalendarViewDate.getFullYear()}`;
  } else {
    monthYear.innerText = mainCalendarViewDate.toLocaleDateString('en-US', { month: 'short', year: 'numeric' });
  }

  const year = mainCalendarViewDate.getFullYear();
  const month = mainCalendarViewDate.getMonth();

  const firstDay = new Date(year, month, 1).getDay();
  const daysInMonth = new Date(year, month + 1, 0).getDate();

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const selected = new Date(window.selectedMainDate);
  selected.setHours(0, 0, 0, 0);

  let html = '';
  for (let i = 0; i < firstDay; i++) {
    html += '<div class="w-9 h-8"></div>';
  }

  for (let day = 1; day <= daysInMonth; day++) {
    const date = new Date(year, month, day);
    date.setHours(0, 0, 0, 0);

    const isToday = date.getTime() === today.getTime();
    const isSelected = date.getTime() === selected.getTime();

    let classes = 'w-9 h-8 rounded-lg text-xs font-black flex items-center justify-center cursor-pointer transition-all active:scale-95 active:translate-x-[1px] active:translate-y-[1px] shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] active:shadow-none bg-white active:bg-orange-600 active:text-white ';

    if (isSelected) {
      classes += '!bg-orange-600 !text-white border-2 border-black !shadow-none translate-x-[1px] translate-y-[1px]';
    } else if (isToday) {
      classes += 'border-2 border-orange-600 text-orange-600 md:hover:bg-orange-50';
    } else {
      classes += 'md:hover:bg-orange-50 md:hover:text-orange-600 border-2 border-black';
    }

    const dateStr = `${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
    html += `<button type="button" class="${classes}" onclick="selectMainCalendarDate('${dateStr}')">${day}</button>`;
  }

  daysContainer.innerHTML = html;
}

function selectMainCalendarDate(dateStr) {
  const parts = dateStr.split('-');
  const selectedDate = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]));
  window.selectedMainDate = selectedDate;

  const lang = window.currentSystemLanguage || 'en';
  if (lang === 'ka') {
    const monthsKa = [
      window.APP_LANGUAGES.jan, window.APP_LANGUAGES.feb, window.APP_LANGUAGES.mar,
      window.APP_LANGUAGES.apr, window.APP_LANGUAGES.may, window.APP_LANGUAGES.jun,
      window.APP_LANGUAGES.jul, window.APP_LANGUAGES.aug, window.APP_LANGUAGES.sep,
      window.APP_LANGUAGES.oct, window.APP_LANGUAGES.nov, window.APP_LANGUAGES.dec
    ];
    document.getElementById('dateDisplay').innerText = `${monthsKa[selectedDate.getMonth()]} ${selectedDate.getDate()}, ${selectedDate.getFullYear()}`;
  } else {
    document.getElementById('dateDisplay').innerText = selectedDate.toLocaleDateString('en-US', {
      month: 'short', day: 'numeric', year: 'numeric'
    });
  }

  // Re-calculate Due Date: either re-apply NET offset, or recalc days label for hard-picked date
  if (window.currentDueOffset !== null && window.currentDueOffset !== undefined) {
    updateDueDate(window.currentDueOffset, null);
  } else if (window.selectedDueDate) {
    updateDueDate(null, window.selectedDueDate);
  }

  setTimeout(() => renderMainCalendar(), 0);
}


function addFullSection(title, items, isProtected = false, explicitType = null) {
  const container = document.getElementById("dynamicSections");
  const sectionId = "section_" + Date.now() + "_" + Math.floor(Math.random() * 1000);

  // 1. Detect if this is a Labor/Service section
  const lowerTitle = (title || '').toString().toLowerCase();
  const normalizedType = (explicitType || '').toString().toLowerCase();
  const isLaborService = (normalizedType === 'labor') || /labor|labour|service|install|repair|maintenance|diag|tech|professional/i.test(lowerTitle);

  if (isLaborService) {
    // Route to the special Labor Items Container
    const laborContainer = document.getElementById("laborItemsContainer");
    if (laborContainer) {
      // Show the group
      addLaborSection();
      // Clear existing items in Labor Container (assuming AI sends full list)
      // Exception: If we want to append? Usually AI sends full structure.
      laborContainer.innerHTML = '';

      if (items && items.length > 0) {
        items.forEach(item => {
          if (!item) return;
          const val = typeof item === 'object' ? (item.desc || "") : item;
          const price = typeof item === 'object' ? (item.price ?? "") : "";
          const mode = typeof item === 'object' ? (item.mode || "") : "";
          const taxable = typeof item === 'object' ? (item.taxable) : null;
          const discFlat = typeof item === 'object' ? (item.discount_flat || "") : "";
          const discPercent = typeof item === 'object' ? (item.discount_percent || "") : "";
          const taxRate = typeof item === 'object' ? (item.tax_rate || "") : "";
          const rate = typeof item === 'object' ? (item.rate ?? "") : "";

          const sub_categories = (item && typeof item === 'object') ? (item.sub_categories || []) : [];
          addLaborItem(val, price, mode, taxable, discFlat, discPercent, taxRate, rate, sub_categories);
        });
      } else {
        // Ensure at least one empty item if cleared
        addLaborItem();
      }
      return; // STOP execution, do not create dynamic section
    }
  }

  // --- STANDARD SECTION CREATION ---

  const sectionDiv = document.createElement('div');
  sectionDiv.className = "dynamic-section space-y-3 animate-in fade-in slide-in-from-bottom-2 duration-500";
  // Determine identifier for protection
  if (isProtected) sectionDiv.dataset.protected = explicitType || lowerTitle;

  const isMaterials = ['materials', 'material', 'products', 'product', 'parts', 'part'].includes(normalizedType) || /material|product|part/.test(lowerTitle);
  const isExpenses = ['expenses', 'expense', 'reimbursements', 'reimbursement', 'reimburse'].includes(normalizedType) || /expense|reimburse/.test(lowerTitle);
  const isFees = ['fees', 'fee', 'surcharges', 'surcharge'].includes(normalizedType) || /fee|surcharge/.test(lowerTitle);

  if (isMaterials) sectionDiv.dataset.protected = "materials";
  else if (isExpenses) sectionDiv.dataset.protected = "expenses";
  else if (isFees) sectionDiv.dataset.protected = "fees";

  const resolvedTitle = isMaterials
    ? (window.APP_LANGUAGES.materials || "Materials")
    : isExpenses
      ? (window.APP_LANGUAGES.expenses || "Expenses")
      : isFees
        ? (window.APP_LANGUAGES.fees || "Fees")
        : title;

  // Icons and Colors for sections
  let sectionIcon = "";
  let accentColorClass = "text-orange-600";

  if (isMaterials) {
    sectionIcon = `<svg class="h-4 w-4 text-orange-600 mr-2"><use xlink:href="#icon-material"></use></svg>`;
    accentColorClass = "text-orange-600";
  } else if (isExpenses) {
    sectionIcon = `<svg class="h-4 w-4 mr-2" style="color: #E7000B;"><use xlink:href="#icon-expense"></use></svg>`;
    accentColorClass = "";
  } else if (isFees) {
    sectionIcon = `<svg class="h-4 w-4 mr-2" style="color: #2B7FFF;"><use xlink:href="#icon-fee"></use></svg>`;
    accentColorClass = "";
    // We'll apply inline color for fees title below
  } else {
    // Default Tasks Icon (Clipboard)
    sectionIcon = `<svg class="h-4 w-4 text-orange-600 mr-2"><use xlink:href="#icon-labor"></use></svg>`;
    accentColorClass = "text-orange-600";
  }

  // Auto-protect standard titles
  const forceProtect = isProtected || isMaterials || isExpenses || isFees;

  const sectionInlineColor = isFees ? ' style="color: #2B7FFF;"' : isExpenses ? ' style="color: #E7000B;"' : '';
  const titleElement = forceProtect
    ? `<div class="flex items-center">${sectionIcon}<span class="text-base font-black ${accentColorClass} uppercase tracking-widest section-title"${sectionInlineColor}>${resolvedTitle}</span></div>`
    : `<div class="flex items-center w-2/3">${sectionIcon}<input type="text" value="${resolvedTitle}" class="bg-transparent border-none p-0 text-sm font-black ${accentColorClass} uppercase tracking-widest focus:ring-0 w-full section-title"${sectionInlineColor} onblur="validateCategoryName(this)"></div>`;

  const removeButton = `
        <button type="button" onclick="this.closest('.dynamic-section').remove(); updateTotalsSummary();" 
                class="bg-black text-white w-7 h-7 rounded-full flex items-center justify-center shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] active:shadow-none active:translate-x-[1px] active:translate-y-[1px] active:scale-95 hover:bg-gray-800 transition-all" title="Remove Section">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
          </svg>
        </button>`;

  let addBtnBg = "bg-orange-600 hover:bg-orange-700";
  let addBtnStyle = "";
  if (isExpenses) {
    addBtnBg = "";
    addBtnStyle = "background-color: #E7000B;";
  } else if (isFees) {
    addBtnBg = "";
    addBtnStyle = "background-color: #2B7FFF;";
  }

  const addItemBtn = `<button type="button" onclick="addItem('${sectionId}', '', '', null, '${resolvedTitle}')" 
               class="${addBtnBg} text-white w-7 h-7 rounded-full flex items-center justify-center shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] active:shadow-none active:translate-x-[1px] active:translate-y-[1px] active:scale-95 transition-all" style="${addBtnStyle}" title="Add Item">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="3">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 4v16m8-8H4" />
          </svg>
        </button>`;

  sectionDiv.innerHTML = `
    <header class="flex justify-between items-center group border-b-2 border-black pb-1">
      ${titleElement}
      <div class="flex gap-2 mb-1 shrink-0">
        ${addItemBtn}
        ${removeButton}
      </div>
    </header>
    <div id="${sectionId}" class="pt-2"></div>
  `;
  const type = sectionDiv.dataset.protected || 'other';
  insertSectionInOrder(sectionDiv, type);

  // If no items provided, add an empty item automatically
  if (items.length === 0) {
    addItem(sectionId, "", "", null, resolvedTitle);
  } else {
    items.forEach(item => {
      if (!item) return;

      let val = "";
      let price = "";
      let taxable = null;
      let taxRate = null;
      let discFlat = "";
      let discPercent = "";

      if (typeof item === 'object') {
        val = item.desc || "";
        if (item.qty && item.qty !== '1' && item.qty !== 'N/A') {
          val += ` (x${item.qty})`;
        }
        price = item.price || "";
        if (item.taxable !== undefined && item.taxable !== null) {
          taxable = item.taxable;
        }
        if (item.tax_rate) {
          taxRate = item.tax_rate;
        }
        discFlat = item.discount_flat || "";
        discPercent = item.discount_percent || "";
      } else {
        val = item;
      }

      const sub_categories = (item && typeof item === 'object') ? (item.sub_categories || []) : [];
      addItem(sectionId, val, price, taxable, resolvedTitle, taxRate, (item.qty && item.qty !== 'N/A') ? item.qty : 1, discFlat, discPercent, sub_categories, false);
    });
  }
}

// Validate category names - prevent reserved words
function validateCategoryName(input) {
  const reserved = ['fee', 'fees', 'expense', 'expenses', 'material', 'materials', 'labor', 'labour', 'service', 'services'];
  const val = input.value.toLowerCase().trim();

  if (reserved.some(r => val === r || val === r + 's' || val.includes('labor/service'))) {
    alert((window.APP_LANGUAGES.reserved_category || "\"%{name}\" is a reserved category name. Please choose another.").replace('%{name}', input.value));
    input.value = "Custom";
    input.focus();
  }
}


function updateAddMenuButtons() {
  // Check if Materials/Expenses/Fees/Credit sections already exist
  const hasMaterials = document.querySelector('.dynamic-section[data-protected="materials"]');
  const hasExpenses = document.querySelector('.dynamic-section[data-protected="expenses"]');
  const hasFees = document.querySelector('.dynamic-section[data-protected="fees"]');
  const hasCredit = document.getElementById('creditGroup') && !document.getElementById('creditGroup').classList.contains('hidden');
  const hasLabor = document.getElementById('laborGroup') && !document.getElementById('laborGroup').classList.contains('hidden');

  const materialBtn = document.getElementById('addMaterialBtn');
  const expenseBtn = document.getElementById('addExpenseBtn');
  const feeBtn = document.getElementById('addFeeBtn');
  const creditBtn = document.getElementById('addCreditBtn');
  const laborBtn = document.getElementById('addLaborBtn');

  const updateState = (btn, isDisabled, colorClass) => {
    if (!btn) return;
    btn.disabled = isDisabled;
    if (isDisabled) {
      btn.classList.add('text-gray-300', 'cursor-not-allowed', 'pointer-events-none');
      btn.classList.remove('text-black', 'hover:bg-orange-50', 'hover:text-orange-600', 'hover:bg-red-50', 'hover:text-red-600', 'hover:bg-blue-50', 'hover:text-blue-500');
    } else {
      btn.classList.remove('text-gray-300', 'cursor-not-allowed', 'pointer-events-none');
      // Re-add classes based on type if needed, but the HTML has them.
    }
  };

  updateState(laborBtn, hasLabor);
  updateState(materialBtn, hasMaterials);
  updateState(expenseBtn, hasExpenses);
  updateState(feeBtn, hasFees);
  updateState(creditBtn, hasCredit);

  // Auto-close menu if all items are added
  if (hasLabor && hasMaterials && hasExpenses && hasFees && hasCredit) {
    const dropup = document.getElementById('addMenuDropup');
    const btn = document.getElementById('addMenuBtn');
    if (dropup && !dropup.classList.contains('hidden')) {
      dropup.classList.add('hidden');
      if (btn) btn.classList.remove('pop-active');
    }
  }
}

function toggleAddMenu(btn) {
  const dropup = document.getElementById('addMenuDropup');
  const isOpening = dropup.classList.contains('hidden');

  if (isOpening) {
    if (btn) btn.classList.add('pop-active');
    updateAddMenuButtons();
  } else {
    const targetBtn = btn || document.getElementById('addMenuBtn');
    if (targetBtn) targetBtn.classList.remove('pop-active');
  }

  dropup.classList.toggle('hidden');
}

// Close add menu when clicking outside
// Close add menu when clicking outside
document.addEventListener('click', (e) => {
  const dropup = document.getElementById('addMenuDropup');
  const btn = document.getElementById('addMenuBtn');
  if (dropup && btn && !dropup.contains(e.target) && !btn.contains(e.target)) {
    if (!dropup.classList.contains('hidden')) {
      dropup.classList.add('hidden');
      btn.classList.remove('pop-active');
    }
  }
});

// Helper to enforce section order
function insertSectionInOrder(sectionDiv, type) {
  const container = document.getElementById("dynamicSections");
  const order = { 'materials': 1, 'expenses': 2, 'fees': 3, 'credit': 4 };
  const currentPriority = order[type] ?? 99;

  const children = Array.from(container.children);
  for (let child of children) {
    const childType = child.dataset.protected || '';
    const childPriority = order[childType] ?? 99;

    if (childPriority > currentPriority) {
      container.insertBefore(sectionDiv, child);
      return;
    }
  }
  container.appendChild(sectionDiv);
}

function addMaterialSection() {
  addFullSection(window.APP_LANGUAGES.materials || "Materials", [], true, 'materials');
}

function addExpenseSection() {
  addFullSection(window.APP_LANGUAGES.expenses || "Expenses", [], true, 'expenses');
}

function addFeeSection() {
  addFullSection(window.APP_LANGUAGES.fees || "Fees", [], true, 'fees');
}

// --- MISSING SECTION UTILITIES ---
function addLaborSection() {
  const group = document.getElementById('laborGroup');
  if (group) {
    group.classList.remove('hidden');
    // Ensure at least one item if empty (only has add button)
    const container = document.getElementById('laborItemsContainer');
    if (container && container.querySelectorAll('.labor-item-row').length === 0) {
      addLaborItem();
    } else {
      updateTotalsSummary();
    }
  }
}

function removeLaborSection() {
  const group = document.getElementById('laborGroup');
  if (group) {
    group.classList.add('hidden');
    // Clear all labor items when the section is removed
    const container = document.getElementById('laborItemsContainer');
    if (container) {
      container.querySelectorAll('.labor-item-row').forEach(row => row.remove());
    }
  }
  updateTotalsSummary();
}

function addCreditSection(skipDefault = false) {
  const group = document.getElementById('creditGroup');
  const container = document.getElementById('creditItemsContainer');
  if (group) {
    group.classList.remove('hidden');
    // If empty (e.g. after removal), add a fresh default item (unless skipDefault is true)
    if (!skipDefault && container && container.querySelectorAll('.credit-item-row').length === 0) {
      addCreditItem('creditItemsContainer');
    }
    group.scrollIntoView({ behavior: 'smooth', block: 'center' });
  }
}

function removeCreditSection() {
  const group = document.getElementById('creditGroup');
  const container = document.getElementById('creditItemsContainer');
  if (group) {
    group.classList.add('hidden');
    // Remove all credit rows
    if (container) {
      container.querySelectorAll('.credit-item-row').forEach(row => row.remove());
    }
  }
  updateTotalsSummary();
}

// Add a sub-category bullet point under a Labor/Service item
function addLaborSubCategory(btn) {
  const laborItemRow = btn.closest('.labor-item-row');
  if (!laborItemRow) return;

  const subContainer = laborItemRow.querySelector('.labor-sub-categories');
  if (!subContainer) return;

  const subItem = document.createElement('div');
  subItem.className = "flex items-center gap-2 animate-in fade-in slide-in-from-left-2 duration-300 labor-sub-item";

  subItem.innerHTML = `
    <div class="w-2 h-2 rounded-full bg-black flex-shrink-0"></div>
    <div class="flex-1 flex items-center border-2 border-black rounded-lg bg-white shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] transition-colors relative h-8">
      <input type="text" class="flex-1 bg-transparent border-none text-[11px] font-bold text-black focus:ring-0 py-1 px-3 labor-sub-input placeholder:text-gray-300 min-w-0 outline-none" placeholder="${window.APP_LANGUAGES.subcategory_placeholder || "Description..."}">
    </div>
    <button type="button" onclick="removeLaborSubCategory(this)" class="w-5 h-8 flex items-center justify-center text-gray-300 hover:text-red-500 transition-colors font-bold text-xl flex-shrink-0">×</button>
  `;

  subContainer.appendChild(subItem);
  if (window.innerWidth >= 768) subItem.querySelector('input').focus();

  // Adjust spacing when subcategories are added
  const buttonRow = laborItemRow.querySelector('.labor-action-row');
  if (subContainer && buttonRow) {
    // Keep subcategories spacing (mt-2 mb-2)
    subContainer.classList.remove('mt-0', 'mb-0');
    subContainer.classList.add('mt-2', 'mb-2');
    // Add gap back to button row when subcategories present
    buttonRow.classList.remove('mb-0', 'md:mb-0');
    buttonRow.classList.add('mb-1');
  }

  // Update button color to orange
  updateLaborAddBtnColor(laborItemRow);
}

function removeLaborSubCategory(btn) {
  const laborItemRow = btn.closest('.labor-item-row');
  btn.parentElement.remove();
  if (laborItemRow) {
    // Adjust spacing when subcategories are removed
    const subContainer = laborItemRow.querySelector('.labor-sub-categories');
    const buttonRow = laborItemRow.querySelector('.labor-action-row');
    if (subContainer && buttonRow) {
      const hasSubCategories = subContainer.children.length > 0;
      if (hasSubCategories) {
        // Keep subcategories spacing (mt-2 mb-2)
        subContainer.classList.remove('mt-0', 'mb-0');
        subContainer.classList.add('mt-2', 'mb-2');
        // Add gap back to button row when subcategories present
        buttonRow.classList.remove('mb-0', 'md:mb-0');
        buttonRow.classList.add('mb-1');
      } else {
        // Remove subcategories spacing when empty
        subContainer.classList.remove('mt-2', 'mb-2');
        subContainer.classList.add('mt-0', 'mb-0');
        // Use responsive spacing when no subcategories
        buttonRow.classList.remove('mb-1');
        buttonRow.classList.add('mb-0', 'md:mb-0');
      }
    }
    updateLaborAddBtnColor(laborItemRow);
  }
}

function removeItemSubCategory(btn) {
  const itemRow = btn.closest('.item-row');
  btn.parentElement.remove();
  if (itemRow) {
    // Adjust spacing when subcategories are removed
    const subContainer = itemRow.querySelector('.sub-categories');
    const buttonRow = itemRow.querySelector('.item-action-row');
    if (subContainer && buttonRow) {
      const hasSubCategories = subContainer.children.length > 0;
      if (hasSubCategories) {
        // Keep subcategories spacing (mt-2 mb-2)
        subContainer.classList.remove('mt-0', 'mb-0');
        subContainer.classList.add('mt-2', 'mb-2');
        // Add gap back to button row when subcategories present
        buttonRow.classList.remove('mb-0', 'md:mb-0');
        buttonRow.classList.add('mb-1');
      } else {
        // Remove subcategories spacing when empty
        subContainer.classList.remove('mt-2', 'mb-2');
        subContainer.classList.add('mt-0', 'mb-0');
        // Use responsive spacing when no subcategories
        buttonRow.classList.remove('mb-1');
        buttonRow.classList.add('mb-0', 'md:mb-0');
      }
    }
    updateTotalsSummary();
  }
}

// Add a sub-category bullet point under a standard item
function addItemSubCategory(btn) {
  const itemRow = btn.closest('.item-row');
  if (!itemRow) return;

  const subContainer = itemRow.querySelector('.sub-categories');
  if (!subContainer) return;

  const subItem = document.createElement('div');
  subItem.className = "flex items-center gap-2 animate-in fade-in slide-in-from-left-2 duration-300 sub-item";

  subItem.innerHTML = `
    <div class="w-2 h-2 rounded-full bg-black flex-shrink-0"></div>
    <div class="flex-1 flex items-center border-2 border-black rounded-lg bg-white shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] transition-colors relative h-8">
      <input type="text" class="flex-1 bg-transparent border-none text-[11px] font-bold text-black focus:ring-0 py-1 px-3 sub-input placeholder:text-gray-300 min-w-0 outline-none" placeholder="${window.APP_LANGUAGES.subcategory_placeholder || "Description..."}">
    </div>
    <button type="button" onclick="removeItemSubCategory(this);" class="w-5 h-8 flex items-center justify-center text-gray-300 hover:text-red-500 transition-colors font-bold text-xl flex-shrink-0">×</button>
  `;

  subContainer.appendChild(subItem);
  if (window.innerWidth >= 768) subItem.querySelector('input').focus();

  // Adjust spacing when subcategories are added
  const buttonRow = itemRow.querySelector('.item-action-row');
  if (subContainer && buttonRow) {
    // Keep subcategories spacing (mt-2 mb-2)
    subContainer.classList.remove('mt-0', 'mb-0');
    subContainer.classList.add('mt-2', 'mb-2');
    // Add gap back to button row when subcategories present
    buttonRow.classList.remove('mb-0', 'md:mb-0');
    buttonRow.classList.add('mb-1');
  }

  // Trigger layout adjustment
  requestAnimationFrame(adjustBadgeSpacing);

  // Close menu
  const dropdown = btn.closest('.item-menu-dropdown');
  if (dropdown) {
    dropdown.classList.remove('show');
    const menuBtn = dropdown.previousElementSibling;
    if (menuBtn) {
      menuBtn.classList.remove('active', 'pop-active');
      randomizeIcon(menuBtn);
    }
    // Reset corners
    const container = btn.closest('.border-2.rounded-xl');
    if (container) {
      container.style.borderBottomLeftRadius = '';
    }
  }
}


function updateLaborAddBtnColor(row) {
  // No-op: keep + button always black
}

// Add a new Labor/Service item with simplified structure
// Add a new Labor/Service item with simplified structure
function addLaborItem(value = '', price = '', mode = '', taxable = null, discFlat = '', discPercent = '', taxRate = '', rate = '', sub_categories = [], noFocus = false) {
  const container = document.getElementById('laborItemsContainer');
  if (!container) return;

  const div = document.createElement('div');
  div.className = "flex flex-col gap-2 w-full labor-item-row animate-in fade-in slide-in-from-left-2 duration-300 border-t-2 border-dashed pt-6 mt-6 first:border-0 first:pt-0 first:mt-0";
  div.style.borderColor = "#EA580C";
  // Log ALL addLaborItem attempts for diagnostics
  console.log(`[addLaborItem CALL] Description: "${value}" | Price: "${price}" | TaxableArg: ${taxable} | Scope: "${currentLogTaxScope}"`);

  // Use the same tax fallback logic as addItem
  // true = Forced On, false = Forced Off, null = check defaults (only if price exists)
  if (taxable === null || taxable === undefined) {
    // IMPORTANT: No price = no taxable. Can't tax something with no price.
    const hasPrice = price && price !== "" && parseFloat(price) > 0;

    if (!hasPrice) {
      // No price, no taxable - regardless of scope
      taxable = false;
      console.log(`[addLaborItem TAX DECISION] No price, setting taxable=false`);
    } else {
      const scopeData = (currentLogTaxScope || "").toLowerCase();
      const scope = scopeData.split(",").map(t => t.trim());

      const taxAll = scope.includes("all") || scope.includes("total") || (scope.length >= 4);
      const hasLaborScope = scope.some(s => s.includes("labor"));

      // If scope includes "all" or "labor", the item should be taxable by default
      taxable = (taxAll || hasLaborScope);

      console.log(`[addLaborItem TAX DECISION] Final: ${taxable} | Scope: "${scopeData}"`);
    }
  }

  // If taxable is true but no explicit taxRate, pre-fill with profileTaxRate for inline input
  if (taxable && (!taxRate || taxRate === '' || taxRate === '0')) {
    taxRate = profileTaxRate;
  }

  div.dataset.taxable = (taxRate !== null && taxRate !== undefined && taxRate !== '' && parseFloat(taxRate) > 0) ? 'true' : 'false';

  const currencySymbol = activeCurrencySymbol;
  div.dataset.symbol = currencySymbol;

  // Resolve initial billing mode: default to 'hourly' if global is 'mixed'
  let initialMode = mode || currentLogBillingMode;
  if (initialMode === 'mixed') initialMode = 'hourly';
  div.dataset.billingMode = initialMode;

  const billingMode = initialMode;
  const defaultRate = (rate !== "" && rate !== null && rate !== undefined) ? rate : profileHourlyRate;
  const laborPriceVal = (price === "" || price === null || price === undefined) ? (billingMode === 'hourly' ? "1" : "100") : price;

  // DEFAULT LABOR NAME
  let finalValue = value;
  if (!finalValue || finalValue.trim() === "") {
    finalValue = window.APP_LANGUAGES.professional_services || "Professional Services";
  }

  const labelText = billingMode === 'hourly' ? (window.APP_LANGUAGES.labor_hours_caps || 'LABOR HOURS') : (window.APP_LANGUAGES.labor_price_caps || 'LABOR PRICE');
  const rateLabel = window.APP_LANGUAGES.rate || 'RATE';

  const taxLabel = window.APP_LANGUAGES.tax || 'TAX';
  const taxVal = (taxRate !== null && taxRate !== undefined && taxRate !== '') ? taxRate : '';

  // MUTUALLY EXCLUSIVE: percentage wins if both present; cap values
  let discPercentCleaned = (discPercent !== '' && discPercent !== '0' && discPercent !== 0 && discPercent !== null && discPercent !== undefined) ? discPercent : '';
  let discFlatCleaned = (discFlat !== '' && discFlat !== '0' && discFlat !== 0 && discFlat !== null && discFlat !== undefined) ? discFlat : '';
  if (discPercentCleaned !== '' && parseFloat(discPercentCleaned) > 100) discPercentCleaned = '100';
  const laborBaseForCap = parseFloat(laborPriceVal) || 0;
  const laborRateForCap = parseFloat(defaultRate) || 0;
  const laborGrossForCap = (billingMode === 'hourly') ? laborBaseForCap * laborRateForCap : laborBaseForCap;
  if (discFlatCleaned !== '' && laborGrossForCap > 0 && parseFloat(discFlatCleaned) > laborGrossForCap) discFlatCleaned = cleanNum(laborGrossForCap);
  let hasDiscPercent = discPercentCleaned !== '' && parseFloat(discPercentCleaned) > 0;
  let hasDiscFlat = discFlatCleaned !== '' && parseFloat(discFlatCleaned) > 0;
  if (hasDiscPercent && hasDiscFlat) {
    discFlatCleaned = '';
    hasDiscFlat = false;
  }
  discPercent = discPercentCleaned || discPercent;
  discFlat = discFlatCleaned || discFlat;

  let priceGroupHtml = '';
  if (billingMode === 'hourly') {
    priceGroupHtml = `
      <div class="flex flex-col labor-price-group">
        <div class="flex items-start gap-2">
          <div class="flex flex-col">
            <span class="text-[8px] font-black text-black uppercase tracking-wider ml-2 mb-0.5 labor-label-price">${labelText}</span>
            <div class="flex items-center gap-1.5 px-2.5 h-10 border-2 border-black bg-white rounded-xl labor-price-container">
              <div class="flex items-center justify-center bg-orange-600 text-white border-2 border-black rounded-lg h-6 w-6 shrink-0 select-none">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="3">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
              <input type="number" step="0.1" class="labor-price-input bg-transparent border-none p-0 font-black text-black focus:ring-0 outline-none text-left min-w-0 text-sm placeholder:text-gray-300 w-9" 
                     value="${laborPriceVal}" placeholder="0" oninput="updateTotalsSummary()">
            </div>
          </div>
          <div class="flex flex-col" style="margin-left: -1px; margin-right: -2px;">
            <div class="text-[8px] mb-0.5">&nbsp;</div>
            <div class="flex items-center h-10">
              <span class="text-black font-black text-sm select-none">×</span>
            </div>
          </div>
          <div class="flex flex-col">
            <span class="text-[8px] font-black text-black uppercase tracking-wider ml-2 mb-0.5">${rateLabel}</span>
            <div class="flex items-center gap-1.5 px-2.5 h-10 border-2 border-black bg-white rounded-xl labor-rate-container">
              <div class="flex items-center justify-center bg-orange-600 text-white font-black border-2 border-black rounded-lg h-6 w-6 shrink-0 select-none text-[10px] labor-currency-symbol">
                ${currencySymbol}
              </div>
              <input type="number" step="0.01" class="rate-menu-input bg-transparent border-none p-0 font-black text-black focus:ring-0 outline-none text-left min-w-0 text-sm placeholder:text-gray-300 w-12" 
                     value="${defaultRate}" placeholder="0.00" oninput="updateTotalsSummary()">
            </div>
          </div>
          <div class="flex flex-col labor-tax-wrapper">
            <span class="text-[8px] font-black text-black uppercase tracking-wider ml-2 mb-0.5">${taxLabel}</span>
            <div class="flex items-center gap-1.5 px-2.5 h-10 border-2 border-black rounded-xl tax-wrapper" style="background-color: white;">
              <div class="flex items-center justify-center bg-gray-700 text-white font-black border-2 border-black rounded-lg h-6 w-6 shrink-0 select-none text-[10px]">
                <span>%</span>
              </div>
              <input type="number" step="0.1" class="tax-menu-input bg-transparent border-none p-0 font-black text-black focus:ring-0 outline-none text-left min-w-0 text-sm placeholder:text-gray-300 w-9"
                     value="${taxVal}" placeholder="0" oninput="updateTotalsSummary()">
            </div>
          </div>
        </div>
      </div>`;
  } else {
    priceGroupHtml = `
      <div class="flex flex-col labor-price-group">
        <div class="flex items-start gap-2">
          <div class="flex flex-col">
            <span class="text-[8px] font-black text-black uppercase tracking-wider ml-2 mb-0.5 labor-label-price">${labelText}</span>
            <div class="flex items-center gap-1.5 px-2.5 h-10 border-2 border-black bg-white rounded-xl labor-price-container">
              <div class="flex items-center justify-center bg-orange-600 text-white font-black border-2 border-black rounded-lg h-6 w-6 shrink-0 select-none text-[10px] labor-currency-symbol">
                ${currencySymbol}
              </div>
              <input type="number" step="0.01" class="labor-price-input bg-transparent border-none p-0 font-black text-black focus:ring-0 outline-none text-left min-w-0 text-sm placeholder:text-gray-300 w-20" 
                     value="${laborPriceVal ?? defaultRate}" placeholder="0.00" oninput="updateTotalsSummary()">
            </div>
          </div>
          <div class="flex flex-col labor-tax-wrapper">
            <span class="text-[8px] font-black text-black uppercase tracking-wider ml-2 mb-0.5">${taxLabel}</span>
            <div class="flex items-center gap-1.5 px-2.5 h-10 border-2 border-black rounded-xl tax-wrapper" style="background-color: white;">
              <div class="flex items-center justify-center bg-gray-700 text-white font-black border-2 border-black rounded-lg h-6 w-6 shrink-0 select-none text-[10px]">
                <span>%</span>
              </div>
              <input type="number" step="0.1" class="tax-menu-input bg-transparent border-none p-0 font-black text-black focus:ring-0 outline-none text-left min-w-0 text-sm placeholder:text-gray-300 w-9"
                     value="${taxVal}" placeholder="0" oninput="updateTotalsSummary()">
            </div>
          </div>
        </div>
      </div>`;
  }

  div.innerHTML = `
    <div class="flex items-center gap-2 w-full">
      <div class="flex flex-1 items-center border-2 border-black rounded-xl bg-white shadow-[3px_3px_0px_0px_rgba(0,0,0,1)] min-w-0 main-item-box transition-colors relative">
        <!-- Add Sub-category Button -->
        <button type="button" onclick="addLaborSubCategory(this)" class="h-8 w-9 border-r-2 border-black flex-shrink-0 flex items-center justify-center bg-white transition-colors rounded-l-[10px] labor-add-sub-btn" title="${window.APP_LANGUAGES.add_subcategory || 'Add Description'}">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-black transition-colors" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 4v16m8-8H4" />
          </svg>
          </button>
        <input type="text" value="${finalValue}" class="flex-1 bg-transparent border-none text-sm font-bold text-black focus:ring-0 py-2 px-3 labor-item-input placeholder:text-gray-300 min-w-0 rounded-r-xl" placeholder="${window.APP_LANGUAGES.professional_services || "Professional Services"}" oninput="updateTotalsSummary()">
      </div>
      <button type="button" onclick="this.closest('.labor-item-row').remove(); updateTotalsSummary();" class="remove-labor-btn w-6 h-10 flex items-center justify-center text-gray-300 hover:text-red-500 transition-colors font-bold text-xl flex-shrink-0">×</button>
    </div>
    <!-- Sub-categories container -->
    <div class="labor-sub-categories space-y-2 mt-2 mb-2 pl-6"></div>
    
    <!-- Top row: Billing toggle + ADD DISCOUNT button -->
    <div class="flex items-center gap-2 mb-0 md:mb-0 labor-action-row">
      <div class="billing-pill-container" style="margin:0; border: 2px solid black; border-radius: 10px; overflow: hidden; height: 28px; width: fit-content;">
        <button type="button" class="billing-pill-btn ${billingMode === 'hourly' ? 'active' : ''}" data-mode="hourly" onclick="setLaborRowBillingMode(this, 'hourly')" style="border-radius: 8px; padding: 0 8px;">
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
          ${window.APP_LANGUAGES.hourly || 'Hourly'}
        </button>
        <button type="button" class="billing-pill-btn ${billingMode === 'fixed' ? 'active' : ''}" data-mode="fixed" onclick="setLaborRowBillingMode(this, 'fixed')" style="border-radius: 8px; padding: 0 8px;">
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
          ${window.APP_LANGUAGES.fixed || 'Fixed'}
        </button>
      </div>
      <!-- ADD DISCOUNT button -->
      <div class="relative">
        <button type="button" onclick="toggleLaborDiscountDropdown(this)" class="flex items-center gap-1 px-2.5 h-7 border-2 rounded-lg text-[10px] font-black uppercase tracking-wider transition-colors labor-add-discount-btn" style="background-color: white; border-color: #00A63E; color: #00A63E;">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="3"><path stroke-linecap="round" stroke-linejoin="round" d="M12 4v16m8-8H4" /></svg>
          ${window.APP_LANGUAGES.labor_add_discount || window.APP_LANGUAGES.add_discount || 'ADD DISCOUNT'}
        </button>
        <div class="labor-discount-dropdown hidden absolute left-1/2 -translate-x-1/2 top-full mt-1 z-50 bg-white border-2 border-black rounded-lg overflow-hidden min-w-[160px]">
          <button type="button" onclick="showLaborDiscount(this, 'percent')" class="flex items-center gap-2 w-full px-3 py-2 text-[11px] font-bold text-black hover:bg-green-50 transition-colors">
            <span class="flex items-center justify-center bg-green-600 text-white font-black border-2 border-black rounded-md h-5 w-5 shrink-0 text-[9px]">%</span>
            ${window.APP_LANGUAGES.discount_percentage_type || 'Percentage'}
          </button>
          <button type="button" onclick="showLaborDiscount(this, 'flat')" class="flex items-center gap-2 w-full px-3 py-2 text-[11px] font-bold text-black hover:bg-green-50 transition-colors border-t border-gray-200">
            <span class="flex items-center justify-center bg-green-600 text-white font-black border-2 border-black rounded-md h-5 w-5 shrink-0 text-[9px] discount-flat-symbol">${currencySymbol}</span>
            ${window.APP_LANGUAGES.discount_flat_type || 'Flat'}
          </button>
        </div>
      </div>
    </div>

    <!-- Price / Tax / Discount fields -->
    <div class="flex flex-col md:flex-row md:flex-wrap items-start md:items-end gap-2 labor-inline-row labor-inputs-target">

      <!-- Hours/Price/Tax — injected from priceGroupHtml -->
      ${priceGroupHtml}

      <!-- Discount Group -->
      <div class="flex items-start gap-2 discount-wrapper labor-discount-group">
        <!-- Percentage Discount (hidden by default) -->
        <div class="flex items-end gap-1 labor-discount-percent-wrapper ${hasDiscPercent ? '' : 'hidden'}">
          <div class="flex flex-col">
            <span class="text-[8px] font-black text-black uppercase tracking-wider ml-2 mb-0.5">${window.APP_LANGUAGES.discount || 'DISCOUNT'}</span>
            <div class="flex items-center gap-1.5 px-2.5 h-10 border-2 border-black bg-white rounded-xl">
              <div class="flex items-center justify-center bg-green-600 text-white font-black border-2 border-black rounded-lg h-6 w-6 shrink-0 select-none text-[10px]">
                <span>%</span>
              </div>
              <input type="number" step="0.1" class="discount-percent-input bg-transparent border-none p-0 font-black text-black focus:ring-0 outline-none text-left min-w-0 text-sm placeholder:text-gray-300 w-9"
                     value="${discPercent}"
                     placeholder="0"
                     oninput="updateTotalsSummary()">
            </div>
          </div>
          <button type="button" onclick="removeLaborDiscount(this, 'percent')" class="w-5 h-10 flex items-center justify-center text-gray-300 hover:text-red-500 transition-colors font-bold text-sm flex-shrink-0">×</button>
        </div>
        <!-- Flat Discount (hidden by default) -->
        <div class="flex items-end gap-1 labor-discount-flat-wrapper ${hasDiscFlat ? '' : 'hidden'}">
          <div class="flex flex-col">
            <span class="text-[8px] font-black text-black uppercase tracking-wider ml-2 mb-0.5">${window.APP_LANGUAGES.discount || 'DISCOUNT'}</span>
            <div class="flex items-center gap-1.5 px-2.5 h-10 border-2 border-black bg-white rounded-xl">
              <div class="flex items-center justify-center bg-green-600 text-white font-black border-2 border-black rounded-lg h-6 w-6 shrink-0 select-none text-[10px] discount-flat-symbol">
                ${currencySymbol}
              </div>
              <input type="number" step="0.01" class="discount-flat-input bg-transparent border-none p-0 font-black text-black focus:ring-0 outline-none text-left min-w-0 text-sm placeholder:text-gray-300 w-12"
                     value="${discFlat}"
                     placeholder="0"
                     oninput="updateTotalsSummary()">
            </div>
          </div>
          <button type="button" onclick="removeLaborDiscount(this, 'flat')" class="w-5 h-10 flex items-center justify-center text-gray-300 hover:text-red-500 transition-colors font-bold text-sm flex-shrink-0">×</button>
        </div>
      </div>

    </div>
  `;

  container.appendChild(div);

  // Populate Sub-categories
  if (sub_categories && sub_categories.length > 0) {
    const subContainer = div.querySelector('.labor-sub-categories');
    sub_categories.forEach(sub => {
      if (!sub) return;
      const subItem = document.createElement('div');
      subItem.className = "flex items-center gap-2 animate-in fade-in slide-in-from-left-2 duration-300 labor-sub-item";
      subItem.innerHTML = `
        <div class="w-2 h-2 rounded-full bg-black flex-shrink-0"></div>
        <div class="flex-1 flex items-center border-2 border-black rounded-lg bg-white transition-colors relative h-8">
          <input type="text" class="flex-1 bg-transparent border-none text-[11px] font-bold text-black focus:ring-0 py-1 px-3 labor-sub-input placeholder:text-gray-300 min-w-0 outline-none" value="${String(sub).replace(/"/g, '&quot;')}" placeholder="${window.APP_LANGUAGES.subcategory_placeholder || "Description..."}">
        </div>
        <button type="button" onclick="removeLaborSubCategory(this)" class="w-5 h-8 flex items-center justify-center text-gray-300 hover:text-red-500 transition-colors font-bold text-sm flex-shrink-0">×</button>
      `;
      subContainer.appendChild(subItem);
    });
    updateLaborAddBtnColor(div);
  }

  // Adjust spacing based on subcategories presence
  const laborSubContainer = div.querySelector('.labor-sub-categories');
  const laborButtonRow = div.querySelector('.labor-action-row');
  if (laborSubContainer && laborButtonRow) {
    const hasSubCategories = laborSubContainer.children.length > 0;
    if (hasSubCategories) {
      // Keep subcategories spacing (mt-2 mb-2)
      laborSubContainer.classList.remove('mt-0', 'mb-0');
      laborSubContainer.classList.add('mt-2', 'mb-2');
      // Add gap back to button row when subcategories present
      laborButtonRow.classList.remove('mb-0', 'md:mb-0');
      laborButtonRow.classList.add('mb-1');
    } else {
      // Remove subcategories spacing when empty
      laborSubContainer.classList.remove('mt-2', 'mb-2');
      laborSubContainer.classList.add('mt-0', 'mb-0');
      // Use responsive spacing when no subcategories
      laborButtonRow.classList.remove('mb-1');
      laborButtonRow.classList.add('mb-0', 'md:mb-0');
    }
  }

  // Set initial active state for +DISCOUNT button
  if (hasDiscPercent || hasDiscFlat) {
    const discBtn = div.querySelector('.labor-add-discount-btn');
    if (discBtn) {
      discBtn.style.backgroundColor = '#00A63E';
      discBtn.style.borderColor = '#00A63E';
      discBtn.style.color = 'white';
    }
  }

  // Only focus when user explicitly clicks add (no value pre-filled AND not suppressed)
  if (!value && !price && !mode && !noFocus && window.innerWidth >= 768) {
    div.querySelector('.labor-item-input').focus();
  }
  updateTotalsSummary();
}

function addCreditSection(skipDefault = false) {
  const group = document.getElementById('creditGroup');
  const container = document.getElementById('creditItemsContainer');
  if (group) {
    group.classList.remove('hidden');
    // If empty (e.g. after removal), add a fresh default item (unless skipDefault is true)
    if (!skipDefault && container && container.querySelectorAll('.credit-item-row').length === 0) {
      addCreditItem('creditItemsContainer');
    }
    group.scrollIntoView({ behavior: 'smooth', block: 'center' });
  }
}

function removeLaborSection() {
  const group = document.getElementById('laborGroup');
  if (group) {
    group.classList.add('hidden');
  }
  updateTotalsSummary();
}

function removeCreditSection() {
  const group = document.getElementById('creditGroup');
  const container = document.getElementById('creditItemsContainer');
  if (group) {
    group.classList.add('hidden');
    // Remove all credit rows
    if (container) {
      container.querySelectorAll('.credit-item-row').forEach(row => row.remove());
    }
  }
  updateTotalsSummary();
}

// Add Credit item (Reason + Amount)
function addCreditItem(containerId, reason = (window.APP_LANGUAGES?.courtesy_credit || "Courtesy Credit"), amount = "50") {
  const container = document.getElementById(containerId);
  if (!container) return;

  const div = document.createElement('div');
  div.className = "flex flex-col gap-2 w-full animate-in fade-in slide-in-from-left-2 duration-300 credit-item-row border-t-2 border-dashed pt-6 mt-6 first:border-0 first:pt-0 first:mt-0";
  div.style.borderColor = "#E7000B";

  const currencySymbol = typeof activeCurrencySymbol !== 'undefined' ? activeCurrencySymbol : "$";

  div.innerHTML = `
    <div class="flex items-center gap-2 w-full">
      <div class="flex flex-1 items-center border-2 border-black rounded-xl bg-white shadow-[3px_3px_0px_0px_rgba(0,0,0,1)] min-w-0 main-item-box transition-colors relative">
        <input type="text" value="${reason || (window.APP_LANGUAGES?.courtesy_credit || 'Courtesy Credit')}" class="flex-1 bg-transparent border-none text-sm font-bold text-black focus:ring-0 py-2 px-3 credit-reason-input placeholder:text-gray-300 min-w-0 rounded-xl"
               placeholder="${window.APP_LANGUAGES.reason_for_credit || (window.APP_LANGUAGES?.courtesy_credit || 'Courtesy Credit')}" oninput="updateTotalsSummary()">
      </div>

      <button type="button" 
              onclick="this.closest('.credit-item-row').remove(); updateTotalsSummary();" 
              class="remove-credit-btn w-6 h-10 flex items-center justify-center text-gray-300 hover:text-red-500 transition-colors font-bold text-xl flex-shrink-0">
        ×
      </button>
    </div>

    <div class="flex flex-wrap items-start gap-2">
      <div class="flex flex-col">
        <span class="text-[8px] font-black text-black uppercase tracking-wider ml-2 mb-0.5">${window.APP_LANGUAGES.credit_quantity || window.APP_LANGUAGES.amount || 'AMOUNT'}</span>
        <div class="flex items-center gap-1.5 px-2.5 h-10 border-2 border-black rounded-xl" style="background-color: white;">
          <div class="flex items-center justify-center text-white font-black border-2 border-black rounded-lg h-6 w-6 shrink-0 select-none text-[10px] credit-unit-indicator" style="background-color: #E7000B;">
            ${currencySymbol}
          </div>
          <input type="number" step="0.01"
                 class="credit-amount-input bg-transparent border-none p-0 font-black text-black focus:ring-0 outline-none text-left min-w-0 text-sm placeholder:text-gray-300 w-20"
                 value="${amount}"
                 placeholder="0.00"
                 oninput="updateTotalsSummary()">
        </div>
      </div>
    </div>
  `;

  container.appendChild(div);
}

function randomizeIcon(container) {
  const heads = container.querySelectorAll('path[class^="slider-head-"]');
  heads.forEach(h => {
    const rand = (Math.random() * 14) - 7;
    h.style.transform = `translateX(${rand}px)`;
  });
}

function toggleMenu(btn) {
  const dropdown = btn.nextElementSibling;
  const isShow = dropdown.classList.contains('show');

  // Close all others and reset their container corners
  document.querySelectorAll('.item-menu-dropdown.show').forEach(d => {
    // Don't close the one we just clicked (toggle logic handles it)
    if (d === dropdown) return;

    d.classList.remove('show');
    // Remove active class from buttons
    const otherBtn = d.previousElementSibling;
    if (otherBtn) {
      otherBtn.classList.remove('active', 'pop-active');
      randomizeIcon(otherBtn);
    }

    // Reset corners of their containers
    const container = d.closest('.border-2.rounded-xl');
    if (container) {
      container.style.borderBottomLeftRadius = '';
    }
  });

  if (!isShow) {
    dropdown.classList.add('show');
    btn.classList.add('active', 'pop-active');

    // Rerandomize on click for extra dynamic feel
    randomizeIcon(btn);

    const container = btn.closest('.border-2.rounded-xl');

    // Apply Corner Logic
    if (container) {
      container.style.borderBottomLeftRadius = '0';
    }

  } else {
    // Already open, so close it
    dropdown.classList.remove('show');
    btn.classList.remove('active', 'pop-active');
    randomizeIcon(btn);

    // Reset corners
    const container = btn.closest('.border-2.rounded-xl');
    if (container) {
      container.style.borderBottomLeftRadius = '';
    }
  }
}

function updateBadge(row) {
  const priceInput = row.querySelector('.price-menu-input');
  const taxInput = row.querySelector('.tax-menu-input');
  const priceBadge = row.querySelector('.badge-price');
  const taxBadge = row.querySelector('.badge-tax');
  const afterTaxBadge = row.querySelector('.badge-after-tax');
  const multiplier = row.querySelector('.badge-multiplier');
  const equals = row.querySelector('.badge-equals');

  if (!priceInput || !taxInput) return;

  const priceVal = parseFloat(priceInput.value) || 0;
  const taxRate = parseFloat(taxInput.value) || 0;
  const currencySymbol = activeCurrencySymbol;
  const isTaxable = taxRate > 0;
  row.dataset.taxable = isTaxable ? "true" : "false";

  // Read quantity from input if available, otherwise fallback to dataset
  const qtyInput = row.querySelector('.qty-input');
  let qtyVal = 1;
  if (qtyInput) {
    const val = parseFloat(qtyInput.value);
    // Treat empty or zero as 1 for calculations to prevent NaN or vanishing totals
    qtyVal = (isNaN(val) || val <= 0) ? 1 : val;
  } else {
    qtyVal = parseFloat(row.dataset.qty) || 1;
  }

  // Sync dataset.qty for other functions that might rely on it
  row.dataset.qty = qtyVal;

  // Discount Calculation & Validation — MUTUALLY EXCLUSIVE: only use the visible type
  const discFlatInput = row.querySelector('.discount-flat-input');
  const discPercentInput = row.querySelector('.discount-percent-input');
  const pctWrapper = row.querySelector('.item-discount-percent-wrapper') || row.querySelector('.labor-discount-percent-wrapper');
  const flatWrapper = row.querySelector('.item-discount-flat-wrapper') || row.querySelector('.labor-discount-flat-wrapper');
  const pctVisible = pctWrapper && !pctWrapper.classList.contains('hidden');
  const flatVisible = flatWrapper && !flatWrapper.classList.contains('hidden');

  let discPercent = pctVisible ? (parseFloat(discPercentInput ? discPercentInput.value : 0) || 0) : 0;
  let discFlat = flatVisible ? (parseFloat(discFlatInput ? discFlatInput.value : 0) || 0) : 0;

  const baseTotal = priceVal * qtyVal;

  // Validation: Cap Percentage at 100
  if (discPercent > 100) {
    discPercent = 100;
    if (discPercentInput) discPercentInput.value = "100";
  }

  // Validation: Cap Flat at BaseTotal (can't reduce below 0)
  if (baseTotal > 0 && discFlat > baseTotal) {
    discFlat = baseTotal;
    if (discFlatInput) discFlatInput.value = cleanNum(baseTotal);
  }

  let discountAmount = discFlat + (baseTotal * (discPercent / 100));

  // Final safety cap
  if (discountAmount > baseTotal) {
    discountAmount = baseTotal;
  }

  const subtotal = Math.max(0, baseTotal - discountAmount); // Pre-tax subtotal after discount



  // 1. Update Price Badge (Show discounted amount)
  // Logic: Show if BaseTotal > 0.
  // Exception: Hide if Discount is Active AND Not Taxable (Redundant with top equation).
  // Always show price if > 0 (User Requirement)
  let showPrice = baseTotal > 0;
  // if (discountAmount > 0 && !isTaxable) { showPrice = false; } // REMOVED

  if (showPrice) {
    priceBadge.innerText = getCurrencyFormat(subtotal, activeCurrencyCode);
    priceBadge.classList.remove('hidden');
  } else {
    priceBadge.classList.add('hidden');
  }

  // 1.5 Update Top Scrollable Area (Discount Formula)
  // Elements
  const origPriceBadge = row.querySelector('.badge-original-price');
  const minusOp = row.querySelector('.badge-minus');
  const discAmountBadge = row.querySelector('.badge-discount-amount');
  const equalsOpTop = row.querySelector('.badge-equals-top');
  const discountedPriceBadge = row.querySelector('.badge-discounted-price');
  const oldDiscountBadge = row.querySelector('.badge-discount'); // Legacy

  if (discountAmount > 0 && origPriceBadge) {
    const discMsg = (row.querySelector('.discount-message-input')?.value || "").trim();
    // const msgPrefix = discMsg ? `${discMsg}: ` : ""; // User didn't explicitly ask for message here, but we can keep it inside if needed. 
    // Requirement: "original price badge minues icon flat discount... equals icon calculated price badge"
    // Usually badges are just numbers. Let's stick to numbers for the formula to be clean.

    // Original Price
    origPriceBadge.innerHTML = `<span style="transform: rotateX(180deg); display: flex;">${getCurrencyFormat(baseTotal, activeCurrencyCode)}</span>`;
    origPriceBadge.classList.remove('hidden');

    // Operator
    minusOp.classList.remove('hidden');

    // Discount Amount (Always flat calculated)
    discAmountBadge.innerHTML = `<span style="transform: rotateX(180deg); display: flex;">${getCurrencyFormat(discountAmount, activeCurrencyCode)}</span>`;
    discAmountBadge.classList.remove('hidden');

    // Operator
    equalsOpTop.classList.remove('hidden');

    // Result
    discountedPriceBadge.innerHTML = `<span style="transform: rotateX(180deg); display: flex;">${getCurrencyFormat(subtotal, activeCurrencyCode)}</span>`;
    discountedPriceBadge.classList.remove('hidden');

    if (oldDiscountBadge) oldDiscountBadge.classList.add('hidden');

  } else {
    if (origPriceBadge) origPriceBadge.classList.add('hidden');
    if (minusOp) minusOp.classList.add('hidden');
    if (discAmountBadge) discAmountBadge.classList.add('hidden');
    if (equalsOpTop) equalsOpTop.classList.add('hidden');
    if (discountedPriceBadge) discountedPriceBadge.classList.add('hidden');
    if (oldDiscountBadge) oldDiscountBadge.classList.add('hidden');
  }

  // 2. Update Tax Badge - Only show if taxable AND has a price
  if (isTaxable && subtotal > 0) {
    const displayRate = parseFloat(taxRate); // Strip .0
    taxBadge.innerText = `${displayRate}%`;
    taxBadge.classList.remove('hidden');
    const menuTax = row.querySelector('.menu-item-tax');
    if (menuTax) menuTax.classList.add('active');
  } else {
    taxBadge.classList.add('hidden');
    const menuTax = row.querySelector('.menu-item-tax');
    if (menuTax) menuTax.classList.toggle('active', isTaxable);
  }

  // 3. Update Equation visibility and Result Badge
  let taxAmount = 0;
  if (isTaxable && subtotal > 0) {
    taxAmount = subtotal * (taxRate / 100);

    afterTaxBadge.innerText = getCurrencyFormat(taxAmount, activeCurrencyCode);
    afterTaxBadge.classList.remove('hidden');
    multiplier.classList.remove('hidden');
    equals.classList.remove('hidden');
  } else {
    afterTaxBadge.classList.add('hidden');
    multiplier.classList.add('hidden');
    equals.classList.add('hidden');
  }

  // 4. Item-Specific Subtotal Field (Formula Breakdown)
  const subtotalContainer = row.querySelector('.item-subtotal-container');
  if (subtotalContainer) {
    const finalItemTotal = subtotal + taxAmount;
    const formulaRow = subtotalContainer.querySelector('.item-formula-row');
    if (finalItemTotal > 0 && formulaRow) {
      subtotalContainer.classList.remove('hidden');

      const rowCurrencyCode = row.dataset.currencyCode || activeCurrencyCode;
      const rowCurrencySym = getCurrencySym(rowCurrencyCode);

      let html = `
        <div class="flex items-center justify-center bg-orange-600 text-white font-black border border-black rounded-md px-1.5 h-6 shrink-0 select-none text-[10px] min-w-[24px]">
            ${getCurrencyFormat(subtotal, rowCurrencyCode)}
        </div>
        <div class="flex items-center justify-center mx-1 shrink-0">
            <svg width="8" height="8" viewBox="0 0 24 24" fill="none" stroke="black" stroke-width="4" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>
        </div>
        <div class="flex items-center justify-center bg-gray-700 text-white font-black border border-black rounded-md px-1.5 h-6 shrink-0 select-none text-[10px] min-w-[24px]">
            ${getCurrencyFormat(taxAmount, rowCurrencyCode)}
        </div>
        <div class="flex items-center justify-center mx-1 shrink-0">
            <svg width="8" height="6" viewBox="0 0 24 24" fill="none" stroke="black" stroke-width="4" stroke-linecap="round"><path d="M4 8h16M4 16h16"/></svg>
        </div>
        <div class="flex items-center justify-center bg-orange-600 text-white font-black border-2 border-black rounded-lg h-6 w-6 shrink-0 select-none text-[10px] mr-2">
            ${rowCurrencySym}
        </div>
        <span class="font-black text-black text-sm shrink-0">${cleanNum(finalItemTotal)}</span>
        <div class="w-2 shrink-0 h-1"></div>
      `;
      formulaRow.innerHTML = html;
    } else {
      subtotalContainer.classList.add('hidden');
    }
  }

  // Update totals summary
  updateTotalsSummary();
}

function toggleTaxable(menuItem) {
  /* New Toggle Taxable Logic */
  const row = menuItem.closest('.item-row');
  const wrapper = menuItem.closest('.tax-wrapper');
  const taxInputRow = wrapper.querySelector('.tax-inputs-row');
  const taxInput = wrapper.querySelector('.tax-menu-input');

  const priceWrapper = row.querySelector('.price-wrapper');
  const priceInputRow = priceWrapper.querySelector('.price-inputs-row');
  const priceMenuItem = row.querySelector('.menu-item-price');
  const priceInput = row.querySelector('.price-menu-input');
  const priceLabel = priceMenuItem.querySelector('span');
  const priceIcon = priceMenuItem.querySelector('.menu-icon');

  // Toggle Taxable State
  let newTaxableState = false;
  if (menuItem.classList.contains('active')) {
    menuItem.classList.remove('active');
    taxInputRow.classList.add('hidden');
    taxInputRow.classList.remove('grid');
    newTaxableState = false;
  } else {
    menuItem.classList.add('active');
    taxInputRow.classList.remove('hidden');
    taxInputRow.classList.add('grid');
    if (!taxInput.value) {
      taxInput.value = defaultGlobalTaxRate;
    }

    // Auto-enable Price if not active, and populate default if empty
    if (!priceMenuItem.classList.contains('active')) {
      priceMenuItem.classList.add('active');
      priceInputRow.classList.remove('hidden'); // SHOW PRICE INPUT
      priceInputRow.classList.add('grid');
      if (!priceInput.value || parseFloat(priceInput.value) === 0) {
        priceInput.value = "10"; // Default price
      }
    }
    newTaxableState = true;
  }

  row.dataset.taxable = newTaxableState; // Keep dataset sync
  updateBadge(row);
  updateHamburgerGlow(row);

  // --- DEPENDENCY LOGIC ---
  if (newTaxableState) {
    priceLabel.style.opacity = "0.5";
    priceIcon.style.opacity = "0.5";
    priceMenuItem.style.cursor = "not-allowed";
  } else {
    const discountMenuItem = row.querySelector('.menu-item-discount');
    const isDiscountActive = discountMenuItem && discountMenuItem.classList.contains('active');

    if (!isDiscountActive) {
      priceLabel.style.opacity = "1";
      priceIcon.style.opacity = "1";
      priceMenuItem.style.cursor = "pointer";
    }
  }

  // If turning ON, focus the TAX input
  if (newTaxableState) {
    setTimeout(() => taxInput.focus(), 50);
  }
}


function toggleLaborTaxable(menuItem) {
  const laborRow = menuItem.closest('.labor-item-row');
  if (!laborRow) return; // specific to per-item labor now
  const isTaxable = laborRow.dataset.taxable === "true";
  const newTaxableState = !isTaxable;
  laborRow.dataset.taxable = newTaxableState;

  const wrapper = menuItem.closest('.tax-wrapper');
  const taxInputRow = wrapper.querySelector('.tax-inputs-row');
  const taxInput = wrapper.querySelector('.tax-menu-input');

  if (newTaxableState) {
    menuItem.classList.add('active');
    taxInputRow.classList.remove('hidden');
    taxInputRow.classList.add('grid');
    if (!taxInput.value || taxInput.value === "0") {
      // Should pull default from somewhere if needed, currently value is in HTML or user set
    }
    setTimeout(() => taxInput.focus(), 50);
  } else {
    menuItem.classList.remove('active');
    taxInputRow.classList.add('hidden');
    taxInputRow.classList.remove('grid');
  }



  updateTotalsSummary();
  updateHamburgerGlow(laborRow);
}

function updateHamburgerGlow(container) {
  const isLegacyLabor = container.id === 'laborBox';
  const isLaborItem = container.classList.contains('labor-item-row');
  const isTaxable = container.dataset.taxable === "true";
  const discountMenuItem = container.querySelector('.menu-item-discount');
  const isDiscountActive = discountMenuItem && discountMenuItem.classList.contains('active');

  // Disable glow if value is 0 or empty (Labor only)
  if (isLaborItem) {
    const input = container.querySelector('.labor-price-input');
    if (input) {
      const val = parseFloat(input.value) || 0;
      if (val === 0) {
        const sliderIcon = container.querySelector('.slider-icon');
        if (sliderIcon) {
          sliderIcon.classList.remove('text-orange-600', 'text-green-600');
          sliderIcon.classList.add('text-black');
        }
        return;
      }
    }
  }

  let isOrange = isTaxable;
  if (!isLegacyLabor && !isLaborItem) {
    const priceMenuItem = container.querySelector('.menu-item-price');
    const priceActive = priceMenuItem && priceMenuItem.classList.contains('active');
    if (priceActive) isOrange = true;
  }
  const sliderIcon = container.querySelector('.slider-icon');
  if (sliderIcon) {
    if (isOrange) {
      sliderIcon.classList.remove('text-black', 'text-green-600');
      sliderIcon.classList.add('text-orange-600');
    } else if (isDiscountActive) {
      sliderIcon.classList.remove('text-black', 'text-orange-600');
      sliderIcon.classList.add('text-green-600');
    } else {
      sliderIcon.classList.remove('text-orange-600', 'text-green-600');
      sliderIcon.classList.add('text-black');
    }
  }
}

function updateLaborBadge() {
  const laborBox = document.getElementById('laborBox');
  const isTaxable = laborBox.dataset.taxable === "true";
  const taxBadge = document.getElementById('laborTaxBadge');
  const timeInput = document.getElementById('editTime');
  const afterTaxDisplay = document.getElementById('laborAfterTaxDisplay');
  const value = parseFloat(timeInput.value) || 0;
  const taxInput = laborBox.querySelector('.tax-menu-input');
  let currentTaxRate = taxInput && taxInput.value ? parseFloat(taxInput.value) : (parseFloat(laborBox.dataset.taxRate) || parseFloat(defaultGlobalTaxRate));
  const discFlatInput = laborBox.querySelector('.discount-flat-input');
  const discPercentInput = laborBox.querySelector('.discount-percent-input');
  let discFlat = parseFloat(discFlatInput ? discFlatInput.value : 0) || 0;
  let discPercent = parseFloat(discPercentInput ? discPercentInput.value : 0) || 0;
  const billingMode = currentLogBillingMode;
  const hourlyRateInput = document.getElementById('editHourlyRate');
  const currentHourlyRate = (hourlyRateInput && hourlyRateInput.value) ? parseFloat(hourlyRateInput.value) : (parseFloat(laborBox.dataset.hourlyRate) || profileHourlyRate);
  const baseCost = billingMode === 'fixed' ? value : value * currentHourlyRate;
  if (discPercent > 100) { discPercent = 100; discPercentInput.value = "100"; }
  if (discFlat > baseCost && baseCost > 0) { discFlat = baseCost; discFlatInput.value = cleanNum(baseCost); }
  let discountAmount = discFlat + (baseCost * (discPercent / 100));
  if (discountAmount > baseCost) discountAmount = baseCost;
  const laborCost = Math.max(0, baseCost - discountAmount);
  const discountBadge = document.getElementById('laborDiscountBadge');
  if (discountAmount > 0) {
    const currencySym = typeof activeCurrencySymbol !== 'undefined' ? activeCurrencySymbol : "$";
    if (discPercent > 0 && discFlat === 0) {
      discountBadge.innerText = `-${cleanNum(discPercent)}%`;
    } else {
      discountBadge.innerText = `-${currencySym}${cleanNum(discountAmount)}`;
    }
    discountBadge.classList.remove('hidden');
  } else {
    discountBadge.classList.add('hidden');
  }
  if (isTaxable && laborCost > 0) {
    taxBadge.innerText = `${cleanNum(currentTaxRate)}%`;
    taxBadge.classList.remove('hidden');
  } else {
    taxBadge.classList.add('hidden');
  }
  let tax = isTaxable ? laborCost * (currentTaxRate / 100) : 0;
  const total = laborCost + tax;
  const currencySym = typeof activeCurrencySymbol !== 'undefined' ? activeCurrencySymbol : "$";
  if (total <= 0) {
    afterTaxDisplay.innerText = `${currencySym} ${window.APP_LANGUAGES.no_charge || "NO CHARGE"}`;
  } else {
    afterTaxDisplay.innerText = cleanNum(total);
  }

  // Ensure icon glow updates based on value
  updateHamburgerGlow(laborBox);

  // Update totals summary
  updateTotalsSummary();
}


function togglePrice(menuItem) {
  const row = menuItem.closest('.item-row');
  const isTaxable = row.dataset.taxable === "true";

  // Prevent disabling if Taxable is ON OR Discount is ON
  const discountMenuItem = row.querySelector('.menu-item-discount');
  const isDiscount = discountMenuItem && discountMenuItem.classList.contains('active');

  if ((isTaxable || isDiscount) && menuItem.classList.contains('active')) {
    return;
  }

  const wrapper = menuItem.closest('.price-wrapper');
  const priceInputRow = wrapper.querySelector('.price-inputs-row');
  const priceInput = wrapper.querySelector('.price-menu-input');

  // If globally disabled (due to Taxable/Discount being active), prevent interaction
  if (menuItem.style.cursor === "not-allowed") return;

  if (menuItem.classList.contains('active')) {
    menuItem.classList.remove('active');
    priceInputRow.classList.add('hidden');
    priceInputRow.classList.remove('grid');
    priceInput.value = "";
  } else {
    menuItem.classList.add('active');
    priceInputRow.classList.remove('hidden');
    priceInputRow.classList.add('grid');
    // Set default value if empty when activating
    if (!priceInput.value || parseFloat(priceInput.value) === 0) {
      priceInput.value = "10";
    }
    setTimeout(() => priceInput.focus(), 50);
  }

  updateBadge(row);
  updateHamburgerGlow(row);
  updateTotalsSummary();
}

function toggleDiscount(menuItem) {
  const container = menuItem.closest('.item-row') || menuItem.closest('.labor-item-row') || menuItem.closest('#laborBox');
  const wrapper = menuItem.closest('.discount-wrapper');
  const inputsRow = wrapper.querySelector('.discount-inputs-row');

  menuItem.classList.toggle('active');
  const isActive = menuItem.classList.contains('active');

  const flatInput = inputsRow.querySelector('.discount-flat-input');

  if (isActive) {
    inputsRow.classList.remove('hidden');
    inputsRow.classList.add('grid'); // Ensure grid layout

    // 1. Auto-Activate and Lock Price (for Items) FIRST
    if (container.id !== 'laborBox') {
      const priceMenuItem = container.querySelector('.menu-item-price');

      if (priceMenuItem) {
        const priceInputRow = container.querySelector('.price-inputs-row');
        const priceInput = container.querySelector('.price-menu-input');
        const priceLabel = priceMenuItem.querySelector('span');
        const priceIcon = priceMenuItem.querySelector('.menu-icon');

        if (!priceMenuItem.classList.contains('active')) {
          priceMenuItem.classList.add('active');
          // SHOW PRICE INPUT ROW
          priceInputRow.classList.remove('hidden');
          priceInputRow.classList.add('grid');

          if (!priceInput.value || parseFloat(priceInput.value) === 0) {
            priceInput.value = "10";
          }
        }
        // Lock UI
        priceLabel.style.opacity = "0.5";
        priceIcon.style.opacity = "0.5";
        priceMenuItem.style.cursor = "not-allowed";
      }
    }

    // 2. Set Default Discount Value (5) and Auto-Adjust Price/Labor
    const percentVal = inputsRow.querySelector('.discount-percent-input').value;
    if (!flatInput.value || flatInput.value === "0" || flatInput.value === "") {
      if (!percentVal || percentVal === "0" || percentVal === "") {
        flatInput.value = "5";
      }
    }

    const currentFlat = parseFloat(flatInput.value) || 0;
    if (currentFlat > 0) {
      // Auto-adjust Labor
      if (container.classList.contains('labor-item-row')) {
        const laborInput = container.querySelector('.labor-price-input');
        const rateInput = container.querySelector('.rate-menu-input');
        const currentHours = parseFloat(laborInput.value) || 0;
        const currentRate = parseFloat(rateInput?.value) || 0;

        if (currentHours < 1) laborInput.value = "1";

        let newHours = parseFloat(laborInput.value) || 1;
        let itemAmount = newHours * (parseFloat(rateInput?.value) || 20); // Fallback rate if 0

        if (itemAmount < currentFlat) {
          if (rateInput) {
            rateInput.value = currentFlat.toFixed(2);
          } else {
            laborInput.value = currentFlat.toFixed(2);
          }
        }
      }
      // Auto-adjust Standard Items
      else if (container.classList.contains('item-row')) {
        const priceInput = container.querySelector('.price-menu-input');
        const currentPrice = parseFloat(priceInput.value) || 0;
        if (currentPrice < currentFlat) {
          priceInput.value = currentFlat.toFixed(2);
        }
      }
    }

    // 3. Update Badges
    if (container.classList.contains('labor-item-row')) {
      updateTotalsSummary();
    } else if (container.id === 'laborBox') {
      updateLaborBadge();
    } else {
      updateBadge(container);
    }

    setTimeout(() => flatInput.focus(), 50);

  } else {
    inputsRow.classList.add('hidden');
    // Clear inputs
    const percentInput = inputsRow.querySelector('.discount-percent-input');
    if (flatInput) flatInput.value = "";
    if (percentInput) percentInput.value = "";

    // Unlock Price UI if needed (for Items)
    if (container.id !== 'laborBox' && !container.classList.contains('labor-item-row')) {
      const priceMenuItem = container.querySelector('.menu-item-price');

      if (priceMenuItem) {
        const priceLabel = priceMenuItem.querySelector('span');
        const priceIcon = priceMenuItem.querySelector('.menu-icon');
        const isTaxable = container.dataset.taxable === "true";

        // Only unlock if Taxable is ALSO not active
        if (!isTaxable) {
          priceLabel.style.opacity = "1";
          priceIcon.style.opacity = "1";
          priceMenuItem.style.cursor = "pointer";
        }
      }
    }

    if (container.classList.contains('labor-item-row')) {
      updateTotalsSummary();
    } else if (container.id === 'laborBox') {
      updateLaborBadge(); // Legacy support if box still exists
    } else {
      updateBadge(container);
    }
  }

  if (container.classList.contains('labor-item-row')) {
    updateTotalsSummary();
  }
  updateHamburgerGlow(container);
}

function addItem(containerId, value = "", price = "", taxable = null, sectionTitle = "", taxRate = null, qty = 1, discFlat = "", discPercent = "", sub_categories = [], isManualAdd = true) {
  // --- SMART QTY EXTRACTION AND DESC CLEANING ---
  let finalValue = (value || "").trim();
  let finalQty = qty || 1;
  const qtyPatterns = [
    { regex: /[\(\s]x(\d+)[\)]?$/i, group: 1 },        // (x2), x2 at end
    { regex: /[\(\s]\((\d+)\)$/i, group: 1 },          // (2) at end
    { regex: /^(\d+)\s*x\s+/i, group: 1 },             // 2x at start
    { regex: /[\(\s](\d+)\s*units?$/i, group: 1 }      // 2 units at end
  ];

  for (const p of qtyPatterns) {
    const match = finalValue.match(p.regex);
    if (match) {
      const extracted = parseFloat(match[p.group]);
      if (!isNaN(extracted) && extracted > 0) {
        if (finalQty === 1) finalQty = extracted;
        finalValue = finalValue.replace(p.regex, '').trim();
        // Clean up any remaining empty parentheses
        finalValue = finalValue.replace(/\(\s*\)$/, '').trim();
        break;
      }
    }
  }

  const currencySymbol = typeof activeCurrencySymbol !== 'undefined' ? activeCurrencySymbol : "$";
  const subtotalLabelText = window.APP_LANGUAGES.after_tax || "AFTER TAX";

  // Default taxable logic and item naming
  const lowerTitle = (sectionTitle || "").toLowerCase();

  // Detect section type from container's parent data-protected attribute (most reliable)
  const containerEl = document.getElementById(containerId);
  const parentSection = containerEl ? containerEl.closest('.dynamic-section') : null;
  const protectedType = parentSection ? (parentSection.dataset.protected || "") : "";

  // Localized checks
  const matKey = (window.APP_LANGUAGES.materials || "").toLowerCase();
  const feeKey = (window.APP_LANGUAGES.fees || "").toLowerCase();
  const expKey = (window.APP_LANGUAGES.expenses || "").toLowerCase();

  const isLaborSection = protectedType === 'labor' || /labor|service|install|diag|repair|maintenance|tech|professional/i.test(lowerTitle) || (window.APP_LANGUAGES.professional_services && lowerTitle.includes(window.APP_LANGUAGES.professional_services.toLowerCase()));
  const isMaterialSection = protectedType === 'materials' || /material|part|item/i.test(lowerTitle) || (matKey && lowerTitle.includes(matKey));
  const isFeeSection = protectedType === 'fees' || /fee|surcharge/i.test(lowerTitle) || (feeKey && lowerTitle.includes(feeKey));
  const isExpenseSection = protectedType === 'expenses' || /expense|reimburse/i.test(lowerTitle) || (expKey && lowerTitle.includes(expKey));

  // DEFAULT ITEM NAME based on section
  if (!finalValue || finalValue.trim() === "") {
    if (isMaterialSection) finalValue = window.APP_LANGUAGES.item_material || "Material";
    else if (isFeeSection) finalValue = window.APP_LANGUAGES.item_fee || "Fee";
    else if (isExpenseSection) finalValue = window.APP_LANGUAGES.item_expense || "Expense";
    else finalValue = window.APP_LANGUAGES.item || "Item";
  }

  // Log ALL addItem attempts for diagnostics
  console.log(`[addItem CALL] Section: "${sectionTitle}" | Price: "${price}" | TaxableArg: ${taxable} | Scope: "${currentLogTaxScope}"`);

  // If taxable is exactly false, we respect it as "No Tax".
  // null = check defaults, BUT only if there's a price to tax!
  if (taxable === null || taxable === undefined) {
    // IMPORTANT: No price = no taxable. Can't tax something with no price.
    const hasPrice = price && price !== "" && parseFloat(price) > 0;

    if (!hasPrice) {
      // No price, no taxable - regardless of scope
      taxable = false;
      console.log(`[addItem TAX DECISION] No price, setting taxable=false`);
    } else {
      // Has price, check tax scope
      const scopeData = (currentLogTaxScope || "").toLowerCase();
      const scope = scopeData.split(",").map(t => t.trim());

      const taxAll = scope.includes("all") || scope.includes("total") || (scope.length >= 4);

      const hasLaborScope = scope.some(s => s.includes("labor"));
      const hasMaterialScope = scope.some(s => s.includes("material") || s.includes("part"));
      const hasFeeScope = scope.some(s => s.includes("fee") || s.includes("surcharge"));
      const hasExpenseScope = scope.some(s => s.includes("expense") || s.includes("reimburse"));

      if (taxAll) {
        taxable = true;
      } else {
        if (isMaterialSection && hasMaterialScope) taxable = true;
        else if (isLaborSection && hasLaborScope) taxable = true;
        else if (isFeeSection && hasFeeScope) taxable = true;
        else if (isExpenseSection && hasExpenseScope) taxable = true;
        else taxable = false;
      }

      console.log(`[addItem TAX DECISION] Final: ${taxable} | SectionUsed: ${isLaborSection ? 'Labor' : isMaterialSection ? 'Materials' : 'Other'} | Scope: "${scopeData}"`);
    }
  }



  // Default Tax Rate
  const globalRate = profileTaxRate;
  if ((taxRate === null || taxRate === undefined || taxRate === '') && taxable) {
    taxRate = globalRate;
  }

  // Determine divider color based on section type
  let dividerClasses = "border-t-2 border-dashed pt-6 mt-6 first:border-0 first:pt-0 first:mt-0";
  let dividerInlineStyle = "";
  if (isExpenseSection) {
    dividerInlineStyle = "border-color: #E7000B;";
  } else if (isFeeSection) {
    dividerInlineStyle = "border-color: #2B7FFF;";
  } else {
    // Default for LABOR and PRODUCTS
    dividerInlineStyle = "border-color: #EA580C;";
  }

  // Inputs (Price and Tax)
  const hasPrice = price && price !== "" && price !== "0" && price !== "0.00";
  const priceVal = hasPrice ? cleanNum(price) : "";

  // Discount Logic for Initial Load — MUTUALLY EXCLUSIVE: percentage wins if both present
  let discFlatVal = discFlat ? cleanNum(discFlat) : "";
  let discPercentVal = discPercent ? cleanNum(discPercent) : "";
  // Cap percentage at 100
  if (discPercentVal !== '' && parseFloat(discPercentVal) > 100) discPercentVal = '100';
  // Cap flat at base price (price * qty)
  const baseForCap = (parseFloat(priceVal) || 0) * (finalQty || 1);
  if (discFlatVal !== '' && baseForCap > 0 && parseFloat(discFlatVal) > baseForCap) discFlatVal = cleanNum(baseForCap);
  let hasDiscPercent = discPercentVal !== '' && discPercentVal !== '0' && parseFloat(discPercentVal) > 0;
  let hasDiscFlat = discFlatVal !== '' && discFlatVal !== '0' && parseFloat(discFlatVal) > 0;
  // Mutual exclusivity: if both present, keep percentage, clear flat
  if (hasDiscPercent && hasDiscFlat) {
    discFlatVal = '';
    hasDiscFlat = false;
  }
  const hasTaxPreset = taxRate !== null && taxRate !== undefined && taxRate !== '' && parseFloat(taxRate) > 0;
  const usesPriceToggle = isMaterialSection || isExpenseSection || isFeeSection;
  const isPriceActiveDefault = usesPriceToggle ? (hasPrice || hasTaxPreset || hasDiscPercent || hasDiscFlat) : true;

  const div = document.createElement('div');
  div.dataset.taxable = (taxRate !== null && taxRate !== undefined && taxRate !== '' && parseFloat(taxRate) > 0) ? 'true' : 'false';
  div.dataset.symbol = currencySymbol;
  div.dataset.qty = finalQty;
  div.dataset.priceToggleEligible = usesPriceToggle ? 'true' : 'false';
  div.dataset.priceActive = isPriceActiveDefault ? 'true' : 'false';
  div.className = `flex flex-col gap-2 w-full animate-in fade-in slide-in-from-left-2 duration-300 item-row transition-all ${dividerClasses}`;
  if (dividerInlineStyle) div.style.cssText = dividerInlineStyle;

  const addPriceButtonHtml = usesPriceToggle
    ? `<button type="button" onclick="toggleItemPrice(this)" class="flex items-center gap-1 px-2.5 h-7 border-2 rounded-lg text-[10px] font-black uppercase tracking-wider transition-colors item-add-price-btn" style="background-color: white; border-color: #EA580C; color: #EA580C;">
         <svg xmlns="http://www.w3.org/2000/svg" class="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="3"><path stroke-linecap="round" stroke-linejoin="round" d="M12 4v16m8-8H4" /></svg>
         ${window.APP_LANGUAGES.add_price || 'ADD PRICE'}
       </button>`
    : '';

  div.innerHTML = `
      <div class="flex items-center gap-2 w-full">
        <div class="flex flex-1 items-center border-2 border-black rounded-xl bg-white shadow-[3px_3px_0px_0px_rgba(0,0,0,1)] min-w-0 main-item-box transition-colors relative">
          <!-- Add Sub-category Button -->
          <button type="button" onclick="addItemSubCategory(this)" class="h-8 w-8 border-r-2 border-black flex-shrink-0 flex items-center justify-center bg-white transition-colors rounded-l-[10px] item-add-sub-btn" title="${window.APP_LANGUAGES.add_subcategory || 'Add Description'}">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-black transition-colors" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 4v16m8-8H4" />
            </svg>
          </button>
          <input type="text" value="${finalValue}" 
                 class="flex-1 bg-transparent border-none text-sm font-bold text-black focus:ring-0 py-2 px-3 item-input placeholder:text-gray-300 min-w-0"
                 placeholder="${window.APP_LANGUAGES.description_placeholder || "Description..."}" oninput="updateTotalsSummary()">
        </div>
        <button type="button" onclick="this.closest('.item-row').remove(); updateTotalsSummary();" 
                class="remove-item-btn w-6 h-10 flex items-center justify-center text-gray-300 hover:text-red-500 transition-colors font-bold text-xl flex-shrink-0">×</button>
      </div>
      <!-- Sub-categories container -->
      <div class="sub-categories pl-6 space-y-2 mt-2 mb-2"></div>
      
      <!-- Top row: ADD PRICE + ADD DISCOUNT buttons -->
      <div class="flex items-center gap-2 mb-0 md:mb-0 item-action-row">
        ${addPriceButtonHtml}
        <!-- ADD DISCOUNT button -->
        <div class="relative item-add-discount-wrap ${usesPriceToggle && !isPriceActiveDefault ? 'hidden' : ''}">
          <button type="button" onclick="toggleItemDiscountDropdown(this)" class="flex items-center gap-1 px-2.5 h-7 border-2 rounded-lg text-[10px] font-black uppercase tracking-wider transition-colors item-add-discount-btn" style="background-color: white; border-color: #00A63E; color: #00A63E;">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="3"><path stroke-linecap="round" stroke-linejoin="round" d="M12 4v16m8-8H4" /></svg>
            ${window.APP_LANGUAGES.add_discount || 'ADD DISCOUNT'}
          </button>
          <div class="item-discount-dropdown hidden absolute left-1/2 -translate-x-1/2 top-full mt-1 z-50 bg-white border-2 border-black rounded-lg overflow-hidden min-w-[160px]">
            <button type="button" onclick="showItemDiscount(this, 'percent')" class="flex items-center gap-2 w-full px-3 py-2 text-[11px] font-bold text-black hover:bg-green-50 transition-colors">
              <span class="flex items-center justify-center bg-green-600 text-white font-black border-2 border-black rounded-md h-5 w-5 shrink-0 text-[9px]">%</span>
              ${window.APP_LANGUAGES.discount_percentage_type || 'Percentage'}
            </button>
            <button type="button" onclick="showItemDiscount(this, 'flat')" class="flex items-center gap-2 w-full px-3 py-2 text-[11px] font-bold text-black hover:bg-green-50 transition-colors border-t border-gray-200">
              <span class="flex items-center justify-center bg-green-600 text-white font-black border-2 border-black rounded-md h-5 w-5 shrink-0 text-[9px] discount-flat-symbol">${currencySymbol}</span>
              ${window.APP_LANGUAGES.discount_flat_type || 'Flat'}
            </button>
          </div>
        </div>
      </div>
      <!-- Price / Tax / Discount fields (flex-wrap so discount wraps on mobile) -->
      <div class="flex flex-wrap items-start gap-2 item-inputs-target">
        <!-- PRICE -->
        <div class="flex flex-col item-price-wrapper ${usesPriceToggle && !isPriceActiveDefault ? 'hidden' : ''}">
          <span class="text-[8px] font-black text-black uppercase tracking-wider ml-2 mb-0.5">${window.APP_LANGUAGES.price || 'PRICE'}</span>
          <div class="flex items-center gap-1.5 px-2.5 h-10 border-2 border-black bg-white rounded-xl">
            <div class="flex items-center justify-center bg-orange-600 text-white font-black border-2 border-black rounded-lg h-6 w-6 shrink-0 select-none text-[10px] price-input-symbol">
              ${currencySymbol}
            </div>
            <input type="number" step="0.01" class="price-menu-input bg-transparent border-none p-0 font-black text-black focus:ring-0 outline-none text-left min-w-0 text-sm placeholder:text-gray-300 w-20"
                   value="${priceVal}" placeholder="0.00" oninput="updateTotalsSummary()">
          </div>
        </div>
        <!-- TAX -->
        <div class="flex flex-col item-tax-wrapper ${usesPriceToggle && !isPriceActiveDefault ? 'hidden' : ''}">
          <span class="text-[8px] font-black text-black uppercase tracking-wider ml-2 mb-0.5">${window.APP_LANGUAGES.tax || 'TAX'}</span>
          <div class="flex items-center gap-1.5 px-2.5 h-10 border-2 border-black rounded-xl tax-wrapper" style="background-color: white;">
            <div class="flex items-center justify-center bg-gray-700 text-white font-black border-2 border-black rounded-lg h-6 w-6 shrink-0 select-none text-[10px]">
              <span>%</span>
            </div>
            <input type="number" step="0.1" class="tax-menu-input bg-transparent border-none p-0 font-black text-black focus:ring-0 outline-none text-left min-w-0 text-sm placeholder:text-gray-300 w-9"
                   value="${(taxRate !== null && taxRate !== undefined && taxRate !== '') ? taxRate : ''}" placeholder="0" oninput="updateTotalsSummary()">
          </div>
        </div>
        ${usesPriceToggle ? `
        <!-- QUANTITY -->
        <div class="flex flex-col item-qty-wrapper ${!isPriceActiveDefault ? 'hidden' : ''}">
          <span class="text-[8px] font-black text-black uppercase tracking-wider ml-2 mb-0.5">${window.APP_LANGUAGES.quantity || 'QTY'}</span>
          <div class="flex items-center px-2.5 h-10 border-2 border-black rounded-xl" style="background-color: white;">
            <input type="number" step="1" min="0" class="qty-input bg-transparent border-none p-0 font-black text-black focus:ring-0 outline-none text-left min-w-0 text-sm placeholder:text-gray-300 w-8"
                   value="${finalQty}" placeholder="1" oninput="updateTotalsSummary()">
          </div>
        </div>` : ''}
        <!-- Discount Group -->
        <div class="flex items-start gap-2 discount-wrapper item-discount-group ${usesPriceToggle && !isPriceActiveDefault ? 'hidden' : ''}">
          <!-- Percentage Discount (hidden by default) -->
          <div class="flex items-end gap-1 item-discount-percent-wrapper ${hasDiscPercent ? '' : 'hidden'}">
            <div class="flex flex-col">
              <span class="text-[8px] font-black text-black uppercase tracking-wider ml-2 mb-0.5">${window.APP_LANGUAGES.discount || 'Discount'}</span>
              <div class="flex items-center gap-1.5 px-2.5 h-10 border-2 border-black bg-white rounded-xl">
                <div class="flex items-center justify-center bg-green-600 text-white font-black border-2 border-black rounded-lg h-6 w-6 shrink-0 select-none text-[10px]">
                  <span>%</span>
                </div>
                <input type="number" step="0.1" class="discount-percent-input bg-transparent border-none p-0 font-black text-black focus:ring-0 outline-none text-left min-w-0 text-sm placeholder:text-gray-300 w-9"
                       value="${discPercentVal}" placeholder="0" oninput="updateTotalsSummary()">
              </div>
            </div>
            <button type="button" onclick="removeItemDiscount(this, 'percent')" class="w-5 h-10 flex items-center justify-center text-gray-300 hover:text-red-500 transition-colors font-bold text-sm flex-shrink-0">×</button>
          </div>
          <!-- Flat Discount (hidden by default) -->
          <div class="flex items-end gap-1 item-discount-flat-wrapper ${hasDiscFlat ? '' : 'hidden'}">
            <div class="flex flex-col">
              <span class="text-[8px] font-black text-black uppercase tracking-wider ml-2 mb-0.5">${window.APP_LANGUAGES.discount || 'DISCOUNT'}</span>
              <div class="flex items-center gap-1.5 px-2.5 h-10 border-2 border-black bg-white rounded-xl">
                <div class="flex items-center justify-center bg-green-600 text-white font-black border-2 border-black rounded-lg h-6 w-6 shrink-0 select-none text-[10px] discount-flat-symbol">
                  ${currencySymbol}
                </div>
                <input type="number" step="0.01" class="discount-flat-input bg-transparent border-none p-0 font-black text-black focus:ring-0 outline-none text-left min-w-0 text-sm placeholder:text-gray-300 w-12"
                       value="${discFlatVal}" placeholder="0" oninput="updateTotalsSummary()">
              </div>
            </div>
            <button type="button" onclick="removeItemDiscount(this, 'flat')" class="w-5 h-10 flex items-center justify-center text-gray-300 hover:text-red-500 transition-colors font-bold text-sm flex-shrink-0">×</button>
          </div>
        </div>
      </div>
    `;
  // Finalize
  document.getElementById(containerId).appendChild(div);

  // Populate Sub-categories
  if (sub_categories && sub_categories.length > 0) {
    const subContainer = div.querySelector('.sub-categories');
    sub_categories.forEach(sub => {
      if (!sub) return;
      const subItem = document.createElement('div');
      subItem.className = "flex items-center gap-2 animate-in fade-in slide-in-from-left-2 duration-300 sub-item";
      subItem.innerHTML = `
        <div class="w-2 h-2 rounded-full bg-black flex-shrink-0"></div>
        <div class="flex-1 flex items-center border-2 border-black rounded-lg bg-white shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] transition-colors relative h-8">
          <input type="text" class="flex-1 bg-transparent border-none text-[11px] font-bold text-black focus:ring-0 py-1 px-3 sub-input placeholder:text-gray-300 min-w-0 outline-none" value="${String(sub).replace(/"/g, '&quot;')}" placeholder="${window.APP_LANGUAGES.subcategory_placeholder || "Description..."}">
        </div>
        <button type="button" onclick="removeItemSubCategory(this);" class="w-5 h-8 flex items-center justify-center text-gray-300 hover:text-red-500 transition-colors font-bold text-sm flex-shrink-0">×</button>
      `;
      subContainer.appendChild(subItem);
    });
  }

  // Adjust spacing based on subcategories presence
  const subContainer = div.querySelector('.sub-categories');
  const buttonRow = div.querySelector('.item-action-row');
  if (subContainer && buttonRow) {
    const hasSubCategories = subContainer.children.length > 0;
    if (hasSubCategories) {
      // Keep subcategories spacing (mt-2 mb-2)
      subContainer.classList.remove('mt-0', 'mb-0');
      subContainer.classList.add('mt-2', 'mb-2');
      // Add gap back to button row when subcategories present
      buttonRow.classList.remove('mb-0', 'md:mb-0');
      buttonRow.classList.add('mb-1');
    } else {
      // Remove subcategories spacing when empty
      subContainer.classList.remove('mt-2', 'mb-2');
      subContainer.classList.add('mt-0', 'mb-0');
      // Use responsive spacing when no subcategories
      buttonRow.classList.remove('mb-1');
      buttonRow.classList.add('mb-0', 'md:mb-0');
    }
  }

  // Set initial active states for row action buttons
  const discBtn = div.querySelector('.item-add-discount-btn');
  setItemDiscountButtonState(discBtn, hasDiscPercent || hasDiscFlat);

  if (usesPriceToggle) {
    setItemPriceActive(div, isPriceActiveDefault, { clearValues: false, suppressTotals: true });
  }

  updateTotalsSummary();
  return div;
}

function updateUI(data) {
  window.isAutoUpdating = true;
  logAlreadySaved = false;
  savedLogId = null;
  savedLogDisplayNumber = null;
  savedLogClient = null;
  if (!data) return;
  try {
    const transcriptArea = document.getElementById("mainTranscript");
    // Skip transcript update if processing clarification (flag set by submitClarifications)
    if (data.raw_summary && !window.skipTranscriptUpdate) {
      const limit = window.profileCharLimit || 2000;
      transcriptArea.value = data.raw_summary.substring(0, limit);
      autoResize(transcriptArea);
    }
    // Reset assistant state for ANY fresh parse (not a follow-up)
    if (!window.skipTranscriptUpdate) {
      window.previousClarificationAnswers = [];
      window.clarificationHistory = [];
      window._pendingAnswer = null;
      renderConversationHistory();
      const assistInput = document.getElementById('assistantInput');
      if (assistInput) { assistInput.value = ''; assistInput.disabled = false; }
      if (window.updateDynamicCounters) window.updateDynamicCounters();
    }
    window.skipTranscriptUpdate = false; // Reset flag after use
    document.getElementById("editClient").value = data.client || "";

    // Populate FROM/BILLED TO displays from AI response
    if (data.sender_info && typeof window.setSenderInfo === 'function') {
      window.setSenderInfo(data.sender_info);
    }
    if (data.recipient_info && typeof window.setRecipientInfo === 'function') {
      window.setRecipientInfo(data.recipient_info);
    } else if (data.client) {
      // Fallback: if AI only returned a client string, update billed-to display
      const btDisplay = document.getElementById('billedToFieldDisplay');
      if (btDisplay) {
        btDisplay.textContent = data.client;
        btDisplay.classList.remove('text-gray-300');
        btDisplay.classList.add('text-black');
      }
    }

    // Set tax scope (AI-detected or profile default)
    currentLogTaxScope = data.tax_scope || window.profileTaxScope || "tax_excluded";
    console.log("[updateUI] currentLogTaxScope set to:", currentLogTaxScope);

    // Hide all protected sections by default - they will be shown only if AI returns relevant data
    removeLaborSection();
    removeCreditSection();

    // Billing Mode Synchronization
    const billingMode = data.billing_mode || currentLogBillingMode;
    if (data.hourly_rate) {
      profileHourlyRate = parseFloat(data.hourly_rate);
    }
    if (data.tax_rate !== undefined && data.tax_rate !== null && data.tax_rate !== "") {
      profileTaxRate = parseFloat(data.tax_rate);
    }
    if (data.accent_color) {
      currentLogAccentColor = data.accent_color;
    }
    setGlobalBillingMode(billingMode);

    if (data.discount_tax_mode) {
      setGlobalTaxRule(data.discount_tax_mode);
    }

    // Currency Update Logic (Sync with UI)
    if (data.currency) {
      activeCurrencyCode = data.currency;
      const c = CURRENCIES.find(x => x.c === activeCurrencyCode);
      if (c) {
        activeCurrencySymbol = c.s;
        document.getElementById('globalCurrencyDisplay').innerHTML = `
          <span class="fi fi-${c.i} rounded-sm shadow-sm scale-90"></span> 
          <span>${c.c} (${c.s})</span>
        `;
      }
    }
    const currencySymbol = activeCurrencySymbol;

    // Update Global Discount Currency Symbol
    const globalDiscSym = document.getElementById("discountCurrencySymbol");
    if (globalDiscSym) globalDiscSym.innerText = currencySymbol;

    // Update ALL dynamic items (Price icon and input symbols)
    document.querySelectorAll('.price-menu-icon').forEach(el => el.innerText = currencySymbol);
    document.querySelectorAll('.price-input-symbol').forEach(el => el.innerText = currencySymbol);
    document.querySelectorAll('.discount-flat-symbol').forEach(el => el.innerText = currencySymbol);
    document.querySelectorAll('.labor-currency-symbol').forEach(el => el.innerText = currencySymbol);
    document.querySelectorAll('.credit-unit-indicator').forEach(el => el.innerText = currencySymbol);
    document.querySelectorAll('.badge-price').forEach(el => {
      // Since badges often contain calculations, we might need a more complex update logic
      // but for now, we'll let updateBadge handle it since it's called in most places.
      // However, updating the symbol inside the badge text if it's static is good.
    });

    // Update ANY existing items/badges if they differ (though usually we clear sections below, but labor might persist)
    // Actually sections are cleared below (sectionContainer.innerHTML = ""), so we only need to worry about Labor Box here.
    // However, if we preserve any state, we should be careful. 
    // Data from AI usually replaces everything.



    // ... (rest of function continues)

    // *IMPORTANT*: Since sections are rebuilt below using `addFullSection` -> `addItem`, 
    // we need to make sure `addItem` uses the global `activeCurrencySymbol`.
    // I will update addItem separately.





    // Populate Global Discount
    const gDiscFlat = data.global_discount_flat || "";
    const gDiscPercent = data.global_discount_percent || "";
    const gFlatInput = document.getElementById('globalDiscountFlat');
    const gPercentInput = document.getElementById('globalDiscountPercent');

    if (gFlatInput) gFlatInput.value = gDiscFlat ? cleanNum(gDiscFlat) : "";
    if (gPercentInput) gPercentInput.value = gDiscPercent ? cleanNum(gDiscPercent) : "";

    // Populate Credits
    const credits = data.credits || [];
    const creditItemsCont = document.getElementById('creditItemsContainer');

    if (creditItemsCont) {
      // Clear all existing item rows first, but preserve the Add Button
      const existingRows = creditItemsCont.querySelectorAll('.credit-item-row');
      existingRows.forEach(row => row.remove());

      if (credits.length > 0) {
        addCreditSection(true); // Skip default item
        credits.forEach(c => {
          addCreditItem('creditItemsContainer', c.reason, c.amount);
        });
      } else if (data.credit_flat && parseFloat(data.credit_flat) > 0) {
        // Legacy/Fallback Support
        addCreditSection(true); // Skip default item
        addCreditItem('creditItemsContainer', data.credit_reason || (window.APP_LANGUAGES?.courtesy_credit || "Courtesy Credit"), data.credit_flat);
      } else {
        // If no credits in the explicit array and no legacy credit, hide the section
        removeCreditSection();
      }
    }

    // DEBUG: Check what we received
    // if (data.credit_flat) {
    //    alert("DEBUG: Credit Flat = " + data.credit_flat + ", Reason = " + data.credit_reason);
    // }

    // If AI detected credit, ensure Credit section exists (even if reason is missing, we add a placeholder)
    // MOVED LOGIC BELOW TO AFTER SECTION REBUILDING
    // if (creditFlat && parseFloat(creditFlat) > 0) { ... }

    // Labor section is handled below via addFullSection for "Labor/Service"
    // which correctly processes multiple items with their own prices/modes.
    // We only preserve the global billing mode detected by AI.


    let dateVal = data.date;
    if (!dateVal || dateVal === "N/A" || dateVal.toLowerCase().includes("specified")) {
      dateVal = null;
    }
    // Parse the date (AI always returns English format like "Feb 21, 2026")
    const parsedDate = dateVal ? new Date(dateVal) : new Date();
    if (isNaN(parsedDate.getTime())) {
      window.selectedMainDate = new Date();
    } else {
      window.selectedMainDate = parsedDate;
    }
    // Format date display according to system language
    const lang = window.currentSystemLanguage || 'en';
    if (lang === 'ka') {
      const monthsKa = [
        window.APP_LANGUAGES.jan, window.APP_LANGUAGES.feb, window.APP_LANGUAGES.mar,
        window.APP_LANGUAGES.apr, window.APP_LANGUAGES.may, window.APP_LANGUAGES.jun,
        window.APP_LANGUAGES.jul, window.APP_LANGUAGES.aug, window.APP_LANGUAGES.sep,
        window.APP_LANGUAGES.oct, window.APP_LANGUAGES.nov, window.APP_LANGUAGES.dec
      ];
      document.getElementById("dateDisplay").innerText = `${monthsKa[window.selectedMainDate.getMonth()]} ${window.selectedMainDate.getDate()}, ${window.selectedMainDate.getFullYear()}`;
    } else {
      document.getElementById("dateDisplay").innerText = window.selectedMainDate.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
    }

    // Due Date Logic
    updateDueDate(data.due_days, data.due_date);

    // Clear existing sections first (except protected ones? No, AI rebuilds everything)
    // BUT we must be careful not to delete the Labor section if it's protected in HTML?
    // Actually, dynamicSections contains Labor section too? 
    // Wait, the static HTML has <div id="dynamicSections"> ... <div data-protected="labor"> ... </div> </div>
    // So sectionContainer.innerHTML = "" WIPES OUT THE LABOR SECTION TOO.
    // The previous code re-added "Labor/Service" via addFullSection? No.
    // Let's check how Labor is handled. Use data-protected.

    const sectionContainer = document.getElementById("dynamicSections");
    sectionContainer.innerHTML = "";

    // Rebuild standard sections
    if (data.sections && data.sections.length > 0) {
      data.sections.forEach(sec => addFullSection(sec.title, sec.items, false, sec.type || null));
    } else if (data.tasks) {
      addFullSection("Tasks", Array.isArray(data.tasks) ? data.tasks : [data.tasks]);
    } else {
      // AI didn't return sections? Keep Labor?
      // If AI returns empty sections (e.g. credit only), we want empty container (except Credit).
    }

    // NOW Create/Update Credit Section (after sections are rebuilt)
    // If AI detected credit, ensure Credit section exists
    const hasCredits = (data.credits && data.credits.length > 0) || (data.credit_flat && parseFloat(data.credit_flat) > 0);
    if (hasCredits) {
      addCreditSection();
    }

    // Handle Labor/Service specific logic
    // If AI returns labor items in "Labor/Service" section, fine. 
    // If AI returns explicit "labor_service_items" in JSON (from controller), we should create that section if data.sections didn't.
    if (data.labor_service_items && data.labor_service_items.length > 0) {
      // Check if Labor already exists (from data.sections)
      const existingLabor = Array.from(document.querySelectorAll('.section-title')).find(el => el.innerText === "LABOR/SERVICE" || el.value === "Labor/Service");
      if (!existingLabor) {
        addFullSection("Labor/Service", data.labor_service_items);
        const laborSec = sectionContainer.lastElementChild;
        if (laborSec) sectionContainer.prepend(laborSec);
      }
    }

    // Update totals summary after all items are added
    updateTotalsSummary();

    // Always show invoice preview
    document.getElementById("invoicePreview").classList.remove("hidden");

    // Handle AI Clarification Questions (shown as chat bubbles alongside invoice)
    handleClarifications(data.clarifications || []);

    if (window.pendingClarifications && window.pendingClarifications.length === 0) {
      window.setupSaveButton();
    }

    // Scroll to assistant chat if questions exist, otherwise to invoice
    const assistantSection = document.getElementById('aiAssistantSection');
    if (window.pendingClarifications && window.pendingClarifications.length > 0 && assistantSection) {
      assistantSection.scrollIntoView({ behavior: 'smooth', block: 'center' });
    } else {
      document.getElementById("invoicePreview").scrollIntoView({ behavior: 'smooth' });
    }

    if (typeof window.trackEvent === 'function') {
      window.trackEvent('invoice_generated');
    }

    window._analysisSucceeded = true;
    window.lastAiResult = data;
    window.isAutoUpdating = false;
  } catch (e) {
    window.isAutoUpdating = false;
    showError((window.APP_LANGUAGES.ui_update_error || "UI Update Error: ") + e.message);
    console.error(e);
  }
}

// Store pending clarifications globally
window.skipTranscriptUpdate = false;
window.pendingClarifications = [];
window.originalTranscript = "";
window.previousClarificationAnswers = [];
window.clarificationHistory = [];
window._pendingAnswer = null;
window._analysisSucceeded = false;
window.lastAiResult = null;

window.calculateHistoricalChars = function() {
  if (!window.clarificationHistory || window.clarificationHistory.length === 0) return 0;
  return window.clarificationHistory.reduce(function(sum, h) { return sum + (h.answer || '').length; }, 0);
};

window.finalizePendingAnswer = function() {
  if (!window._pendingAnswer) return;
  var pending = window._pendingAnswer;

  // Commit history entry (data only, NO DOM rebuild)
  if (pending.historyEntry) {
    if (!window.clarificationHistory) window.clarificationHistory = [];
    window.clarificationHistory.push(pending.historyEntry);
  }

  // Add to conversation history (data only)
  if (!window.previousClarificationAnswers) window.previousClarificationAnswers = [];
  window.previousClarificationAnswers.push({ text: pending.text, type: pending.type });

  // Re-enable the unified input (user bubble is already in DOM from submitAssistantMessage)
  var assistIn = document.getElementById('assistantInput');
  if (assistIn) { assistIn.value = ''; assistIn.disabled = false; }

  if (window.updateDynamicCounters) window.updateDynamicCounters();
  window._pendingAnswer = null;
};

window.rollbackPendingAnswer = function() {
  if (!window._pendingAnswer) return;
  var assistIn = document.getElementById('assistantInput');
  if (assistIn) assistIn.disabled = false;
  window._pendingAnswer = null;
};

function handleClarifications(clarifications) {
  const section = document.getElementById('aiAssistantSection');
  removeTypingIndicator();

  // Filter out already-answered clarifications
  const unansweredClarifications = (clarifications || []).filter(c => {
    return c.question && c.question.trim();
  });

  // Always show the assistant section after analysis
  if (section) section.classList.remove('hidden');

  // Only rebuild conversation from scratch on FIRST call (fresh analysis)
  // Subsequent calls (after user answers) just append — bubbles already in DOM
  const conversation = document.getElementById('assistantConversation');
  const isFirstCall = !conversation || conversation.children.length === 0;
  if (isFirstCall) {
    renderConversationHistory();
  }

  if (!unansweredClarifications || unansweredClarifications.length === 0) {
    window.pendingClarifications = [];

    // AI "all good" message with typing animation
    showTypingIndicator();
    setTimeout(() => {
      removeTypingIndicator();
      addAIBubble(window.APP_LANGUAGES.anything_else || "Anything else to change?");
      const assistInput = document.getElementById('assistantInput');
      if (assistInput) {
        assistInput.placeholder = window.APP_LANGUAGES.assistant_placeholder || "Tell me what to change...";
        assistInput.focus();
      }
    }, 600);
    return;
  }

  // Store for later submission
  window.pendingClarifications = unansweredClarifications;
  window.originalTranscript = document.getElementById('mainTranscript').value;

  // Show each question as its own chat bubble with typing animation
  unansweredClarifications.forEach((c, index) => {
    let guessDisplay;
    if (c.guess === true || c.guess === "true") {
      guessDisplay = window.APP_LANGUAGES.guess_yes || "Yes";
    } else if (c.guess === false || c.guess === "false") {
      guessDisplay = window.APP_LANGUAGES.guess_no || "No";
    } else if (c.guess === 0 || c.guess === "0" || c.guess === "" || c.guess === null || c.guess === undefined) {
      guessDisplay = window.APP_LANGUAGES.not_specified || "not specified";
    } else {
      // Format comma-separated item names with proper conjunction
      const guessStr = String(c.guess);
      const parts = guessStr.split(/\s*,\s*/).filter(p => p.trim());
      if (parts.length > 1) {
        const lang = window.currentSystemLanguage || 'en';
        const conjunction = (lang === 'ka') ? ' და ' : ' and ';
        guessDisplay = parts.slice(0, -1).join(', ') + conjunction + parts[parts.length - 1];
      } else {
        guessDisplay = guessStr;
      }
    }

    const questionText = c.question;
    const guessLabel = window.APP_LANGUAGES.current_guess || "My guess:";
    const guessHtml = `${escapeHtml(guessLabel)} ${escapeHtml(guessDisplay)}`;

    // Stagger bubbles with typing indicator
    setTimeout(() => {
      removeTypingIndicator();
      addAIBubble(questionText, guessHtml);
      // Show typing indicator for next bubble (if not the last)
      if (index < unansweredClarifications.length - 1) {
        showTypingIndicator();
      }
    }, index * 800 + 400);
  });

  // Show typing indicator before first bubble
  showTypingIndicator();

  // Clear the input field for fresh answer after all bubbles shown
  const totalDelay = unansweredClarifications.length * 800 + 400;
  setTimeout(() => {
    if (!window._pendingAnswer) {
      const assistInput = document.getElementById('assistantInput');
      if (assistInput) {
        assistInput.value = '';
        assistInput.placeholder = window.APP_LANGUAGES.answer_placeholder || "Type or speak your answer...";
        assistInput.focus();
      }
    }
  }, totalDelay);
}

function toggleSection(contentId, arrowId, btn) {
  const content = document.getElementById(contentId);
  const arrow = document.getElementById(arrowId);
  if (!content || !arrow) return;

  if (content.classList.contains('hidden')) {
    content.classList.remove('hidden');
    arrow.classList.remove('-rotate-90');
    if (btn) btn.classList.add('rounded-b-none');
  } else {
    content.classList.add('hidden');
    arrow.classList.add('-rotate-90');
    if (btn) btn.classList.remove('rounded-b-none');
  }
}

function showTypingIndicator() {
  const conversation = document.getElementById('assistantConversation');
  if (!conversation) return;

  // Don't add duplicate
  if (conversation.querySelector('.typing-indicator')) return;

  const div = document.createElement('div');
  div.className = "typing-indicator flex items-start gap-2 animate-in fade-in duration-200";
  div.innerHTML = `
    <img src="/logo-no-shadow.svg" alt="" class="shrink-0 w-7 h-7 rounded-lg">
    <div class="bg-gray-50 border-2 border-gray-200 rounded-2xl rounded-tl-none px-4 py-2.5 shadow-sm">
      <div class="flex gap-1 items-center h-4">
        <span class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 0ms;"></span>
        <span class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 150ms;"></span>
        <span class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 300ms;"></span>
      </div>
    </div>
  `;
  conversation.appendChild(div);
  conversation.scrollTop = conversation.scrollHeight;
}

function removeTypingIndicator() {
  const conversation = document.getElementById('assistantConversation');
  if (!conversation) return;
  const indicator = conversation.querySelector('.typing-indicator');
  if (indicator) indicator.remove();
}

function addAIBubble(text, guessHtml) {
  const conversation = document.getElementById('assistantConversation');
  if (!conversation) return;

  const div = document.createElement('div');
  div.className = "flex items-start gap-2 animate-in fade-in slide-in-from-left-2 duration-300";
  const guessBlock = guessHtml ? `<div class="mt-1.5 px-3 py-1 bg-orange-50 border border-dashed border-orange-300 rounded-lg text-[11px] text-orange-700 font-bold">${guessHtml}</div>` : '';
  div.innerHTML = `
    <img src="/logo-no-shadow.svg" alt="" class="shrink-0 w-7 h-7 rounded-lg">
    <div class="max-w-[85%]">
      <div class="bg-gray-50 border-2 border-gray-200 rounded-2xl rounded-tl-none px-4 py-2 text-sm font-bold text-gray-800 shadow-sm">
        ${escapeHtml(text)}
      </div>
      ${guessBlock}
    </div>
  `;
  conversation.appendChild(div);
  conversation.scrollTop = conversation.scrollHeight;
}

function addUserBubble(text) {
  const conversation = document.getElementById('assistantConversation');
  if (!conversation) return;

  const div = document.createElement('div');
  div.className = "flex justify-end animate-in fade-in slide-in-from-right-2 duration-300";
  div.innerHTML = `
    <div class="bg-orange-50 border-2 border-orange-200 rounded-2xl rounded-tr-none px-4 py-2 text-sm font-bold text-orange-800 shadow-sm max-w-[80%]">
      ${escapeHtml(text)}
    </div>
  `;
  conversation.appendChild(div);
  conversation.scrollTop = conversation.scrollHeight;
}

function renderConversationHistory() {
  const conversation = document.getElementById('assistantConversation');
  if (!conversation) return;

  conversation.innerHTML = '';

  const history = window.clarificationHistory || [];
  const answers = window.previousClarificationAnswers || [];

  if (history.length === 0 && answers.length === 0) return;

  // Interleave Q&A in chronological order: Q1 → A1 → Q2 → A2 → ...
  const maxLen = Math.max(history.length, answers.length);
  for (let i = 0; i < maxLen; i++) {
    if (i < history.length) {
      const h = history[i];
      if (h.questions && h.questions !== "User requested change") {
        addAIBubble(h.questions);
      } else if (h.questions === "User requested change") {
        // Show a subtle label for user-initiated changes
      }
    }
    if (i < answers.length) {
      addUserBubble(answers[i].text);
    }
  }
}

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

// Unified voice recording for assistant input
let assistantRecorder = null;
let assistantChunks = [];

async function startAssistantRecording() {
  const btn = document.getElementById('assistantMicBtn');
  if (!btn) return;

  if (assistantRecorder && assistantRecorder.state === 'recording') {
    assistantRecorder.stop();
    return;
  }

  try {
    const input = document.getElementById('assistantInput');
    const audioLimit = window.profileAudioLimit || 120;
    const timeLeft = audioLimit - (window.totalVoiceUsed || 0);

    if (timeLeft <= 0) {
      if (window.showPremiumModal) window.showPremiumModal();
      else showError(window.APP_LANGUAGES.voice_limit_reached || "Voice limit reached for this session.");
      return;
    }

    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    assistantRecorder = new MediaRecorder(stream);
    assistantChunks = [];
    window.recordingStartTime = Date.now();

    assistantRecorder.ondataavailable = (e) => assistantChunks.push(e.data);
    assistantRecorder.onstop = processAssistantAudio;

    assistantRecorder.start();
    if (input) startLiveTranscription(input);

    btn.classList.remove('bg-black', 'hover:bg-gray-800');
    btn.classList.add('bg-red-500', 'animate-pulse');
    btn.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-white" fill="currentColor" viewBox="0 0 24 24"><rect x="6" y="6" width="12" height="12" rx="2" /></svg>`;

    const timerCont = document.getElementById('assistantTimer');
    const timerLabel = document.getElementById('assistantTimeLeft');
    if (timerCont) timerCont.classList.remove('hidden');
    if (timerLabel) timerLabel.innerText = timeLeft;

    let localInterval = setInterval(() => {
      const elapsed = Math.floor((Date.now() - window.recordingStartTime) / 1000);
      const remaining = timeLeft - elapsed;
      if (timerLabel) timerLabel.innerText = Math.max(0, remaining);
      if (remaining <= 0) {
        clearInterval(localInterval);
        if (assistantRecorder && assistantRecorder.state === 'recording') {
          window.voiceLimitTriggered = true;
          assistantRecorder.stop();
          if (window.showPremiumModal) window.showPremiumModal();
        }
      }
    }, 1000);

    assistantRecorder.addEventListener('stop', () => clearInterval(localInterval), { once: true });

    setTimeout(() => {
      if (assistantRecorder && assistantRecorder.state === 'recording') assistantRecorder.stop();
    }, timeLeft * 1000);
  } catch (e) {
    console.error("Assistant Recording Error:", e);
    if (e.name === 'NotAllowedError' || e.name === 'NotFoundError') {
      showError(window.APP_LANGUAGES.microphone_access_denied || "Microphone access required");
    } else {
      showError((window.APP_LANGUAGES.recording_failed || "Recording failed: ") + e.message);
    }
  }
}

async function processAssistantAudio() {
  const btn = document.getElementById('assistantMicBtn');
  const input = document.getElementById('assistantInput');

  if (btn) {
    btn.classList.remove('bg-red-500', 'animate-pulse');
    btn.classList.add('bg-black', 'hover:bg-gray-800');
    btn.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" /></svg>`;
  }
  if (window.liveRecognition) {
    try { window.liveRecognition.stop(); } catch (e) { }
    window.liveRecognition = null;
  }
  const duration = window.recordingStartTime ? Math.floor((Date.now() - window.recordingStartTime) / 1000) : 0;
  window.totalVoiceUsed = (window.totalVoiceUsed || 0) + duration;

  const timerCont = document.getElementById('assistantTimer');
  if (timerCont) timerCont.classList.add('hidden');

  if (assistantRecorder && assistantRecorder.stream) {
    assistantRecorder.stream.getTracks().forEach(t => t.stop());
  }

  if (assistantChunks.length === 0) return;

  // If live transcription already captured text, skip server call
  if (input && input.value.trim().length > 5) {
    submitAssistantMessage();
    return;
  }

  const audioBlob = new Blob(assistantChunks, { type: 'audio/webm' });
  const formData = new FormData();
  formData.append("audio", audioBlob);
  formData.append("transcribe_only", "true");
  formData.append("language", localStorage.getItem('transcriptLanguage') || window.profileSystemLanguage || 'en');

  try {
    const res = await fetch("/process_audio", {
      method: "POST",
      headers: { "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content },
      body: formData
    });
    const data = await res.json();
    if (input) {
      input.placeholder = window.APP_LANGUAGES.assistant_placeholder || "Tell me what to change...";
      const transcribed = (data.raw_summary || '').trim();
      if (transcribed.length >= 2) {
        input.value = transcribed;
        setTimeout(() => submitAssistantMessage(), 300);
      }
    }
  } catch (e) {
    showError(window.APP_LANGUAGES.transcription_failed || "Transcription failed");
    console.error(e);
  }
}

async function submitAssistantMessage() {
  if (window._pendingAnswer) return; // Prevent spam clicks while reparse in flight
  const input = document.getElementById('assistantInput');
  const userMessage = input ? input.value.trim() : '';

  if (!userMessage || userMessage.length < 2) {
    return; // Silently ignore empty/barely legible input
  }

  // Determine type: if there are pending clarifications, it's a clarification answer; otherwise it's a user-initiated change
  const hasPendingQuestions = window.pendingClarifications && window.pendingClarifications.length > 0;
  const type = hasPendingQuestions ? 'clarification' : 'refinement';
  const questionsText = hasPendingQuestions
    ? window.pendingClarifications.map(c => c.question).join(' ')
    : "User requested change";

  addUserBubble(userMessage);
  if (input) { input.value = ''; if (typeof autoResize === 'function') autoResize(input); }
  showTypingIndicator();
  triggerAssistantReparse(userMessage, type, questionsText);
}

async function triggerAssistantReparse(userAnswer, type, questionsText) {
  const input = document.getElementById('assistantInput');
  const currentQuestions = questionsText || (type === 'clarification'
    ? (window.pendingClarifications || []).map(c => c.question).join(' ')
    : "User requested change");

  const historyEntry = { questions: currentQuestions, answer: userAnswer };

  // Queue answer for display AFTER AI finishes
  window._pendingAnswer = { text: userAnswer, type: type, historyEntry: historyEntry };
  if (input) input.disabled = true;

  // Build conversation history text
  const allEntries = [...(window.clarificationHistory || []), historyEntry];
  let historyText = "";
  if (allEntries.length > 1) {
    historyText = "--- PREVIOUS Q&A CONTEXT ---";
    allEntries.slice(0, -1).forEach((h, i) => {
      if (h.questions === "User requested change") {
        historyText += `\n[Round ${i + 1} - User correction/addition: "${h.answer}"]`;
      } else {
        historyText += `\n[Round ${i + 1} - AI asked: "${h.questions}" → User answered: "${h.answer}"]`;
      }
    });
    historyText += "\n--- END CONTEXT ---";
  }

  // Use /refine_invoice with existing JSON if available
  if (window.lastAiResult) {
    try {
      const res = await fetch("/refine_invoice", {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({
          current_json: window.lastAiResult,
          user_message: (type === 'clarification' && currentQuestions && currentQuestions !== "User requested change")
            ? `[AI asked: "${currentQuestions}"] User answered: "${userAnswer}"`
            : userAnswer,
          conversation_history: historyText,
          language: localStorage.getItem('transcriptLanguage') || window.profileSystemLanguage || 'en'
        })
      });
      const data = await res.json();

      removeTypingIndicator();

      if (data.error) {
        showError(data.error);
        if (window.rollbackPendingAnswer) window.rollbackPendingAnswer();
        return;
      }

      // Update UI with refined result (without touching transcript)
      updateUIWithoutTranscript(data);

      // Finalize the pending answer
      if (window._pendingAnswer && window._analysisSucceeded) {
        if (window.finalizePendingAnswer) window.finalizePendingAnswer();
      } else if (window._pendingAnswer) {
        if (window.rollbackPendingAnswer) window.rollbackPendingAnswer();
      }

    } catch (e) {
      removeTypingIndicator();
      showError(window.APP_LANGUAGES.network_error || "Network error.");
      console.error("Refine error:", e);
      if (window.rollbackPendingAnswer) window.rollbackPendingAnswer();
    }
    return;
  }

  // Fallback: no lastAiResult available, use legacy re-parse via Apply button
  window.skipTranscriptUpdate = true;
  const transcriptArea = document.getElementById('mainTranscript');
  const originalValue = transcriptArea.value;
  let fullHistory = "\n\n--- PREVIOUS Q&A CONTEXT (you MUST treat this as an ongoing conversation and consider ALL previous answers) ---";
  allEntries.forEach((h, i) => {
    if (h.questions === "User requested change") {
      fullHistory += `\n[Round ${i + 1} - User correction/addition: "${h.answer}"]`;
    } else {
      fullHistory += `\n[Round ${i + 1} - AI asked: "${h.questions}" → User answered: "${h.answer}"]`;
    }
  });
  fullHistory += "\n--- END CONTEXT ---";
  transcriptArea.value = `${window.originalTranscript || originalValue}${fullHistory}`;

  const applyBtn = document.getElementById('reParseBtn');
  if (applyBtn) {
    applyBtn.click();
  }

  transcriptArea.value = originalValue;
}

// Special version of updateUI that doesn't touch the transcript
function updateUIWithoutTranscript(data) {
  window.isAutoUpdating = true;
  logAlreadySaved = false;
  savedLogId = null;
  savedLogDisplayNumber = null;
  savedLogClient = null;
  if (!data) return;

  try {
    // DON'T update transcript - keep it as is

    document.getElementById("editClient").value = data.client || document.getElementById("editClient").value || "";

    // Populate FROM/BILLED TO displays from AI response
    if (data.sender_info && typeof window.setSenderInfo === 'function') {
      window.setSenderInfo(data.sender_info);
    }
    if (data.recipient_info && typeof window.setRecipientInfo === 'function') {
      window.setRecipientInfo(data.recipient_info);
    } else if (data.client) {
      const btDisplay = document.getElementById('billedToFieldDisplay');
      if (btDisplay) {
        btDisplay.textContent = data.client;
        btDisplay.classList.remove('text-gray-300');
        btDisplay.classList.add('text-black');
      }
    }

    // Set tax scope (AI-detected or profile default)
    currentLogTaxScope = data.tax_scope || currentLogTaxScope || window.profileTaxScope || "tax_excluded";

    // Hide all protected sections by default
    removeLaborSection();
    removeCreditSection();

    // Billing Mode Synchronization
    const billingMode = data.billing_mode || currentLogBillingMode;
    if (data.hourly_rate) {
      profileHourlyRate = parseFloat(data.hourly_rate);
    }
    if (data.labor_tax_rate !== undefined && data.labor_tax_rate !== null && data.labor_tax_rate !== "") {
      profileTaxRate = parseFloat(data.labor_tax_rate);
    }
    setGlobalBillingMode(billingMode);

    // Currency Update
    if (data.currency) {
      activeCurrencyCode = data.currency.toUpperCase();
      const curr = CURRENCIES.find(c => c.c === activeCurrencyCode);
      if (curr) {
        activeCurrencySymbol = curr.s;
        const display = document.getElementById('globalCurrencyDisplay');
        if (display) {
          display.innerHTML = `<span class="fi fi-${curr.i} rounded-sm shadow-sm scale-90"></span> <span>${curr.c} (${curr.s})</span>`;
        }
      }
    }

    // Global Discount
    const gDiscFlat = data.global_discount_flat || "";
    const gDiscPercent = data.global_discount_percent || "";
    document.getElementById("globalDiscountFlat").value = gDiscFlat;
    document.getElementById("globalDiscountPercent").value = gDiscPercent;

    // Credits
    if (data.credits && data.credits.length > 0) {
      addCreditSection(true);
      const creditContainer = document.getElementById("creditItemsContainer");
      if (creditContainer) {
        creditContainer.querySelectorAll('.credit-item-row').forEach(row => row.remove());
        data.credits.forEach(credit => {
          addCreditItem('creditItemsContainer', credit.reason, credit.amount);
        });
      }
    }

    // Sections
    const sectionContainer = document.getElementById("dynamicSections");
    sectionContainer.innerHTML = "";

    if (data.sections && data.sections.length > 0) {
      data.sections.forEach(sec => addFullSection(sec.title, sec.items, false, sec.type || null));
    }

    if (data.labor_service_items && data.labor_service_items.length > 0) {
      const existingLabor = Array.from(document.querySelectorAll('.section-title')).find(el => el.innerText === "LABOR/SERVICE" || el.value === "Labor/Service");
      if (!existingLabor) {
        addFullSection("Labor/Service", data.labor_service_items);
        const laborSec = sectionContainer.lastElementChild;
        if (laborSec) sectionContainer.prepend(laborSec);
      }
    }

    updateTotalsSummary();

    document.getElementById("invoicePreview").classList.remove("hidden");

    // Handle AI Clarification Questions (shown as chat bubbles alongside invoice)
    handleClarifications(data.clarifications || []);

    if (window.pendingClarifications && window.pendingClarifications.length === 0) {
      window.setupSaveButton();
    }

    window._analysisSucceeded = true;
    window.lastAiResult = data;
    window.isAutoUpdating = false;
  } catch (e) {
    window.isAutoUpdating = false;
    showError((window.APP_LANGUAGES.ui_update_error || "UI Update Error: ") + e.message);
    console.error(e);
  }
}

// showError is now defined globally via window.showError in the layout's unified toast system

function toggleLaborGroup() {
  const content = document.getElementById('laborContent');
  if (!content) return;
  content.classList.toggle('hidden');
}



function toggleLaborRate(menuItem) {
  const wrapper = menuItem.closest('.rate-wrapper');
  const inputRow = wrapper.querySelector('.rate-inputs-row');
  const input = wrapper.querySelector('.rate-menu-input');

  menuItem.classList.toggle('active');
  const isActive = menuItem.classList.contains('active');

  if (isActive) {
    inputRow.classList.remove('hidden');
    inputRow.classList.add('grid');
    setTimeout(() => input.focus(), 50);
  } else {
    inputRow.classList.add('hidden');
    inputRow.classList.remove('grid');
  }

  updateTotalsSummary();
}

// Global protection against negative numbers in all number-related inputs
document.addEventListener('keydown', (e) => {
  const isNumericInput = e.target.type === 'number' ||
    e.target.classList.contains('labor-price-input') ||
    e.target.classList.contains('rate-menu-input') ||
    e.target.id === 'editCreditAmount';

  if (isNumericInput && e.key === '-') {
    e.preventDefault();
  }
});

document.addEventListener('input', (e) => {
  const isNumericInput = e.target.type === 'number' ||
    e.target.classList.contains('labor-price-input') ||
    e.target.classList.contains('rate-menu-input') ||
    e.target.id === 'editCreditAmount';

  if (isNumericInput && e.target.value.includes('-')) {
    e.target.value = e.target.value.replace(/-/g, '');
  }

  // Mutual exclusion for discount inputs
  if (e.target.classList.contains('discount-flat-input')) {
    const row = e.target.closest('.item-row, .labor-item-row');
    if (row && e.target.value !== "") {
      const pctInput = row.querySelector('.discount-percent-input');
      if (pctInput) {
        pctInput.value = "";
        updateTotalsSummary();
      }
    }
  }
  if (e.target.classList.contains('discount-percent-input')) {
    const row = e.target.closest('.item-row, .labor-item-row');
    if (row && e.target.value !== "") {
      const flatInput = row.querySelector('.discount-flat-input');
      if (flatInput) {
        flatInput.value = "";
        updateTotalsSummary();
      }
    }
  }
  // Global discounts mutual exclusion
  if (e.target.id === 'globalDiscountFlat' && e.target.value !== "") {
    const pctInput = document.getElementById('globalDiscountPercent');
    if (pctInput) {
      pctInput.value = "";
      updateTotalsSummary();
    }
  }
  if (e.target.id === 'globalDiscountPercent' && e.target.value !== "") {
    const flatInput = document.getElementById('globalDiscountFlat');
    if (flatInput) {
      flatInput.value = "";
      updateTotalsSummary();
    }
  }
});



window.toggleItemsTotalBreakdown = function () {
  const breakdown = document.getElementById('itemsTotalBreakdown');
  const chevron = document.getElementById('itemsTotalChevron');
  if (!breakdown || (breakdown.classList.contains('hidden') && breakdown.children.length === 0)) return;

  breakdown.classList.toggle('hidden');
  const isVisible = !breakdown.classList.contains('hidden');
  chevron.style.transform = isVisible ? 'rotate(180deg)' : '';
}

window.toggleItemDiscountsBreakdown = function () {
  const breakdown = document.getElementById('itemDiscountsBreakdown');
  const chevron = document.getElementById('itemDiscountsChevron');
  if (!breakdown || (breakdown.classList.contains('hidden') && breakdown.children.length === 0)) return;

  breakdown.classList.toggle('hidden');
  const isVisible = !breakdown.classList.contains('hidden');
  chevron.style.transform = isVisible ? 'rotate(180deg)' : '';
}

window.toggleSubtotalBreakdown = function () {
  const breakdown = document.getElementById('subtotalBreakdown');
  const chevron = document.getElementById('subtotalChevron');
  if (!breakdown || (breakdown.classList.contains('hidden') && breakdown.children.length === 0)) return;

  breakdown.classList.toggle('hidden');
  const isVisible = !breakdown.classList.contains('hidden');
  chevron.style.transform = isVisible ? 'rotate(180deg)' : '';
}

window.toggleTaxBreakdown = function () {
  const breakdown = document.getElementById('taxBreakdown');
  const chevron = document.getElementById('taxChevron');
  if (!breakdown || (breakdown.classList.contains('hidden') && breakdown.children.length === 0)) return;

  breakdown.classList.toggle('hidden');
  const isVisible = !breakdown.classList.contains('hidden');
  chevron.style.transform = isVisible ? 'rotate(180deg)' : '';
}

window.toggleCreditBreakdown = function () {
  const breakdown = document.getElementById('creditBreakdown');
  const chevron = document.getElementById('creditChevron');
  if (!breakdown || (breakdown.classList.contains('hidden') && breakdown.children.length === 0)) return;

  breakdown.classList.toggle('hidden');
  const isVisible = !breakdown.classList.contains('hidden');
  chevron.style.transform = isVisible ? 'rotate(180deg)' : '';
}

// Global Export for legacy inline HTML onclick handlers
Object.assign(window, {
  autoResize,
  getCurrencyFormat,
  getCurrencySym,
  resizeInput,
  resizeQtyInput,
  cleanNum,
  formatMoney,
  updateAllLaborRowsMode,
  updateLaborRowModelUI,
  updateTotalsSummary,
  adjustBadgeSpacing,
  updateDueDate,
  toggleCalendar,
  changeCalendarMonth,
  renderCalendar,
  selectCalendarDate,
  setQuickDue,
  updateNetButtonState,
  toggleMainCalendar,
  changeMainCalendarMonth,
  renderMainCalendar,
  selectMainCalendarDate,
  addFullSection,
  validateCategoryName,
  updateAddMenuButtons,
  toggleAddMenu,
  insertSectionInOrder,
  addMaterialSection,
  addExpenseSection,
  addFeeSection,
  addLaborSection,
  removeLaborSection,
  addCreditSection,
  removeCreditSection,
  addLaborSubCategory,
  removeLaborSubCategory,
  addItemSubCategory,
  updateLaborAddBtnColor,
  addLaborItem,
  addCreditItem,
  randomizeIcon,
  toggleMenu,
  updateBadge,
  toggleTaxable,
  toggleLaborTaxable,
  updateHamburgerGlow,
  updateLaborBadge,
  togglePrice,
  toggleDiscount,
  addItem,
  updateUI,
  handleClarifications,
  toggleSection,
  showTypingIndicator,
  removeTypingIndicator,
  addAIBubble,
  addUserBubble,
  renderConversationHistory,
  escapeHtml,
  startAssistantRecording,
  processAssistantAudio,
  submitAssistantMessage,
  triggerAssistantReparse,
  updateUIWithoutTranscript,
  showError,
  toggleLaborGroup,
  toggleLaborRate,
});
