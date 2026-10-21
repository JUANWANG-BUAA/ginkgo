$ErrorActionPreference = 'Stop'
$resolver = Join-Path $PSScriptRoot '../flutter/rust_builder/cargokit/cmake/resolve_symlinks.ps1'
$fixture = Join-Path ([System.IO.Path]::GetTempPath()) ("ginkgo paths " + [guid]::NewGuid())
$real = Join-Path $fixture 'real package'
$alias = Join-Path $fixture 'plugin junction'
try {
    New-Item -ItemType Directory -Path (Join-Path $real 'cargokit/cmake') -Force | Out-Null
    New-Item -ItemType Junction -Path $alias -Target $real | Out-Null
    foreach ($root in @($real, $alias)) {
        $inputPath = Join-Path $root 'cargokit'
        if ($root -eq $alias) { $inputPath = $inputPath.Replace('\', '/') }
        $actual = & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $resolver $inputPath
        if ($LASTEXITCODE -ne 0) { throw "Resolver failed for $inputPath" }
        $expected = [System.IO.Path]::GetFullPath((Join-Path $real 'cargokit')).Replace('\', '/')
        if ($actual -ne $expected) { throw "Resolved $actual; expected $expected" }
    }
    # Failure must reach CMake rather than returning a plausible but wrong path.
    $process = Start-Process powershell.exe -ArgumentList @(
        '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
        '-File', ('"' + $resolver + '"'), ('"' + (Join-Path $fixture 'missing') + '"')
    ) -Wait -PassThru -WindowStyle Hidden -RedirectStandardError (Join-Path $fixture 'expected-error.txt')
    if ($process.ExitCode -eq 0) { throw 'Missing path unexpectedly resolved' }
    Write-Output 'Windows PowerShell: direct path, spaced junction and missing-path checks passed'
} finally {
    if (Test-Path -LiteralPath $alias) {
        [System.IO.Directory]::Delete($alias)
    }
    if (Test-Path -LiteralPath $fixture) {
        Remove-Item -LiteralPath $fixture -Recurse -Force
    }
}
