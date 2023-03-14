#!/usr/bin/pwsh

using namespace System.IO

param (
    [string]
    $InFile,
    [string]
    $OutFile
)

function ArrayContentEqual([byte[]]$a, [byte[]]$b) {
    return $null -eq (Compare-Object $a $b -SyncWindow 0)
}

function FindNext([int]$pos, [byte[]]$needle, [byte[]]$haystack) {
    while ($pos -lt $haystack.Length) {
        if (ArrayContentEqual $needle $haystack[$pos..($pos + ($needle.Length - 1))]) {
            break
        }
        $pos++
    }
    return $pos
}

function GetDocType([byte[]]$data) {
    [byte[]]$docTypeSignature = [byte[]]@(0x42, 0x82)
    [byte[]]$docTypeVersionSignature = [byte[]]@(0x42, 0x87)
    [int]$docTypeStart = FindNext 0 $docTypeSignature $data
    [int]$docTypeEnd = FindNext $docTypeStart $docTypeVersionSignature $data
    return $data[($docTypeStart + $docTypeSignature.Length)..($docTypeEnd - 1)]
}

[byte[]]$webmMagicNumber = [byte[]]@(0x1A, 0x45, 0xDF, 0xA3)
[byte[]]$webmDocType = [byte[]]@(0x77, 0x65, 0x62, 0x6D)  # webm

[byte[]]$inBytes = [File]::ReadAllBytes($inFile)

[byte[]]$inMagicNumber = $inBytes[0..($webmMagicNumber.Length - 1)]
[byte[]]$inDocType = GetDocType $inBytes | Select-Object -Skip 1

if (-not ((ArrayContentEqual $webmMagicNumber $inMagicNumber) -and (ArrayContentEqual $webmDocType $inDocType))) {
    Write-Error "File is not webm"
    exit 1
}

[byte[]]$bytes_x2AD7B1 = [byte[]]@(0x2A, 0xD7, 0xB1)
[byte[]]$bytes_x4489 = [byte[]]@(0x44, 0x89)

# Find 0x2ad7b1
$filePos = FindNext 0 $bytes_x2AD7B1 $inBytes
$filePos += $bytes_x2AD7B1.Length

# Find 0x4489
$filePos = FindNext $filePos $bytes_x4489 $inBytes
$filePos += $bytes_x4489.Length

# Set duration
# The magic duration value is the next four bytes, but the increasing
# thing only appears to work if the second byte is zero.
$inBytes[$filePos + 1] = 0

# Write-Host "Writing file"
[File]::WriteAllBytes($OutFile, $inBytes)
