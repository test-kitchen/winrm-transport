trap {$e = $_.Exception; $e.InvocationInfo.ScriptName; do {$e.Message; $e = $e.InnerException} while ($e); break;}
$progresspreference = $warningpreference = 'SilentlyContinue'
function Decode-Base64File($src, $dst) {set-content -Encoding Byte -Path $dst -Value ([Convert]::FromBase64String([IO.File]::ReadAllLines($src)))}
function Copy-Stream($src, $dst) { $b = New-Object Byte[] 4096; while (($i = $src.Read($b, 0, $b.Length)) -ne 0) { $dst.Write($b, 0, $i) } }
function Resolve-ProviderPath{ $input | % {if ($_){(Resolve-Path $_).ProviderPath} else{$null}} }
function Get-FrameworkVersion { "Full", "Client" | % {([version](gp "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v4\$_").Version)} | select -first 1}
function Test-NETStack($Version){ Get-FrameworkVersion -ge $Version }
function Test-IOCompression {($PSVersionTable.PSVersion.Major -ge 3) -and (Test-NETStack '4.5')}
function directory($path){ $path | ? {-not (test-path $_)} | % {$null = mkdir $_}}
function disposable($o){($o -is [IDisposable]) -and (($o | gm | %{$_.name}) -contains 'Dispose')}
function use($obj, [scriptblock]$sb){try {& $sb} catch [exception]{throw $_} finally {if (disposable $obj) {$obj.Dispose()}} }
set-alias RPP -Value Resolve-ProviderPath

Function Decode-Files($hash) {
  foreach ($key in $hash.keys) {
    $value = $hash[$key]
    $tmp, $tzip, $dst = $Key, $Value["tmpzip"], $Value["dst"]
    $sMd5 = (Get-Item $tmp).BaseName.Replace("b64-", "")
    $decoded = if ($tzip -ne $null) { $tzip } else { $dst }
    Decode-Base64File $tmp $decoded
    rm $tmp -Force
    $dMd5 = Get-MD5Sum $decoded
    $verifies = $sMd5 -like $dMd5
    if ($tzip) {Unzip-File $tzip $dst;rm $tzip -Force}
    New-Object psobject -Property @{ dst = $dst; verifies = $verifies; src_md5 = $sMd5; dst_md5 = $dMd5; tmpfile = $tmp; tmpzip = $tzip }
  }
}

Function Get-MD5Sum($src) {
  if ($src -and (test-path $src)) {
  use ($c = New-Object -TypeName Security.Cryptography.MD5CryptoServiceProvider) {
    use ($in = (Get-Item $src).OpenRead()) {([BitConverter]::ToString($c.ComputeHash($in))).Replace("-", "").ToLower()}}
  }
}

Function Invoke-Input($in) {
  $in = $in | rpp
  $decoded = "$($in).ps1"
  Decode-Base64File $in $decoded
  $expr = gc $decoded | Out-String
  rm $in,$decoded -Force
  iex "$expr"
}

Function Unzip-File($src, $dst) {
  $unpack = $src -replace '\.zip'
  directory $unpack, $dst
  if (Test-IOCompression) {Add-Type -AN System.IO.Compression.FileSystem; [IO.Compression.ZipFile]::ExtractToDirectory($src, $unpack)}
  else {Try {$s = New-Object -ComObject Shell.Application; ($s.NameSpace($unpack)).CopyHere(($s.NameSpace($src)).Items(), 0x610)} Finally {[void][Runtime.Interopservices.Marshal]::ReleaseComObject($s)}}
  dir $unpack | cp -dest "$dst/" -force -recurse
  rm $unpack -recurse -force
}
