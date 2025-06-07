#!/bin/bash

# linux.sh - Setup script for Claude Desktop + Home Assistant MCP on Ubuntu

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

# Verificar e instalar curl
if ! command -v curl &> /dev/null; then
    echo -e "${RED}curl no está instalado. Instalando...${NC}"
    sudo apt update && sudo apt install -y curl
fi

# Verificar e instalar git
if ! command -v git &> /dev/null; then
    echo -e "${RED}git no está instalado. Instalando...${NC}"
    sudo apt install -y git
fi

# Verificar e instalar Node.js
if ! command -v node &> /dev/null; then
    echo -e "${RED}Node.js no está instalado. Instalando Node.js 20 LTS...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt install -y nodejs
else
    NODE_VERSION=$(node -v)
    if ! version_greater_equal "${NODE_VERSION//v/}" "20.10.0"; then
        echo -e "${RED}Node.js debe ser >= 20.10.0. Instalando versión correcta...${NC}"
        curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
        sudo apt install -y nodejs
    fi
fi

# Verificar npm
if ! command -v npm &> /dev/null; then
    echo -e "${RED}npm no está instalado. Instalando...${NC}"
    sudo apt install -y npm
fi

# Verificar jq
if ! command -v jq &> /dev/null; then
    echo -e "${RED}jq no está instalado. Instalando...${NC}"
    sudo apt install -y jq
fi

# Verificar bun
if ! command -v bun &> /dev/null; then
    echo -e "${RED}Bun no está instalado. Instalando...${NC}"
    curl -fsSL https://bun.sh/install | bash

    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
fi

# Crear directorio MCP
MCP_DIR="$HOME/.mcp"
mkdir -p "$MCP_DIR"

# Clonar repo MCP
echo -e "${BLUE}Clonando repositorio de Home Assistant MCP...${NC}"
git clone https://github.com/jango-blockchained/homeassistant-mcp.git "$MCP_DIR/homeassistant-mcp"
cd "$MCP_DIR/homeassistant-mcp" || { echo -e "${RED}Error al ingresar al directorio MCP${NC}"; exit 1; }

# Instalar dependencias y construir
echo -e "${BLUE}Instalando dependencias y construyendo...${NC}"
npm install
npm run build

# Directorio de configuración (Linux)
CLAUDE_CONFIG_DIR="$HOME/.config/Claude"
mkdir -p "$CLAUDE_CONFIG_DIR"

# Solicitar datos
echo -e "${BLUE}Ingrese sus configuraciones:${NC}"
read -p "Home Assistant URL (e.g., http://homeassistant.local:8123): " HASS_HOST
read -p "Token de acceso largo de Home Assistant: " HASS_TOKEN

# .env para MCP
cat > "$MCP_DIR/homeassistant-mcp/.env" << EOL
NODE_ENV=production
HASS_HOST=$HASS_HOST
HASS_TOKEN=$HASS_TOKEN
PORT=3000
EOL

# Configuración JSON base
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
read -p "¿Desea habilitar Brave Search MCP? (y/n): " ENABLE_BRAVE_SEARCH
if [[ $ENABLE_BRAVE_SEARCH =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Instalando Brave Search MCP...${NC}"
    npm install -g @modelcontextprotocol/server-brave-search

    read -p "Clave API de Brave Search: " BRAVE_API_KEY

    CONFIG_JSON=$(echo "$CONFIG_JSON" | jq '.mcpServers += {
      "brave-search": {
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-brave-search"],
        "env": {
          "BRAVE_API_KEY": "'$BRAVE_API_KEY'"
        }
      }
    }')
fi

# Guardar archivo de configuración
echo "$CONFIG_JSON" | jq '.' > "$CLAUDE_CONFIG_DIR/claude_desktop_config.json"
chmod 600 "$CLAUDE_CONFIG_DIR/claude_desktop_config.json"
chmod 600 "$MCP_DIR/homeassistant-mcp/.env"

# Mensaje final
echo -e "${GREEN}¡Instalación completada!${NC}"
echo -e "${BLUE}Archivos de configuración creados en:${NC}"
echo " - $CLAUDE_CONFIG_DIR/claude_desktop_config.json"
echo " - $MCP_DIR/homeassistant-mcp/.env"

echo -e "${BLUE}Pasos siguientes:${NC}"
echo "1. Asegúrese de tener Claude Desktop instalado: https://claude.ai/download"
echo "2. Reinicie Claude Desktop"
echo "3. Integración MCP con Home Assistant activada"
[[ $ENABLE_BRAVE_SEARCH =~ ^[Yy]$ ]] && echo "4. Integración Brave Search también activa"

# Pruebas
read -p "¿Desea probar la conexión ahora? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Probando conexión con Home Assistant MCP...${NC}"
    node "$MCP_DIR/homeassistant-mcp/dist/index.js" test
    if [[ $ENABLE_BRAVE_SEARCH =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Probando Brave Search MCP...${NC}"
        npx @modelcontextprotocol/server-brave-search test
    fi
fi
