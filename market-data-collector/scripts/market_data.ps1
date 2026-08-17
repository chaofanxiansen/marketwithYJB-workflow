# market_data.ps1
# Market hard-data fetcher for A-share + global markets.
# Zero-dependency: uses only PowerShell 5.1 built-ins (Invoke-RestMethod).
# Data sources: Eastmoney (push2 / push2ex), Sina (hq.sinajs.cn).
# Every endpoint is independent: a failure in one never kills the others.
# NOTE: keep this file ASCII-only (PowerShell 5.1 parses ANSI by default).

param([string]$Date = (Get-Date).ToString("yyyyMMdd"))

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$script:UA = @{ 'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' }

function Get-Json {
    param([string]$Url, [int]$TimeoutSec = 12)
    # HTTPS first, auto-fallback to HTTP (some networks block TLS egress)
    foreach ($scheme in @('https', 'http')) {
        $u = $Url -replace '^https:', "${scheme}:"
        try {
            return Invoke-RestMethod -Uri $u -TimeoutSec $TimeoutSec -Headers $script:UA
        } catch {
            Write-Output "[WARN] fetch failed: $u  =>  $($_.Exception.Message.Substring(0, [Math]::Min(70, $_.Exception.Message.Length)))"
        }
    }
    return $null
}

function Show-UL {
    param($Diff, [string]$Label)
    if ($null -eq $Diff) { Write-Output "$Label : (no data)"; return }
    foreach ($d in $Diff) {
        Write-Output ("{0}: {1} | {2} | chg {3}% | amount {4}" -f $Label, $d.f14, $d.f2, $d.f3, $d.f6)
    }
}

Write-Output ("===== A-SHARE INDICES ({0} close) =====" -f $Date)
$idx = Get-Json "https://push2.eastmoney.com/api/qt/ulist.np/get?fltt=2&secids=1.000001,0.399001,1.000300,0.399006,1.000688&fields=f2,f3,f4,f6,f12,f14"
Show-UL $idx.data.diff "IDX"

Write-Output ""
Write-Output "===== MARKET BREADTH (up/down counts per exchange) ====="
foreach ($m in @(@("1.000001","SH"), @("0.399001","SZ"))) {
    $b = Get-Json ("https://push2.eastmoney.com/api/qt/ulist.np/get?fltt=2&secids={0}&fields=f104,f105,f106" -f $m[0])
    if ($b -and $b.data.diff) {
        $d = $b.data.diff[0]
        Write-Output ("{0}: up {1} | down {2} | flat {3}" -f $m[1], $d.f104, $d.f105, $d.f106)
    }
}

Write-Output ""
Write-Output "===== LIMIT UP / DOWN COUNTS ====="
$zt = Get-Json ("https://push2ex.eastmoney.com/getTopicZTPool?ut=7eea3edcaed734bea9cbfc24409ed989&dpt=wz.ztzt&Pageindex=0&pagesize=1&sort=fbt:asc&date={0}" -f $Date)
$dt = Get-Json ("https://push2ex.eastmoney.com/getTopicDTPool?ut=7eea3edcaed734bea9cbfc24409ed989&dpt=wz.ztzt&Pageindex=0&pagesize=1&sort=fund:asc&date={0}" -f $Date)
Write-Output ("Limit-up: {0} | Limit-down: {1}" -f $(if ($zt.data) { $zt.data.tc } else { "n/a" }), $(if ($dt.data) { $dt.data.tc } else { "n/a" }))

Write-Output ""
Write-Output "===== GLOBAL INDICES (latest session) ====="
$g = Get-Json "https://push2.eastmoney.com/api/qt/ulist.np/get?fltt=2&secids=100.DJIA,100.SPX,100.NDX,100.IXIC,100.HSI,100.N225,100.KS11,100.TWII,100.FTSE,100.GDAXI,100.FCHI&fields=f2,f3,f4,f12,f14"
Show-UL $g.data.diff "GLOBAL"

Write-Output ""
Write-Output "===== US DOLLAR INDEX ====="
$ud = Get-Json "https://push2.eastmoney.com/api/qt/ulist.np/get?fltt=2&secids=100.UDI&fields=f2,f3,f12,f14"
Show-UL $ud.data.diff "DXY"

Write-Output ""
Write-Output "===== FX (USDCNH USDCNY EURCNY JPYCNY) ====="
$fx = Get-Json "https://push2.eastmoney.com/api/qt/ulist.np/get?fltt=2&secids=133.USDCNH,133.USDCNY,133.EURCNY,133.JPYCNY&fields=f2,f3,f12,f14"
Show-UL $fx.data.diff "FX"

Write-Output ""
Write-Output "===== GOLD & OIL (Sina) ====="
try {
    # Sina: HTTPS first, HTTP fallback
    $sina = $null
    foreach ($scheme in @('https', 'http')) {
        try {
            $sina = Invoke-RestMethod -Uri ("${scheme}://hq.sinajs.cn/list=hf_GC,hf_CL,hf_SI") -TimeoutSec 10 -Headers @{ 'User-Agent' = 'Mozilla/5.0'; 'Referer' = 'https://finance.sina.com.cn' }
            break
        } catch {
            Write-Output "[WARN] sina $scheme failed: $($_.Exception.Message.Substring(0, [Math]::Min(70, $_.Exception.Message.Length)))"
        }
    }
    if (-not $sina) { throw 'all sina schemes failed' }
    $sina -split "`n" | ForEach-Object {
        if ($_ -match 'hf_GC="([^"]*)"') {
            $f = $Matches[1] -split ","
            Write-Output ("COMEX GOLD: {0} | chg {1}% (from prev close {2})" -f $f[0], [Math]::Round((($f[0] / $f[7] - 1) * 100), 2), $f[7])
        }
        elseif ($_ -match 'hf_CL="([^"]*)"') {
            $f = $Matches[1] -split ","
            Write-Output ("WTI CRUDE: {0} | chg {1}% (from prev close {2})" -f $f[0], [Math]::Round((($f[0] / $f[7] - 1) * 100), 2), $f[7])
        }
        elseif ($_ -match 'hf_SI="([^"]*)"') {
            $f = $Matches[1] -split ","
            Write-Output ("COMEX SILVER: {0} | chg {1}% (from prev close {2})" -f $f[0], [Math]::Round((($f[0] / $f[7] - 1) * 100), 2), $f[7])
        }
    }
} catch {
    Write-Output "[WARN] sina commodities failed: $($_.Exception.Message.Substring(0, [Math]::Min(70, $_.Exception.Message.Length)))"
}

Write-Output ""
Write-Output "===== NORTHBOUND (note: realtime net-buy disclosure stopped 2024-08) ====="
$nb = Get-Json "https://push2.eastmoney.com/api/qt/kamt.rtmin/get?fields1=f1,f2,f3,f4&fields2=f51,f52,f53,f54,f55,f56"
if ($nb -and $nb.data) {
    Write-Output "Northbound API responds (turnover only; net-buy no longer disclosed in realtime)."
    $nb.data.s2n | Select-Object -First 1 | ForEach-Object {
        Write-Output ("SH-Connect turnover today (first row): {0}" -f $_)
    }
} else {
    Write-Output "Northbound: no realtime data (expected since 2024-08 reform)."
}

Write-Output ""
Write-Output "===== SECTOR FUND FLOW (top 8 by net inflow) ====="
# clist: try push2 (https->http), then push2delay host fallback
$sec = $null
foreach ($base in @('https://push2.eastmoney.com', 'http://push2.eastmoney.com', 'http://push2delay.eastmoney.com')) {
    $sec = Get-Json ("$base/api/qt/clist/get?pn=1&pz=8&po=1&np=1&fltt=2&invt=2&fid=f62&fs=m:90+t:2&fields=f12,f14,f3,f62")
    if ($sec -and $sec.data.diff) { break }
}
if ($sec -and $sec.data.diff) {
    $sec.data.diff | ForEach-Object {
        Write-Output ("{0}: chg {1}% | net inflow {2} yuan" -f $_.f14, $_.f3, $_.f62)
    }
}

Write-Output ""
Write-Output "===== SECTOR FUND FLOW (top 5 by net outflow) ====="
$sec2 = $null
foreach ($base in @('https://push2.eastmoney.com', 'http://push2.eastmoney.com', 'http://push2delay.eastmoney.com')) {
    $sec2 = Get-Json ("$base/api/qt/clist/get?pn=1&pz=5&po=0&np=1&fltt=2&invt=2&fid=f62&fs=m:90+t:2&fields=f12,f14,f3,f62")
    if ($sec2 -and $sec2.data.diff) { break }
}
if ($sec2 -and $sec2.data.diff) {
    $sec2.data.diff | ForEach-Object {
        Write-Output ("{0}: chg {1}% | net inflow {2} yuan" -f $_.f14, $_.f3, $_.f62)
    }
}

Write-Output ""
Write-Output "===== CONCEPT GAINERS (top 10) ====="
$cg = $null
foreach ($base in @('https://push2.eastmoney.com', 'http://push2.eastmoney.com', 'http://push2delay.eastmoney.com')) {
    $cg = Get-Json ("$base/api/qt/clist/get?pn=1&pz=10&po=1&np=1&fltt=2&invt=2&fid=f3&fs=m:90+t:3&fields=f12,f14,f3,f62")
    if ($cg -and $cg.data.diff) { break }
}
if ($cg -and $cg.data.diff) {
    $cg.data.diff | ForEach-Object {
        Write-Output ("{0}: chg {1}%" -f $_.f14, $_.f3)
    }
}

Write-Output ""
Write-Output "===== HSI / HSTECH / US INDEX DETAIL ====="
$hd = Get-Json "https://push2.eastmoney.com/api/qt/ulist.np/get?fltt=2&secids=100.HSI,100.HSTECH,100.DJIA,100.NDX&fields=f2,f3,f4,f6,f12,f14"
Show-UL $hd.data.diff "DETAIL"

Write-Output ""
Write-Output "===== CHINA A50 FUTURES (SGX) - fallback via search if empty ====="
$a50 = Get-Json "https://push2.eastmoney.com/api/qt/ulist.np/get?fltt=2&secids=100.CN00Y,101.CN00Y,100.A50,100.CN50&fields=f2,f3,f12,f14"
Show-UL $a50.data.diff "A50"

Write-Output ""
Write-Output "===== CRYPTO (BTC) - optional ====="
$btc = Get-Json "https://push2.eastmoney.com/api/qt/ulist.np/get?fltt=2&secids=100.BTC,100.BTCUSD,133.BTCUSD&fields=f2,f3,f12,f14"
Show-UL $btc.data.diff "BTC"

Write-Output ""
Write-Output "[DONE]"
