# Windows Native File & Content Search using Windows Search Index (OLE DB)
param(
    [Parameter(Mandatory=$true)]
    [string]$Query,
    [string]$PathScope = ""
)

$connection = New-Object -ComObject ADODB.Connection
$recordset = New-Object -ComObject ADODB.Recordset
$connection.Open("Provider=Search.CollatorDSO;Extended Properties='Application=Windows';")

$sql = "SELECT System.ItemPathDisplay, System.ItemNameDisplay, System.Size FROM SYSTEMINDEX WHERE CONTAINS('$Query') OR System.ItemNameDisplay LIKE '%$Query%'"
if ($PathScope -ne "") {
    $resolvedScope = (Resolve-Path $PathScope).Path
    $sql += " AND SCOPE='$resolvedScope'"
}

try {
    $recordset.Open($sql, $connection)
    Write-Output "=== WINDOWS SEARCH RESULTS FOR '$Query' ==="
    while (-not $recordset.EOF) {
        $path = $recordset.Fields.Item("System.ItemPathDisplay").Value
        $name = $recordset.Fields.Item("System.ItemNameDisplay").Value
        Write-Output "- $name ($path)"
        $recordset.MoveNext()
    }
} catch {
    Write-Error "Error querying Windows Search Index: $_"
} finally {
    if ($recordset.State -eq 1) { $recordset.Close() }
    if ($connection.State -eq 1) { $connection.Close() }
}
