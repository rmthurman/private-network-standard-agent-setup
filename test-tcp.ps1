# Test 1: SSH data from VPN to VM (SSH server sends banner first)
Write-Host "=== Test 1: SSH data to VM 10.0.3.86:22 ==="
try {
    $t = New-Object Net.Sockets.TcpClient
    $t.ReceiveTimeout = 10000
    $t.Connect('10.0.3.86', 22)
    Write-Host "TCP Connected: $($t.Connected)"
    $s = $t.GetStream()
    $b = New-Object byte[] 256
    $n = $s.Read($b, 0, 256)
    $txt = [Text.Encoding]::ASCII.GetString($b, 0, $n)
    Write-Host "SSH banner ($n bytes): $txt"
    $t.Close()
} catch {
    Write-Host "FAIL: $($_.Exception.Message)"
}

# Test 2: TLS through proxy VM to PE
Write-Host ""
Write-Host "=== Test 2: TLS through proxy VM 10.0.3.86:443 ==="
try {
    $t2 = New-Object Net.Sockets.TcpClient
    $t2.ReceiveTimeout = 15000
    $t2.NoDelay = $true
    $t2.Connect('10.0.3.86', 443)
    Write-Host "TCP Connected: $($t2.Connected)"
    $s2 = $t2.GetStream()
    $ssl = New-Object Net.Security.SslStream($s2, $false, {$true})
    $ssl.AuthenticateAsClient('foundrype4cey.cognitiveservices.azure.com')
    Write-Host "TLS SUCCESS: $($ssl.SslProtocol) - Cert: $($ssl.RemoteCertificate.Subject)"
    $t2.Close()
} catch {
    $inner = $_.Exception.InnerException
    if ($inner) { Write-Host "TLS FAIL: $($inner.Message)" }
    else { Write-Host "TLS FAIL: $($_.Exception.Message)" }
}

# Test 3: Direct PE (expect fail - baseline)
Write-Host ""
Write-Host "=== Test 3: Direct TLS to spoke PE 10.200.3.12:443 (expect fail) ==="
try {
    $t3 = New-Object Net.Sockets.TcpClient
    $t3.ReceiveTimeout = 10000
    $t3.NoDelay = $true
    $t3.Connect('10.200.3.12', 443)
    Write-Host "TCP Connected: $($t3.Connected)"
    $s3 = $t3.GetStream()
    $ssl3 = New-Object Net.Security.SslStream($s3, $false, {$true})
    $ssl3.AuthenticateAsClient('foundrype4cey.cognitiveservices.azure.com')
    Write-Host "TLS SUCCESS (unexpected!): $($ssl3.SslProtocol)"
    $t3.Close()
} catch {
    $inner3 = $_.Exception.InnerException
    if ($inner3) { Write-Host "TLS FAIL (expected): $($inner3.Message)" }
    else { Write-Host "TLS FAIL (expected): $($_.Exception.Message)" }
}

# Test 4: DNS UDP still working
Write-Host ""
Write-Host "=== Test 4: DNS UDP resolution ==="
try {
    $result = Resolve-DnsName -Name "foundrype4cey.cognitiveservices.azure.com" -Server 10.0.1.132 -Type A -ErrorAction Stop
    foreach ($r in $result) {
        if ($r.QueryType -eq 'A') { Write-Host "DNS: $($r.Name) -> $($r.IPAddress)" }
        elseif ($r.QueryType -eq 'CNAME') { Write-Host "DNS: $($r.Name) -> CNAME $($r.NameHost)" }
    }
} catch {
    Write-Host "DNS FAIL: $($_.Exception.Message)"
}
