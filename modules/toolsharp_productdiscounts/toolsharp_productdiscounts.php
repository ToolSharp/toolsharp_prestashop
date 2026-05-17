<?php
/**
 * Product Discounts Module for PrestaShop 8.2.3
 * Displays valid discount codes on the product page.
 */

if (!defined('_PS_VERSION_')) {
    exit;
}

require_once __DIR__ . '/classes/UpdateChecker.php';

class Toolsharp_Productdiscounts extends Module
{
    public function __construct()
    {
        $this->name = 'toolsharp_productdiscounts';
        $this->tab = 'front_office_features';
        $this->version = '0.0.1';
        $this->author = 'ToolSharp';
        $this->need_instance = 0;
        $this->bootstrap = true;

        parent::__construct();

        $this->displayName = $this->l('Product Discount Codes');
        $this->description = $this->l('Shows valid discount / voucher codes applicable to the current product on its product page.');
        $this->ps_versions_compliancy = ['min' => '8.0.0', 'max' => _PS_VERSION_];
    }

    /* ------------------------------------------------------------------ */
    /* Install / Uninstall                                                  */
    /* ------------------------------------------------------------------ */

    public function install()
    {
        ToolsharpProductdiscountsUpdateChecker::clearCache();
        return parent::install()
            && $this->registerHook('displayProductPriceBlock');       // inside the price block
    }

    public function uninstall()
    {
        ToolsharpProductdiscountsUpdateChecker::clearCache();
        return parent::uninstall();
    }

    /* ------------------------------------------------------------------ */
    /* Hooks                                                                */
    /* ------------------------------------------------------------------ */


    /**
     * Displayed inside the price block.
     * We only render here for the 'after_price' position so we don't
     * duplicate output in every sub-position PrestaShop calls this hook.
     *
     * Remove this hook registration (and method) if you only want one location.
     */
    public function hookDisplayProductPriceBlock(array $params): string
    {
        // Only inject at the 'after_price' position to avoid duplication.
        if (!isset($params['type']) || $params['type'] !== 'after_price') {
            return '';
        }

        return $this->renderDiscountCard($params);
    }

    /* ------------------------------------------------------------------ */
    /* Core rendering logic                                                 */
    /* ------------------------------------------------------------------ */

    /**
     * Fetches discounts and assigns them to the Smarty template.
     */
    private function renderDiscountCard(array $params): string
    {
        // PrestaShop 8 passes the product as an array under 'product'
        $product = $params['product'] ?? null;

        if (empty($product)) {
            return '';
        }

        $idProduct = (int) ($product['id_product'] ?? $product['id'] ?? 0);
        if ($idProduct === 0) {
            return '';
        }

        $idLang = (int) $this->context->language->id;
        $idCurrency = (int) $this->context->currency->id;
        $discounts = $this->getValidDiscountsForProduct($idProduct, $idLang, $idCurrency);

        if (empty($discounts)) {
            return '';
        }

        $this->context->smarty->assign([
            'pd_discounts' => $discounts,
            'pd_currency' => $this->context->currency,
            'pd_module_dir' => $this->_path,
        ]);

        return $this->display(__FILE__, 'views/templates/hook/product_discounts.tpl');
    }

    /* ------------------------------------------------------------------ */
    /* Data retrieval                                                       */
    /* ------------------------------------------------------------------ */

    /**
     * Returns all cart rules (voucher codes) that:
     *   - Are active, not deleted, and have a public code
     *   - Are currently within their validity dates
     *   - Apply to this shop
     *   - Apply to the current customer group (or have no group restriction)
     *   - Apply to the current product (no product restriction, OR the product /
     *     one of its categories is explicitly whitelisted)
     *
     * @param int $idProduct
     * @param int $idLang
     * @param int $idCurrency
     * @return array
     */
    private function getValidDiscountsForProduct(int $idProduct, int $idLang, int $idCurrency): array
    {
        $db = Db::getInstance();
        $now = pSQL(date('Y-m-d H:i:s'));
        $p = _DB_PREFIX_;

        // ---- Customer group ----
        $idGroup = (int) Group::getCurrent()->id;

        // ---- Product categories ----
        $rawCategories = Product::getProductCategories($idProduct);
        $categories = array_map('intval', $rawCategories);
        $categoriesIn = implode(',', $categories ?: [0]);

        // ---- Base conditions shared by all sub-queries ----
        // Note: ps_cart_rule has no `deleted` column — activity is controlled by `active` only.
        $baseWhere = "
            cr.active  = 1
            AND cr.code   != ''
            AND '$now'    >= cr.date_from
            AND '$now'    <= cr.date_to
        ";

        // ---- Shop restriction ----
        // shop_restriction = 0 → applies to all shops.
        // shop_restriction = 1 → only shops listed in ps_cart_rule_shop.
        $idShop = (int) $this->context->shop->id;
        $shopJoin = "
            LEFT JOIN {$p}cart_rule_shop crs
                ON crs.id_cart_rule = cr.id_cart_rule
               AND crs.id_shop      = $idShop
        ";
        $shopWhere = "
            AND (cr.shop_restriction = 0 OR crs.id_shop IS NOT NULL)
        ";

        // ---- Group restriction ----
        // cart_rule.group_restriction = 1 means the rule only works for certain groups.
        $groupJoin = "
            LEFT JOIN {$p}cart_rule_group crg
                ON crg.id_cart_rule = cr.id_cart_rule
                AND crg.id_group     = $idGroup
        ";
        $groupWhere = "
            AND (cr.group_restriction = 0 OR crg.id_group IS NOT NULL)
        ";

        // ================================================================
        // Query A: Rules with NO product restriction (apply to everything)
        // ================================================================
        $sqlAll = "
            SELECT DISTINCT cr.id_cart_rule
            FROM {$p}cart_rule cr
            {$shopJoin}
            {$groupJoin}
            WHERE {$baseWhere}
              AND cr.product_restriction = 0
              {$shopWhere}
              {$groupWhere}
        ";

        // ================================================================
        // Query B: Rules restricted to this specific PRODUCT
        // ================================================================
        $sqlProduct = "
            SELECT DISTINCT cr.id_cart_rule
            FROM {$p}cart_rule cr
            {$shopJoin}
            {$groupJoin}
            INNER JOIN {$p}cart_rule_product_rule_group crprg
                ON crprg.id_cart_rule = cr.id_cart_rule
            INNER JOIN {$p}cart_rule_product_rule crpr
                ON crpr.id_product_rule_group = crprg.id_product_rule_group
               AND crpr.type = 'products'
            INNER JOIN {$p}cart_rule_product_rule_value crprv
                ON crprv.id_product_rule = crpr.id_product_rule
               AND crprv.id_item = $idProduct
            WHERE {$baseWhere}
              AND cr.product_restriction = 1
              {$shopWhere}
              {$groupWhere}
        ";

        // ================================================================
        // Query C: Rules restricted to a CATEGORY that contains this product
        // ================================================================
        $sqlCategory = "
            SELECT DISTINCT cr.id_cart_rule
            FROM {$p}cart_rule cr
            {$shopJoin}
            {$groupJoin}
            INNER JOIN {$p}cart_rule_product_rule_group crprg
                ON crprg.id_cart_rule = cr.id_cart_rule
            INNER JOIN {$p}cart_rule_product_rule crpr
                ON crpr.id_product_rule_group = crprg.id_product_rule_group
               AND crpr.type = 'categories'
            INNER JOIN {$p}cart_rule_product_rule_value crprv
                ON crprv.id_product_rule = crpr.id_product_rule
               AND crprv.id_item IN ($categoriesIn)
            WHERE {$baseWhere}
              AND cr.product_restriction = 1
              {$shopWhere}
              {$groupWhere}
        ";

        // ================================================================
        // Combine and fetch full rule data + language label
        // ================================================================
        $idsSql = "
            SELECT id_cart_rule FROM (
                {$sqlAll}
                UNION
                {$sqlProduct}
                UNION
                {$sqlCategory}
            ) AS combined_ids
        ";

        $fullSql = "
            SELECT
                cr.id_cart_rule,
                cr.code,
                crl.name            AS description,
                cr.reduction_percent,
                cr.reduction_amount,
                cr.free_shipping,
                cr.reduction_tax,
                cr.minimum_amount,
                cr.minimum_amount_tax,
                cr.date_to,
                cr.highlight
            FROM {$p}cart_rule cr
            LEFT JOIN {$p}cart_rule_lang crl
                ON crl.id_cart_rule = cr.id_cart_rule
               AND crl.id_lang = $idLang
            WHERE cr.id_cart_rule IN ($idsSql)
            ORDER BY cr.reduction_percent DESC, cr.reduction_amount DESC
        ";

        $rows = $db->executeS($fullSql);

        if (empty($rows)) {
            return [];
        }

        // ---- Format each row for the template ----
        $discounts = [];
        foreach ($rows as $row) {
            $discounts[] = $this->formatDiscount($row, $idCurrency);
        }

        return $discounts;
    }

    /**
     * Formats a raw cart rule DB row into a display-friendly array.
     */
    private function formatDiscount(array $row, int $idCurrency): array
    {
        $type = 'none';
        $value = '';

        if ((float) $row['reduction_percent'] > 0) {
            $type = 'percent';
            $value = (float) $row['reduction_percent'] . '%';
        } elseif ((float) $row['reduction_amount'] > 0) {
            $type = 'amount';
            // Format using the currency symbol / position
            $value = Tools::displayPrice(
                (float) $row['reduction_amount'],
                new Currency($idCurrency)
            );
        } elseif ((int) $row['free_shipping'] === 1) {
            $type = 'shipping';
            $value = $this->l('Free shipping');
        }

        $minimumAmount = '';
        if ((float) $row['minimum_amount'] > 0) {
            $minimumAmount = Tools::displayPrice(
                (float) $row['minimum_amount'],
                new Currency($idCurrency)
            );
        }

        // How long is the code valid?
        $expiresIn = '';
        if (!empty($row['date_to'])) {
            $dateTo = new DateTime($row['date_to']);
            $now = new DateTime();
            $diff = $now->diff($dateTo);

            if ($diff->days === 0) {
                $expiresIn = $this->l('Expires today');
            } elseif ($diff->days === 1) {
                $expiresIn = $this->l('Expires tomorrow');
            } elseif ($diff->days <= 7) {
                $expiresIn = sprintf($this->l('Expires in %d days'), $diff->days);
            }
        }

        return [
            'id' => (int) $row['id_cart_rule'],
            'code' => $row['code'],
            'description' => $row['description'] ?? '',
            'type' => $type,
            'value' => $value,
            'minimum_amount' => $minimumAmount,
            'expires_in' => $expiresIn,
            'free_shipping' => (int) $row['free_shipping'] === 1,
        ];
    }

    public function getContent(): string
    {
        $checker = new ToolsharpProductdiscountsUpdateChecker($this->version, $this->name);

        // "Check for updates now" button was clicked — bypass cache
        $force = Tools::isSubmit('ts_check_updates');
        $update = $checker->check($force);

        // Format the "last checked" and "next check" strings for the template
        $checkedAt = date('d M Y H:i', $update['checked_at']);

        $nextCheckSeconds = ToolsharpProductdiscountsUpdateChecker::CACHE_TTL
            - (time() - $update['checked_at']);
        $nextCheck = $this->formatDuration(max(0, $nextCheckSeconds));

        $this->context->smarty->assign([
            'ts_installed_version' => $this->version,
            'ts_update' => $update,
            'ts_checked_at' => $checkedAt,
            'ts_next_check' => $nextCheck,
            'ts_form_action' => $this->context->link->getAdminLink('AdminModules', true, [], [
                'configure' => $this->name,
                'tab_module' => $this->tab,
                'module_name' => $this->name,
            ]),
        ]);

        return $this->display(__FILE__, 'views/templates/admin/configuration.tpl');
    }

    /**
     * Converts a number of seconds into a human-readable string,
     * e.g. "23 hours 4 minutes".
     */
    private function formatDuration(int $seconds): string
    {
        $hours = (int) floor($seconds / 3600);
        $minutes = (int) floor(($seconds % 3600) / 60);

        $parts = [];
        if ($hours > 0) {
            $parts[] = sprintf('%d %s', $hours, $hours === 1
                ? $this->l('hour')
                : $this->l('hours'));
        }
        if ($minutes > 0 || $hours === 0) {
            $parts[] = sprintf('%d %s', $minutes, $minutes === 1
                ? $this->l('minute')
                : $this->l('minutes'));
        }

        return implode(' ', $parts);
    }
}
