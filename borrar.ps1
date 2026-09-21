# Borra tareas (o un tema entero) del portfolio y publica el cambio.
# Pregunta: qué borrar (tareas o un tema entero) -> la tarea (o el tema) -> confirmación.
# Uso: doble clic en borrar.bat
[CmdletBinding(PositionalBinding = $false)]
param(
    [ValidateSet('tarea', 'tema')][string]$Que,
    [string]$Tema,          # carpeta del tema (para automatizar o probar)
    [string[]]$Tarea,       # carpetas de las tareas (para automatizar o probar)
    [switch]$Confirmar,     # no pedir confirmación (para automatizar o probar)
    [switch]$SinSubir
)

$ErrorActionPreference = 'Stop'

function Ask([string]$prompt) {
    $answer = Read-Host $prompt
    if ($null -eq $answer) { throw 'Entrada cancelada.' }
    $answer.Trim()
}

# Ejecuta git y falla con su mensaje si devuelve error (los avisos de git no cuentan como error).
function Invoke-Git {
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = & git @args 2>&1 | ForEach-Object { "$_" } | Where-Object { $_ -and $_ -ne 'System.Management.Automation.RemoteException' }
    $code = $LASTEXITCODE
    $ErrorActionPreference = $old
    if ($code -ne 0) { throw "git $($args -join ' ') falló:`n$(($out | Out-String).Trim())" }
    $out
}

function TemaLegible([string]$folder) { $folder -replace '-', ' ' }

# Datos de una tarea (carpeta o archivo suelto) para mostrarla en la lista
function InfoDe($item) {
    $titulo = $item.Name; $fecha = ''; $subida = ''
    if ($item.PSIsContainer) {
        $f = Join-Path $item.FullName 'info.json'
        if (Test-Path -LiteralPath $f) {
            try {
                $j = Get-Content -LiteralPath $f -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($j.titulo) { $titulo = $j.titulo }
                if ($j.fecha) { $fecha = [string]$j.fecha }
                if ($j.subida) { $subida = [string]$j.subida }
            } catch { }
        }
    }
    if (-not $fecha -and $item.Name -match '^(\d{4}-\d{2}-\d{2})') { $fecha = $Matches[1] }
    $dirTema = Split-Path $item.FullName -Parent
    [pscustomobject]@{ Item = $item; Titulo = $titulo; Fecha = $fecha; Subida = $subida; TemaDir = $dirTema; TemaNombre = (Split-Path $dirTema -Leaf) }
}

# Pide uno o varios números de una lista. Devuelve los índices (base 0).
function ChooseIndexes([string]$prompt, [int]$count, [bool]$multi) {
    while ($true) {
        $raw = Ask $prompt
        if ($multi -and $raw -match '^(todas|todos)$') { return 0..($count - 1) }
        $nums = @($raw -split '[,\s]+' | Where-Object { $_ })
        $ok = $nums.Count -gt 0 -and ($multi -or $nums.Count -eq 1) -and -not ($nums | Where-Object { $_ -notmatch '^\d+$' -or [int]$_ -lt 1 -or [int]$_ -gt $count })
        if ($ok) { return @($nums | ForEach-Object { [int]$_ - 1 } | Select-Object -Unique) }
        $ayuda = if ($multi) { "Escribe uno o varios números separados por comas (ej. 1,3), o 'todas'." } else { "Escribe un número entre 1 y $count." }
        Write-Host $ayuda -ForegroundColor Yellow
    }
}

$IGNORAR = @('.gitkeep', 'info.json', 'unidad.json', 'readme.md', 'thumbs.db', '.ds_store')

try {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'No encuentro git. Instálalo desde https://git-scm.com' }

    # El script debe trabajar dentro del repositorio del portfolio. Si se ejecuta desde otra
    # carpeta, busca el portfolio en la carpeta de usuario.
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

    Write-Host ''
    Write-Host '=== Borrar del portfolio ===' -ForegroundColor Cyan
    Write-Host ''

    $temas = @(if (Test-Path $tareas) { Get-ChildItem $tareas -Directory | Where-Object { $_.Name -notlike '.*' } | Sort-Object Name })
    if ($temas.Count -eq 0) { Write-Host 'No hay ningún tema publicado: no hay nada que borrar.'; exit 0 }

    # 1. ¿Qué borrar?
    if (-not $Que) {
        do { $r = (Ask '¿Qué quieres borrar? (T = tareas, M = un tema entero con todas sus tareas)').ToUpper() } while ($r -notin 'T', 'M')
        $Que = if ($r -eq 'T') { 'tarea' } else { 'tema' }
    }

    # 2. Qué se borra exactamente
    if ($Que -eq 'tema') {
        # Borrar un tema entero: se elige el tema
        if ($Tema) {
            $dirTema = Join-Path $tareas $Tema
            if (-not (Test-Path -LiteralPath $dirTema)) { throw "No existe el tema: $Tema" }
            $temaNombre = $Tema
        } else {
            Write-Host ''
            Write-Host 'Temas:'
            for ($i = 0; $i -lt $temas.Count; $i++) {
                $n = @(Get-ChildItem $temas[$i].FullName | Where-Object { $IGNORAR -notcontains $_.Name.ToLower() }).Count
                Write-Host ('  {0}) {1}  ({2} {3})' -f ($i + 1), (TemaLegible $temas[$i].Name), $n, $(if ($n -eq 1) { 'tarea' } else { 'tareas' }))
            }
            $idx = (ChooseIndexes 'Elige el número del tema' $temas.Count $false)[0]
            $temaNombre = $temas[$idx].Name
            $dirTema = $temas[$idx].FullName
        }
        $numTareas = @(Get-ChildItem -LiteralPath $dirTema | Where-Object { $IGNORAR -notcontains $_.Name.ToLower() -and $_.Name -notlike '.*' }).Count
        $objetivos = @($dirTema)
        $carpetasTema = @($dirTema)
        $resumen = "el tema completo «$(TemaLegible $temaNombre)» y sus $numTareas tarea(s)"
        $mensaje = "Borra tema: $(TemaLegible $temaNombre)"
    } else {
        # Borrar tareas: se elige directamente la tarea (agrupadas por tema, con numeración continua)
        $fuentes = $temas
        if ($Tema) {
            if (-not (Test-Path -LiteralPath (Join-Path $tareas $Tema))) { throw "No existe el tema: $Tema" }
            $fuentes = @(Get-Item -LiteralPath (Join-Path $tareas $Tema))
        }
        $todas = @()
        foreach ($t in $fuentes) {
            $todas += @(Get-ChildItem -LiteralPath $t.FullName | Where-Object { $IGNORAR -notcontains $_.Name.ToLower() -and $_.Name -notlike '.*' } | ForEach-Object { InfoDe $_ } |
                Sort-Object @{ Expression = 'Fecha'; Descending = $true }, @{ Expression = 'Subida'; Descending = $true })
        }
        if ($todas.Count -eq 0) { Write-Host 'No hay ninguna tarea publicada.'; exit 0 }
        if ($Tarea) {
            $elegidas = @($todas | Where-Object { $Tarea -contains $_.Item.Name })
            if ($elegidas.Count -ne $Tarea.Count) { throw 'Alguna de las tareas indicadas no existe.' }
        } else {
            Write-Host ''
            Write-Host 'Tareas publicadas:'
            $ultimo = $null
            for ($i = 0; $i -lt $todas.Count; $i++) {
                if ($todas[$i].TemaDir -ne $ultimo) {
                    Write-Host ''
                    Write-Host (TemaLegible $todas[$i].TemaNombre) -ForegroundColor Cyan
                    $ultimo = $todas[$i].TemaDir
                }
                Write-Host ('  {0}) {1}   {2}' -f ($i + 1), $todas[$i].Fecha, $todas[$i].Titulo)
            }
            Write-Host ''
            $sel = ChooseIndexes 'Elige la tarea (o varias separadas por comas, o "todas")' $todas.Count $true
            $elegidas = @($sel | ForEach-Object { $todas[$_] })
        }
        $objetivos = @($elegidas | ForEach-Object { $_.Item.FullName })
        $carpetasTema = @($elegidas | ForEach-Object { $_.TemaDir })
        $resumen = if ($elegidas.Count -eq 1) { "la tarea «$($elegidas[0].Titulo)»" } else { "$($elegidas.Count) tareas: " + (($elegidas | ForEach-Object { "«$($_.Titulo)»" }) -join ', ') }
        $mensaje = if ($elegidas.Count -eq 1) { "Borra tarea: $($elegidas[0].Titulo)" } else { "Borra $($elegidas.Count) tareas" }
    }

    # 3. Confirmación
    Write-Host ''
    Write-Host "Se va a borrar $resumen." -ForegroundColor Yellow
    Write-Host 'Los archivos dejarán de estar en la web y en tu carpeta (seguirán en el historial de git).' -ForegroundColor Yellow
    if (-not $Confirmar) {
        if ((Ask 'Escribe SI para confirmar, o pulsa Enter para cancelar').ToUpper() -ne 'SI') { Write-Host 'Cancelado. No se ha borrado nada.'; exit 0 }
    }

    # 4. Borrar
    foreach ($o in $objetivos) { Remove-Item -LiteralPath $o -Recurse -Force }
    # Si un tema se queda sin tareas, se elimina también la carpeta vacía
    foreach ($d in ($carpetasTema | Select-Object -Unique)) {
        if ((Test-Path -LiteralPath $d) -and -not (Get-ChildItem -LiteralPath $d | Where-Object { $IGNORAR -notcontains $_.Name.ToLower() -and $_.Name -notlike '.*' })) {
            Remove-Item -LiteralPath $d -Recurse -Force
            Write-Host "El tema «$(TemaLegible (Split-Path $d -Leaf))» se ha quedado sin tareas y también se ha eliminado."
        }
    }
    Write-Host 'Borrado en tu carpeta.' -ForegroundColor Green

    # 5. Publicar
    if ($SinSubir) { Write-Host 'Modo prueba: no se ha subido nada a GitHub.'; exit 0 }
    $cambios = Invoke-Git status --porcelain -- tareas
    if (-not $cambios) { Write-Host 'Eso no estaba publicado en GitHub, así que no hay nada que subir.'; exit 0 }
    Write-Host 'Subiendo a GitHub...'
    try {
        Invoke-Git add -A -- tareas | Out-Null
        Invoke-Git commit -q -m $mensaje | Out-Null
        Invoke-Git pull --rebase --autostash -q origin main | Out-Null
        Invoke-Git push -q origin main | Out-Null
    } catch {
        # Si la integración quedó a medias, dejar el repositorio como estaba
        $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        & git rebase --abort *> $null
        $ErrorActionPreference = $old
        Write-Host ''
        Write-Host 'El borrado está hecho en tu PC pero NO se ha subido a GitHub.' -ForegroundColor Yellow
        Write-Host 'Cuando tengas conexión, abre una terminal en esta carpeta y ejecuta: git pull --rebase origin main' -ForegroundColor Yellow
        Write-Host 'y después: git push origin main   (no repitas el borrado)' -ForegroundColor Yellow
        throw
    }
    Write-Host ''
    Write-Host 'Hecho. La web se actualiza en 1 o 2 minutos:' -ForegroundColor Green
    Write-Host 'https://vklf-official.github.io/portfolio-iaw/'
} catch {
    Write-Host ''
    Write-Host "No se pudo completar: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
