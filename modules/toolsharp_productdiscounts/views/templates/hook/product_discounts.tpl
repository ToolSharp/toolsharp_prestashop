{**
 * Product Discounts – product_discounts.tpl
 * Rendered by hookDisplayProductPriceBlock (after_price position)
 *}

{if $pd_discounts|count > 0}
<link rel="stylesheet" href="{$pd_module_dir}views/css/productdiscounts.css">

<section class="pd-discounts" aria-label="{l s='Available discount codes' mod='toolsharp_productdiscounts'}">

    <header class="pd-discounts__header">
        <span class="pd-discounts__icon" aria-hidden="true">
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none"
                 stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"
                 aria-hidden="true" focusable="false">
                <path d="M20.59 13.41l-7.17 7.17a2 2 0 01-2.83 0L2 12V2h10l8.59 8.59a2 2 0 010 2.82z"/>
                <line x1="7" y1="7" x2="7.01" y2="7"/>
            </svg>
        </span>
        <h3 class="pd-discounts__title">
            {if $pd_discounts|count == 1}
                {l s='1 discount code available' mod='toolsharp_productdiscounts'}
            {else}
                {l s='%d discount codes available' sprintf=[$pd_discounts|count] mod='toolsharp_productdiscounts'}
            {/if}
        </h3>
    </header>

    <ul class="pd-discounts__list" role="list">
    {foreach from=$pd_discounts item=discount}
        <li class="pd-discount pd-discount--{$discount.type}">

            {* ---- Code badge + copy button ---- *}
            <div class="pd-discount__code-wrap">
                <button
                    class="pd-discount__code"
                    type="button"
                    data-code="{$discount.code|escape:'html':'UTF-8'}"
                    aria-label="{l s='Copy code %s' sprintf=[$discount.code] mod='toolsharp_productdiscounts'}"
                    title="{l s='Click to copy' mod='toolsharp_productdiscounts'}"
                >
                    <span class="pd-discount__code-text">{$discount.code|escape:'html':'UTF-8'}</span>
                    <span class="pd-discount__copy-icon" aria-hidden="true">
                        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none"
                             stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                            <rect x="9" y="9" width="13" height="13" rx="2" ry="2"/>
                            <path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1"/>
                        </svg>
                    </span>
                    <span class="pd-discount__copied-msg" aria-live="polite">
                        {l s='Copied!' mod='toolsharp_productdiscounts'}
                    </span>
                </button>
            </div>

            {* ---- Discount value pill ---- *}
            {if $discount.value}
                <span class="pd-discount__value" aria-label="{l s='Discount value' mod='toolsharp_productdiscounts'}">
                    {if $discount.type == 'percent' || $discount.type == 'amount'}
                        {l s='Save %s' sprintf=[$discount.value] mod='toolsharp_productdiscounts'}
                    {else}
                        {$discount.value|escape:'html':'UTF-8'}
                    {/if}
                </span>
            {/if}

            {* ---- Description ---- *}
            {if $discount.description}
                <p class="pd-discount__desc">{$discount.description|escape:'html':'UTF-8'}</p>
            {/if}

            {* ---- Meta row: minimum spend + expiry ---- *}
            {if $discount.minimum_amount || $discount.expires_in}
                <div class="pd-discount__meta">
                    {if $discount.minimum_amount}
                        <span class="pd-discount__min">
                            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none"
                                 stroke="currentColor" stroke-width="2" aria-hidden="true" focusable="false">
                                <circle cx="12" cy="12" r="10"/>
                                <line x1="12" y1="8" x2="12" y2="12"/>
                                <line x1="12" y1="16" x2="12.01" y2="16"/>
                            </svg>
                            {l s='Min. spend %s' sprintf=[$discount.minimum_amount] mod='toolsharp_productdiscounts'}
                        </span>
                    {/if}
                    {if $discount.expires_in}
                        <span class="pd-discount__expiry">
                            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none"
                                 stroke="currentColor" stroke-width="2" aria-hidden="true" focusable="false">
                                <circle cx="12" cy="12" r="10"/>
                                <polyline points="12 6 12 12 16 14"/>
                            </svg>
                            {$discount.expires_in|escape:'html':'UTF-8'}
                        </span>
                    {/if}
                </div>
            {/if}

            {* ---- Info button (opens detail popup) ---- *}
            <button
                class="pd-discount__info-btn"
                type="button"
                aria-label="{l s='More details' mod='toolsharp_productdiscounts'}"
                title="{l s='More details' mod='toolsharp_productdiscounts'}"
                data-pd-info='{
                    "code":           "{$discount.code|escape:'javascript'}",
                    "value":          "{$discount.value|escape:'javascript'}",
                    "type":           "{$discount.type|escape:'javascript'}",
                    "description":    "{$discount.description|escape:'javascript'}",
                    "minimum_amount": "{$discount.minimum_amount|escape:'javascript'}",
                    "expires_in":     "{$discount.expires_in|escape:'javascript'}",
                    "expiry_date":    "{$discount.expiry_date|escape:'javascript'}",
                    "free_shipping":  {if $discount.free_shipping}true{else}false{/if}
                }'
            >
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none"
                     stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"
                     aria-hidden="true" focusable="false">
                    <circle cx="12" cy="12" r="10"/>
                    <line x1="12" y1="16" x2="12" y2="12"/>
                    <line x1="12" y1="8" x2="12.01" y2="8"/>
                </svg>
            </button>

        </li>
    {/foreach}
    </ul>

</section>

{* =====================================================================
   Detail modal — one shared instance, populated by JS on open
   ===================================================================== *}
<div class="pd-modal-overlay" id="pdDiscountModal" role="dialog" aria-modal="true"
     aria-label="{l s='Discount code details' mod='toolsharp_productdiscounts'}" hidden>
    <div class="pd-modal">

        <button class="pd-modal__close" type="button"
                aria-label="{l s='Close' mod='toolsharp_productdiscounts'}">
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none"
                 stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"
                 aria-hidden="true" focusable="false">
                <line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>
            </svg>
        </button>

        {* Hero: value *}
        <div class="pd-modal__hero">
            <p class="pd-modal__value" id="pdModalValue"></p>
        </div>

        {* Code row *}
        <div class="pd-modal__code-row">
            <button class="pd-discount__code pd-modal__code-btn" type="button" id="pdModalCodeBtn"
                    title="{l s='Click to copy' mod='toolsharp_productdiscounts'}">
                <span class="pd-discount__code-text" id="pdModalCodeText"></span>
                <span class="pd-discount__copy-icon" aria-hidden="true">
                    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none"
                         stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <rect x="9" y="9" width="13" height="13" rx="2" ry="2"/>
                        <path d="M5 15H4a2 2 0 01-2-2V4a2 2 0 012-2h9a2 2 0 012 2v1"/>
                    </svg>
                </span>
                <span class="pd-discount__copied-msg" aria-live="polite">
                    {l s='Copied!' mod='toolsharp_productdiscounts'}
                </span>
            </button>
        </div>

        <hr class="pd-modal__divider">

        {* Conditions *}
        <div class="pd-modal__conditions" id="pdModalConditions">
            <p class="pd-modal__conditions-title">
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none"
                     stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"
                     aria-hidden="true" focusable="false" style="width:1rem;height:1rem;vertical-align:-.15em;margin-right:.3rem;">
                    <circle cx="12" cy="12" r="10"/>
                    <line x1="12" y1="16" x2="12" y2="12"/>
                    <line x1="12" y1="8" x2="12.01" y2="8"/>
                </svg>
                {l s="Don't forget!" mod='toolsharp_productdiscounts'}
            </p>
            <ul class="pd-modal__conditions-list" id="pdModalConditionsList"></ul>
        </div>

    </div>
</div>

<script>
(function () {
    'use strict';

    /* ---- Copy helper ---- */
    function copyToClipboard(code, btn) {
        if (navigator.clipboard) {
            navigator.clipboard.writeText(code).catch(function () {});
        } else {
            var ta = document.createElement('textarea');
            ta.value = code;
            ta.style.cssText = 'position:fixed;opacity:0';
            document.body.appendChild(ta);
            ta.select();
            try { document.execCommand('copy'); } catch (e) {}
            document.body.removeChild(ta);
        }
        btn.classList.add('pd-discount__code--copied');
        setTimeout(function () { btn.classList.remove('pd-discount__code--copied'); }, 2000);
    }

    /* ---- Inline copy buttons ---- */
    document.querySelectorAll('.pd-discount__code[data-code]').forEach(function (btn) {
        btn.addEventListener('click', function () {
            copyToClipboard(btn.dataset.code, btn);
        });
    });

    /* ---- Modal elements ---- */
    var overlay    = document.getElementById('pdDiscountModal');
    var modalValue = document.getElementById('pdModalValue');
    var codeBtn    = document.getElementById('pdModalCodeBtn');
    var codeText   = document.getElementById('pdModalCodeText');
    var condList   = document.getElementById('pdModalConditionsList');
    var closeBtn   = overlay ? overlay.querySelector('.pd-modal__close') : null;
    var lastFocus  = null;

    function openModal(info) {
        lastFocus = document.activeElement;

        /* Hero value label */
        modalValue.textContent = info.value || '';
        modalValue.className = 'pd-modal__value pd-modal__value--' + (info.type || 'none');

        /* Code button */
        codeText.textContent = info.code || '';
        codeBtn.dataset.code = info.code || '';
        codeBtn.setAttribute('aria-label', 'Copy code ' + info.code);

        /* Conditions list */
        condList.innerHTML = '';
        var items = [];

        if (info.description) {
            items.push(info.description);
        }
        if (info.minimum_amount) {
            items.push('Valid for purchases of ' + info.minimum_amount + ' or more.');
        }
        if (info.free_shipping) {
            items.push('Includes free shipping.');
        }
        if (info.expiry_date) {
            items.push('Valid until ' + info.expiry_date + '.');
        } else if (info.expires_in) {
            items.push(info.expires_in + '.');
        }

        if (items.length === 0) {
            items.push('No additional conditions.');
        }

        items.forEach(function (text) {
            var li = document.createElement('li');
            li.textContent = text;
            condList.appendChild(li);
        });

        overlay.hidden = false;
        document.body.classList.add('pd-modal-open');
        closeBtn && closeBtn.focus();
    }

    function closeModal() {
        overlay.hidden = true;
        document.body.classList.remove('pd-modal-open');
        lastFocus && lastFocus.focus();
    }

    /* ---- Info button clicks ---- */
    document.querySelectorAll('.pd-discount__info-btn').forEach(function (btn) {
        btn.addEventListener('click', function () {
            try {
                var info = JSON.parse(btn.dataset.pdInfo);
                openModal(info);
            } catch (e) {
                console.error('pd: could not parse discount info', e);
            }
        });
    });

    /* ---- Close triggers ---- */
    if (closeBtn) {
        closeBtn.addEventListener('click', closeModal);
    }

    if (overlay) {
        /* Click outside the modal panel */
        overlay.addEventListener('click', function (e) {
            if (e.target === overlay) closeModal();
        });

        /* Escape key */
        document.addEventListener('keydown', function (e) {
            if (!overlay.hidden && (e.key === 'Escape' || e.key === 'Esc')) {
                closeModal();
            }
        });

        /* Modal copy button */
        codeBtn.addEventListener('click', function () {
            copyToClipboard(codeBtn.dataset.code, codeBtn);
        });
    }
}());
</script>
{/if}
