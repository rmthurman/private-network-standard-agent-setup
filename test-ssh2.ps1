Write-Host "=== Test SSH data to new VM 10.0.2.36:22 ==="
try {
    $t = New-Object Net.Sockets.TcpClient
    $t.ReceiveTimeout = 10000
    $t.Connect('10.0.2.36', 22)
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
