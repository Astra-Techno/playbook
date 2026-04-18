<?php
/**
 * Pre-seed the places cache for major Tamil Nadu cities.
 *
 * Run from the backend directory:
 *   php scripts/prefetch_tamilnadu.php
 *
 * Quota cost: up to 5 API calls per city (1 Nearby + 4 Text Search).
 * ~81 cities = ~567 calls (7 API calls/city) — well within the 6,000/month free tier.
 *
 * Already-cached cities are skipped automatically.
 * A 1.5 s sleep between cities keeps us under Google's per-second rate limit.
 */

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../src/Controllers/PlacesController.php';

// ── Tamil Nadu cities (name, lat, lng) ──────────────────────────────────────
$cities = [
    // ── Tier 1: Major cities ──────────────────────────────────────────────────
    ['Chennai',              13.0827,  80.2707],
    ['Coimbatore',           11.0168,  76.9558],
    ['Madurai',               9.9252,  78.1198],
    ['Trichy',               10.7905,  78.7047],
    ['Salem',                11.6643,  78.1460],
    ['Tirunelveli',           8.7139,  77.7567],
    ['Vellore',              12.9165,  79.1325],
    ['Erode',                11.3410,  77.7172],
    ['Tiruppur',             11.1085,  77.3411],
    ['Thoothukudi',           8.7642,  78.1348],
    ['Nagercoil',             8.1833,  77.4119],
    ['Hosur',                12.7409,  77.8253],

    // ── Tier 2: District headquarters ────────────────────────────────────────
    ['Kancheepuram',         12.8394,  79.7000],
    ['Thanjavur',            10.7870,  79.1378],
    ['Dindigul',             10.3673,  77.9803],
    ['Cuddalore',            11.7480,  79.7714],
    ['Kumbakonam',           10.9602,  79.3845],
    ['Namakkal',             11.2196,  78.1671],
    ['Karur',                10.9601,  78.0766],
    ['Pudukkottai',          10.3797,  78.8201],
    ['Villupuram',           11.9401,  79.4861],
    ['Krishnagiri',          12.5186,  78.2137],
    ['Dharmapuri',           12.1281,  78.1582],
    ['Tiruvallur',           13.1437,  79.9093],
    ['Chengalpattu',         12.6922,  79.9759],
    ['Ranipet',              12.9283,  79.3328],
    ['Tiruvannamalai',       12.2253,  79.0747],
    ['Tirupattur',           12.4960,  78.5730],
    ['Kallakurichi',         11.7354,  78.9602],
    ['Ariyalur',             11.1390,  79.0771],
    ['Perambalur',           11.2330,  78.8804],
    ['Mayiladuthurai',       11.1033,  79.6533],
    ['Nagapattinam',         10.7672,  79.8449],
    ['Tiruvarur',            10.7726,  79.6356],
    ['Sivaganga',             9.8438,  78.4828],
    ['Ramanathapuram',        9.3639,  78.8395],
    ['Virudhunagar',          9.5872,  77.9622],
    ['Tenkasi',               8.9594,  77.3153],
    ['Theni',                10.0104,  77.4770],

    // ── Tier 3: Major towns & tourist/sports hubs ─────────────────────────────
    ['Ooty',                 11.4102,  76.6950],
    ['Kodaikanal',           10.2381,  77.4892],
    ['Pollachi',             10.6554,  77.0070],
    ['Palani',               10.4476,  77.5230],
    ['Gobichettipalayam',    11.4547,  77.3572],
    ['Bhavani',              11.4451,  77.6831],
    ['Mettur',               11.7925,  77.8011],
    ['Sathyamangalam',       11.5011,  77.2340],
    ['Sivakasi',              9.4533,  77.7997],
    ['Rajapalayam',           9.4880,  77.5527],
    ['Ambur',                12.7933,  78.7185],
    ['Gudiyatham',           12.9483,  78.8742],
    ['Chidambaram',          11.3995,  79.6913],
    ['Rasipuram',            11.4612,  78.1767],
    ['Yercaud',              11.7720,  78.2092],

    // ── Tier 4: Famous towns (pilgrimage, heritage, hill stations, industrial) ─
    ['Kanyakumari',           8.0883,  77.5385],  // southernmost tip
    ['Rameswaram',            9.2876,  79.3129],  // pilgrimage island
    ['Tiruchendur',           8.4973,  78.1218],  // coastal temple town
    ['Velankanni',           10.6874,  79.8537],  // pilgrimage town
    ['Mahabalipuram',        12.6269,  80.1927],  // UNESCO heritage + beach
    ['Karaikudi',            10.0757,  78.7734],  // Chettinad cultural hub
    ['Coonoor',              11.3530,  76.7959],  // Nilgiris hill station
    ['Mettupalayam',         11.2964,  76.9431],  // gateway to Ooty
    ['Valparai',             10.3269,  76.9550],  // Anaimalai hill station
    ['Kovilpatti',            9.1706,  77.8680],  // match industry hub
    ['Aruppukkottai',         9.5091,  78.0972],
    ['Srivilliputhur',        9.5117,  77.6369],
    ['Sankarankovil',         9.1701,  77.5536],
    ['Sattur',                9.3479,  77.9098],
    ['Paramakudi',            9.5197,  78.5912],
    ['Periyakulam',          10.1148,  77.5540],
    ['Bodinayakanur',        10.0108,  77.3530],
    ['Udumalpet',            10.5852,  77.2486],
    ['Kangeyam',             11.0061,  77.5612],
    ['Attur',                11.5969,  78.5992],
    ['Arakkonam',            13.0786,  79.6682],
    ['Vaniyambadi',          12.6840,  78.6230],
    ['Jolarpettai',          12.5600,  78.5767],
    ['Harur',                12.0516,  78.4794],
    ['Bargur',               12.1992,  78.2339],
    ['Arani',                12.6701,  79.2814],
    ['Cheyyar',              12.6543,  79.5460],
    ['Gingee',               12.2531,  79.4167],
    ['Tindivanam',           12.2432,  79.6569],
    ['Ulundurpet',           11.6725,  79.3227],
];

$ctrl  = new PlacesController();
$total = 0;
$skipped = 0;

echo "KoCourt — Tamil Nadu places prefetch\n";
echo str_repeat('─', 50) . "\n";

foreach ($cities as [$name, $lat, $lng]) {
    $count = $ctrl->prefetchCity((float)$lat, (float)$lng);

    if ($count === 0) {
        echo "  SKIP  $name (already cached or quota exceeded)\n";
        $skipped++;
    } else {
        echo "  OK    $name → $count places stored\n";
        $total += $count;
    }

    sleep(1); // respect Google's per-second rate limit
}

echo str_repeat('─', 50) . "\n";
echo "Done. $total new places stored, $skipped cities skipped.\n";
