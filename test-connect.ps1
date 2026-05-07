Write-Host "Connecting to VM 10.0.3.86:443..."
try {
    $t = New-Object Net.Sockets.TcpClient
    $t.ReceiveTimeout = 8000
    $t.Connect('10.0.3.86', 443)
    Write-Host "TCP connected: $($t.Connected)"
    $s = $t.GetStream()
    $msg = [Text.Encoding]::ASCII.GetBytes("HELLO-FROM-CLIENT`n")
    $s.Write($msg, 0, $msg.Length)
    $s.Flush()
    Write-Host "Sent HELLO-FROM-CLIENT"
    $buf = New-Object byte[] 256
    $n = $s.Read($buf, 0, 256)
    Write-Host "Got $n bytes: $([Text.Encoding]::ASCII.GetString($buf, 0, $n))"
    $t.Close()
} catch {
    Write-Host "ERROR: $($_.Exception.Message)"
}
