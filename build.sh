#!/bin/bash

# This script compiles the client and server TypeScript apps.

# Exit on any error
set -eou pipefail

# Helper function to execute a command in a specific directory
run_command() {
  local command=$1
  local cwd=$2
  echo "Running '$command' in $cwd"
  
  (cd "$cwd" && eval "$command")
  
  if [ $? -eq 0 ]; then
    echo "✅ Completed '$command'"
  else
    echo "❌ Failed to execute '$command'"
    exit 1
  fi
}

# Determine root directory
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_DIR="$ROOT_DIR/client"
SERVER_DIR="$ROOT_DIR/server"
COMMON_DIR="$ROOT_DIR/common"

echo "📦 Starting build process..."

# Build common package
echo "🔨 Building common package..."
run_command "npm install" "$COMMON_DIR"

# Build client
echo "🔨 Building client..."
run_command "npm install" "$CLIENT_DIR"
run_command "npm run build" "$CLIENT_DIR"

# Build server
echo "🔨 Building server..."
run_command "npm install" "$SERVER_DIR"
run_command "npm run build" "$SERVER_DIR"

echo "✨ Build completed successfully!"