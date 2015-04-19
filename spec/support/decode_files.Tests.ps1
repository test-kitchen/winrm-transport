. $PSScriptRoot\..\..\support\decode_files.ps1

describe 'Decode-Base64File' {
  context 'when given the hash map' {
    $Content = 'QHsKICAiJGVudjpURU1QXGI2NC1mMWFlNGMyNzgwMWQ0NDMyNjliMjAyZTEyYWYyMDdkYS50eHQiID0gQHsKICAgICJkc3QiID0gIiRlbnY6VEVNUFxraXRjaGVuIgogICAgInRtcHppcCIgPSAiJGVudjpURU1QXHRtcHppcC1mMWFlNGMyNzgwMWQ0NDMyNjliMjAyZTEyYWYyMDdkYS56aXAiCiAgfQogICIkZW52OlRFTVBcYjY0LThjYzM5NDViZTA0NWZhNGY4YjAyZmFmM2I3ZDRjZGJkLnR4dCIgPSBAewogICAgImRzdCIgPSAiJGVudjpURU1QXGtpdGNoZW4iCiAgICAidG1wemlwIiA9ICIkZW52OlRFTVBcdG1wemlwLThjYzM5NDViZTA0NWZhNGY4YjAyZmFmM2I3ZDRjZGJkLnppcCIKICB9Cn0= '
    $EncodedSource = "$env:temp\encoded.txt"
    $DecodedDestination = "$env:temp\decoded.txt"
    Set-Content $EncodedSource -value $content
    Decode-Base64File $EncodedSource $DecodedDestination
    $DecodedContent  = gc $DecodedDestination | out-string
    $hash = invoke-expression $DecodedContent

    it 'has two keys' {
      $hash.keys.count | should be 2
    }
    it 'has a key that matches $env:TEMP\b64-f1ae4c27801d443269b202e12af207da.txt' {
      $hash.keys |
        where {$_ -like "$env:TEMP\b64-f1ae4c27801d443269b202e12af207da.txt"} |
        should not be $null
    }
    it 'has keys with values including "dst" and "tmpzip"' {
       $hash.keys |
        where { -not ( ($hash[$_].keys -contains 'dst') -and
          ($hash[$_].keys -contains 'tmpzip') ) } |
        should be $null
    }
    rm $EncodedSource, $DecodedDestination
  }
}

describe 'Test-IOCompression' {
  context 'when PowerShell version is 3 or greater' {
    it 'and .NET 4.5 client is present - use IO.Compression' {
      mock Test-NETStack -mockwith {$true}
      Test-IOCompression | should be $true
    }
    it 'and .NET 4.5 client is absent - use COM' {
      mock Test-NETStack -mockwith {$false}
      Test-IOCompression | should be $false
    }
  }
}

