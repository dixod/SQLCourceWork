param(
    [string]$SnapshotDate = (Get-Date -Format 'yyyy-MM-dd'),
    [string]$Server = 'localhost',
    [int]$Port = 5432,
    [string]$User = 'postgres',
    [string]$OltpDatabase = 'coursework_oltp',
    [string]$OlapDatabase = 'coursework_olap',
    [string]$PsqlPath = 'C:\Program Files\PostgreSQL\18\bin\psql.exe'
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path $PSScriptRoot -Parent

if (-not (Test-Path -LiteralPath $PsqlPath)) {
    $PsqlPath = (Get-Command psql -ErrorAction Stop).Source
}
if ($OltpDatabase -eq $OlapDatabase) {
    throw 'OLTP and OLAP must use different databases'
}
$ParsedDate = [datetime]::ParseExact($SnapshotDate, 'yyyy-MM-dd', $null)
$PreviousPassword = $env:PGPASSWORD

if (-not $env:PGPASSWORD) {
    $PasswordFile = Join-Path $ProjectRoot '.local\postgres-password.txt'
    if (Test-Path -LiteralPath $PasswordFile) {
        $env:PGPASSWORD = [IO.File]::ReadAllText($PasswordFile).Trim()
    } else {
        $SecurePassword = Read-Host 'PostgreSQL password' -AsSecureString
        $env:PGPASSWORD = [System.Net.NetworkCredential]::new('', $SecurePassword).Password
    }
}

function Invoke-SqlFile {
    param([string]$Database, [string]$File, [string[]]$Variables = @())
    Write-Host $File
    & $PsqlPath -X -h $Server -p $Port -U $User -d $Database -v ON_ERROR_STOP=1 @Variables -f (Join-Path $ProjectRoot $File)
    if ($LASTEXITCODE -ne 0) {
        throw "Failed: $File"
    }
}

Push-Location $ProjectRoot
try {
    Invoke-SqlFile 'postgres' 'sql\0_create_databases.sql' @(
        '-v', "oltp_db=$OltpDatabase", '-v', "olap_db=$OlapDatabase"
    )
    Invoke-SqlFile $OltpDatabase 'sql\1_create_oltp.sql'
    Invoke-SqlFile $OltpDatabase 'sql\2_load_csv_to_oltp.sql'
    Invoke-SqlFile $OlapDatabase 'sql\3_create_olap.sql'
    Invoke-SqlFile $OlapDatabase 'sql\3a_connect_oltp.sql' @(
        '-v', "source_host=$Server", '-v', "source_port=$Port",
        '-v', "source_user=$User", '-v', "oltp_db=$OltpDatabase"
    )
    Invoke-SqlFile $OlapDatabase 'sql\4_etl_oltp_to_olap.sql' @(
        '-v', "snapshot_date=$SnapshotDate"
    )
    Invoke-SqlFile $OlapDatabase 'sql\5_power_bi_views.sql'
    Write-Host "Loaded snapshot $SnapshotDate into $OlapDatabase"
} finally {
    Pop-Location
    $env:PGPASSWORD = $PreviousPassword
}
