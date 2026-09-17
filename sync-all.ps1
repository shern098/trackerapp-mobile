$categories = @("rapid-bus-kl", "rapid-bus-penang", "rapid-bus-kuantan", "rapid-bus-mrtfeeder", "rapid-rail-kl")
$files = @("agency", "routes", "stops", "trips", "shapes", "stop_times")

foreach ($category in $categories) {
    foreach ($file in $files) {
        $url = "https://lgoretuvgdfoppntgtbv.supabase.co/functions/v1/sync-gtfs?category=$category&file=$file"
        Write-Host "Syncing $category/$file..."
        $response = curl.exe -s $url
        Write-Host $response
        Write-Host "---"
    }
}