$ErrorActionPreference = 'Stop'
$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add('http://127.0.0.1:8766/')
try {
    $listener.Start()
    Write-Host "Peta lokal aktif: http://127.0.0.1:8766/web_peta/index.html"
    Write-Host 'Biarkan jendela ini terbuka. Tekan Ctrl+C untuk menghentikan server.'
    Start-Process 'http://127.0.0.1:8766/web_peta/index.html'
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        try {
            $relative = [System.Uri]::UnescapeDataString($context.Request.Url.AbsolutePath.TrimStart('/'))
            if ([string]::IsNullOrWhiteSpace($relative)) { $relative = 'web_peta/index.html' }
            $relative = $relative.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
            $filePath = [System.IO.Path]::GetFullPath((Join-Path $root $relative))
            if (-not $filePath.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
                $context.Response.StatusCode = 403; $context.Response.Close(); continue
            }
            if (Test-Path -LiteralPath $filePath -PathType Container) { $filePath = Join-Path $filePath 'index.html' }
            if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
                $context.Response.StatusCode = 404; $context.Response.Close(); continue
            }
            $extension = [System.IO.Path]::GetExtension($filePath).ToLowerInvariant()
            $contentType = switch ($extension) {
                '.html' { 'text/html; charset=utf-8' }
                '.pbf'  { 'application/x-protobuf' }
                '.js'   { 'text/javascript; charset=utf-8' }
                '.css'  { 'text/css; charset=utf-8' }
                '.png'  { 'image/png' }
                '.json' { 'application/json; charset=utf-8' }
                default { 'application/octet-stream' }
            }
            $bytes = [System.IO.File]::ReadAllBytes($filePath)
            $context.Response.StatusCode = 200; $context.Response.ContentType = $contentType
            $context.Response.ContentLength64 = $bytes.LongLength
            $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
            $context.Response.Close()
        } catch {
            try { $context.Response.StatusCode = 500; $context.Response.Close() } catch {}
        }
    }
} finally {
    if ($listener.IsListening) { $listener.Stop() }
    $listener.Close()
}
