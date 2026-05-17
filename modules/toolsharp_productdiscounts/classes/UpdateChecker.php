<?php
/**
 * ToolSharp — ProductDiscounts
 * Update checker — compares installed version against latest GitHub Release.
 *
 * Results are cached in PS Configuration for 24 hours so the GitHub API is
 * hit at most once per day per store, regardless of how many admins open the
 * configuration page.
 */

if (!defined('_PS_VERSION_')) {
    exit;
}

use Symfony\Component\HttpClient\HttpClient;
use Symfony\Contracts\HttpClient\Exception\TransportExceptionInterface;

class ToolsharpProductdiscountsUpdateChecker
{
    const MODULE_PREFIX = 'toolsharp_';

    /** GitHub repository in "owner/repo" format */
    const GITHUB_REPO = 'ToolSharp/toolsharp_prestashop';

    /** How long to cache a successful API response (seconds) */
    const CACHE_TTL = 86400; // 24 hours

    const CONFIG_CACHE_DATA = 'TOOLSHARP_PD_UPDATE_CACHE';
    const CONFIG_CACHE_TIME = 'TOOLSHARP_PD_UPDATE_CACHE_TIME';

    /** @var string The currently installed module version */
    private $installedVersion;
    private $moduleShortName;


    public function __construct(string $installedVersion, string $moduleName)
    {
        $this->installedVersion = $installedVersion;
        $this->moduleShortName = str_replace(self::MODULE_PREFIX, '', $moduleName);
    }

    /**
     * Returns cached update info if available and fresh, otherwise fetches
     * from GitHub. Pass $force = true to bypass the cache (button click).
     *
     * @return array{
     *   checked_at: int,
     *   from_cache: bool,
     *   error: string|null,
     *   update_available: bool,
     *   installed_version: string,
     *   latest_version: string|null,
     *   release_url: string|null,
     *   release_notes: string|null,
     * }
     */
    public function check(bool $force = false): array
    {
        if (!$force && $this->isCacheFresh()) {
            $cached = json_decode(Configuration::get(self::CONFIG_CACHE_DATA), true);
            if (is_array($cached)) {
                $cached['from_cache'] = true;
                return $cached;
            }
        }

        $result = $this->fetchFromGitHub();
        $this->writeCache($result);
        return $result;
    }

    /**
     * Removes the cached result so the next check always hits the API.
     */
    public static function clearCache(): void
    {
        Configuration::deleteByName(self::CONFIG_CACHE_DATA);
        Configuration::deleteByName(self::CONFIG_CACHE_TIME);
    }

    // -------------------------------------------------------------------------

    private function isCacheFresh(): bool
    {
        $cachedAt = (int) Configuration::get(self::CONFIG_CACHE_TIME);
        if ($cachedAt === 0) {
            return false;
        }
        return (time() - $cachedAt) < self::CACHE_TTL;
    }

    private function writeCache(array $result): void
    {
        Configuration::updateValue(self::CONFIG_CACHE_DATA, json_encode($result));
        Configuration::updateValue(self::CONFIG_CACHE_TIME, time());
    }


    private function fetchFromGitHub(): array
    {
        $base = [
            'checked_at' => time(),
            'from_cache' => false,
            'error' => null,
            'update_available' => false,
            'installed_version' => $this->installedVersion,
            'latest_version' => null,
            'release_url' => null,
            'release_notes' => null,
        ];

        $url = 'https://api.github.com/repos/' . self::GITHUB_REPO . '/releases?per_page=20&page=1';

        try {
            $client = HttpClient::create();
            $response = $client->request('GET', $url, [
                'timeout' => 5,
                'headers' => [
                    'User-Agent' => 'ToolSharp-PrestaShop-Module/' . $this->installedVersion,
                    'Accept' => 'application/vnd.github+json',
                ],
            ]);

            // Pass false so we handle non-2xx ourselves rather than catching HttpExceptionInterface
            $releases = $response->toArray(false);

        } catch (TransportExceptionInterface $e) {
            $base['error'] = 'Could not reach GitHub. Check your server\'s outbound internet access.';
            return $base;
        }

        if ($response->getStatusCode() !== 200) {
            $base['error'] = '(' . $response->getStatusCode() . ') GitHub API error: ' . ($releases['message'] ?? 'Unexpected status ' . $response->getStatusCode());
            return $base;
        }

        if (empty($releases)) {
            $base['error'] = sprintf('No releases found for module "%s" on GitHub.', $this->moduleShortName);
            return $base;
        }

        // Find the first release whose tag matches this module
        $matched = null;
        $latestVersion = '';
        foreach ($releases as $release) {
            $tagName = $release['tag_name'] ?? '';
            if (!str_contains($tagName, '@')) {
                continue;
            }
            [$tagModule, $tagVersion] = explode('@', $tagName, 2);
            if ($tagModule === $this->moduleShortName && $tagVersion !== '') {
                $matched = $release;
                $latestVersion = ltrim($tagVersion, 'v'); // strip leading v
                break;
            }
        }

        if ($matched === null) {
            $base['error'] = sprintf('No release found for module "%s" on GitHub.', $this->moduleShortName);
            return $base;
        }

        $base['latest_version'] = $latestVersion;
        $base['release_url'] = $matched['html_url'] ?? null;
        $base['release_notes'] = $matched['body'] ?? null;
        $base['update_available'] = version_compare($latestVersion, $this->installedVersion, '>');

        return $base;
    }
}
