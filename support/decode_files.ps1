Function Cleanup($o) { if (($o) -and ($o.GetType().GetMethod("Dispose") -ne $null)) { $o.Dispose() } }
Function Decode-Base64File($src, $dst) {set-content -Encoding Byte -Path $dst -Value ([Convert]::FromBase64String([IO.File]::ReadAllLines($src)))}
Function Copy-Stream($src, $dst) { $b = New-Object Byte[] 4096; while (($i = $src.Read($b, 0, $b.Length)) -ne 0) { $dst.Write($b, 0, $i) } }
Function Resolve-ProviderPath{ $input | % {if ($_){(Resolve-Path $_).ProviderPath} else{$null}} }
Function Release-COM($o) { if ($o -ne $null) { [void][Runtime.Interopservices.Marshal]::ReleaseComObject($o) } }
Function Test-NETStack($Version, $r = 'HKLM:\Software\Microsoft\NET Framework Setup\NDP\v4') { [bool]("$r\Full", "$r\Client" | ? {(gp $_).Version -like "$($Version)*"}) }
Function Test-IOCompression {($PSVersionTable.PSVersion.Major -ge 3) -and (Test-NETStack '4.5')}
set-alias RPP -Value Resolve-ProviderPath

Function Decode-Files($hash) {
  foreach ($key in $hash.keys) {
    $value = $hash[$key]
    $tmp, $tzip, $dst = $Key, $Value["tmpzip"], $Value["dst"]
    $sMd5 = (Get-Item $tmp).BaseName.Replace("b64-", "")
    $decoded = if ($tzip -ne $null) { $tzip } else { $dst }
    Decode-Base64File $tmp $decoded
    Remove-Item $tmp -Force
    $dMd5 = Get-MD5Sum $decoded
    $verifies = $sMd5 -like $dMd5
    if ($tzip) {Unzip-File $tzip $dst;Remove-Item $tzip -Force}
    New-Object psobject -Property @{ dst = $dst; verifies = $verifies; src_md5 = $sMd5; dst_md5 = $dMd5; tmpfile = $tmp; tmpzip = $tzip }
  }
}

Function Get-MD5Sum($src) {
  Try {
    $c = New-Object -TypeName Security.Cryptography.MD5CryptoServiceProvider
    $bytes = $c.ComputeHash(($in = (Get-Item $src).OpenRead()))
    ([BitConverter]::ToString($bytes)).Replace("-", "").ToLower()
  } catch [exception]{throw $_} finally { Cleanup $c; Cleanup $in }
}

Function Invoke-Input($in) {
  $in = $in | rpp
  Decode-Base64File $in ($decoded = "$($in).ps1")
  $expr = Get-Content $decoded | Out-String
  Remove-Item $in,$decoded -Force
  Invoke-Expression "$expr"
}

Function Unzip-File($src, $dst) {
  if (Test-IOCompression) {
    $unpack = $src -replace '\.zip'
    Add-Type -AN System.IO.Compression.FileSystem; [IO.Compression.ZipFile]::ExtractToDirectory($src, $unpack)
    if (-not (test-path $dst)) {$null = mkdir $dst }
    dir $unpack | cp -dest "$dst/" -force -recurse
    rm $unpack -recurse -force
  }
  else {
    Try {
      $shell = New-Object -ComObject Shell.Application;
      $zip = $shell.NameSpace($src)
      $destination_dir = $shell.NameSpace($dst)
      foreach($item in $zip.Items()) {$destination_dir.CopyHere($item, 0x610)}
    }
    Finally { Release-Com $shell; Release-Com $zip; Release-COM $destination_dir }
  }
}

Decode-Files (Invoke-Input $hash_file) | ConvertTo-Csv -NoTypeInformation
