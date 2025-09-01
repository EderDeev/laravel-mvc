#!/usr/bin/env bash
set -euo pipefail

# --- XDEBUG ---
echo "==> Verificando Xdebug"
if ! php -m | grep -qi '^xdebug$'; then
  echo "==> Instalando Xdebug via PECL"
  sudo pecl install -f xdebug || true
  # Habilita extensão
  sudo bash -lc "echo 'zend_extension=$(php -i | awk -F\"=> \" \"/^extension_dir/ {print \$2}\")/xdebug.so' > /usr/local/etc/php/conf.d/00-xdebug-loader.ini"
fi

# Escreve/atualiza conf do Xdebug
sudo cp -f .devcontainer/xdebug.ini /usr/local/etc/php/conf.d/99-xdebug.ini

echo "==> PHP -m (trecho):"
php -m | grep -E 'xdebug|mbstring|xml|curl|zip' || true

# --- EXTENSÕES ÚTEIS DO LARAVEL (se imagem não tiver) ---
echo "==> Garantindo extensões comuns do Laravel"
sudo apt-get update
sudo apt-get install -y php8.3-mbstring php8.3-xml php8.3-curl php8.3-zip php8.3-sqlite3 unzip

# --- PREPARO DO LARAVEL ---
# Ajuste este caminho se seu projeto não estiver neste subdiretório:
APP_DIR="/workspaces/laravel-mvc/controle-series"

if [ -d "$APP_DIR" ]; then
  echo "==> Preparando Laravel em: $APP_DIR"
  cd "$APP_DIR"

  if ! command -v composer >/dev/null 2>&1; then
    echo "Composer não encontrado. Instalando..."
    php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    php composer-setup.php --install-dir=/usr/local/bin --filename=composer
    rm composer-setup.php
  fi

  # Instala vendors (caso ainda não exista)
  if [ ! -f "vendor/autoload.php" ]; then
    composer install --no-interaction --prefer-dist
  fi

  # .env + APP_KEY
  if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
      cp .env.example .env
    else
      touch .env
    fi
  fi
  php artisan key:generate || true

  # Permissões e caches
  chmod -R ug+rw storage bootstrap/cache || true
  composer dump-autoload -o
  php artisan config:clear || true
  php artisan cache:clear || true

  echo "==> Laravel OK. Para iniciar:"
  echo "cd $APP_DIR && php artisan serve --host 0.0.0.0 --port 8000"
else
  echo "Aviso: diretório $APP_DIR não encontrado. Ajuste APP_DIR no setup.sh conforme sua estrutura."
fi

echo "==> Setup concluído."
