function assert-directory {
  param (
    [parameter(valuefrompipelinebypropertyname=$true)]
    [string]
    $path,
    [switch]
    $Passthru
  )
  process {
    if (test-path $path) {
      remove-item $path -force -recurse
    }
    $null = mkdir $path
    if ($Passthru) {$Path}
  }
}

function New-TestFile {
  param (
    [parameter(valuefrompipelinebypropertyname=$true)]
    [string]
    $path,
    [string]
    $Content = 'Some Text'
  )
  process {
    $Content | out-file $path
  }
}