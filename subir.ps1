# Sube una tarea al portfolio: crea la carpeta, copia los archivos, hace commit y push.
# Uso: doble clic en subir.bat, o arrastra los archivos sobre subir.bat.
param(
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Archivos,
    [string]$Unidad,
    [string]$Titulo,
    [string]$Fecha,
    [string]$Descripcion,
    [switch]$SinSubir
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$tareas = Join-Path $PSScriptRoot 'tareas'
New-Item -ItemType Directory -Force $tareas | Out-Null

function Slug([string]$text) { ($text -replace '[^\p{L}\p{N}]+', '-').Trim('-') }

function Ask([string]$prompt, [string]$default = '') {
    $suffix = if ($default) { " [$default]" } else { '' }
    $answer = Read-Host "$prompt$suffix"
    if ([string]::IsNullOrWhiteSpace($answer)) { $default } else { $answer.Trim() }
}

Write-Host ''
Write-Host '=== Subir tarea al portfolio ===' -ForegroundColor Cyan

# 1. Archivos
$archivos = @($Archivos | Where-Object { $_ })
while ($archivos.Count -eq 0) {
    $entrada = Ask 'Arrastra aqui los archivos o la carpeta (o escribe la ruta) y pulsa Enter'
    $archivos = @($entrada -split '"\s*"|"' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    if ($archivos.Count -eq 0) { $archivos = @($entrada) }
    $archivos = @($archivos | Where-Object { $_ -and (Test-Path -LiteralPath $_) })
    if ($archivos.Count -eq 0) { Write-Host 'No encuentro esos archivos. Prueba otra vez.' -ForegroundColor Yellow }
}

# 2. Unidad
$unidades = @(Get-ChildItem $tareas -Directory | Where-Object { $_.Name -notlike '.*' } | Sort-Object Name)
if (-not $Unidad) {
    Write-Host ''
    Write-Host 'Unidad / tema:'
    for ($i = 0; $i -lt $unidades.Count; $i++) { Write-Host ("  {0}) {1}" -f ($i + 1), $unidades[$i].Name) }
    Write-Host '  N) Crear una unidad nueva'
    $elige = Ask 'Elige una opcion' $(if ($unidades.Count) { '1' } else { 'N' })
    if ($elige -match '^\d+$' -and [int]$elige -ge 1 -and [int]$elige -le $unidades.Count) {
        $Unidad = $unidades[[int]$elige - 1].Name
    } else {
        $etiqueta = Ask 'Etiqueta de la unidad (ej. UT2)'
        $nombreU = Ask 'Nombre de la unidad (ej. Servidores web)'
        $Unidad = Slug ("$etiqueta $nombreU")
    }
}
$dirUnidad = Join-Path $tareas $Unidad
New-Item -ItemType Directory -Force $dirUnidad | Out-Null

# 3. Datos de la tarea
if (-not $Titulo) { $Titulo = Ask 'Titulo de la tarea (ej. Virtual hosts en Apache)' }
if (-not $Titulo) { throw 'Hace falta un titulo.' }
if (-not $Fecha) { $Fecha = Ask 'Fecha de la tarea (AAAA-MM-DD)' (Get-Date -Format 'yyyy-MM-dd') }
if ($Fecha -notmatch '^\d{4}-\d{2}-\d{2}$') { throw "La fecha debe ser AAAA-MM-DD, no '$Fecha'." }
if (-not $PSBoundParameters.ContainsKey('Descripcion')) { $Descripcion = Ask 'Descripcion breve (opcional, Enter para saltar)' }

$carpeta = Join-Path $dirUnidad ("$Fecha-" + (Slug $Titulo))
if (Test-Path $carpeta) { throw "Ya existe la tarea: $carpeta" }
New-Item -ItemType Directory $carpeta | Out-Null

# 4. Copiar archivos y guardar datos
foreach ($a in $archivos) { Copy-Item -LiteralPath $a -Destination $carpeta -Recurse }
$info = [ordered]@{ titulo = $Titulo; fecha = $Fecha }
if ($Descripcion) { $info.descripcion = $Descripcion }
[IO.File]::WriteAllText((Join-Path $carpeta 'info.json'), ($info | ConvertTo-Json), (New-Object Text.UTF8Encoding $false))

Write-Host ''
Write-Host "Tarea creada en: $($carpeta.Replace($PSScriptRoot + '\', ''))" -ForegroundColor Green

# 5. Publicar
if ($SinSubir) { Write-Host 'Modo prueba: no se ha subido nada a GitHub.'; exit 0 }
git add -A
git commit -q -m "Anade tarea: $Titulo"
git push -q origin main
Write-Host ''
Write-Host 'Subida. La web se actualiza en 1 o 2 minutos:' -ForegroundColor Green
Write-Host 'https://vklf-official.github.io/portfolio-iaw/'
