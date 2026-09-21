<?php
// Muestra la versión de PHP y el servidor que atiende la petición
header('Content-Type: text/plain; charset=utf-8');
echo "PHP " . PHP_VERSION . "\n";
echo "Servidor: " . $_SERVER['SERVER_SOFTWARE'] . "\n";
