{**
 * Product Discounts – product_discounts.tpl
 * Rendered by hookDisplayProductAdditionalInfo / hookDisplayProductPriceBlock
 *}

{if $pd_discounts|count > 0}
<link rel="stylesheet" href="{$pd_module_dir}views/css/productdiscounts.css">

<section class="pd-discounts" aria-label="{l s='Available discount codes' mod='toolsharp_productdiscounts'}">

    <header class="pd-discounts__header">
        <span class="pd-discounts__icon" aria-hidden="true">
            {* Inline SVG tag icon — no external dependency *}
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
                    {if $discount.type == 'percent'}
                        {* Translators: %s = e.g. "10%" *}
                        {l s='Save %s' sprintf=[$discount.value] mod='toolsharp_productdiscounts'}
                    {elseif $discount.type == 'amount'}
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

        </li>
    {/foreach}
    </ul>

</section>

<script>
(function () {
    'use strict';

    document.querySelectorAll('.pd-discount__code').forEach(function (btn) {
        btn.addEventListener('click', function () {
            var code = btn.dataset.code;
            var copied = btn.querySelector('.pd-discount__copied-msg');

            if (!navigator.clipboard) {
                // Fallback for older browsers
                var ta = document.createElement('textarea');
                ta.value = code;
                ta.style.position = 'fixed';
                ta.style.opacity  = '0';
                document.body.appendChild(ta);
                ta.select();
                try { document.execCommand('copy'); } catch (e) {}
                document.body.removeChild(ta);
            } else {
                navigator.clipboard.writeText(code).catch(function () {});
            }

            btn.classList.add('pd-discount__code--copied');
            setTimeout(function () {
                btn.classList.remove('pd-discount__code--copied');
            }, 2000);
        });
    });
}());
</script>
{/if}
