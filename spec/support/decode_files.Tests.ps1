. $PSScriptRoot\..\..\support\decode_files.ps1
. $PSScriptRoot\test_helpers.ps1

describe 'Length of file' {
  it 'is below 2800' {
    (get-item "$PSScriptRoot\..\..\support\decode_files.ps1").length -lt 2800 |
      should be $true
  }
}

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

  context 'when a file exists at the destination, the content is updated' {
    $Content = 'QHsKICAiJGVudjpURU1QXGI2NC1mMWFlNGMyNzgwMWQ0NDMyNjliMjAyZTEyYWYyMDdkYS50eHQiID0gQHsKICAgICJkc3QiID0gIiRlbnY6VEVNUFxraXRjaGVuIgogICAgInRtcHppcCIgPSAiJGVudjpURU1QXHRtcHppcC1mMWFlNGMyNzgwMWQ0NDMyNjliMjAyZTEyYWYyMDdkYS56aXAiCiAgfQogICIkZW52OlRFTVBcYjY0LThjYzM5NDViZTA0NWZhNGY4YjAyZmFmM2I3ZDRjZGJkLnR4dCIgPSBAewogICAgImRzdCIgPSAiJGVudjpURU1QXGtpdGNoZW4iCiAgICAidG1wemlwIiA9ICIkZW52OlRFTVBcdG1wemlwLThjYzM5NDViZTA0NWZhNGY4YjAyZmFmM2I3ZDRjZGJkLnppcCIKICB9Cn0= '
    $EncodedSource = "$env:temp\encoded.txt"
    $DecodedDestination = "$env:temp\decoded.txt"
    '@{}' | out-file $DecodedDestination
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

if ($PSVersionTable.PSVersion.Major -ge 4) {
  describe 'Get-MD5Sum' {
    $Path = (Resolve-path $PSScriptRoot\..\..\support\decode_files.ps1).Path
    it 'Get-MD5Sum matches Get-FileHash -Algorithm MD5' {
      Get-MD5Sum $Path |
        should be (Get-FileHash -Path $Path -Algorithm MD5).Hash
    }
  }
}

describe 'Test-NETStack' {
  context 'When .NET 3.5.1 and expecting .NET 4.5 or newer' {
    mock Get-FrameworkVersion -mockwith {[version]'3.5.1'}
    it 'returns false' {
      Test-NETStack '4.5' | should be $true
    }
  }
  context 'When .NET 4.0 and expecting .NET 4.5 or newer' {
    mock Get-FrameworkVersion -mockwith {[version]'4.0'}
    it 'returns false' {
      Test-NETStack '4.5' | should be $true
    }
  }
  context 'When .NET 4.5 and expecting .NET 4.5 or newer' {
    mock Get-FrameworkVersion -mockwith {[version]'4.5'}

    it 'returns true' {
      Test-NETStack '4.5' | should be $true
    }
  }
  context 'When .NET 4.6 and expecting .NET 4.5 or newer' {
    mock Get-FrameworkVersion -mockwith {[version]'4.6.0'}

    it 'returns true' {
      Test-NETStack '4.5' | should be $true
    }
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

if ($PSVersionTable.PSVersion.Major -ge 3){
  Add-Type -AN System.IO.Compression.FileSystem

  describe 'Unzip-File with IO.Compression' {
    context 'With no existing folders and only files' {
      $TestFolder = assert-directory (join-path $PSScriptRoot 'Temp') -passthru
      $SourceFolder = assert-directory (join-path $TestFolder 'NewStuff') -passthru

      1..5 | New-TestFile -Path {(join-path $SourceFolder "File$_.txt")}

      $TestZipFile = join-path $TestFolder 'AllTheThings.zip'
      if (test-path $TestZipFile) {rm $TestZipFile -force}
      [IO.Compression.ZipFile]::CreateFromDirectory($SourceFolder, $TestZipFile)

      it 'Extracts 5 files to ./Temp/kitchen' {
        $DestinationFolder = (join-path $TestFolder 'kitchen')
        Unzip-File $TestZipFile $DestinationFolder
        (dir -recurse -file $DestinationFolder | measure).count |
          should be 5
      }
    }

    context 'With nested directories' {
      $TestFolder = assert-directory (join-path $PSScriptRoot 'Temp') -passthru
      $SourceFolder = assert-directory (join-path $TestFolder 'NewStuff') -passthru
      $NestedSourceFolder = assert-directory (join-path $SourceFolder 'Nested') -passthru

      1..5 | New-TestFile -Path {(join-path $SourceFolder "File$_.txt")}
      6..10 | New-TestFile -Path {(join-path $NestedSourceFolder "File$_.txt")}

      $TestZipFile = join-path $TestFolder 'AllTheThings.zip'
      if (test-path $TestZipFile) {rm $TestZipFile -force}
      [IO.Compression.ZipFile]::CreateFromDirectory($SourceFolder, $TestZipFile)

      $DestinationFolder = (join-path $TestFolder 'kitchen')
      $NestedDestinationFolder = (join-path $DestinationFolder 'Nested')
      Unzip-File $TestZipFile $DestinationFolder

      it 'Extracts 10 files to ./Temp/kitchen' {
        (dir -recurse -file $DestinationFolder | measure).count |
          should be 10
      }

      it 'Created a nested directory' {
        test-path $NestedDestinationFolder | should be $true
      }

      it 'Extracts 5 files to a nested directory' {
        (dir -recurse -file $NestedDestinationFolder | measure).count |
          should be 5
      }
    }
  }

  describe 'Unzip-File with COM' {
    mock Test-NETStack -mockwith {$false}
    context 'With no existing folders and only files' {
      $TestFolder = assert-directory (join-path $PSScriptRoot 'Temp') -passthru
      $SourceFolder = assert-directory (join-path $TestFolder 'NewStuff') -passthru

      1..5 | New-TestFile -Path {(join-path $SourceFolder "File$_.txt")}

      $TestZipFile = join-path $TestFolder 'AllTheThings.zip'
      if (test-path $TestZipFile) {rm $TestZipFile -force}
      [IO.Compression.ZipFile]::CreateFromDirectory($SourceFolder, $TestZipFile)

      it 'Extracts 5 files to ./Temp/kitchen' {
        $DestinationFolder = (join-path $TestFolder 'kitchen')
        Unzip-File $TestZipFile $DestinationFolder
        (dir -recurse -file $DestinationFolder | measure).count |
          should be 5
      }
    }

    context 'With nested directories' {
      $TestFolder = assert-directory (join-path $PSScriptRoot 'Temp') -passthru
      $SourceFolder = assert-directory (join-path $TestFolder 'NewStuff') -passthru
      $NestedSourceFolder = assert-directory (join-path $SourceFolder 'Nested') -passthru

      1..5 | New-TestFile -Path {(join-path $SourceFolder "File$_.txt")}
      6..10 | New-TestFile -Path {(join-path $NestedSourceFolder "File$_.txt")}

      $TestZipFile = join-path $TestFolder 'AllTheThings.zip'
      if (test-path $TestZipFile) {rm $TestZipFile -force}
      [IO.Compression.ZipFile]::CreateFromDirectory($SourceFolder, $TestZipFile)

      $DestinationFolder = (join-path $TestFolder 'kitchen')
      $NestedDestinationFolder = (join-path $DestinationFolder 'Nested')
      Unzip-File $TestZipFile $DestinationFolder

      it 'Extracts 10 files to ./Temp/kitchen' {
        (dir -recurse -file $DestinationFolder | measure).count |
          should be 10
      }

      it 'Created a nested directory' {
        test-path $NestedDestinationFolder | should be $true
      }

      it 'Extracts 5 files to a nested directory' {
        (dir -recurse -file $NestedDestinationFolder | measure).count |
          should be 5
      }
    }
  }

  remove-item (join-path $PSScriptRoot 'Temp') -force -recurse
}
