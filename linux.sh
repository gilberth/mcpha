#!/bin/bash

# ubuntu-setup.sh

# Colores para salida
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Configurando integración MCP para Claude Desktop en Ubuntu...${NC}"

# Función para comparar versiones
version_greater_equal() {
    printf '%s\n' "$2" "$1" | sort -V -C
}

# Actualizar sistema
sudo apt update -y

# Verificar Node.js
if ! command -v node &> /dev/null; then
    echo -e "${RED}Node.js no está instalado. Instalando Node.js 20...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt install -y nodejs
else
    NODE_VERSION=$(node -v)
    if ! version_greater_equal "${NODE_VERSION//v/}" "20.10.0"; then
        echo -e "${RED}Se requiere Node.js >= 20.10.0. Versión actual: $NODE_VERSION${NC}"
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt install -y nodejs
    fi
fi

# Verificar npm
if ! command -v npm &> /dev/null; then
    echo -e "${RED}npm no está instalado. Instalándolo...${NC}"
    sudo apt install -y npm
fi

# Verificar jq
if ! command -v jq &> /dev/null; then
    echo -e "${RED}jq no está instalado. Instalándolo...${NC}"
    sudo apt install -y jq
fi

# Crear carpeta MCP
MCP_DIR="$HOME/.mcp"
mkdir -p "$MCP_DIR"

# Clonar repositorio MCP
echo -e "${BLUE}Clonando repositorio de Home Assistant MCP...${NC}"
git clone https://github.com/jango-blockchained/homeassistant-mcp.git "$MCP_DIR/homeassistant-mcp"
cd "$MCP_DIR/homeassistant-mcp"

# Instalar dependencias y construir
echo -e "${BLUE}Instalando dependencias y construyendo...${NC}"
npm install
npm run build

# Directorio de configuración de Claude Desktop (en Linux, usar ~/.config)
CLAUDE_CONFIG_DIR="$HOME/.config/claude-desktop"
mkdir -p "$CLAUDE_CONFIG_DIR"

# Solicitar datos
echo -e "${BLUE}Ingrese sus configuraciones:${NC}"
read -p "URL de Home Assistant (ej: http://homeassistant.local:8123): " HASS_HOST
read -p "Token de acceso largo de Home Assistant: " HASS_TOKEN

# Crear archivo .env
cat > "$MCP_DIR/homeassistant-mcp/.env" << EOL
NODE_ENV=production
HASS_HOST=$HASS_HOST
HASS_TOKEN=$HASS_TOKEN
PORT=3000
EOL

# Crear configuración base
CONFIG_JSON='{
  "mcpServers": {
    "homeassistant": {
      "command": "node",
      "args": [
        "'$MCP_DIR'/homeassistant-mcp/dist/index.js"
      ],
      "env": {
        "HASS_TOKEN": "'$HASS_TOKEN'",
        "HASS_HOST": "'$HASS_HOST'",
        "NODE_ENV": "production",
        "PORT": "3000"
      }
    }
  }
}'

# Brave Search
read -p "¿Deseas habilitar la integración con Brave Search? (y/n): " ENABLE_BRAVE_SEARCH

if [[ $ENABLE_BRAVE_SEARCH =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Instalando Brave Search MCP...${NC}"
    npm install -g @modelcontextprotocol/server-brave-search
    read -p "Brave Search API Key: " BRAVE_API_KEY

    CONFIG_JSON=$(echo $CONFIG_JSON | jq '.mcpServers += {
      "brave-search": {
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-brave-search"],
        "env": {
          "BRAVE_API_KEY": "'$BRAVE_API_KEY'"
        }
      }
    }')
fi

# Guardar configuración
echo $CONFIG_JSON | jq '.' > "$CLAUDE_CONFIG_DIR/claude_desktop_config.json"

chmod 600 "$CLAUDE_CONFIG_DIR/claude_desktop_config.json"
chmod 600 "$MCP_DIR/homeassistant-mcp/.env"

echo -e "${GREEN}¡Instalación completada!${NC}"
echo -e "${BLUE}Archivos creados en:${NC}"
echo " - $CLAUDE_CONFIG_DIR/claude_desktop_config.json"
echo " - $MCP_DIR/homeassistant-mcp/.env"

echo -e "${BLUE}Para usar la integración:${NC}"
echo "1. Asegúrate de tener Claude Desktop instalado (https://claude.ai/download)"
echo "2. Reinicia Claude Desktop"
echo "3. La integración con Home Assistant debería estar activa"
if [[ $ENABLE_BRAVE_SEARCH =~ ^[Yy]$ ]]; then
    echo "4. Brave Search MCP también está activo"
fi

echo -e "${RED}Nota: Nunca compartas tus tokens o claves API públicamente${NC}"

# Pruebas
read -p "¿Deseas probar las instalaciones ahora? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Probando conexión con Home Assistant MCP...${NC}"
    node "$MCP_DIR/homeassistant-mcp/dist/index.js" test
    if [[ $ENABLE_BRAVE_SEARCH =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Probando Brave Search MCP...${NC}"
        npx @modelcontextprotocol/server-brave-search test
    fi
fi
