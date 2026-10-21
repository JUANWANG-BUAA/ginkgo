$ErrorActionPreference = 'Stop'

function Resolve-Symlinks {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string] $Path
    )

    [string] $separator = '/'
    [string[]] $parts = $Path.Replace('\', '/').Split($separator)

    [string] $realPath = ''
    foreach ($part in $parts) {
        if ($realPath -and !$realPath.EndsWith($separator)) {
            $realPath += $separator
        }

        $realPath += $part.Replace('\', '/')

        # The slash is important when using Get-Item on Drive letters in pwsh.
        if (-not($realPath.Contains($separator)) -and $realPath.EndsWith(':')) {
            $realPath += '/'
        }

        $item = Get-Item -LiteralPath $realPath -Force
        # Windows PowerShell 5.1 exposes Target; LinkTarget requires PowerShell 7.
        # Target supports both directory junctions and symbolic links.
        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            $target = @($item.Target)[0]
            if (-not $target) {
                throw "Cannot resolve reparse point: $realPath"
            }
            if (-not [System.IO.Path]::IsPathRooted($target)) {
                $target = Join-Path $item.Parent.FullName $target
            }
            $realPath = [System.IO.Path]::GetFullPath($target).Replace('\', '/')
        }
    }
    $realPath
}

$path = Resolve-Symlinks -Path $args[0]
Write-Output $path
