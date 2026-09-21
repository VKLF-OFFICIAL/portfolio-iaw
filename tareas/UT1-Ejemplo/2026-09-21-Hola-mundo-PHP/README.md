Ejemplo de cómo se ve una tarea publicada: un virtual host de Apache que sirve una página PHP. Borra la carpeta `tareas/UT1-Ejemplo` cuando subas la primera tarea real.

## Objetivo

Servir un sitio en `ejemplo.local` desde Apache con PHP, sin listado de directorios.

## Pasos

1. Instalar Apache y PHP con `instalar.sh`.
2. Copiar `index.php` a `/var/www/ejemplo`.
3. Activar el virtual host de `vhost.conf` y recargar Apache.
4. Añadir `ejemplo.local` al fichero `hosts` y comprobar con `curl`.

## Resultado

La respuesta esperada aparece en la captura `resultado.svg`:

```
PHP 8.3.6
Servidor: Apache/2.4.58 (Ubuntu)
```

Esta descripción sale del `README.md` de la carpeta y admite Markdown.
