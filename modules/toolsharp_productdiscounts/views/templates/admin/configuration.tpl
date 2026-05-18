{**
 * ToolSharp — ProductDiscounts
 * Back office configuration page — settings + update checker
 *}

{* =====================================================================
   Panel 1: Display settings
   ===================================================================== *}
<div class="panel">
    <div class="panel-heading">
        <i class="icon-sliders"></i>
        {l s='Display settings' mod='toolsharp_productdiscounts'}
    </div>

    <div class="panel-body">
        <form method="post" action="{$ts_form_action|escape:'html':'UTF-8'}">

            {* ---- Block size ---- *}
            <div class="form-group">
                <label class="control-label col-lg-3" for="ts_scale">
                    {l s='Block size' mod='toolsharp_productdiscounts'}
                </label>
                <div class="col-lg-9">
                    <div style="display:flex;align-items:center;gap:1rem;max-width:420px;">
                        <input
                            type="range"
                            id="ts_scale"
                            name="ts_scale"
                            min="75"
                            max="100"
                            step="1"
                            value="{$ts_current_scale|intval}"
                            oninput="document.getElementById('ts_scale_val').textContent = this.value + '%'"
                            style="flex:1;"
                        >
                        <span id="ts_scale_val" style="min-width:3rem;font-weight:600;">
                            {$ts_current_scale|intval}%
                        </span>
                    </div>
                    <p class="help-block">
                        {l s='Controls the overall size of the discount block on the product page (75 %% – 100 %%). Default: 100 %%.' mod='toolsharp_productdiscounts'}
                    </p>
                </div>
            </div>

            {* ---- Promotion details page URL ---- *}
            <div class="form-group">
                <label class="control-label col-lg-3" for="ts_promo_url">
                    {l s='Promotion details page URL' mod='toolsharp_productdiscounts'}
                </label>
                <div class="col-lg-9">
                    <input
                        type="url"
                        id="ts_promo_url"
                        name="ts_promo_url"
                        class="form-control"
                        placeholder="https://your-shop.com/promotions"
                        value="{$ts_current_promo_url|escape:'html':'UTF-8'}"
                        style="max-width:480px;"
                    >
                    <p class="help-block">
                        {l s='Optional. When set, a "Promotion details" link appears in the discount block on the product page, pointing customers to this URL. Leave blank to disable.' mod='toolsharp_productdiscounts'}
                    </p>
                </div>
            </div>

            <div class="panel-footer">
                <button type="submit" name="ts_save_settings" class="btn btn-primary">
                    <i class="icon-save"></i>
                    {l s='Save settings' mod='toolsharp_productdiscounts'}
                </button>
            </div>

        </form>
    </div>
</div>

{* =====================================================================
   Panel 2: Update checker (unchanged)
   ===================================================================== *}
<div class="panel">

    <div class="panel-heading">
        <i class="icon-code-fork"></i>
        {l s='ToolSharp — Product Discount Codes' mod='toolsharp_productdiscounts'}
        <span class="panel-heading-action">
            <span class="badge badge-secondary">v{$ts_installed_version|escape:'html':'UTF-8'}</span>
        </span>
    </div>

    <div class="panel-body">

        {* ---- API / network error ---- *}
        {if $ts_update.error}
            <div class="alert alert-warning">
                <strong>{l s='Update check failed' mod='toolsharp_productdiscounts'}</strong><br>
                {$ts_update.error|escape:'html':'UTF-8'}
            </div>

        {* ---- Update available ---- *}
        {elseif $ts_update.update_available}
            <div class="alert alert-info">
                <h4>
                    <i class="icon-download"></i>
                    {l s='A new version is available: v%s' sprintf=[$ts_update.latest_version] mod='toolsharp_productdiscounts'}
                </h4>
                <p>
                    {l s='You are running v%s.' sprintf=[$ts_update.installed_version] mod='toolsharp_productdiscounts'}
                </p>

                {if $ts_update.release_notes}
                    <hr>
                    <h5>{l s='Release notes' mod='toolsharp_productdiscounts'}</h5>
                    <pre style="white-space:pre-wrap;font-size:.85rem;">{$ts_update.release_notes|escape:'html':'UTF-8'}</pre>
                {/if}

                {if $ts_update.release_url}
                    <a href="{$ts_update.release_url|escape:'html':'UTF-8'}"
                       target="_blank"
                       rel="noopener noreferrer"
                       class="btn btn-primary">
                        <i class="icon-external-link"></i>
                        {l s='View release on GitHub' mod='toolsharp_productdiscounts'}
                    </a>
                {/if}
            </div>

        {* ---- Up to date ---- *}
        {else}
            <div class="alert alert-success">
                <i class="icon-check"></i>
                {l s='You are running the latest version (v%s).' sprintf=[$ts_update.installed_version] mod='toolsharp_productdiscounts'}
            </div>
        {/if}

        {* ---- Cache notice ---- *}
        {if $ts_update.from_cache && !$ts_update.error}
            <p class="text-muted" style="font-size:.85rem;">
                <i class="icon-clock-o"></i>
                {l s='Result cached. Last checked: %s' sprintf=[$ts_checked_at] mod='toolsharp_productdiscounts'}
                &mdash;
                {l s='Next automatic check in %s.' sprintf=[$ts_next_check] mod='toolsharp_productdiscounts'}
            </p>
        {/if}

    </div>

    <div class="panel-footer">
        <form method="post" action="{$ts_form_action|escape:'html':'UTF-8'}">
            <input type="hidden" name="ts_check_updates" value="1">
            <button type="submit" class="btn btn-default">
                <i class="icon-refresh"></i>
                {l s='Check for updates now' mod='toolsharp_productdiscounts'}
            </button>
            <span class="text-muted" style="margin-left:1rem;font-size:.85rem;">
                {l s='This will contact GitHub and refresh the cached result.' mod='toolsharp_productdiscounts'}
            </span>
        </form>
    </div>

</div>
