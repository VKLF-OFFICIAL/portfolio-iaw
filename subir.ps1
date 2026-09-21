# Sube una tarea (un PDF) al portfolio.
# Pregunta: tema nuevo o existente -> nombre/selección del tema -> nombre de la tarea -> descripción (opcional) -> PDF.
# Uso: doble clic en subir.bat, o arrastra el PDF sobre subir.bat.
[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Archivo,
    [ValidateSet('nuevo', 'existente')][string]$Modo,
    [string]$Tema,
    [string]$Titulo,
    [string]$Descripcion,
    [string]$Fecha = (Get-Date -Format 'yyyy-MM-dd'),
    [switch]$SinSubir
)

$ErrorActionPreference = 'Stop'

function Slug([string]$text) { ($text -replace '[^\p{L}\p{N}]+', '-').Trim('-') }

function Ask([string]$prompt) {
    $answer = Read-Host $prompt
    if ($null -eq $answer) { throw 'Entrada cancelada.' }
    $answer.Trim()
}

function AskRequired([string]$prompt) {
    do { $answer = Ask $prompt } while (-not $answer)
    $answer
}

# Ejecuta git y falla con su mensaje si devuelve error (los avisos de git no cuentan como error).
function Invoke-Git {
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = & git @args 2>&1 | ForEach-Object { "$_" } | Where-Object { $_ -and $_ -ne 'System.Management.Automation.RemoteException' }
    $code = $LASTEXITCODE
    $ErrorActionPreference = $old
    if ($code -ne 0) { throw "git $($args -join ' ') falló:`n$(($out | Out-String).Trim())" }
}

function TemaLegible([string]$folder) { $folder -replace '-', ' ' }

try {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'No encuentro git. Instálalo desde https://git-scm.com' }

    # El script debe trabajar dentro del repositorio del portfolio. Si se ejecuta desde otra
    # carpeta (por ejemplo Descargas), busca el portfolio en la carpeta de usuario.
    $repo = $PSScriptRoot
    if (-not (Test-Path (Join-Path $repo '.git'))) {
        $candidato = Join-Path $env:USERPROFILE 'portfolio-iaw'
        if (Test-Path (Join-Path $candidato '.git')) {
            $repo = $candidato
            Write-Host "Usando el portfolio de: $repo" -ForegroundColor DarkGray
        } else {
            throw "Este script tiene que estar en la carpeta del portfolio (la que contiene .git), y ahora está en: $PSScriptRoot"
        }
    }
    Set-Location $repo
    $tareas = Join-Path $repo 'tareas'
    New-Item -ItemType Directory -Force $tareas | Out-Null

    Write-Host ''
    Write-Host '=== Subir tarea al portfolio ===' -ForegroundColor Cyan
    Write-Host ''

    # 1. ¿Tema nuevo o existente?
    $temas = @(Get-ChildItem $tareas -Directory | Where-Object { $_.Name -notlike '.*' } | Sort-Object Name)
    if (-not $Modo) {
        if ($temas.Count -eq 0) {
            Write-Host 'Todavía no hay ningún tema: vamos a crear el primero.'
            $Modo = 'nuevo'
        } else {
            do { $r = (Ask '¿El tema es nuevo o ya existe? (N = nuevo, E = existente)').ToUpper() } while ($r -notin 'N', 'E')
            $Modo = if ($r -eq 'N') { 'nuevo' } else { 'existente' }
        }
    }

    # 2. Nombre del tema nuevo, o selección de uno existente
    if ($Modo -eq 'nuevo') {
        if (-not $Tema) { $Tema = AskRequired 'Nombre del tema nuevo' }
        # Si el nombre ya empieza por UD1, UT2, UD-3... se quita: el número se pone solo
        $Tema = $Tema -replace '^\s*U[TD]\s*-?\s*\d+\s*[-:.\s]*', ''
        if (-not (Slug $Tema)) { throw 'El nombre del tema debe tener letras o números.' }
        $numeros = @($temas | ForEach-Object { if ($_.Name -match '^U[TD](\d+)') { [int]$Matches[1] } })
        $siguiente = if ($numeros.Count) { ($numeros | Measure-Object -Maximum).Maximum + 1 } else { 1 }
        $carpetaTema = Slug "UD$siguiente $Tema"
    } else {
        if ($temas.Count -eq 0) { throw 'No hay temas existentes. Usa un tema nuevo.' }
        if (-not $Tema) {
            Write-Host ''
            Write-Host 'Temas existentes:'
            for ($i = 0; $i -lt $temas.Count; $i++) { Write-Host ('  {0}) {1}' -f ($i + 1), (TemaLegible $temas[$i].Name)) }
            do {
                $n = AskRequired 'Elige el número del tema'
                $ok = $n -match '^\d+$' -and [int]$n -ge 1 -and [int]$n -le $temas.Count
                if (-not $ok) { Write-Host "Escribe un número entre 1 y $($temas.Count)." -ForegroundColor Yellow }
            } until ($ok)
            $carpetaTema = $temas[[int]$n - 1].Name
        } else {
            $carpetaTema = $Tema
            if (-not (Test-Path (Join-Path $tareas $carpetaTema))) { throw "No existe el tema: $Tema" }
        }
    }

    # 3. Nombre de la tarea
    Write-Host ''
    if (-not $Titulo) { $Titulo = AskRequired 'Nombre de la tarea' }
    if (-not (Slug $Titulo)) { throw 'El nombre de la tarea debe tener letras o números.' }
    if ($Fecha -notmatch '^\d{4}-\d{2}-\d{2}$') { throw "La fecha debe ser AAAA-MM-DD, no '$Fecha'." }

    # 4. Descripción (opcional) y PDF
    if (-not $PSBoundParameters.ContainsKey('Descripcion')) { $Descripcion = Ask 'Descripción breve de la tarea (opcional, Enter para omitir)' }
    $pdfs = @($Archivo | Where-Object { $_ -and $_ -match '\.pdf$' -and (Test-Path -LiteralPath $_ -PathType Leaf) })
    while ($pdfs.Count -eq 0) {
        $ruta = (Ask 'Arrastra aquí el PDF (o escribe su ruta) y pulsa Enter').Trim('"', "'", ' ')
        if ($ruta -match '\.pdf$' -and (Test-Path -LiteralPath $ruta -PathType Leaf)) { $pdfs = @($ruta) }
        else { Write-Host 'No encuentro un archivo .pdf en esa ruta. Prueba otra vez.' -ForegroundColor Yellow }
    }

    # 5. Crear la tarea
    $carpeta = Join-Path (Join-Path $tareas $carpetaTema) "$Fecha-$(Slug $Titulo)"
    if (Test-Path $carpeta) { throw "Ya existe una tarea con ese nombre y fecha: $carpeta" }
    New-Item -ItemType Directory -Force $carpeta | Out-Null
    foreach ($p in $pdfs) { Copy-Item -LiteralPath $p -Destination $carpeta }
    $info = [ordered]@{ titulo = $Titulo; fecha = $Fecha }
    if ($Descripcion) { $info.descripcion = $Descripcion }
    [IO.File]::WriteAllText((Join-Path $carpeta 'info.json'), ($info | ConvertTo-Json), (New-Object Text.UTF8Encoding $false))

    Write-Host ''
    Write-Host "Tarea creada en: $($carpeta.Replace($repo + '\', ''))" -ForegroundColor Green

    # 6. Publicar
    if ($SinSubir) { Write-Host 'Modo prueba: no se ha subido nada a GitHub.'; exit 0 }
    Write-Host 'Subiendo a GitHub...'
    try {
        Invoke-Git add -- tareas
        Invoke-Git commit -q -m "Añade tarea: $Titulo"
        Invoke-Git pull --rebase --autostash -q origin main
        Invoke-Git push -q origin main
    } catch {
        # Si la integración quedó a medias, dejar el repositorio como estaba
        $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        & git rebase --abort *> $null
        $ErrorActionPreference = $old
        Write-Host ''
        Write-Host 'La tarea está guardada en tu PC pero NO se ha subido a GitHub.' -ForegroundColor Yellow
        Write-Host 'Cuando tengas conexión, abre una terminal en esta carpeta y ejecuta: git pull --rebase origin main' -ForegroundColor Yellow
        Write-Host 'y después: git push origin main   (no vuelvas a usar subir.bat para esta tarea)' -ForegroundColor Yellow
        throw
    }
    Write-Host ''
    Write-Host 'Subida. La web se actualiza en 1 o 2 minutos:' -ForegroundColor Green
    Write-Host 'https://vklf-official.github.io/portfolio-iaw/'
} catch {
    Write-Host ''
    Write-Host "No se pudo completar: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
