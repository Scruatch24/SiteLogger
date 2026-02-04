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
      document.querySelectorAll('#creditUnitIndicator').forEach(el => el.innerText = c.s);
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

  // PDF Selectors in Modal
  if (!e.target.closest('#pdfStatusBadge') && !e.target.closest('#pdfStatusDropdown') &&
    !e.target.closest('#pdfCategoryBadge') && !e.target.closest('#pdfCategoryDropdown')) {
    if (typeof closeAllPdfSelectors === 'function') closeAllPdfSelectors();
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
  text.innerText = status.charAt(0).toUpperCase() + status.slice(1);

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
    text.classList.add('italic', 'text-gray-400');
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

  const inactiveClasses = ['bg-white', 'text-black', 'shadow-[3px_3px_0px_0px_rgba(0,0,0,1)]', 'hover:bg-orange-50'];
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
  const labelText = mode === 'hourly' ? 'LABOR HOURS' : 'LABOR PRICE';

  // Update Label
  const label = row.querySelector('.labor-label-price');
  if (label) label.innerText = labelText;

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
    // No mode change, just preserve
    newPriceValue = oldPriceStr;
    newRateValue = oldRateInput ? oldRateInput.value : defaultRate;
  } else if (oldMode === 'fixed' && mode === 'hourly') {
    // Fixed -> Hourly: FixedPrice becomes Rate, Hours reset to 1
    newPriceValue = "1";
    newRateValue = cleanNum(oldPrice) || defaultRate;
  } else if (oldMode === 'hourly' && mode === 'fixed') {
    // Hourly -> Fixed: (Hours * Rate) becomes Price
    newPriceValue = cleanNum(oldPrice * oldRate);
    newRateValue = defaultRate; // Not used in fixed HTML but good for consistency
  } else {
    // Default / Fallback
    newPriceValue = oldPriceStr;
    newRateValue = oldRate || defaultRate;
  }

  let newHtml = '';

  if (mode === 'hourly') {
    newHtml = `
              <div class="flex items-center justify-center bg-orange-600 text-white border-2 border-black rounded-lg h-6 w-6 shrink-0 select-none">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="3">
                   <path stroke-linecap="round" stroke-linejoin="round" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
              <input type="number" step="0.1" class="labor-price-input bg-transparent border-none p-0 font-black text-black focus:ring-0 outline-none text-left min-w-0 text-sm placeholder:text-gray-300 w-12" 
                     value="${newPriceValue}"
                     placeholder="0" oninput="updateTotalsSummary()">
              <div class="flex items-center justify-center shrink-0">
                  <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="#9CA3AF" stroke-width="5" stroke-linecap="round"><path d="M18 6L6 18M6 6l12 12"/></svg>
              </div>
              <div class="flex items-center justify-center bg-orange-600 text-white font-black border-2 border-black rounded-lg h-6 w-6 shrink-0 select-none text-[10px] labor-currency-symbol">
                  ${currencySymbol}
              </div>
              <input type="number" step="0.01" class="rate-menu-input bg-transparent border-none p-0 font-black text-black focus:ring-0 outline-none text-left min-w-0 text-sm placeholder:text-gray-300 flex-1" 
                     value="${newRateValue}" placeholder="0.00" oninput="updateTotalsSummary()">
        `;
  } else {
    newHtml = `
              <div class="flex items-center justify-center bg-orange-600 text-white font-black border-2 border-black rounded-lg h-6 w-6 shrink-0 select-none text-[10px] labor-currency-symbol">
                  ${currencySymbol}
              </div>
              <input type="number" step="0.01" class="labor-price-input bg-transparent border-none p-0 font-black text-black focus:ring-0 outline-none text-left min-w-0 text-sm placeholder:text-gray-300 w-full flex-1" 
                     value="${newPriceValue}" placeholder="0.00" oninput="updateTotalsSummary()">
        `;
  }

  target.innerHTML = newHtml;

  // Update the toggle pills in the dropdown
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
        const reason = rawReason || "Courtesy Credit";
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

        let discFlat = parseFloat(item.querySelector('.discount-flat-input')?.value) || 0;
        let discPercent = parseFloat(item.querySelector('.discount-percent-input')?.value) || 0;

        // Discount logic (Math.min below handles capping without destroying user input)
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

        // Tax calculation
        let rowTax = 0;
        if (item.dataset.taxable === "true") {
          const taxRateInput = item.querySelector('.tax-menu-input');
          const taxRate = (taxRateInput && taxRateInput.value !== "") ? parseFloat(taxRateInput.value) : profileTaxRate;
          rowTax = rowNet * (taxRate / 100);
          if (rowTax > 0) {
            totalTax += rowTax;
            allTaxesList.push({ name: desc, amount: rowTax, rate: taxRate });
          }
        }

        // --- UPDATE BADGES & UI ---
        const rowCurrencyCode = item.dataset.currencyCode || activeCurrencyCode;
        const rowCurrencySym = getCurrencySym(rowCurrencyCode);

        // 1. Discount Equation Badges
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
        const laborPriceBadge = item.querySelector('.badge-price');
        const laborMultiplierBadge = item.querySelector('.badge-multiplier');
        const isTaxable = item.dataset.taxable === "true";

        if (laborPriceBadge) {
          // Show if price > 0 AND (Tax is on OR Discount is off)
          // This hides it when there's a discount but NO tax (to avoid redundancy with the discount result badge)
          if (rowNet > 0 && (isTaxable || rowDisc === 0)) {
            laborPriceBadge.innerText = getCurrencyFormat(rowNet, rowCurrencyCode);
            laborPriceBadge.classList.remove('hidden');
          } else {
            laborPriceBadge.classList.add('hidden');
          }
        }

        if (isTaxable) {
          if (laborMultiplierBadge) laborMultiplierBadge.classList.remove('hidden');
        } else {
          if (laborMultiplierBadge) laborMultiplierBadge.classList.add('hidden');
        }

        // 3. Tax Equation Badges
        const laborTaxBadge = item.querySelector('.badge-tax');
        const laborEqualsBadge = item.querySelector('.badge-equals');
        const laborAfterTaxBadge = item.querySelector('.badge-after-tax');

        if (isTaxable) {
          const taxRateInput = item.querySelector('.tax-menu-input');
          const ctxTaxRate = (taxRateInput && taxRateInput.value !== "") ? parseFloat(taxRateInput.value) : profileTaxRate;
          if (laborTaxBadge) {
            laborTaxBadge.innerText = `${cleanNum(ctxTaxRate)}%`;
            laborTaxBadge.classList.remove('hidden');
          }
          if (rowTax > 0) {
            if (laborEqualsBadge) laborEqualsBadge.classList.remove('hidden');
            if (laborAfterTaxBadge) {
              laborAfterTaxBadge.innerText = getCurrencyFormat(rowTax, rowCurrencyCode);
              laborAfterTaxBadge.classList.remove('hidden');
            }
          } else {
            if (laborEqualsBadge) laborEqualsBadge.classList.add('hidden');
            if (laborAfterTaxBadge) laborAfterTaxBadge.classList.add('hidden');
          }
        } else {
          [laborTaxBadge, laborEqualsBadge, laborAfterTaxBadge].forEach(el => el?.classList.add('hidden'));
        }

        // 4. Formula Row Display
        const formulaRow = item.querySelector('.labor-formula-row');
        if (formulaRow) {
          const finalTotal = rowNet + rowTax;
          formulaRow.innerHTML = `
                        <div class="flex items-center justify-center bg-orange-600 text-white font-black border border-black rounded-md px-1.5 h-6 shrink-0 select-none text-[10px] min-w-[24px]">
                            ${getCurrencyFormat(rowNet, rowCurrencyCode)}
                        </div>
                        <div class="flex items-center justify-center mx-1 shrink-0">
                            <svg width="8" height="8" viewBox="0 0 24 24" fill="none" stroke="black" stroke-width="4" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>
                        </div>
                        <div class="flex items-center justify-center bg-gray-700 text-white font-black border border-black rounded-md px-1.5 h-6 shrink-0 select-none text-[10px] min-w-[24px]">
                            ${getCurrencyFormat(rowTax, rowCurrencyCode)}
                        </div>
                        <div class="flex items-center justify-center mx-1 shrink-0">
                            <svg width="8" height="6" viewBox="0 0 24 24" fill="none" stroke="black" stroke-width="4" stroke-linecap="round"><path d="M4 8h16M4 16h16"/></svg>
                        </div>
                        <div class="flex items-center justify-center bg-orange-600 text-white font-black border-2 border-black rounded-lg h-6 w-6 shrink-0 select-none text-[10px] mr-2">
                            ${rowCurrencySym}
                        </div>
                        <span class="font-black text-black text-sm shrink-0">${cleanNum(finalTotal)}</span>
                        <div class="w-2 shrink-0 h-1"></div>
                    `;
        }

        updateHamburgerGlow(item);
      });
    }

    // 3. Process Dynamic Section Items
    document.querySelectorAll('.dynamic-section .item-row').forEach(item => {
      const priceVal = parseFloat(item.querySelector('.price-menu-input')?.value) || 0;
      const qtyVal = parseFloat(item.querySelector('.qty-input')?.value) || parseFloat(item.dataset.qty) || 1;
      const rowGross = priceVal * qtyVal;

      let discFlat = parseFloat(item.querySelector('.discount-flat-input')?.value) || 0;
      let discPercent = parseFloat(item.querySelector('.discount-percent-input')?.value) || 0;

      // Discount logic (Math.min below handles capping without destroying user input)
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
      if (item.dataset.taxable === 'true') {
        const taxRateInput = item.querySelector('.tax-menu-input');
        const taxRate = (taxRateInput && taxRateInput.value !== "") ? parseFloat(taxRateInput.value) : profileTaxRate;
        rowTax = rowNet * (taxRate / 100);
        if (rowTax > 0) {
          totalTax += rowTax;
          allTaxesList.push({ name: displayName, amount: rowTax, rate: taxRate });
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
      const isTaxable = item.dataset.taxable === 'true';
      if (itemPriceBadge) {
        // Show if price > 0 AND (Tax is on OR Discount is off)
        if (rowNet > 0 && (isTaxable || rowDisc === 0)) {
          itemPriceBadge.innerText = getCurrencyFormat(rowNet, rowCurrencyCode);
          itemPriceBadge.classList.remove('hidden');
        } else {
          itemPriceBadge.classList.add('hidden');
        }
      }

      if (isTaxable) {
        if (itemMultiplierBadge) itemMultiplierBadge.classList.remove('hidden');
      } else {
        if (itemMultiplierBadge) itemMultiplierBadge.classList.add('hidden');
      }


      // 3. Tax Equation
      const itemTaxBadge = item.querySelector('.badge-tax');
      const itemEqualsBadge = item.querySelector('.badge-equals');
      const itemAfterTaxBadge = item.querySelector('.badge-after-tax');
      if (isTaxable) {
        const taxRateInput = item.querySelector('.tax-menu-input');
        const ctxTaxRate = (taxRateInput && taxRateInput.value !== "") ? parseFloat(taxRateInput.value) : profileTaxRate;
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
    if (hasItemDiscounts) {
      renderBreakdown('itemsTotalBreakdown', 'itemsTotalChevron', allItemPrices, 'text-gray-500/70');
      renderBreakdown('itemDiscountsBreakdown', 'itemDiscountsChevron', allItemDiscountsList, 'text-green-600/70', true);
      // Disable subtotal breakdown interaction
      renderBreakdown('subtotalBreakdown', 'subtotalChevron', [], 'text-gray-500/70');
      if (subClickable) subClickable.classList.remove('cursor-pointer');
      const subBreak = document.getElementById('subtotalBreakdown');
      if (subBreak) subBreak.classList.add('hidden');
    } else {
      // If multiple items, give breakdown to Subtotal row
      const hasMultipleItems = allItemPrices.length > 1;
      renderBreakdown('subtotalBreakdown', 'subtotalChevron', hasMultipleItems ? allItemPrices : [], 'text-gray-500/70');
      if (subClickable) {
        if (hasMultipleItems) subClickable.classList.add('cursor-pointer');
        else subClickable.classList.remove('cursor-pointer');
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

      // Internal Layout Adjustment (Labor only)
      if (row.classList.contains('labor-item-row')) {
        const priceLabel = row.querySelector('.labor-label-price');
        const priceInputBox = row.querySelector('.labor-price-container > div:last-child'); // The actual input border box
        // Check for ANY visible top badge (Equation parts or Legacy)
        const discountBadge = row.querySelector('.badge-original-price:not(.hidden), .badge-discount-amount:not(.hidden), .badge-discounted-price:not(.hidden), .badge-discount:not(.hidden)');

        if (priceLabel && discountBadge) {
          const labelRect = priceLabel.getBoundingClientRect();
          const badgeRect = discountBadge.getBoundingClientRect();

          if (labelRect.width > 0 && badgeRect.width > 0) {
            // If badge overlaps the label (using simple left/right check)
            // Since badges grow from right to left (RTL), we check if the LEFTMOST edge of the badge set hits the label?
            // Actually, the badges are in a flex-end (RTL) container. The detected 'discountBadge' is just ONE of them.
            // We should probably check the container? 
            // But 'discountBadge' here will likely be the first found, e.g. original-price.
            if (badgeRect.left < (labelRect.right + 2)) {
              // Keep label static, push the input field down
              if (priceInputBox) priceInputBox.style.marginTop = '32px';
              isLabelShifted = true;
            } else {
              if (priceInputBox) priceInputBox.style.marginTop = '';
            }
          }
        } else if (priceInputBox) {
          priceInputBox.style.marginTop = '';
        }

        // Ensure label transform is always cleared from previous iterations
        if (priceLabel) priceLabel.style.transform = '';
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
  recognition.lang = 'en-US';

  recognition.onresult = (event) => {
    let fullTranscript = '';
    for (let i = 0; i < event.results.length; ++i) {
      fullTranscript += event.results[i][0].transcript;
    }

    if (fullTranscript) {
      targetInput.value = fullTranscript;
      autoResize(targetInput);
      if (window.updateDynamicCountersCheck) {
        window.updateDynamicCountersCheck(targetInput);
      } else if (window.updateDynamicCounters) {
        window.updateDynamicCounters();
      }
    }
  };

  recognition.onerror = (event) => {
    console.error("Speech recognition error:", event.error);
  };

  recognition.onend = () => {
    window.liveRecognition = null;
  };

  recognition.start();
  window.liveRecognition = recognition;
}

document.addEventListener("DOMContentLoaded", () => {
  const recordBtn = document.getElementById("recordButton");
  const transcriptArea = document.getElementById("mainTranscript");
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
        renderPreviousAnswers();
        const refInput = document.getElementById('refinementInput');
        const clarInput = document.getElementById('clarificationAnswerInput');
        if (refInput) refInput.value = '';
        if (clarInput) clarInput.value = '';
        if (window.updateDynamicCounters) window.updateDynamicCounters();
        window.totalVoiceUsed = 0; // Reset bank on new main recording
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
        buttonText.innerText = "PROCESS";
        recordBtn.classList.add("recording");
        document.getElementById("recordingWave").classList.remove("hidden");
        document.getElementById("status").innerText = "RECORDING...";
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
        showError("Microphone access required.");
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
        showError("Hold longer to record");
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
    buttonText.innerText = "TAP TO RECORD";
    recordBtn.classList.remove("recording");
    document.getElementById("status").innerText = "READY";
    document.getElementById("status").classList.replace("text-red-600", "text-orange-600");
    document.getElementById("status").classList.replace("bg-red-50", "bg-orange-50");
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
          showError("Limit reached (" + limit + "). Upgrade to add more text.");
        }
        stopAnalysisUI();
        return;
      }

      const formData = new FormData();
      formData.append("audio", audioBlob);
      formData.append("audio_duration", durationSec);
      formData.append("manual_text", currentText);

      const res = await fetch("/process_audio", {
        method: "POST",
        headers: { "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content },
        body: formData,
        signal: analysisAbortController?.signal
      });

      const data = await res.json();
      if (!res.ok || data.error) showError(data.error || "Speech not recognized.");
      else updateUI(data);
      stopAnalysisUI();
    } catch (e) {
      if (e.name === 'AbortError') {
        console.log("Analysis cancelled by user");
      } else {
        showError("Network error.");
        console.error(e);
      }
      stopAnalysisUI();
    }
  }

  function startAnalysisUI() {
    isAnalyzing = true;
    buttonText.innerText = "CANCEL";
    analysisAbortController = new AbortController();

    document.getElementById("status").innerText = "PROCESSING...";
    recordBtn.classList.remove("recording");
    document.getElementById("recordingWave").classList.add("hidden");

    const transcriptCont = document.getElementById('transcriptContainer');
    const reviewCont = document.getElementById('reviewContainer');
    const overlay = document.getElementById('analyzingOverlay');

    if (transcriptCont) transcriptCont.classList.add('analyzing');
    if (reviewCont) reviewCont.classList.add('analyzing');
    if (overlay) overlay.classList.add('active');
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

    resetRecorderUI();
  }

  reParseBtn.onclick = async () => {
    const text = transcriptArea.value;
    const limit = window.profileCharLimit || 2000;

    // Use total user-content limit check only for manual re-parse
    // Refinements and Clarifications have their own pre-validation
    if (!window.skipTranscriptUpdate) {
      if (text.length > limit) {
        showError("Your transcript would exceed your character limit (" + limit + "). Upgrade to generate longer transcripts.");
        return;
      }
    }

    if (!text) return;

    // NEW: Clear previous answers if this is a fresh manual click (not via clarification)
    if (!window.skipTranscriptUpdate) {
      window.previousClarificationAnswers = [];
      window.clarificationHistory = [];
      renderPreviousAnswers();

      // Reset refinement/clarification inputs
      const refInput = document.getElementById('refinementInput');
      const clarInput = document.getElementById('clarificationAnswerInput');
      if (refInput) refInput.value = '';
      if (clarInput) clarInput.value = '';
      if (window.updateDynamicCounters) window.updateDynamicCounters();
    }

    startAnalysisUI();

    try {
      const res = await fetch("/process_audio", {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
          "Content-Type": "application/json"
        },
        body: JSON.stringify({ manual_text: text }),
        signal: analysisAbortController?.signal
      });
      const data = await res.json();

      if (data.error) showError(data.error);
      else updateUI(data);
    } catch (e) {
      if (e.name === 'AbortError') {
        console.log("Analysis cancelled by user");
      } else {
        showError("Network error.");
        console.error(e);
      }
    } finally {
      stopAnalysisUI();
    }
  };

  window.gatherLogData = function () {
    const client = document.getElementById("editClient")?.value || "";
    const date = document.getElementById("dateDisplay")?.innerText || "";
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
        const taxable = row.dataset.taxable === "true";
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
            tax_rate: (taxable && taxRate) ? taxRate : null,
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
        const taxable = row.dataset.taxable === "true";
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
        const reason = row.querySelector('.credit-reason-input')?.value?.trim() || "Courtesy Credit";
        if (amount > 0) {
          credits.push({ amount, reason });
          totalCreditValue += amount;
        }
      });
    }

    return {
      client, time: calculatedTotalTime.toString(), date,
      due_date: document.getElementById("dueDateValue")?.innerText || "",
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
      category_ids: document.getElementById("pdfLogCategory")?.value ? [document.getElementById("pdfLogCategory").value] : []
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
        saveLabel.innerText = 'Save';
        saveLabel.classList.add('text-gray-500');
        saveLabel.classList.remove('text-green-600');
      }

      // Reset Selectors
      if (typeof setPdfStatus === 'function') setPdfStatus('draft');
      if (typeof setPdfCategory === 'function') setPdfCategory('', '- No Category -', '');

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
    document.body.classList.add('overflow-hidden'); // PREVENT SCROLLING BACKGROUND

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

      // Store globally
      window.currentPdfUrl = url;
      window.currentPdfBlob = blob;
      window.currentPdfBuffer = arrayBuffer;

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
            throw new Error("Render process failed");
          }
        }).catch(err => {
          console.error("PDF.js Error:", err);
          showError("Display Error (" + (err.message || "Unknown") + "). Use Share button.");
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
      showError("Failed to generate preview");
      closePdfModal();
    }
  }

  window.closePdfModal = function () {
    const modal = document.getElementById('pdfModal');
    const overlay = document.getElementById('pdfModalOverlay');
    const content = document.getElementById('pdfModalContent');
    overlay.classList.remove('opacity-100');
    content.classList.add('translate-y-full');
    document.body.classList.remove('overflow-hidden'); // RESTORE SCROLLING BACKGROUND

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
      if (window.currentPdfUrl) {
        URL.revokeObjectURL(window.currentPdfUrl);
        window.currentPdfUrl = null;
        window.currentPdfBlob = null;
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
      saveLabel.innerText = 'Saved';
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
      saveLabel.innerText = 'LIMIT REACHED';
      saveLabel.classList.remove('text-gray-500', 'text-green-600');
      saveLabel.classList.add('text-red-600');
      saveLabel.classList.add('text-center');
    }
  }

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
    const originalLabelText = saveLabel ? saveLabel.innerText : 'Save';

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

        // Record the export event
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
            shareLabel.innerText = 'LIMIT REACHED';
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
    const currentSrc = window.currentPdfUrl || iframe?.src;

    if (!currentSrc || currentSrc === "" || currentSrc === "about:blank") {
      showError("PDF is still loading...");
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
              sLabel.innerText = 'LIMIT REACHED';
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
      let blob = window.currentPdfBlob;
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
      showError("Draft prepared. Click Share again to send.");
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
            saveLabel.innerText = 'Save';
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
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    targetDate.setHours(0, 0, 0, 0);
    daysUntil = Math.ceil((targetDate - today) / (1000 * 60 * 60 * 24));

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
  const formattedDate = targetDate.toLocaleDateString('en-US', {
    day: 'numeric',
    month: 'short',
    year: 'numeric'
  });

  dueDateValue.innerText = formattedDate;

  // Format the days label
  if (daysUntil === 0) {
    dueDaysLabel.innerText = '(due today)';
  } else if (daysUntil === 1) {
    dueDaysLabel.innerText = '(in 1 day)';
  } else if (daysUntil < 0) {
    dueDaysLabel.innerText = `(${Math.abs(daysUntil)} days overdue)`;
    dueDaysLabel.classList.add('text-red-500');
    dueDaysLabel.classList.remove('text-gray-400');
  } else {
    dueDaysLabel.innerText = `(in ${daysUntil} days)`;
    dueDaysLabel.classList.remove('text-red-500');
    dueDaysLabel.classList.add('text-gray-400');
  }

  // Store the selected date for calendar
  window.selectedDueDate = targetDate;
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
  monthYear.innerText = calendarViewDate.toLocaleDateString('en-US', { month: 'short', year: 'numeric' });

  // Get first day of month and total days
  const firstDay = new Date(year, month, 1).getDay();
  const daysInMonth = new Date(year, month + 1, 0).getDate();

  // Get today for highlighting
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  // Get selected date for highlighting
  const selected = window.selectedDueDate ? new Date(window.selectedDueDate) : null;
  if (selected) selected.setHours(0, 0, 0, 0);

  let html = '';

  // Empty cells for days before first day of month
  for (let i = 0; i < firstDay; i++) {
    html += '<div class="w-8 h-8"></div>';
  }

  // Days of the month
  for (let day = 1; day <= daysInMonth; day++) {
    const date = new Date(year, month, day);
    date.setHours(0, 0, 0, 0);

    const isToday = date.getTime() === today.getTime();
    const isSelected = selected && date.getTime() === selected.getTime();
    const isPast = date < today;

    let classes = 'w-8 h-8 rounded-lg text-xs font-black flex items-center justify-center cursor-pointer transition-all active:scale-95 active:translate-x-[1px] active:translate-y-[1px] shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] active:shadow-none bg-white active:bg-orange-600 active:text-white ';

    if (isSelected) {
      classes += '!bg-orange-600 !text-white border-2 border-black !shadow-none translate-x-[1px] translate-y-[1px]';
    } else if (isToday) {
      classes += 'border-2 border-orange-600 text-orange-600 md:hover:bg-orange-50';
    } else if (isPast) {
      classes += 'text-gray-300 cursor-not-allowed !shadow-none';
    } else {
      classes += 'md:hover:bg-orange-50 md:hover:text-orange-600 border-2 border-black';
    }

    const dateStr = `${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
    const onclick = isPast ? '' : `onclick="selectCalendarDate('${dateStr}')"`;

    html += `<button type="button" class="${classes}" ${onclick}>${day}</button>`;
  }

  daysContainer.innerHTML = html;
}

function selectCalendarDate(dateStr) {
  const parts = dateStr.split('-');
  const selectedDate = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]));

  // Use specific date pick (clears NET offset)
  updateDueDate(null, selectedDate);
  setTimeout(() => renderCalendar(), 0); // Defer to prevent "click outside" close
}

function setQuickDue(days) {
  updateDueDate(days, null);
  // Auto-scroll calendar view to show the new due date's month
  if (window.selectedDueDate) {
    calendarViewDate = new Date(window.selectedDueDate);
  }
  setTimeout(() => renderCalendar(), 0);
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

  const year = mainCalendarViewDate.getFullYear();
  const month = mainCalendarViewDate.getMonth();

  monthYear.innerText = mainCalendarViewDate.toLocaleDateString('en-US', { month: 'short', year: 'numeric' });

  const firstDay = new Date(year, month, 1).getDay();
  const daysInMonth = new Date(year, month + 1, 0).getDate();

  const today = new Date();
  today.setHours(0, 0, 0, 0);

  const selected = new Date(window.selectedMainDate);
  selected.setHours(0, 0, 0, 0);

  let html = '';
  for (let i = 0; i < firstDay; i++) {
    html += '<div class="w-8 h-8"></div>';
  }

  for (let day = 1; day <= daysInMonth; day++) {
    const date = new Date(year, month, day);
    date.setHours(0, 0, 0, 0);

    const isToday = date.getTime() === today.getTime();
    const isSelected = date.getTime() === selected.getTime();

    let classes = 'w-8 h-8 rounded-lg text-xs font-black flex items-center justify-center cursor-pointer transition-all active:scale-95 active:translate-x-[1px] active:translate-y-[1px] shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] active:shadow-none bg-white active:bg-orange-600 active:text-white ';

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

  document.getElementById('dateDisplay').innerText = selectedDate.toLocaleDateString('en-US', {
    month: 'short', day: 'numeric', year: 'numeric'
  });

  // Re-calculate Due Date if it's currently based on a NET offset
  if (window.currentDueOffset !== null && window.currentDueOffset !== undefined) {
    updateDueDate(window.currentDueOffset, null);
  }

  setTimeout(() => renderMainCalendar(), 0);
}


function addFullSection(title, items, isProtected = false) {
  const container = document.getElementById("dynamicSections");
  const sectionId = "section_" + Date.now() + "_" + Math.floor(Math.random() * 1000);

  // 1. Detect if this is a Labor/Service section
  const lowerTitle = title.toLowerCase();
  const isLaborService = /labor|service|install|repair|maintenance|diag|tech|professional/i.test(lowerTitle);

  if (isLaborService) {
    // Route to the special Labor Items Container
    const laborContainer = document.getElementById("laborItemsContainer");
    if (laborContainer) {
      // Show the group
      addLaborSection();
      // Clear existing items in Labor Container (assuming AI sends full list)
      // Exception: If we want to append? Usually AI sends full structure.
      laborContainer.innerHTML = `
             <!-- Add Item Button at Bottom -->
             <div class="flex justify-center mt-8 section-add-btn-container">
               <button type="button" onclick="addLaborItem()" 
                       class="bg-orange-600 text-white w-8 h-8 rounded-full flex items-center justify-center shadow-[3px_3px_0px_0px_rgba(0,0,0,1)] active:shadow-none active:translate-x-[2px] active:translate-y-[2px] active:scale-95 btn-add-labor-hover transition-all" title="Add Labor Item">
                 <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="3">
                   <path stroke-linecap="round" stroke-linejoin="round" d="M12 4v16m8-8H4" />
                 </svg>
               </button>
             </div>
          `;

      if (items && items.length > 0) {
        items.forEach(item => {
          if (!item) return;
          const val = typeof item === 'object' ? (item.desc || "") : item;
          const price = typeof item === 'object' ? (item.price || "") : "";
          const mode = typeof item === 'object' ? (item.mode || "") : "";
          const taxable = typeof item === 'object' ? (item.taxable) : null;
          const discFlat = typeof item === 'object' ? (item.discount_flat || "") : "";
          const discPercent = typeof item === 'object' ? (item.discount_percent || "") : "";
          const taxRate = typeof item === 'object' ? (item.tax_rate || "") : "";
          const rate = typeof item === 'object' ? (item.rate || "") : "";

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
  if (isProtected) sectionDiv.dataset.protected = title.toLowerCase();

  const isMaterials = /material/.test(lowerTitle);
  const isExpenses = /expense/.test(lowerTitle);
  const isFees = /fee/.test(lowerTitle);

  if (isMaterials) sectionDiv.dataset.protected = "materials";
  else if (isExpenses) sectionDiv.dataset.protected = "expenses";
  else if (isFees) sectionDiv.dataset.protected = "fees";

  // Icons and Colors for sections
  let sectionIcon = "";
  let accentColorClass = "text-orange-600";

  if (isMaterials) {
    sectionIcon = `<svg class="h-4 w-4 text-orange-600 mr-2"><use xlink:href="#icon-material"></use></svg>`;
    accentColorClass = "text-orange-600";
  } else if (isExpenses) {
    sectionIcon = `<svg class="h-4 w-4 text-red-600 mr-2"><use xlink:href="#icon-expense"></use></svg>`;
    accentColorClass = "text-red-600";
  } else if (isFees) {
    sectionIcon = `<svg class="h-4 w-4 text-blue-500 mr-2"><use xlink:href="#icon-fee"></use></svg>`;
    accentColorClass = "text-blue-500";
  } else {
    // Default Tasks Icon (Clipboard)
    sectionIcon = `<svg class="h-4 w-4 text-orange-600 mr-2"><use xlink:href="#icon-labor"></use></svg>`;
    accentColorClass = "text-orange-600";
  }

  // Auto-protect standard titles
  const forceProtect = isProtected || isMaterials || isExpenses || isFees;

  const titleElement = forceProtect
    ? `<div class="flex items-center">${sectionIcon}<span class="text-base font-black ${accentColorClass} uppercase tracking-widest section-title">${title}</span></div>`
    : `<div class="flex items-center w-2/3">${sectionIcon}<input type="text" value="${title}" class="bg-transparent border-none p-0 text-sm font-black ${accentColorClass} uppercase tracking-widest focus:ring-0 w-full section-title" onblur="validateCategoryName(this)"></div>`;

  const removeButton = `
        <button type="button" onclick="this.closest('.dynamic-section').remove(); updateTotalsSummary();" 
                class="bg-black text-white w-7 h-7 rounded-full flex items-center justify-center shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] active:shadow-none active:translate-x-[1px] active:translate-y-[1px] active:scale-95 hover:bg-gray-800 transition-all" title="Remove Section">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
          </svg>
        </button>`;

  const addItemBtn = `<button type="button" onclick="addItem('${sectionId}', '', '', null, '${title}')" 
               class="bg-orange-600 text-white w-7 h-7 rounded-full flex items-center justify-center shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] active:shadow-none active:translate-x-[1px] active:translate-y-[1px] active:scale-95 hover:bg-orange-700 transition-all" title="Add Item">
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
    <div id="${sectionId}" class="pt-6"></div>
  `;
  const type = sectionDiv.dataset.protected || 'other';
  insertSectionInOrder(sectionDiv, type);

  // If no items provided, add an empty item automatically
  if (items.length === 0) {
    addItem(sectionId, "", "", null, title);
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
      addItem(sectionId, val, price, taxable, title, taxRate, (item.qty && item.qty !== 'N/A') ? item.qty : 1, discFlat, discPercent, sub_categories);
    });
  }
}

// Validate category names - prevent reserved words
function validateCategoryName(input) {
  const reserved = ['fee', 'fees', 'expense', 'expenses', 'material', 'materials', 'labor', 'labour', 'service', 'services'];
  const val = input.value.toLowerCase().trim();

  if (reserved.some(r => val === r || val === r + 's' || val.includes('labor/service'))) {
    alert(`"${input.value}" is a reserved category name. Please choose a different name.`);
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
      btn.classList.add('text-gray-300', 'cursor-not-allowed');
      btn.classList.remove('text-black', 'hover:bg-orange-50', 'hover:text-orange-600', 'hover:bg-red-50', 'hover:text-red-600', 'hover:bg-blue-50', 'hover:text-blue-500');
    } else {
      btn.classList.remove('text-gray-300', 'cursor-not-allowed');
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
  const order = { 'materials': 1, 'expenses': 2, 'fees': 3, 'credit': 4, 'other': 5 };
  const currentPriority = order[type] || 5;

  const children = Array.from(container.children);
  for (let child of children) {
    const childType = child.dataset.protected || 'other';
    const childPriority = order[childType] || 5;

    if (childPriority > currentPriority) {
      container.insertBefore(sectionDiv, child);
      return;
    }
  }
  container.appendChild(sectionDiv);
}

function addMaterialSection() {
  addFullSection("Materials", [], true);
}

function addExpenseSection() {
  addFullSection("Expenses", [], true);
}

function addFeeSection() {
  addFullSection("Fees", [], true);
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
      // Re-add the "Add Item" button if it was removed with the last item
      if (!container.querySelector('.section-add-btn-container')) {
        const addButtonContainer = document.createElement('div');
        addButtonContainer.className = "flex justify-center mt-8 section-add-btn-container";
        addButtonContainer.innerHTML = `
               <button type="button" onclick="addLaborItem()" 
                       class="bg-orange-600 text-white w-8 h-8 rounded-full flex items-center justify-center shadow-[3px_3px_0px_0px_rgba(0,0,0,1)] active:shadow-none active:translate-x-[2px] active:translate-y-[2px] active:scale-95 btn-add-labor-hover transition-all" title="Add Labor Item">
                 <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="3">
                   <path stroke-linecap="round" stroke-linejoin="round" d="M12 4v16m8-8H4" />
                 </svg>
               </button>
            `;
        container.appendChild(addButtonContainer);
      }
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
    // Remove only credit rows, preserving the "Add" button
    if (container) {
      container.querySelectorAll('.credit-item-row').forEach(row => row.remove());
      // Re-add the "Add Item" button if it was removed with the last item
      if (!container.querySelector('.section-add-btn-container')) {
        const addButtonContainer = document.createElement('div');
        addButtonContainer.className = "flex justify-center mt-8 section-add-btn-container";
        addButtonContainer.innerHTML = `
                    <button type="button" onclick="addCreditItem('creditItemsContainer')" 
                            class="bg-red-600 text-white w-8 h-8 rounded-full flex items-center justify-center shadow-[3px_3px_0px_0px_rgba(0,0,0,1)] active:shadow-none active:translate-x-[2px] active:translate-y-[2px] active:scale-95 hover:bg-red-700 transition-all" title="Add Credit Item">
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="3">
                        <path stroke-linecap="round" stroke-linejoin="round" d="M12 4v16m8-8H4" />
                      </svg>
                    </button>
                `;
        container.appendChild(addButtonContainer);
      }
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
      <input type="text" class="flex-1 bg-transparent border-none text-[11px] font-bold text-black focus:ring-0 py-1 px-3 labor-sub-input placeholder:text-gray-300 min-w-0 outline-none" placeholder="Sub-category...">
    </div>
    <button type="button" onclick="removeLaborSubCategory(this)" class="w-5 h-8 flex items-center justify-center text-gray-300 hover:text-red-500 transition-colors font-bold text-xl flex-shrink-0">×</button>
  `;

  subContainer.appendChild(subItem);
  subItem.querySelector('input').focus();

  // Update button color to orange
  updateLaborAddBtnColor(laborItemRow);
}

function removeLaborSubCategory(btn) {
  const laborItemRow = btn.closest('.labor-item-row');
  btn.parentElement.remove();
  if (laborItemRow) {
    updateLaborAddBtnColor(laborItemRow);
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
      <input type="text" class="flex-1 bg-transparent border-none text-[11px] font-bold text-black focus:ring-0 py-1 px-3 sub-input placeholder:text-gray-300 min-w-0 outline-none" placeholder="Sub-category...">
    </div>
    <button type="button" onclick="this.parentElement.remove();" class="w-5 h-8 flex items-center justify-center text-gray-300 hover:text-red-500 transition-colors font-bold text-xl flex-shrink-0">×</button>
  `;

  subContainer.appendChild(subItem);
  subItem.querySelector('input').focus();

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
  const btn = row.querySelector('.labor-add-sub-btn');
  const subContainer = row.querySelector('.labor-sub-categories');
  if (!btn || !subContainer) return;

  const svg = btn.querySelector('svg');
  if (!svg) return;

  if (subContainer.children.length > 0) {
    svg.classList.remove('text-black');
    svg.classList.add('text-orange-600');
  } else {
    svg.classList.remove('text-orange-600');
    svg.classList.add('text-black');
  }
}

// Add a new Labor/Service item with simplified structure
// Add a new Labor/Service item with simplified structure
function addLaborItem(value = '', price = '', mode = '', taxable = null, discFlat = '', discPercent = '', taxRate = '', rate = '', sub_categories = [], noFocus = false) {
  const container = document.getElementById('laborItemsContainer');
  if (!container) return;

  // Insert before the "Add Item" button container (which is the last child)
  const addButtonContainer = container.lastElementChild;

  const div = document.createElement('div');
  div.className = "flex flex-col gap-2 w-full labor-item-row animate-in fade-in slide-in-from-left-2 duration-300 border-t-2 border-dashed border-orange-200 pt-6 mt-6 first:border-0 first:pt-0 first:mt-0";
  // Log ALL addLaborItem attempts for diagnostics
  console.log(`[addLaborItem CALL] Description: "${value}" | Price: "${price}" | TaxableArg: ${taxable} | Scope: "${currentLogTaxScope}"`);

  // Use the same tax fallback logic as addItem
  // true = Forced On, false = Forced Off, null = check defaults
  if (taxable === null || taxable === undefined) {
    const scopeData = (currentLogTaxScope || "").toLowerCase();
    const scope = scopeData.split(",").map(t => t.trim());

    const taxAll = scope.includes("all") || scope.includes("total") || (scope.length >= 4);
    const hasLaborScope = scope.some(s => s.includes("labor"));

    // If scope includes "all" or "labor", the item should be taxable by default
    // even if the price is currently empty (for new items).
    taxable = (taxAll || hasLaborScope);

    console.log(`[addLaborItem TAX DECISION] Final: ${taxable} | Scope: "${scopeData}"`);
  }

  div.dataset.taxable = taxable;

  const currencySymbol = activeCurrencySymbol;
  div.dataset.symbol = currencySymbol;

  // Resolve initial billing mode: default to 'hourly' if global is 'mixed'
  let initialMode = mode || currentLogBillingMode;
  if (initialMode === 'mixed') initialMode = 'hourly';
  div.dataset.billingMode = initialMode;

  const billingMode = initialMode;
  const defaultRate = rate || profileHourlyRate;
  const laborPriceVal = (price === "" || parseFloat(price) === 0) ? (billingMode === 'hourly' ? "1" : "10") : price;

  // DEFAULT LABOR NAME
  let finalValue = value;
  if (!finalValue || finalValue.trim() === "") {
    finalValue = "Professional Services";
  }

  const labelText = billingMode === 'hourly' ? 'LABOR HOURS' : 'LABOR PRICE';
  let laborInputHtml = '';

  if (billingMode === 'hourly') {
    laborInputHtml = `
            <div class="labor-inputs-target flex items-center flex-1 min-w-0 h-full px-3 gap-2">
                <!-- Clock Icon (Stylized) -->
                <div class="flex items-center justify-center bg-orange-600 text-white border-2 border-black rounded-lg h-6 w-6 shrink-0 select-none">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="3">
                     <path stroke-linecap="round" stroke-linejoin="round" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                </div>

                <!-- Hours Input -->
                <input type="number" step="0.1" class="labor-price-input bg-transparent border-none p-0 font-black text-black focus:ring-0 outline-none text-left min-w-0 text-sm placeholder:text-gray-300 w-12" 
                       value="${laborPriceVal}"
                       placeholder="0" 
                       oninput="updateTotalsSummary()">
                
                <!-- Multiplication Icon (Simple) -->
                <div class="flex items-center justify-center shrink-0">
                    <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="#9CA3AF" stroke-width="5" stroke-linecap="round"><path d="M18 6L6 18M6 6l12 12"/></svg>
                </div>

                <!-- Currency Icon (Stylized) -->
                <div class="flex items-center justify-center bg-orange-600 text-white font-black border-2 border-black rounded-lg h-6 w-6 shrink-0 select-none text-[10px] labor-currency-symbol">
                    ${currencySymbol}
                </div>

                <!-- Rate Input -->
                <input type="number" step="0.01" class="rate-menu-input bg-transparent border-none p-0 font-black text-black focus:ring-0 outline-none text-left min-w-0 text-sm placeholder:text-gray-300 flex-1" 
                       value="${defaultRate}" 
                       placeholder="0.00" 
                       oninput="updateTotalsSummary()">
            </div>
        `;
  } else {
    laborInputHtml = `
            <div class="labor-inputs-target flex items-center flex-1 min-w-0 h-full px-3 gap-2">
                <!-- Currency Icon (Stylized) -->
                <div class="flex items-center justify-center bg-orange-600 text-white font-black border-2 border-black rounded-lg h-6 w-6 shrink-0 select-none text-[10px] labor-currency-symbol">
                    ${currencySymbol}
                </div>

                <input type="number" step="0.01" class="labor-price-input bg-transparent border-none p-0 font-black text-black focus:ring-0 outline-none text-left min-w-0 text-sm placeholder:text-gray-300 w-full flex-1" 
                       value="${laborPriceVal || defaultRate}" 
                       placeholder="0.00" 
                       oninput="updateTotalsSummary()">
            </div>
        `;
  }

  div.innerHTML = `
    <div class="flex items-center gap-2 w-full">
      <div class="flex flex-1 items-center border-2 border-black rounded-xl bg-white shadow-[3px_3px_0px_0px_rgba(0,0,0,1)] min-w-0 main-item-box transition-colors relative">
        <!-- Add Sub-category Button -->
        <button type="button" onclick="addLaborSubCategory(this)" class="h-10 w-10 border-r-2 border-black flex-shrink-0 flex items-center justify-center bg-white transition-colors rounded-l-[10px] labor-add-sub-btn" title="Add sub-category">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-black transition-colors" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 4v16m8-8H4" />
          </svg>
          </button>
        <input type="text" value="${finalValue}" class="flex-1 bg-transparent border-none text-sm font-bold text-black focus:ring-0 py-2 px-3 labor-item-input placeholder:text-gray-300 min-w-0 rounded-r-xl" placeholder="Professional Services" oninput="updateTotalsSummary()">
      </div>
      <button type="button" onclick="this.closest('.labor-item-row').remove(); updateTotalsSummary();" class="remove-labor-btn w-6 h-10 flex items-center justify-center text-gray-300 hover:text-red-500 transition-colors font-bold text-xl flex-shrink-0">×</button>
    </div>
    <!-- Sub-categories container -->
    <div class="labor-sub-categories pl-6 space-y-2"></div>
    
       <!-- Price and Tax Row -->
    <div class="grid grid-cols-1 md:grid-cols-2 gap-y-3 md:gap-4 mt-1 relative">
        <!-- Labor Price with Settings -->
       <div class="space-y-1 relative labor-price-container">
           <label class="inline-block text-[9px] font-bold text-gray-500 uppercase ml-1 labor-label-price">${labelText}</label>
           <div class="flex items-center border-2 border-black rounded-xl bg-white shadow-[3px_3px_0px_0px_rgba(0,0,0,1)] relative h-[52px]">
               <!-- Menu Trigger -->
               <div class="h-full w-10 border-r-2 border-black flex-shrink-0 item-menu-container">
                  <button type="button" onclick="toggleMenu(this)" class="labor-menu-btn w-full h-full flex flex-col items-center justify-center gap-[3px] hover:bg-gray-50 item-menu-btn rounded-l-[10px]">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 transition-colors slider-icon" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                      <path d="M3 4h18M3 12h18M3 20h18" />
                      <path class="slider-head-1" d="M12 2v4" />
                      <path class="slider-head-2" d="M12 10v4" />
                      <path class="slider-head-3" d="M12 18v4" />
                    </svg>
                  </button>
                  <div class="item-menu-dropdown dropdown-labor-half">
                    <!-- NEW Billing Model Pill Switch -->
                    <div class="px-1 py-1">
                      <div class="billing-switch-group">
                        <span class="text-[8px] font-black text-gray-400 uppercase tracking-tighter ml-1">Billing Model</span>
                        <div class="billing-pill-container">
                          <button type="button" class="billing-pill-btn ${billingMode === 'hourly' ? 'active' : ''}" data-mode="hourly" onclick="setLaborRowBillingMode(this, 'hourly')">
                            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                            Hourly
                          </button>
                          <button type="button" class="billing-pill-btn ${billingMode === 'fixed' ? 'active' : ''}" data-mode="fixed" onclick="setLaborRowBillingMode(this, 'fixed')">
                            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                            Fixed
                          </button>
                        </div>
                      </div>
                    </div>
                    
                    <!-- Divider -->
                    <div class="h-[1px] bg-gray-100 mx-2 my-0.5"></div>
                    <!-- Tax Menu -->
                    <div class="tax-wrapper flex flex-col w-full">
                        <div class="menu-item menu-item-tax ${div.dataset.taxable === 'true' ? 'active' : ''}" onclick="toggleLaborTaxable(this)">
                          <span>Taxable</span>
                          <div class="menu-icon">%</div>
                        </div>
                        <div class="tax-inputs-row ${div.dataset.taxable === 'true' ? 'grid' : 'hidden'} gap-1 p-1 bg-gray-100 animate-in slide-in-from-top-1 duration-200 border border-t-0 border-gray-700 rounded-b-md" style="grid-template-columns: 1fr;">
                             <div class="relative w-full">
                               <div class="absolute left-1 top-1/2 -translate-y-1/2 h-5 w-5 flex items-center justify-center bg-gray-100 text-gray-500 font-bold border border-gray-300 rounded-md text-[9px] pointer-events-none select-none z-10">
                                 <span>%</span>
                               </div>
                               <input type="number" step="0.1" class="menu-input tax-menu-input text-right w-full border-gray-400 pl-7 pr-1 bg-white" 
                                      style="width: 100%"
                                      value="${(taxRate !== null && taxRate !== undefined && taxRate !== '') ? taxRate : profileTaxRate}" placeholder="%" 
                                      oninput="updateTotalsSummary()">
                             </div>
                        </div>
                    </div>
                    <!-- Divider -->
                    <div class="h-[1px] bg-gray-100 mx-2 my-0.5"></div>
                    <!-- Discount Menu -->
                      <div class="discount-wrapper flex flex-col w-full">
                        <div class="menu-item menu-item-discount ${(discFlat || discPercent) ? 'active' : ''}" onclick="toggleDiscount(this)">
                          <span>Item Discount</span>
                          <div class="menu-icon">
                            <svg xmlns="http://www.w3.org/2000/svg" class="h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                              <path stroke-linecap="round" stroke-linejoin="round" d="M12 8v13m0-13V6a2 2 0 112 2h-2zm0 0V5.5A2.5 2.5 0 109.5 8H12zm-7 4h14M5 12a2 2 0 110-4h14a2 2 0 110 4M5 12v7a2 2 0 002 2h10a2 2 0 002-2v-7" />
                            </svg>
                          </div>
                        </div>
                        
                        <div class="discount-inputs-row ${(discFlat || discPercent) ? 'grid' : 'hidden'} gap-1 p-1 bg-green-50 animate-in slide-in-from-top-1 duration-200 border border-t-0 border-green-600 rounded-b-md" style="grid-template-columns: 1fr 1fr;">
                              <div class="relative w-full">
                                <div class="absolute left-1 top-1/2 -translate-y-1/2 h-5 w-5 flex items-center justify-center bg-gray-100 text-gray-500 font-bold border border-gray-300 rounded-md text-[9px] pointer-events-none select-none z-10">
                                  <span class="discount-flat-symbol">${currencySymbol}</span>
                                </div>
                                <input type="number" step="0.01" class="menu-input discount-flat-input text-right w-full border-gray-300 pl-7 pr-1" 
                                       style="width: 100%"
                                       value="${discFlat}"
                                       placeholder="0.00" 
                                       oninput="updateTotalsSummary()">
                              </div>
                              <div class="relative w-full">
                                <div class="absolute left-1 top-1/2 -translate-y-1/2 h-5 w-5 flex items-center justify-center bg-gray-100 text-gray-500 font-bold border border-gray-300 rounded-md text-[9px] pointer-events-none select-none z-10">
                                  <span>%</span>
                                </div>
                                <input type="number" step="0.1" class="menu-input discount-percent-input text-right w-full border-gray-300 pl-7 pr-1" 
                                       style="width: 100%"
                                       value="${discPercent}"
                                       placeholder="0" 
                                       oninput="updateTotalsSummary()">
                              </div>
                              <div class="col-span-2 pt-1 pb-1 px-1">
                                <label class="block text-[8px] font-black uppercase tracking-widest text-gray-400 mb-1 ml-1 text-left">Discount message:</label>
                                <input type="text" class="menu-input discount-message-input text-left w-full border border-gray-300 px-2 py-2 bg-white text-xs font-bold rounded-md" 
                                       placeholder="Reason for discount..." style="width: 100%"
                                       oninput="updateTotalsSummary()">
                              </div>
                       </div>
                    </div>
                 </div>
               </div>
               
               ${laborInputHtml}
               
                <!-- Top Badges Scrollable Area (Discount) -->
                <div class="absolute -top-[31px] left-[10px] right-[8px] h-[30px] pointer-events-none z-[90] overflow-visible">
                    <div class="custom-scrollbar overflow-x-auto h-full pointer-events-auto flex" style="direction: rtl; transform: rotateX(180deg);">
                        <div class="flex items-center gap-1 shrink-0 h-[24px] px-0.5" style="direction: ltr; min-width: 100%; justify-content: flex-end;">
                            <span class="badge badge-original-price hidden bg-orange-600 text-white" 
                                  style="border: 1px solid black; box-shadow: 2px 0 0 0 #000, 0 2px 0 0 #000, 2px 2px 0 0 #000;"></span>
                            
                            <div class="badge-operator badge-minus hidden flex items-center justify-center">
                                <span style="transform: rotateX(180deg); display: flex;">
                                  <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="black" stroke-width="5" stroke-linecap="round"><path d="M5 12h14"/></svg>
                                </span>
                            </div>

                            <span class="badge badge-discount-amount hidden bg-green-600 text-white" 
                                  style="border: 1px solid black; box-shadow: 2px 0 0 0 #000, 0 2px 0 0 #000, 2px 2px 0 0 #000;"></span>
                            
                            <div class="badge-operator badge-equals-top hidden flex items-center justify-center">
                                <span style="transform: rotateX(180deg); display: flex;">
                                  <svg width="12" height="10" viewBox="0 0 24 24" fill="none" stroke="black" stroke-width="5" stroke-linecap="round"><path d="M4 8h16M4 16h16"/></svg>
                                </span>
                            </div>
                            
                            <span class="badge badge-discounted-price hidden bg-orange-600 text-white" 
                                  style="border: 1px solid black; box-shadow: 2px 0 0 0 #000, 0 2px 0 0 #000, 2px 2px 0 0 #000;"></span>

                            <!-- Legacy/Fallback (Hidden) -->
                            <span class="badge badge-discount hidden"></span>
                        </div>
                    </div>
                </div>
                <!-- Bottom Badges Scrollable Area -->
                <div class="absolute -bottom-[31px] left-[10px] right-[8px] h-[30px] pointer-events-none z-[90] overflow-visible">
                    <div class="custom-scrollbar overflow-x-auto h-full pointer-events-auto flex" style="direction: rtl;">
                        <div class="flex items-center gap-1 shrink-0 h-[24px] px-0.5" style="direction: ltr; min-width: 100%; justify-content: flex-end;">
                            <span class="badge badge-price hidden shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] border border-black bg-orange-600 text-white"></span>
                            <div class="badge-operator badge-multiplier hidden flex items-center justify-center">
                                <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="black" stroke-width="5" stroke-linecap="round"><path d="M18 6L6 18M6 6l12 12"/></svg>
                            </div>
                            <span class="badge badge-tax hidden shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] border border-black bg-gray-700 text-white"></span>
                            <div class="badge-operator badge-equals hidden flex items-center justify-center">
                                <svg width="12" height="10" viewBox="0 0 24 24" fill="none" stroke="black" stroke-width="5" stroke-linecap="round"><path d="M4 8h16M4 16h16"/></svg>
                            </div>
                            <span class="badge badge-after-tax hidden shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] border border-black bg-gray-700 text-white"></span>
                        </div>
                    </div>
                </div>
            </div>
        </div>

       <!-- After Tax -->
        <div class="space-y-1 relative labor-after-tax-container">
            <label class="inline-block text-[9px] font-bold text-gray-500 uppercase ml-1 transition-all">AFTER TAX</label>
            <div class="border-2 border-black rounded-xl bg-white shadow-[3px_3px_0px_0px_rgba(0,0,0,1)] relative h-[52px] w-max min-w-[120px] max-w-full overflow-visible">
                <!-- Internal Scrollable Area -->
                <div class="custom-scrollbar overflow-x-auto h-[62px] flex items-start pl-2">
                    <div class="flex items-center gap-0 w-max h-[48px] labor-formula-row">
                        <!-- Rebuilt in JS during updateTotalsSummary -->
                    </div>
                </div>
            </div>
        </div>
    </div>
  `;

  if (addButtonContainer && addButtonContainer.classList.contains('flex') && addButtonContainer.querySelector('button[title="Add Labor Item"]')) {
    container.insertBefore(div, addButtonContainer);
  } else {
    container.appendChild(div);
  }

  // Populate Sub-categories
  if (sub_categories && sub_categories.length > 0) {
    const subContainer = div.querySelector('.labor-sub-categories');
    sub_categories.forEach(sub => {
      if (!sub) return;
      const subItem = document.createElement('div');
      subItem.className = "flex items-center gap-2 animate-in fade-in slide-in-from-left-2 duration-300 labor-sub-item";
      subItem.innerHTML = `
        <div class="w-2 h-2 rounded-full bg-black flex-shrink-0"></div>
        <div class="flex-1 flex items-center border-2 border-black rounded-lg bg-white shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] transition-colors relative h-8">
          <input type="text" class="flex-1 bg-transparent border-none text-[11px] font-bold text-black focus:ring-0 py-1 px-3 labor-sub-input placeholder:text-gray-300 min-w-0 outline-none" value="${String(sub).replace(/"/g, '&quot;')}" placeholder="Sub-category...">
        </div>
        <button type="button" onclick="removeLaborSubCategory(this)" class="w-5 h-8 flex items-center justify-center text-gray-300 hover:text-red-500 transition-colors font-bold text-sm flex-shrink-0">×</button>
      `;
      subContainer.appendChild(subItem);
    });
    updateLaborAddBtnColor(div);
  }

  // Only focus when user explicitly clicks add (no value pre-filled AND not suppressed)
  if (!value && !price && !mode && !noFocus) {
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
    // Remove only credit rows, preserving the "Add" button
    if (container) {
      container.querySelectorAll('.credit-item-row').forEach(row => row.remove());
    }
  }
  updateTotalsSummary();
}

// Add Credit item - just a reason input (price is set via the global Credit popover)
// Add Credit item (Amount + Reason)
function addCreditItem(containerId, reason = "Courtesy Credit", amount = "") {
  const container = document.getElementById(containerId);
  if (!container) return;

  const div = document.createElement('div');
  div.className = "flex flex-col gap-2 w-full animate-in fade-in slide-in-from-left-2 duration-300 credit-item-row border-t-2 border-dashed border-red-200 pt-6 mt-6 first:border-0 first:pt-0 first:mt-0";

  const currencySymbol = typeof activeCurrencySymbol !== 'undefined' ? activeCurrencySymbol : "$";

  div.innerHTML = `
    <!-- Amount Input Section -->
    <div class="space-y-1 relative w-1/2">
      <label class="block text-[9px] font-bold text-gray-500 uppercase ml-1">
        CREDIT AMOUNT
      </label>
      <div class="flex items-center border-2 border-black rounded-xl bg-white shadow-[3px_3px_0px_0px_rgba(0,0,0,1)] relative h-[52px]">
          <span class="flex items-center justify-center bg-red-600 text-white font-black border-2 border-black rounded-lg h-6 w-6 ml-2 shrink-0 select-none text-[10px] credit-unit-indicator">${currencySymbol}</span>
          <input type="number" step="0.01" 
                 class="credit-amount-input bg-transparent border-none py-3 pl-2 pr-2 font-black text-black focus:ring-0 outline-none text-left min-w-0 text-sm placeholder:text-gray-300 w-full flex-1"
                 value="${amount}"
                 placeholder="Amount"
                 oninput="updateTotalsSummary()">
      </div>
    </div>

    <!-- Reason Input Section + Remove -->
    <div class="flex items-center gap-2 w-full">
      <div class="flex flex-1 items-center border-2 border-black rounded-xl bg-white shadow-[3px_3px_0px_0px_rgba(0,0,0,1)] min-w-0 main-item-box transition-colors relative h-[52px]">
        <input type="text" value="${reason || 'Courtesy Credit'}" class="flex-1 bg-transparent border-none text-sm font-bold text-black focus:ring-0 py-3 px-4 credit-reason-input placeholder:text-gray-300 min-w-0 rounded-xl"
               placeholder="Courtesy Credit">
      </div>
      
      <button type="button" 
              onclick="this.closest('.credit-item-row').remove(); updateTotalsSummary();" 
              class="remove-credit-btn w-6 h-10 flex items-center justify-center text-gray-300 hover:text-red-500 transition-colors font-bold text-xl flex-shrink-0">
        ×
      </button>
    </div>
  `;

  const addButtonDiv = container.querySelector('.section-add-btn-container');
  if (addButtonDiv) {
    container.insertBefore(div, addButtonDiv);
  } else {
    container.appendChild(div);
  }
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
  const isTaxable = row.dataset.taxable === "true";

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

  // Discount Calculation & Validation
  const discFlatInput = row.querySelector('.discount-flat-input');
  const discPercentInput = row.querySelector('.discount-percent-input');

  let discFlat = parseFloat(discFlatInput ? discFlatInput.value : 0) || 0;
  let discPercent = parseFloat(discPercentInput ? discPercentInput.value : 0) || 0;

  const baseTotal = priceVal * qtyVal;

  // Validation: Cap Percentage at 100
  if (discPercent > 100) {
    discPercent = 100;
    discPercentInput.value = "100"; // Visual Clamp
  }

  // Validation: Cap Flat at BaseTotal
  if (discFlat > baseTotal) {
    discFlat = baseTotal;
    discFlatInput.value = cleanNum(baseTotal); // Visual Clamp
  }

  // Priority: If Percent is present, it might override or add? 
  // User said "one will say $ for flat, the other % for percentage". Usually mutually exclusive or additive.
  // Implementation plan: Additive (Flat + Percent of Base).
  // But Validation says "Discount cannot be... more than the actual price".

  let discountAmount = discFlat + (baseTotal * (discPercent / 100));

  // Final Cap on Total Discount
  if (discountAmount > baseTotal) {
    discountAmount = baseTotal;
    // If we hit this, it means the combination exceeded total. 
    // We could clamp the flat amount down? Or just clamp the result.
    // Clamping result covers it.
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
    row.querySelector('.menu-item-tax').classList.add('active');
  } else {
    taxBadge.classList.add('hidden');
    row.querySelector('.menu-item-tax').classList.toggle('active', isTaxable);
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
  afterTaxDisplay.innerText = cleanNum(total);

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

function addItem(containerId, value = "", price = "", taxable = null, sectionTitle = "", taxRate = null, qty = 1, discFlat = "", discPercent = "", sub_categories = []) {
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
  const subtotalLabelText = "AFTER TAX";

  // Default taxable logic and item naming
  const lowerTitle = (sectionTitle || "").toLowerCase();
  const isLaborSection = /labor|service|install|diag|repair|maintenance|tech|professional/i.test(lowerTitle);
  const isMaterialSection = /material|part|item/i.test(lowerTitle);
  const isFeeSection = /fee|surcharge/i.test(lowerTitle);
  const isExpenseSection = /expense|reimburse/i.test(lowerTitle);

  // DEFAULT ITEM NAME based on section
  if (!finalValue || finalValue.trim() === "") {
    if (isMaterialSection) finalValue = "Material";
    else if (isFeeSection) finalValue = "Fee";
    else if (isExpenseSection) finalValue = "Expense";
    else finalValue = "Item";
  }

  // Default Price for manually added items in these sections
  if (!price || price === "" || parseFloat(price) === 0) {
    if (isMaterialSection || isExpenseSection || isFeeSection) {
      price = "10";
    }
  }

  // Log ALL addItem attempts for diagnostics
  console.log(`[addItem CALL] Section: "${sectionTitle}" | Price: "${price}" | TaxableArg: ${taxable} | Scope: "${currentLogTaxScope}"`);

  // If taxable is exactly false, we respect it as "No Tax".
  // null = check defaults
  if (taxable === null || taxable === undefined) {
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



  // Default Tax Rate
  const globalRate = profileTaxRate;
  if (taxRate === null || taxRate === undefined || taxRate === '') {
    taxRate = globalRate;
  }

  const div = document.createElement('div');
  div.dataset.taxable = taxable;
  div.dataset.symbol = currencySymbol;
  div.dataset.qty = finalQty;
  // Adjusted margin (mb-8) for optimal spacing
  div.className = "flex flex-col gap-2 mb-8 w-full animate-in fade-in slide-in-from-left-2 duration-300 item-row transition-all";

  // Inputs (Price and Tax)
  const hasPrice = price && price !== "" && price !== "0" && price !== "0.00";
  const priceVal = hasPrice ? cleanNum(price) : "";

  // Discount Logic for Initial Load
  const hasDiscount = (discFlat && parseFloat(discFlat) > 0) || (discPercent && parseFloat(discPercent) > 0);
  const discActiveClass = hasDiscount ? "active" : "";
  const discFlatVal = discFlat ? cleanNum(discFlat) : "";
  const discPercentVal = discPercent ? cleanNum(discPercent) : "";

  const priceActiveClass = hasPrice ? "active" : "";
  const taxActiveClass = taxable ? "active" : "";

  // Style for locked state
  const lockedStyle = taxable ? 'opacity: 0.5;' : '';
  const cursorStyle = taxable ? 'cursor: not-allowed;' : '';

  div.innerHTML = `
      <div class="flex items-center gap-2 w-full">
        <div class="flex flex-1 items-center border-2 border-black rounded-xl bg-white shadow-[3px_3px_0px_0px_rgba(0,0,0,1)] min-w-0 main-item-box transition-colors relative">
          
          <!-- Hamburger Menu Container -->
          <div class="h-10 w-10 border-r-2 border-black flex-shrink-0 item-menu-container">
            <button type="button" onclick="toggleMenu(this)" class="w-full h-full flex flex-col items-center justify-center gap-[3px] btn-hamburger-hover item-menu-btn rounded-l-[10px]">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 transition-colors slider-icon" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
                <path d="M3 4h18M3 12h18M3 20h18" />
                <path class="slider-head-1" d="M12 2v4" />
                <path class="slider-head-2" d="M12 10v4" />
                <path class="slider-head-3" d="M12 18v4" />
              </svg>
            </button>
            
            <div class="item-menu-dropdown dropdown-standard">
              
              <!-- Subcategory Option (NEW) -->
              <div class="menu-item menu-item-subcategory" onclick="addItemSubCategory(this)">
                <span>Add Subcategory</span>
                <div class="menu-icon">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="3">
                    <path stroke-linecap="round" stroke-linejoin="round" d="M12 4v16m8-8H4" />
                  </svg>
                </div>
              </div>
              
              <!-- Divider -->
              <div class="h-[1px] bg-gray-100 mx-2 my-0.5"></div>
            
            <!-- Tax Menu Item (MOVED TOP) -->
            <div class="tax-wrapper flex flex-col w-full">
                <div class="menu-item menu-item-tax ${taxActiveClass}" onclick="toggleTaxable(this)">
                  <span>Taxable</span>
                  <div class="menu-icon">%</div>
                </div>
                
                <div class="tax-inputs-row ${taxable ? 'grid' : 'hidden'} gap-1 p-1 bg-gray-100 animate-in slide-in-from-top-1 duration-200 border border-t-0 border-gray-700 rounded-b-md"
                     style="grid-template-columns: 1fr;">
                     <div class="relative w-full">
                       <div class="absolute left-1 top-1/2 -translate-y-1/2 h-5 w-5 flex items-center justify-center bg-gray-100 text-gray-500 font-bold border border-gray-300 rounded-md text-[9px] pointer-events-none select-none z-10">
                         <span>%</span>
                       </div>
                       <input type="number" step="0.1" class="menu-input tax-menu-input text-right w-full border-gray-400 pl-7 pr-1 bg-white" 
                              style="width: 100%"
                              value="${(taxRate !== null && taxRate !== undefined && taxRate !== '') ? taxRate : profileTaxRate}" placeholder="%" 
                              oninput="updateBadge(this.closest('.item-row'))">
                     </div>
                </div>
            </div>
            <!-- Divider -->
            <div class="h-[1px] bg-gray-100 mx-2 my-0.5"></div>
            <!-- Price Menu Item (Moved Middle) -->
            <div class="price-wrapper flex flex-col w-full">
                <div class="menu-item menu-item-price ${priceActiveClass}" onclick="togglePrice(this)"
                     style="${cursorStyle}">
                  <span style="${lockedStyle}">Price</span>
                  <div class="menu-icon price-menu-icon" style="${lockedStyle}">${currencySymbol}</div>
                </div>

                <div class="price-inputs-row ${hasPrice ? 'grid' : 'hidden'} gap-1 p-1 bg-orange-50 animate-in slide-in-from-top-1 duration-200 border border-t-0 border-orange-600 rounded-b-md"
                     style="grid-template-columns: 1fr;">
                     <div class="relative w-full">
                        <div class="absolute left-1 top-1/2 -translate-y-1/2 h-5 w-5 flex items-center justify-center bg-gray-100 text-gray-500 font-bold border border-gray-300 rounded-md text-[9px] pointer-events-none select-none z-10">
                           <span class="price-input-symbol">${currencySymbol}</span>
                        </div>
                        <input type="number" step="0.01" class="menu-input price-menu-input text-right w-full border-orange-200 pl-7 pr-1" 
                               style="width: 100%"
                               value="${priceVal}" placeholder="0.00" 
                               oninput="updateBadge(this.closest('.item-row'))">
                     </div>
                </div>
            </div>
            <!-- Divider -->
            <div class="h-[1px] bg-gray-100 mx-2 my-0.5"></div>
            <!-- Discount Menu Item (Moved Last) -->
            <div class="discount-wrapper flex flex-col w-full">
                <div class="menu-item menu-item-discount ${discActiveClass}" onclick="toggleDiscount(this)">
                  <span>Item Discount</span>
                  <div class="menu-icon">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M12 8v13m0-13V6a2 2 0 112 2h-2zm0 0V5.5A2.5 2.5 0 109.5 8H12zm-7 4h14M5 12a2 2 0 110-4h14a2 2 0 110 4M5 12v7a2 2 0 002 2h10a2 2 0 002-2v-7" />
                    </svg>
                  </div>
                </div>
                
                <!-- Inline Input Container -->
                <div class="discount-inputs-row ${hasDiscount ? 'grid' : 'hidden'} gap-1 p-1 bg-green-50 animate-in slide-in-from-top-1 duration-200 border border-t-0 border-green-600 rounded-b-md" 
                     style="grid-template-columns: 1fr 1fr;">
                     <div class="relative w-full">
                       <div class="absolute left-1 top-1/2 -translate-y-1/2 h-5 w-5 flex items-center justify-center bg-gray-100 text-gray-500 font-bold border border-gray-300 rounded-md text-[9px] pointer-events-none select-none z-10">
                         <span class="discount-flat-symbol">${currencySymbol}</span>
                       </div>
                       <input type="number" step="0.01" class="menu-input discount-flat-input text-right w-full border-gray-300 pl-7 pr-1" 
                              style="width: 100%"
                              value="${discFlatVal}"
                              placeholder="0.00" 
                              oninput="updateBadge(this.closest('.item-row'))">
                     </div>
                     <div class="relative w-full">
                       <div class="absolute left-1 top-1/2 -translate-y-1/2 h-5 w-5 flex items-center justify-center bg-gray-100 text-gray-500 font-bold border border-gray-300 rounded-md text-[9px] pointer-events-none select-none z-10">
                         <span>%</span>
                       </div>
                       <input type="number" step="0.1" class="menu-input discount-percent-input text-right w-full border-gray-300 pl-7 pr-1" 
                              style="width: 100%"
                              value="${discPercentVal}"
                              placeholder="0" 
                              oninput="updateBadge(this.closest('.item-row'))">
                      </div>
                      <div class="col-span-2 pt-1 pb-1 px-1">
                        <label class="block text-[8px] font-black uppercase tracking-widest text-gray-400 mb-1 ml-1 text-left">Discount message:</label>
                        <input type="text" class="menu-input discount-message-input text-left w-full border border-gray-300 px-2 py-2 bg-white text-xs font-bold rounded-md" 
                               placeholder="Reason for discount..." style="width: 100%"
                               oninput="updateBadge(this.closest('.item-row'))">
                      </div>
                 </div>
            </div>

          </div>
        </div>
  
        <input type="text" value="${finalValue}" 
               class="flex-1 bg-transparent border-none text-sm font-bold text-black focus:ring-0 py-2 px-3 item-input placeholder:text-gray-300 min-w-0"
               placeholder="Description..." oninput="updateTotalsSummary()">
        
         <div class="flex items-center gap-0.5 px-1 border-l-2 border-black h-10 group/qty bg-gray-50/50 rounded-r-[10px] shrink-0 overflow-hidden transition-all duration-200">
          <span class="text-[13px] font-black text-black select-none translate-y-[0.5px]">×</span>
          <input type="number" 
                 class="qty-input bg-transparent border-none p-0 font-black text-black focus:ring-0 outline-none text-center text-xs md:text-sm placeholder:text-gray-300"
                 style="min-width: 0; width: 20px;"
                 value="${finalQty}" placeholder="1" 
                 oninput="updateBadge(this.closest('.item-row')); resizeQtyInput(this);"
                 onblur="if(this.value==='' || parseFloat(this.value)<=0){this.value='1'; updateBadge(this.closest('.item-row')); resizeQtyInput(this);}">
        </div>
        
        <!-- Top Badges Scrollable Area (Discount) -->
      <div class="absolute -top-[31px] left-[10px] right-[8px] h-[30px] pointer-events-none z-[90] overflow-visible">
          <div class="custom-scrollbar overflow-x-auto h-full pointer-events-auto flex" style="direction: rtl; transform: rotateX(180deg);">
              <div class="flex items-center gap-1 shrink-0 h-[24px] px-0.5" style="direction: ltr; min-width: 100%; justify-content: flex-end;">
                  <!-- Formula: Original - Discount = Final -->
                  
                  <span class="badge badge-original-price hidden bg-orange-600 text-white" 
                        style="border: 1px solid black; box-shadow: 2px 0 0 0 #000, 0 2px 0 0 #000, 2px 2px 0 0 #000;"></span>
                  
                  <div class="badge-operator badge-minus hidden flex items-center justify-center">
                      <span style="transform: rotateX(180deg); display: flex;">
                        <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="black" stroke-width="5" stroke-linecap="round"><path d="M5 12h14"/></svg>
                      </span>
                  </div>
                  
                  <span class="badge badge-discount-amount hidden bg-green-600 text-white"
                        style="border: 1px solid black; box-shadow: 2px 0 0 0 #000, 0 2px 0 0 #000, 2px 2px 0 0 #000;"></span>
                  
                  <div class="badge-operator badge-equals-top hidden flex items-center justify-center">
                      <span style="transform: rotateX(180deg); display: flex;">
                        <svg width="12" height="10" viewBox="0 0 24 24" fill="none" stroke="black" stroke-width="5" stroke-linecap="round"><path d="M4 8h16M4 16h16"/></svg>
                      </span>
                  </div>
                  
                  <span class="badge badge-discounted-price hidden bg-orange-600 text-white"
                        style="border: 1px solid black; box-shadow: 2px 0 0 0 #000, 0 2px 0 0 #000, 2px 2px 0 0 #000;"></span>
                  
                  <!-- Legacy Fallback (Hidden) -->
                  <span class="badge badge-discount hidden"></span>
              </div>
          </div>
      </div>
      
      <!-- Bottom Badges Scrollable Area -->
      <div class="absolute -bottom-[31px] left-[10px] right-[8px] h-[30px] pointer-events-none z-[90] overflow-visible">
          <div class="custom-scrollbar overflow-x-auto h-full pointer-events-auto flex" style="direction: rtl;">
              <div class="flex items-center gap-1 shrink-0 h-[24px] px-0.5" style="direction: ltr; min-width: 100%; justify-content: flex-end;">
                  <span class="badge badge-price hidden shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] border border-black bg-orange-600 text-white"></span>
                  <div class="badge-operator badge-multiplier hidden flex items-center justify-center">
                      <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="black" stroke-width="5" stroke-linecap="round"><path d="M18 6L6 18M6 6l12 12"/></svg>
                  </div>
                  <span class="badge badge-tax hidden shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] border border-black bg-gray-700 text-white"></span>
                  <div class="badge-operator badge-equals hidden flex items-center justify-center">
                      <svg width="12" height="10" viewBox="0 0 24 24" fill="none" stroke="black" stroke-width="5" stroke-linecap="round"><path d="M4 8h16M4 16h16"/></svg>
                  </div>
                  <span class="badge badge-after-tax hidden shadow-[2px_2px_0px_0px_rgba(0,0,0,1)] border border-black bg-gray-700 text-white"></span>
              </div>
          </div>
      </div>
      </div>
      <button type="button" 
              onclick="this.closest('.item-row').remove(); updateTotalsSummary();" 
              class="remove-item-btn w-6 h-10 flex items-center justify-center text-gray-300 btn-remove-item-hover transition-colors font-bold text-xl flex-shrink-0">
        ×
      </button>
    </div>
    <!-- Sub-categories container -->
    <div class="sub-categories pl-6 space-y-2 mt-6"></div>

    <!-- Item Subtotal Box -->
    <div class="item-subtotal-container pl-6 mt-4 hidden animate-in fade-in slide-in-from-top-1 duration-300">
      <div class="flex flex-col gap-1">
        <label class="item-subtotal-label text-[9px] font-black text-gray-400 uppercase tracking-widest ml-1">AFTER TAX</label>
        <div class="border-2 border-black rounded-xl bg-white shadow-[3px_3px_0px_0px_rgba(0,0,0,1)] relative h-[52px] w-max min-w-[120px] max-w-full overflow-visible">
            <div class="custom-scrollbar overflow-x-auto h-[62px] flex items-start pl-2">
                <div class="flex items-center gap-0 w-max h-[48px] item-formula-row">
                    <!-- Formula injected here in updateBadge -->
                </div>
            </div>
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
          <input type="text" class="flex-1 bg-transparent border-none text-[11px] font-bold text-black focus:ring-0 py-1 px-3 sub-input placeholder:text-gray-300 min-w-0 outline-none" value="${String(sub).replace(/"/g, '&quot;')}" placeholder="Sub-category...">
        </div>
        <button type="button" onclick="this.parentElement.remove();" class="w-5 h-8 flex items-center justify-center text-gray-300 hover:text-red-500 transition-colors font-bold text-sm flex-shrink-0">×</button>
      `;
      subContainer.appendChild(subItem);
    });
  }

  randomizeIcon(div); // RANDOMIZE ON CREATION
  updateBadge(div);
  updateHamburgerGlow(div);
  setTimeout(() => {
    const qi = div.querySelector('.qty-input');
    if (qi) resizeQtyInput(qi);
  }, 50);
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

      // Since this is a fresh transcript, reset refinements/clarifications
      window.previousClarificationAnswers = [];
      window.clarificationHistory = [];
      renderPreviousAnswers();
      const refInput = document.getElementById('refinementInput');
      const clarInput = document.getElementById('clarificationAnswerInput');
      if (refInput) refInput.value = '';
      if (clarInput) clarInput.value = '';

      if (window.updateDynamicCounters) window.updateDynamicCounters();
    }
    window.skipTranscriptUpdate = false; // Reset flag after use
    document.getElementById("editClient").value = data.client || "";
    // const laborBox removed


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
    document.querySelectorAll('#creditUnitIndicator').forEach(el => el.innerText = currencySymbol);
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
        addCreditItem('creditItemsContainer', data.credit_reason || "Courtesy Credit", data.credit_flat);
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
      dateVal = new Date().toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
    }
    document.getElementById("dateDisplay").innerText = dateVal;
    window.selectedMainDate = new Date(dateVal);

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
      data.sections.forEach(sec => addFullSection(sec.title, sec.items));
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

    document.getElementById("invoicePreview").classList.remove("hidden");
    document.getElementById("invoicePreview").scrollIntoView({ behavior: 'smooth' });

    if (typeof window.trackEvent === 'function') {
      window.trackEvent('invoice_generated');
    }

    // Update totals summary after all items are added
    updateTotalsSummary();

    // Handle AI Clarification Questions
    handleClarifications(data.clarifications || []);

    if (window.pendingClarifications && window.pendingClarifications.length === 0) {
      window.setupSaveButton();
    }

    window.isAutoUpdating = false;
  } catch (e) {
    window.isAutoUpdating = false;
    showError("UI Update Error: " + e.message);
    console.error(e);
  }
}

// Store pending clarifications globally
window.skipTranscriptUpdate = false;
window.pendingClarifications = [];
window.originalTranscript = "";
window.previousClarificationAnswers = [];
window.clarificationHistory = [];

function handleClarifications(clarifications) {
  const section = document.getElementById('clarificationsSection');
  const refinementSection = document.getElementById('refinementSection');
  const list = document.getElementById('clarificationsList');

  // Show refinement section once we have any analysis result
  if (refinementSection) refinementSection.classList.remove('hidden');

  // Filter out already-answered clarifications (if we have answers for them)
  const unansweredClarifications = clarifications.filter(c => {
    // Keep questions that haven't been answered yet
    return c.question && c.question.trim();
  });

  if (!unansweredClarifications || unansweredClarifications.length === 0) {
    if (section) section.classList.add('hidden');
    if (list) list.innerHTML = '';
    window.pendingClarifications = [];
    return;
  }

  // Store for later submission
  window.pendingClarifications = unansweredClarifications;
  window.originalTranscript = document.getElementById('mainTranscript').value;

  renderClarifications(unansweredClarifications);
  section.classList.remove('hidden');

  // No auto-expand, honor user request for collapsed by default
  const content = document.getElementById('clarificationsContent');
  const btn = section.querySelector('.section-toggle-btn');
  if (content && !content.classList.contains('hidden')) {
    // If it was already open, make sure button state matches
    if (btn) btn.classList.add('rounded-b-none');
  }

  // Clear the input field for fresh answer
  const answerInput = document.getElementById('clarificationAnswerInput');
  if (answerInput) answerInput.value = '';
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

// Logic for Refinements (Green Section)
let refinementRecorder = null;
let refinementChunks = [];

async function startRefinementRecording() {
  const btn = document.getElementById('refinementMicBtn');
  if (!btn) return;

  if (refinementRecorder && refinementRecorder.state === 'recording') {
    refinementRecorder.stop();
    return;
  }

  try {
    const input = document.getElementById('refinementInput');
    const audioLimit = window.profileAudioLimit || 120;
    const timeLeft = audioLimit - (window.totalVoiceUsed || 0);

    if (timeLeft <= 0) {
      if (window.showPremiumModal) window.showPremiumModal();
      else showError("Voice limit reached for this session.");
      return;
    }

    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    refinementRecorder = new MediaRecorder(stream);
    refinementChunks = [];
    window.recordingStartTime = Date.now(); // Update global start time for sub-recording

    refinementRecorder.ondataavailable = (e) => refinementChunks.push(e.data);
    refinementRecorder.onstop = processRefinementAudio;
    refinementRecorder.start();
    if (input) startLiveTranscription(input);

    btn.classList.remove('bg-emerald-500', 'hover:bg-emerald-600');
    btn.classList.add('bg-red-500', 'animate-pulse');
    btn.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-white" fill="currentColor" viewBox="0 0 24 24"><rect x="6" y="6" width="12" height="12" rx="2" /></svg>`;

    // Timer UI
    const timerCont = document.getElementById('refinementTimer');
    const timerLabel = document.getElementById('refinementTimeLeft');
    if (timerCont) timerCont.classList.remove('hidden');
    if (timerLabel) timerLabel.innerText = timeLeft;

    let localInterval = setInterval(() => {
      const elapsed = Math.floor((Date.now() - window.recordingStartTime) / 1000);
      const remaining = timeLeft - elapsed;
      if (timerLabel) timerLabel.innerText = Math.max(0, remaining);
      if (remaining <= 0) {
        clearInterval(localInterval);
        if (refinementRecorder && refinementRecorder.state === 'recording') {
          window.voiceLimitTriggered = true; // Set flag
          refinementRecorder.stop();
          if (window.showPremiumModal) window.showPremiumModal();
        }
      }
    }, 1000);

    refinementRecorder.addEventListener('stop', () => clearInterval(localInterval), { once: true });

    // Ensure we don't exceed the global limit
    setTimeout(() => {
      if (refinementRecorder && refinementRecorder.state === 'recording') refinementRecorder.stop();
    }, timeLeft * 1000);
  } catch (e) {
    console.error("Refinement Recording Error:", e);
    if (e.name === 'NotAllowedError' || e.name === 'NotFoundError') {
      showError("Microphone access required");
    } else {
      showError("Recording failed: " + e.message);
    }
  }
}

async function processRefinementAudio() {
  const btn = document.getElementById('refinementMicBtn');
  const input = document.getElementById('refinementInput');
  if (btn) {
    btn.classList.remove('bg-red-500', 'animate-pulse');
    btn.classList.add('bg-emerald-500', 'hover:bg-emerald-600');
    btn.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" /></svg>`;
  }
  if (window.liveRecognition) {
    try { window.liveRecognition.stop(); } catch (e) { }
    window.liveRecognition = null;
  }
  const duration = window.recordingStartTime ? Math.floor((Date.now() - window.recordingStartTime) / 1000) : 0;
  window.totalVoiceUsed = (window.totalVoiceUsed || 0) + duration;

  const timerCont = document.getElementById('refinementTimer');
  if (timerCont) timerCont.classList.add('hidden');

  if (refinementRecorder && refinementRecorder.stream) refinementRecorder.stream.getTracks().forEach(t => t.stop());
  if (refinementChunks.length === 0) return;

  const audioBlob = new Blob(refinementChunks, { type: 'audio/webm' });
  const formData = new FormData();
  formData.append("audio", audioBlob);
  formData.append("transcribe_only", "true");

  try {
    const res = await fetch("/process_audio", {
      method: "POST",
      headers: { "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content },
      body: formData
    });
    const data = await res.json();
    if (input) {
      input.placeholder = "Need to fix something? Tell me here...";
      if (data.raw_summary) {
        input.value = data.raw_summary.trim();
        setTimeout(() => submitRefinement(), 300);
      }
    }
  } catch (e) {
    showError("Transcription failed");
  }
}

async function submitRefinement() {
  const input = document.getElementById('refinementInput');
  const instruction = input ? input.value.trim() : '';
  if (!instruction) return showError("Please enter an instruction first");

  // PRE-VALIDATION: Check limits BEFORE modifying history
  const limit = window.profileCharLimit;
  const historyChars = (window.calculateHistoricalChars ? window.calculateHistoricalChars() : 0);
  const transcriptChars = document.getElementById('mainTranscript')?.value.length || 0;

  // Calculate prospective addition
  // Revised: Ignore overhead to match user expectation of "What I type is what I spend"
  const projectedTotal = transcriptChars + historyChars + instruction.length;

  if (projectedTotal > limit) {
    if (window.showPremiumModal) window.showPremiumModal();
    else showError(`Limit Reached (${limit}). Upgrade to add more.`);
    return;
  }

  // Save for AI history & UI with TYPE
  if (!window.clarificationHistory) window.clarificationHistory = [];
  window.clarificationHistory.push({ questions: "User manually refined details", answer: instruction });
  if (!window.previousClarificationAnswers) window.previousClarificationAnswers = [];
  window.previousClarificationAnswers.push({ text: instruction, type: 'refinement' });

  // Clear input and Update counters IMMEDIATELY for real-time visual feedback
  input.value = '';
  if (window.updateDynamicCounters) window.updateDynamicCounters();

  renderPreviousAnswers();

  let historyText = "";
  window.clarificationHistory.forEach(h => {
    historyText += `\n\n[User clarification for "${h.questions}": ${h.answer}]`;
  });

  window.skipTranscriptUpdate = true;
  const transcriptArea = document.getElementById('mainTranscript');
  const originalValue = transcriptArea.value;
  transcriptArea.value = `${window.originalTranscript || originalValue}${historyText}`;

  const applyBtn = document.getElementById('reParseBtn');
  if (applyBtn) {
    // Temporarily override the click handler validation because we ALREADY validated above
    // and we crafted the value manually. We just want the fetch to happen.
    // Actually, reParseBtn.click() triggers the CLICK handler which resets Validation?
    // The click handler checks transcriptArea.value.length.
    // If we crafted it correctly, it should pass.
    applyBtn.click();
  }

  // No auto-expand here, honor user request for collapsed by default
  const content = document.getElementById('refinementContent');
  const btn = document.getElementById('refinementSection').querySelector('.section-toggle-btn');
  if (content && !content.classList.contains('hidden')) {
    if (btn) btn.classList.add('rounded-b-none');
  }

  transcriptArea.value = originalValue;
}

function renderClarifications(clarifications) {
  const list = document.getElementById('clarificationsList');
  list.innerHTML = '';

  clarifications.forEach((c, index) => {
    const div = document.createElement('div');
    div.className = "clarification-item border-b border-gray-100 pb-3 last:border-0 last:pb-0";
    div.dataset.index = index;
    div.dataset.field = c.field || '';
    div.dataset.guess = c.guess || '';
    div.dataset.question = c.question || '';

    // Display "Not specified" for empty/zero guesses
    const guessDisplay = (c.guess === 0 || c.guess === "0" || c.guess === "" || c.guess === null)
      ? "Not specified"
      : c.guess;

    div.innerHTML = `
      <p class="text-sm font-medium text-black leading-relaxed"><span class="text-orange-600 font-bold">${index + 1}.</span> ${escapeHtml(c.question)}</p>
      <p class="text-xs text-gray-500 mt-1 ml-4">Current guess: <span class="font-bold text-orange-600">${guessDisplay}</span></p>
    `;

    list.appendChild(div);
  });
}

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

function renderPreviousAnswers() {
  const section = document.getElementById('previousAnswersSection');
  const list = document.getElementById('previousAnswersList');

  if (!section || !list) return;

  if (!window.previousClarificationAnswers || window.previousClarificationAnswers.length === 0) {
    section.classList.add('hidden');
    list.innerHTML = '';
    return;
  }

  list.innerHTML = '';
  window.previousClarificationAnswers.forEach(ans => {
    const isRefinement = ans.type === 'refinement';
    const div = document.createElement('div');

    // Choose colors based on type
    const bgClass = isRefinement ? 'bg-emerald-50 border-emerald-100' : 'bg-orange-50 border-orange-100';
    const textClass = isRefinement ? 'text-emerald-700' : 'text-orange-700';

    div.className = `self-end ${bgClass} border-2 rounded-2xl rounded-tr-none px-4 py-2 text-sm font-bold ${textClass} shadow-sm animate-in fade-in slide-in-from-right-2 duration-300 max-w-[80%]`;
    div.innerText = ans.text;
    list.appendChild(div);
  });

  section.classList.remove('hidden');
}

// Voice recording for clarification answers - SINGLE MIC for all questions
let clarificationRecorder = null;
let clarificationChunks = [];

async function startClarificationRecording() {
  const btn = document.getElementById('clarificationMicBtn');
  if (!btn) return;

  // If already recording, stop
  if (clarificationRecorder && clarificationRecorder.state === 'recording') {
    clarificationRecorder.stop();
    return;
  }

  try {
    const input = document.getElementById('clarificationAnswerInput');
    const audioLimit = window.profileAudioLimit || 120;
    const timeLeft = audioLimit - (window.totalVoiceUsed || 0);

    if (timeLeft <= 0) {
      if (window.showPremiumModal) window.showPremiumModal();
      else showError("Voice limit reached for this session.");
      return;
    }

    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    clarificationRecorder = new MediaRecorder(stream);
    clarificationChunks = [];
    window.recordingStartTime = Date.now();

    clarificationRecorder.ondataavailable = (e) => clarificationChunks.push(e.data);
    clarificationRecorder.onstop = processClarificationAudio;

    clarificationRecorder.start();
    if (input) startLiveTranscription(input);

    // Visual feedback - recording state
    btn.classList.remove('bg-orange-500', 'hover:bg-orange-600');
    btn.classList.add('bg-red-500', 'animate-pulse');
    btn.innerHTML = `
      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-white" fill="currentColor" viewBox="0 0 24 24">
        <rect x="6" y="6" width="12" height="12" rx="2" />
      </svg>
    `;

    // Timer UI
    const timerCont = document.getElementById('clarificationTimer');
    const timerLabel = document.getElementById('clarificationTimeLeft');
    if (timerCont) timerCont.classList.remove('hidden');
    if (timerLabel) timerLabel.innerText = timeLeft;

    let localInterval = setInterval(() => {
      const elapsed = Math.floor((Date.now() - window.recordingStartTime) / 1000);
      const remaining = timeLeft - elapsed;
      if (timerLabel) timerLabel.innerText = Math.max(0, remaining);
      if (remaining <= 0) {
        clearInterval(localInterval);
        if (clarificationRecorder && clarificationRecorder.state === 'recording') {
          window.voiceLimitTriggered = true; // Set flag
          clarificationRecorder.stop();
          if (window.showPremiumModal) window.showPremiumModal();
        }
      }
    }, 1000);

    clarificationRecorder.addEventListener('stop', () => clearInterval(localInterval), { once: true });

    // Auto-stop
    setTimeout(() => {
      if (clarificationRecorder && clarificationRecorder.state === 'recording') {
        clarificationRecorder.stop();
      }
    }, timeLeft * 1000);

  } catch (e) {
    console.error("Clarification Recording Error:", e);
    if (e.name === 'NotAllowedError' || e.name === 'NotFoundError') {
      showError("Microphone access required");
    } else {
      showError("Recording failed: " + e.message);
    }
  }
}

async function processClarificationAudio() {
  const btn = document.getElementById('clarificationMicBtn');
  const input = document.getElementById('clarificationAnswerInput');

  // Reset button visual
  if (btn) {
    btn.classList.remove('bg-red-500', 'animate-pulse');
    btn.classList.add('bg-orange-500', 'hover:bg-orange-600');
    btn.innerHTML = `
      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5">
        <path stroke-linecap="round" stroke-linejoin="round" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
      </svg>
    `;
  }
  if (window.liveRecognition) {
    try { window.liveRecognition.stop(); } catch (e) { }
    window.liveRecognition = null;
  }
  const duration = window.recordingStartTime ? Math.floor((Date.now() - window.recordingStartTime) / 1000) : 0;
  window.totalVoiceUsed = (window.totalVoiceUsed || 0) + duration;

  const timerCont = document.getElementById('clarificationTimer');
  if (timerCont) timerCont.classList.add('hidden');

  // Stop tracks
  if (clarificationRecorder && clarificationRecorder.stream) {
    clarificationRecorder.stream.getTracks().forEach(t => t.stop());
  }

  if (clarificationChunks.length === 0) return;

  const audioBlob = new Blob(clarificationChunks, { type: 'audio/webm' });

  // Send to transcription endpoint
  const formData = new FormData();
  formData.append("audio", audioBlob);
  formData.append("transcribe_only", "true");

  try {
    const res = await fetch("/process_audio", {
      method: "POST",
      headers: { "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content },
      body: formData
    });

    const data = await res.json();

    if (input) {
      input.placeholder = "Type or speak your answer...";
      if (data.raw_summary) {
        input.value = data.raw_summary.trim();
        // Auto-send after voice transcription
        setTimeout(() => submitClarifications(), 300);
      }
    }
  } catch (e) {
    showError("Transcription failed");
    console.error(e);
  }
}

async function submitClarifications() {
  const answerInput = document.getElementById('clarificationAnswerInput');
  const userAnswer = answerInput ? answerInput.value.trim() : '';

  if (!userAnswer) {
    showError("Please provide an answer first");
    return;
  }

  // Pre-calculate Question text for overhead check
  const currentQuestions = window.pendingClarifications.map(c => c.question).join(' ');

  // PRE-VALIDATION
  const limit = window.profileCharLimit;
  const historyChars = (window.calculateHistoricalChars ? window.calculateHistoricalChars() : 0);
  const transcriptChars = document.getElementById('mainTranscript')?.value.length || 0;
  // Revised: Ignore overhead
  const projectedTotal = transcriptChars + historyChars + userAnswer.length;

  if (projectedTotal > limit) {
    if (window.showPremiumModal) window.showPremiumModal();
    else showError(`Limit Reached (${limit}). Upgrade to add more.`);
    return;
  }

  // Save for the AI prompt history (accumulate multi-turn answers)
  if (!window.clarificationHistory) window.clarificationHistory = [];
  window.clarificationHistory.push({ questions: currentQuestions, answer: userAnswer });

  // Save for UI display with TYPE
  if (!window.previousClarificationAnswers) window.previousClarificationAnswers = [];
  window.previousClarificationAnswers.push({ text: userAnswer, type: 'clarification' });

  // Clear Input and update counters IMMEDIATELY
  answerInput.value = '';
  if (window.updateDynamicCounters) window.updateDynamicCounters();

  renderPreviousAnswers();

  // Build the enhanced prompt with FULL history
  let historyText = "";
  window.clarificationHistory.forEach(h => {
    historyText += `\n\n[User clarification for "${h.questions}": ${h.answer}]`;
  });

  const clarificationPrompt = `${window.originalTranscript || document.getElementById('mainTranscript')?.value}${historyText}`;

  // Set flag to tell updateUI NOT to touch the transcript
  window.skipTranscriptUpdate = true;

  // Save transcript area reference
  const transcriptArea = document.getElementById('mainTranscript');
  const originalValue = transcriptArea.value;

  // Temporarily set the transcript with the FULL clarification history
  transcriptArea.value = clarificationPrompt;

  // Hide the clarifications section
  document.getElementById('clarificationsSection').classList.add('hidden');

  // Click the existing Apply button to trigger the processing
  const applyBtn = document.getElementById('reParseBtn');
  if (applyBtn) {
    applyBtn.click();
  }

  // Restore the original transcript immediately after click
  // The skipTranscriptUpdate flag will prevent it from being overwritten by updateUI
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

    // Set tax scope (AI-detected or profile default)
    currentLogTaxScope = data.tax_scope || currentLogTaxScope || window.profileTaxScope || "tax_excluded";

    // Hide all protected sections by default
    removeLaborSection();
    removeCreditSection();

    // Billing Mode Synchronization
    const billingMode = data.billing_mode || currentLogBillingMode;
    if (data.hourly_rate) {
      document.getElementById("hourlyRateInput").value = data.hourly_rate;
      currentLogHourlyRate = data.hourly_rate;
    }
    if (data.labor_tax_rate) {
      document.getElementById("defaultTaxInput").value = data.labor_tax_rate;
    }
    setGlobalBillingMode(billingMode);

    // Currency Update
    if (data.currency) {
      activeCurrencyCode = data.currency.toUpperCase();
      const curr = allCurrencies.find(c => c.c === activeCurrencyCode);
      if (curr) {
        currencySymbol = curr.s;
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
      showCreditSection();
      const creditContainer = document.getElementById("creditsItemsContainer");
      if (creditContainer) {
        const existingRows = creditContainer.querySelectorAll('.credit-item-row');
        existingRows.forEach((row, idx) => { if (idx > 0) row.remove(); });

        data.credits.forEach((credit, idx) => {
          if (idx === 0) {
            const firstRow = creditContainer.querySelector('.credit-item-row');
            if (firstRow) {
              const amountInput = firstRow.querySelector('input[placeholder*="Amount"], input[id*="credit"]');
              const reasonInput = firstRow.querySelector('input[placeholder*="reason"], input[placeholder*="Reason"]');
              if (amountInput) amountInput.value = credit.amount || "";
              if (reasonInput) reasonInput.value = credit.reason || "";
            }
          } else {
            addCreditItem(credit.amount, credit.reason);
          }
        });
      }
    }

    // Sections
    const sectionContainer = document.getElementById("sectionsContainer");
    sectionContainer.querySelectorAll('.dynamic-section:not([data-protected])').forEach(s => s.remove());

    if (data.sections && data.sections.length > 0) {
      data.sections.forEach(sec => addFullSection(sec.title, sec.items));
    }

    if (data.labor_service_items && data.labor_service_items.length > 0) {
      const existingLabor = Array.from(document.querySelectorAll('.section-title')).find(el => el.innerText === "LABOR/SERVICE" || el.value === "Labor/Service");
      if (!existingLabor) {
        addFullSection("Labor/Service", data.labor_service_items);
        const laborSec = sectionContainer.lastElementChild;
        if (laborSec) sectionContainer.prepend(laborSec);
      }
    }

    document.getElementById("invoicePreview").classList.remove("hidden");

    updateTotalsSummary();

    // Handle new clarifications (questions that are still unanswered)
    handleClarifications(data.clarifications || []);

    if (window.pendingClarifications && window.pendingClarifications.length === 0) {
      window.setupSaveButton();
    }

    window.isAutoUpdating = false;
  } catch (e) {
    window.isAutoUpdating = false;
    showError("UI Update Error: " + e.message);
    console.error(e);
  }
}

function showError(msg) {
  if (msg && (msg.toLowerCase().includes("limit reached") || msg.toLowerCase().includes("rate limit"))) {
    if (window.showPremiumModal) {
      window.showPremiumModal();
      return;
    }
  }
  const toast = document.getElementById("errorToast");
  const msgSpan = document.getElementById("errorMessage");
  if (!toast || !msgSpan) return;
  msgSpan.innerText = msg;
  toast.classList.remove("hidden");
  setTimeout(() => { toast.classList.add("hidden"); }, 4000);
}

function toggleLaborGroup() {
  const group = document.getElementById('laborGroup');
  const content = document.getElementById('laborContent');
  const chevron = document.getElementById('laborChevron');
  const pill = document.getElementById('laborChevronPill');
  const btn = document.getElementById('laborToggleBtn');
  const btnText = btn.querySelector('span');

  const isCollapsed = content.classList.contains('hidden');

  if (isCollapsed) {
    // EXPAND (Opening)
    content.classList.remove('hidden');

    // Group: Restore container look
    group.classList.remove('h-14', 'bg-white', 'border-solid', 'border-black', 'shadow-[4px_4px_0px_0px_rgba(0,0,0,1)]', 'labor-group-hover', 'cursor-pointer');
    group.classList.add('border-dashed', 'border-orange-200', 'bg-orange-50/30', '!mt-12');

    // Button: Move to Top Right (exactly matching Credit's remove button location)
    btn.classList.remove('relative', 'w-full', 'h-full', 'justify-between', 'px-4', 'left-4', '-top-5', 'right-4');
    btn.classList.add('absolute', '-top-3.5', '-right-3.5', 'bg-transparent', 'px-0');

    // Text: Hide when open
    btnText.classList.add('hidden');

    // Chevron Pill: White arrow on orange circle (matching w-7 h-7 size)
    pill.classList.remove('w-5', 'h-5');
    pill.classList.add('bg-orange-600', 'w-7', 'h-7', 'shadow-[1px_1px_0px_0px_rgba(0,0,0,0.3)]');
    chevron.classList.remove('text-orange-400');
    chevron.classList.add('text-white');

    chevron.style.transform = 'rotate(0deg)';
  } else {
    // COLLAPSE (Closing)
    content.classList.add('hidden');

    // Group: Become button-like
    group.classList.remove('border-dashed', 'border-orange-200', 'bg-orange-50/30', '!mt-12');
    group.classList.add('h-14', 'bg-white', 'border-solid', 'border-black', 'shadow-[4px_4px_0px_0px_rgba(0,0,0,1)]', 'labor-group-hover', 'cursor-pointer');

    // Button: Restore original left position/size
    btn.classList.remove('absolute', '-top-3.5', '-right-3.5', 'bg-transparent', 'px-0');
    btn.classList.add('relative', 'w-full', 'h-full', 'justify-between', 'pl-4', 'pr-7', 'left-4');

    // Text: Show and set to black
    btnText.classList.remove('hidden', 'text-orange-400');
    btnText.classList.add('text-black');

    // Chevron Pill: Reset to normal size and filled orange
    pill.classList.remove('w-7', 'h-7');
    pill.classList.add('bg-orange-600', 'w-5', 'h-5');
    chevron.classList.remove('text-orange-400');
    chevron.classList.add('text-white');

    chevron.style.transform = 'rotate(-90deg)';
  }
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
  resetRecorderUI,
  processAudio,
  startAnalysisUI,
  stopAnalysisUI,
  updateSaveButtonToSavedState,
  updateSaveButtonToLimitState,
  updateDueDate,
  toggleCalendar,
  changeCalendarMonth,
  renderCalendar,
  selectCalendarDate,
  setQuickDue,
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
  startRefinementRecording,
  processRefinementAudio,
  submitRefinement,
  renderClarifications,
  escapeHtml,
  renderPreviousAnswers,
  startClarificationRecording,
  processClarificationAudio,
  submitClarifications,
  updateUIWithoutTranscript,
  showError,
  toggleLaborGroup,
  toggleLaborRate,
});
