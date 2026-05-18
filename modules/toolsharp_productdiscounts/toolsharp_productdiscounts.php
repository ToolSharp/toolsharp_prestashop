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
    /** Stored as an integer 75–100 (percentage). Default: 100 = no scaling. */
    const CONFIG_SCALE    = 'TOOLSHARP_PD_SCALE';
    const CONFIG_SCALE_DEFAULT = 100;

    /** Optional URL for the merchant's promotion-details page. Empty = disabled. */
    const CONFIG_PROMO_URL = 'TOOLSHARP_PD_PROMO_URL';

    public function __construct()
    {
        $this->name = 'toolsharp_productdiscounts';
        $this->tab = 'front_office_features';
        $this->version = trim(file_get_contents(__DIR__ . '/version.txt'));
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

        // Seed defaults so the BO form is pre-filled on first open
        Configuration::updateValue(self::CONFIG_SCALE, self::CONFIG_SCALE_DEFAULT);
        Configuration::updateValue(self::CONFIG_PROMO_URL, '');

        return parent::install()
            // NEW hook — renders the block below the add-to-cart button
            && $this->registerHook('displayProductAdditionalInfo')
            // Keep the old hook registered but returning '' so that shops
            // which already had it registered see nothing there anymore.
            && $this->registerHook('displayProductPriceBlock');
    }

    public function uninstall()
    {
        ToolsharpProductdiscountsUpdateChecker::clearCache();
        Configuration::deleteByName(self::CONFIG_SCALE);
        Configuration::deleteByName(self::CONFIG_PROMO_URL);

        return parent::uninstall();
    }

    /* ------------------------------------------------------------------ */
    /* Hooks                                                                */
    /* ------------------------------------------------------------------ */

    /**
     * Primary hook — fires below the add-to-cart button area.
     * Most PS8 themes call this without passing a $product param, so we fall
     * back to reading id_product from the request.
     */
    public function hookDisplayProductAdditionalInfo(array $params): string
    {
        $product = $params['product'] ?? null;

        if (empty($product)) {
            $idProduct = (int) Tools::getValue('id_product');
            if ($idProduct > 0) {
                $product = ['id_product' => $idProduct];
            }
        }

        return $this->renderDiscountCard(['product' => $product]);
    }

    /**
     * Legacy hook — still registered so existing shops that had it don't
     * throw an error, but we intentionally render nothing here now.
     */
    public function hookDisplayProductPriceBlock(array $params): string
    {
        return '';
    }

    /* ------------------------------------------------------------------ */
    /* Core rendering logic                                                 */
    /* ------------------------------------------------------------------ */

    private function renderDiscountCard(array $params): string
    {
        $product = $params['product'] ?? null;

        if (empty($product)) {
            return '';
        }

        $idProduct = (int) ($product['id_product'] ?? $product['id'] ?? 0);
        if ($idProduct === 0) {
            return '';
        }

        $idLang     = (int) $this->context->language->id;
        $idCurrency = (int) $this->context->currency->id;
        $discounts  = $this->getValidDiscountsForProduct($idProduct, $idLang, $idCurrency);

        if (empty($discounts)) {
            return '';
        }

        // Scale: stored as integer 75-100; convert to a 2-decimal CSS float (e.g. 0.90)
        $scaleInt = (int) Configuration::get(self::CONFIG_SCALE);
        if ($scaleInt < 75 || $scaleInt > 100) {
            $scaleInt = self::CONFIG_SCALE_DEFAULT;
        }
        $scaleFactor = number_format($scaleInt / 100, 2, '.', '');

        $promoUrl = (string) Configuration::get(self::CONFIG_PROMO_URL);

        $this->context->smarty->assign([
            'pd_discounts'     => $discounts,
            'pd_currency'      => $this->context->currency,
            'pd_module_dir'    => $this->_path,
            'pd_scale_factor'  => $scaleFactor,   // e.g. "0.90"
            'pd_promo_page_url' => $promoUrl,
        ]);

        return $this->display(__FILE__, 'views/templates/hook/product_discounts.tpl');
    }

    /* ------------------------------------------------------------------ */
    /* Data retrieval                                                       */
    /* ------------------------------------------------------------------ */

    private function getValidDiscountsForProduct(int $idProduct, int $idLang, int $idCurrency): array
    {
        $db  = Db::getInstance();
        $now = pSQL(date('Y-m-d H:i:s'));
        $p   = _DB_PREFIX_;

        $idGroup = (int) Group::getCurrent()->id;

        $rawCategories = Product::getProductCategories($idProduct);
        $categories    = array_map('intval', $rawCategories);
        $categoriesIn  = implode(',', $categories ?: [0]);

        $baseWhere = "
            cr.active  = 1
            AND cr.code   != ''
            AND '$now'    >= cr.date_from
            AND '$now'    <= cr.date_to
        ";

        $idShop   = (int) $this->context->shop->id;
        $shopJoin = "
            LEFT JOIN {$p}cart_rule_shop crs
                ON crs.id_cart_rule = cr.id_cart_rule
               AND crs.id_shop      = $idShop
        ";
        $shopWhere = "AND (cr.shop_restriction = 0 OR crs.id_shop IS NOT NULL)";

        $groupJoin = "
            LEFT JOIN {$p}cart_rule_group crg
                ON crg.id_cart_rule = cr.id_cart_rule
                AND crg.id_group     = $idGroup
        ";
        $groupWhere = "AND (cr.group_restriction = 0 OR crg.id_group IS NOT NULL)";

        $sqlAll = "
            SELECT DISTINCT cr.id_cart_rule
            FROM {$p}cart_rule cr
            {$shopJoin} {$groupJoin}
            WHERE {$baseWhere} AND cr.product_restriction = 0
              {$shopWhere} {$groupWhere}
        ";

        $sqlProduct = "
            SELECT DISTINCT cr.id_cart_rule
            FROM {$p}cart_rule cr
            {$shopJoin} {$groupJoin}
            INNER JOIN {$p}cart_rule_product_rule_group crprg ON crprg.id_cart_rule = cr.id_cart_rule
            INNER JOIN {$p}cart_rule_product_rule crpr
                ON crpr.id_product_rule_group = crprg.id_product_rule_group AND crpr.type = 'products'
            INNER JOIN {$p}cart_rule_product_rule_value crprv
                ON crprv.id_product_rule = crpr.id_product_rule AND crprv.id_item = $idProduct
            WHERE {$baseWhere} AND cr.product_restriction = 1
              {$shopWhere} {$groupWhere}
        ";

        $sqlCategory = "
            SELECT DISTINCT cr.id_cart_rule
            FROM {$p}cart_rule cr
            {$shopJoin} {$groupJoin}
            INNER JOIN {$p}cart_rule_product_rule_group crprg ON crprg.id_cart_rule = cr.id_cart_rule
            INNER JOIN {$p}cart_rule_product_rule crpr
                ON crpr.id_product_rule_group = crprg.id_product_rule_group AND crpr.type = 'categories'
            INNER JOIN {$p}cart_rule_product_rule_value crprv
                ON crprv.id_product_rule = crpr.id_product_rule AND crprv.id_item IN ($categoriesIn)
            WHERE {$baseWhere} AND cr.product_restriction = 1
              {$shopWhere} {$groupWhere}
        ";

        $idsSql = "SELECT id_cart_rule FROM ({$sqlAll} UNION {$sqlProduct} UNION {$sqlCategory}) AS combined_ids";

        $fullSql = "
            SELECT
                cr.id_cart_rule,
                cr.code,
                crl.name                AS description,
                cr.reduction_percent,
                cr.reduction_amount,
                cr.free_shipping,
                cr.reduction_tax,
                cr.minimum_amount,
                cr.minimum_amount_tax,
                cr.date_to,
                cr.highlight,
                cr.product_restriction,
                cr.cart_rule_restriction,
                cr.id_customer
            FROM {$p}cart_rule cr
            LEFT JOIN {$p}cart_rule_lang crl
                ON crl.id_cart_rule = cr.id_cart_rule AND crl.id_lang = $idLang
            WHERE cr.id_cart_rule IN ($idsSql)
            ORDER BY cr.reduction_percent DESC, cr.reduction_amount DESC
        ";

        $rows = $db->executeS($fullSql);

        if (empty($rows)) {
            return [];
        }

        $discounts = [];
        foreach ($rows as $row) {
            $discounts[] = $this->formatDiscount($row, $idCurrency, $idLang);
        }

        return $discounts;
    }

    /**
     * Returns which categories / products a rule is explicitly restricted to.
     *
     * @return array{categories: string[], has_product_restriction: bool}
     */
    private function getProductRuleDetails(int $idCartRule, int $idLang): array
    {
        $db = Db::getInstance();
        $p  = _DB_PREFIX_;

        // Category names this rule is scoped to
        $categorySql = "
            SELECT DISTINCT cl.name
            FROM {$p}cart_rule_product_rule_group crprg
            INNER JOIN {$p}cart_rule_product_rule crpr
                ON crpr.id_product_rule_group = crprg.id_product_rule_group
               AND crpr.type = 'categories'
            INNER JOIN {$p}cart_rule_product_rule_value crprv
                ON crprv.id_product_rule = crpr.id_product_rule
            INNER JOIN {$p}category_lang cl
                ON cl.id_category = crprv.id_item
               AND cl.id_lang = $idLang
            WHERE crprg.id_cart_rule = $idCartRule
            ORDER BY cl.name
        ";

        $categoryRows = $db->executeS($categorySql);
        $categories   = array_column($categoryRows ?: [], 'name');

        // Just detect presence of product-level rules — we don't list every product name
        $productSql = "
            SELECT COUNT(DISTINCT crprv.id_item) AS cnt
            FROM {$p}cart_rule_product_rule_group crprg
            INNER JOIN {$p}cart_rule_product_rule crpr
                ON crpr.id_product_rule_group = crprg.id_product_rule_group
               AND crpr.type = 'products'
            INNER JOIN {$p}cart_rule_product_rule_value crprv
                ON crprv.id_product_rule = crpr.id_product_rule
            WHERE crprg.id_cart_rule = $idCartRule
        ";

        $productCount = (int) $db->getValue($productSql);

        return [
            'categories'             => $categories,
            'has_product_restriction' => $productCount > 0,
        ];
    }

    /**
     * Formats a raw cart rule row into a display-friendly array.
     *
     * Conditions are structured as either a plain string or an object
     * { text: string, items: string[] } so the modal JS can render nested
     * lists for category / product scope conditions.
     */
    private function formatDiscount(array $row, int $idCurrency, int $idLang): array
    {
        /* ---- Discount type & headline value ---- */
        $type  = 'none';
        $value = '';

        if ((float) $row['reduction_percent'] > 0) {
            $type  = 'percent';
            $value = (float) $row['reduction_percent'] . '%';
        } elseif ((float) $row['reduction_amount'] > 0) {
            $type  = 'amount';
            $value = Tools::displayPrice(
                (float) $row['reduction_amount'],
                new Currency($idCurrency)
            );
        } elseif ((int) $row['free_shipping'] === 1) {
            $type  = 'shipping';
            $value = $this->l('Free shipping');
        }

        /* ---- Minimum spend ---- */
        $minimumAmount = '';
        if ((float) $row['minimum_amount'] > 0) {
            $minimumAmount = Tools::displayPrice(
                (float) $row['minimum_amount'],
                new Currency($idCurrency)
            );
        }

        /* ---- Expiry ---- */
        $expiresIn  = '';
        $expiryDate = '';
        if (!empty($row['date_to'])) {
            $dateTo = new DateTime($row['date_to']);
            $now    = new DateTime();
            $diff   = $now->diff($dateTo);

            $expiryDate = $dateTo->format('d/m/Y');

            if ($diff->days === 0) {
                $expiresIn = $this->l('Expires today');
            } elseif ($diff->days === 1) {
                $expiresIn = $this->l('Expires tomorrow');
            } elseif ($diff->days <= 7) {
                $expiresIn = sprintf($this->l('Expires in %d days'), $diff->days);
            }
        }

        /* ---- Build conditions list ---- */
        // Each entry is either:
        //   string                          → plain text condition
        //   ['text' => string, 'items' => string[]]  → header + nested list
        $conditions = [];

        // 1. Category / product scope
        if ((int) $row['product_restriction'] === 1) {
            $details = $this->getProductRuleDetails((int) $row['id_cart_rule'], $idLang);

            if (!empty($details['categories'])) {
                // Structured entry — JS will render categories as a nested <ul>
                $conditions[] = [
                    'text'  => $this->l('Only valid for products in:'),
                    'items' => $details['categories'],
                ];
            }

            if ($details['has_product_restriction']) {
                $conditions[] = $this->l('Only valid for selected products.');
            }
        }

        // 2. Minimum spend
        if ($minimumAmount !== '') {
            $conditions[] = sprintf(
                $this->l('Requires a minimum purchase of %s.'),
                $minimumAmount
            );
        }

        // 3. Free shipping (bonus, when it's not the primary discount type)
        if ((int) $row['free_shipping'] === 1 && $type !== 'shipping') {
            $conditions[] = $this->l('Includes free shipping.');
        }

        // 4. Combinability.
        //    cart_rule_restriction = 1 → cannot be combined with other rules.
        //    BUT: if id_customer > 0 the voucher belongs to a specific customer — it
        //    already implies restricted use, and surfacing the restriction is confusing
        //    for a personalised code. So we only show this for public promotions.
        if ((int) $row['cart_rule_restriction'] === 1 && (int) $row['id_customer'] === 0) {
            $conditions[] = $this->l('Cannot be combined with other promotions.');
        }

        // 5. Expiry
        if ($expiryDate !== '') {
            $conditions[] = sprintf($this->l('Valid until %s.'), $expiryDate);
        } elseif ($expiresIn !== '') {
            $conditions[] = $expiresIn . '.';
        }

        /* ---- JSON blob for the info button ---- */
        // JSON_HEX_* flags make every character safe inside an HTML attribute
        // (no extra Smarty escaping needed).
        $infoJson = json_encode(
            [
                'code'        => $row['code'],
                'value'       => $value,
                'type'        => $type,
                'description' => $row['description'] ?? '',
                'conditions'  => $conditions,
            ],
            JSON_UNESCAPED_UNICODE | JSON_HEX_TAG | JSON_HEX_QUOT | JSON_HEX_AMP | JSON_HEX_APOS
        );

        return [
            'id'             => (int) $row['id_cart_rule'],
            'code'           => $row['code'],
            'description'    => $row['description'] ?? '',
            'type'           => $type,
            'value'          => $value,
            'minimum_amount' => $minimumAmount,
            'expires_in'     => $expiresIn,
            'expiry_date'    => $expiryDate,
            'free_shipping'  => (int) $row['free_shipping'] === 1,
            'info_json'      => $infoJson,
        ];
    }

    /* ------------------------------------------------------------------ */
    /* Back office                                                          */
    /* ------------------------------------------------------------------ */

    public function getContent(): string
    {
        $output = '';

        // ---- Handle settings form ----------------------------------------
        if (Tools::isSubmit('ts_save_settings')) {
            $scale = (int) Tools::getValue('ts_scale', self::CONFIG_SCALE_DEFAULT);
            $scale = max(75, min(100, $scale));
            Configuration::updateValue(self::CONFIG_SCALE, $scale);

            $promoUrl = trim((string) Tools::getValue('ts_promo_url', ''));
            if ($promoUrl !== '' && !Validate::isUrl($promoUrl)) {
                $promoUrl = '';
                $output .= $this->displayError($this->l('The promotion details URL is not valid and has been cleared.'));
            }
            Configuration::updateValue(self::CONFIG_PROMO_URL, $promoUrl);

            $output .= $this->displayConfirmation($this->l('Settings saved.'));
        }

        // ---- Handle update-check form ------------------------------------
        $checker = new ToolsharpProductdiscountsUpdateChecker($this->version, $this->name);
        $force   = Tools::isSubmit('ts_check_updates');
        $update  = $checker->check($force);

        $checkedAt        = date('d M Y H:i', $update['checked_at']);
        $nextCheckSeconds = ToolsharpProductdiscountsUpdateChecker::CACHE_TTL
            - (time() - $update['checked_at']);
        $nextCheck = $this->formatDuration(max(0, $nextCheckSeconds));

        // Current saved settings
        $currentScale    = (int) Configuration::get(self::CONFIG_SCALE) ?: self::CONFIG_SCALE_DEFAULT;
        $currentPromoUrl = (string) Configuration::get(self::CONFIG_PROMO_URL);

        $this->context->smarty->assign([
            'ts_installed_version' => $this->version,
            'ts_update'            => $update,
            'ts_checked_at'        => $checkedAt,
            'ts_next_check'        => $nextCheck,
            'ts_form_action'       => $this->context->link->getAdminLink('AdminModules', true, [], [
                'configure'   => $this->name,
                'tab_module'  => $this->tab,
                'module_name' => $this->name,
            ]),
            // Settings panel vars
            'ts_current_scale'     => $currentScale,
            'ts_current_promo_url' => $currentPromoUrl,
            'ts_scale_default'     => self::CONFIG_SCALE_DEFAULT,
        ]);

        return $output . $this->display(__FILE__, 'views/templates/admin/configuration.tpl');
    }

    private function formatDuration(int $seconds): string
    {
        $hours   = (int) floor($seconds / 3600);
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