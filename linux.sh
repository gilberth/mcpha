#!/bin/bash

# ubuntu-setup.sh

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Configurando integración MCP para Claude Desktop en Ubuntu...${NC}"

# Función para comparar versiones
version_greater_equal() {
    printf '%s\n' "$2" "$1" | sort -V -C
}

# Verifica e instala dependencias básicas
sudo apt update
sudo apt install -y curl git jq

# Instalar Node.js 20 si no existe o es versión antigua
if ! command -v node &> /dev/null; then
    echo -e "${RED}Node.js no está instalado. Instalando Node.js 20...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt install -y nodejs
else
    NODE_VERSION=$(node -v)
    if ! version_greater_equal "${NODE_VERSION//v/}" "20.10.0"; then
        echo -e "${RED}La versión actual de Node.js es muy antigua: $NODE_VERSION${NC}"
        echo -e "${BLUE}Reinstalando Node.js 20...${NC}"
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt install -y nodejs
    fi
fi

# Verifica npm
if ! command -v npm &> /dev/null; then
    echo -e "${RED}npm no está instalado correctamente. Abortando.${NC}"
    exit 1
fi

# Directorio MCP
MCP_DIR="$HOME/.mcp"
mkdir -p "$MCP_DIR"

# Clonar el repositorio
echo -e "${BLUE}Clonando repositorio de Home Assistant MCP...${NC}"
git clone https://github.com/jango-blockchained/homeassistant-mcp.git "$MCP_DIR/homeassistant-mcp"
cd "$MCP_DIR/homeassistant-mcp"

# Instalar dependencias
echo -e "${BLUE}Instalando dependencias y construyendo...${NC}"
npm install
npm run build

# Directorio de configuración para Claude Desktop
CLAUDE_CONFIG_DIR="$HOME/.config/claude"
mkdir -p "$CLAUDE_CONFIG_DIR"

# Datos de Home Assistant
echo -e "${BLUE}Ingrese sus configuraciones:${NC}"
read -p "URL de Home Assistant (ej. http://homeassistant.local:8123): " HASS_HOST
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

# Brave Search (opcional)
read -p "¿Deseas habilitar Brave Search MCP? (s/n): " ENABLE_BRAVE_SEARCH

if [[ $ENABLE_BRAVE_SEARCH =~ ^[Ss]$ ]]; then
    echo -e "${BLUE}Instalando Brave Search MCP...${NC}"
    npm install -g @modelcontextprotocol/server-brave-search
    
    read -p "API Key de Brave Search: " BRAVE_API_KEY

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

# Guardar configuración final
echo $CONFIG_JSON | jq '.' > "$CLAUDE_CONFIG_DIR/claude_desktop_config.json"

# Permisos
chmod 600 "$CLAUDE_CONFIG_DIR/claude_desktop_config.json"
chmod 600 "$MCP_DIR/homeassistant-mcp/.env"

echo -e "${GREEN}¡Instalación completa!${NC}"
echo -e "${BLUE}Archivos de configuración:${NC}"
echo " - $CLAUDE_CONFIG_DIR/claude_desktop_config.json"
echo " - $MCP_DIR/homeassistant-mcp/.env"

echo -e "${BLUE}Pasos finales:${NC}"
echo "1. Asegúrate de tener Claude Desktop instalado desde https://claude.ai/download"
echo "2. Reinicia Claude Desktop"
echo "3. La integración con Home Assistant MCP ya está lista"
[[ $ENABLE_BRAVE_SEARCH =~ ^[Ss]$ ]] && echo "4. También está lista la integración con Brave Search MCP"

echo -e "${RED}Nota: Mantén tus tokens y claves seguros${NC}"

# Test opcional
read -p "¿Deseas probar las integraciones? (s/n): " TEST_OPTION
if [[ $TEST_OPTION =~ ^[Ss]$ ]]; then
    echo -e "${BLUE}Probando Home Assistant MCP...${NC}"
    node "$MCP_DIR/homeassistant-mcp/dist/index.js" test
    if [[ $ENABLE_BRAVE_SEARCH =~ ^[Ss]$ ]]; then
        echo -e "${BLUE}Probando Brave Search MCP...${NC}"
        npx @modelcontextprotocol/server-brave-search test
    fi
fi
