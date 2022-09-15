$lines = Get-Content -Path .env
$env:TOKEN1 = $lines[0].split("=")[1]
$env:TOKEN2 = $lines[1].split("=")[1]

py src/main.py
