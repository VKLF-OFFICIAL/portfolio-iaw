# Portfolio · Implantación de Aplicaciones Web

Web estática publicada con GitHub Pages. URL: https://vklf-official.github.io/portfolio-iaw/

## Añadir una tarea

1. Crea una carpeta dentro de la unidad: `tareas/UT1-Servidores-Web/2026-10-03-Apache-virtualhost/`
   (el prefijo `AAAA-MM-DD-` es la fecha; si falta, se usa la fecha del primer commit).
2. Copia dentro tus archivos: scripts, capturas, PDF, vídeos, configuraciones…
3. Opcional: añade un `README.md` con la explicación (admite Markdown; su primer párrafo sale como resumen)
   o un `info.json`:
   ```json
   { "titulo": "Virtual hosts en Apache", "fecha": "2026-10-03", "descripcion": "Dos sitios en el mismo servidor." }
   ```
4. Sube los cambios:
   ```
   git add .
   git commit -m "Añade tarea Apache virtualhost"
   git push
   ```

Un archivo suelto dentro de una unidad (sin carpeta) cuenta como una tarea.
Para crear una unidad nueva, crea una carpeta en `tareas/` con nombre `UT2-Nombre-de-la-unidad`.

## Ver la web en tu PC

```
python build.py
python -m http.server 8000
```
Abre http://localhost:8000. `build.py` regenera `data/tareas.json`; en GitHub lo hace el Action solo.

## Ajustes

Nombre, centro y texto de presentación: `site.json`.

Límites: GitHub no admite archivos de más de 100 MB. Para vídeos largos, sube el enlace en el README.
