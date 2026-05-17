{**
 * ToolSharp — ProductDiscounts
 * Back office configuration page — update checker
 *}

<div class="panel">

    {* ---- Header ---- *}
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

    {* ---- Footer: Check now button ---- *}
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
