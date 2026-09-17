$offset = 0
$limit = 20000
$more = $true

while ($more) {
    $url = "https://lgoretuvgdfoppntgtbv.supabase.co/functions/v1/sync-gtfs?category=rapid-bus-penang&file=stop_times&offset=$offset&limit=$limit"
    try {
        $response = Invoke-RestMethod -Uri $url -Method Get
        Write-Host ($response | ConvertTo-Json -Compress)
        $more = $response.hasMore
        $offset += $limit
    } catch {
        Write-Host "ERROR at offset $offset : $($_.ErrorDetails.Message)"
        $more = $false
    }
}