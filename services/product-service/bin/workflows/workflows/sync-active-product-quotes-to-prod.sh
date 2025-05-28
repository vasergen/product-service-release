#!/bin/bash
set -eo pipefail

# Source functions
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "${SCRIPT_DIR}/functions.sh"

# required variables
MONGODB_CONNECTION_STRING_PRODUCTION=$1
MONGODB_PASSWORD_PRODUCTION=$2
MONGODB_CONNECTION_STRING_STAGE=$3
MONGODB_PASSWORD_STAGE=$4
PROD_PASSIVE_DB=$5
STAGE_DB="product-service"
MONGODB_USER_NAME="product-service"
COLLECTION_NAME="quoteDefinitions"

# Debug: Print environment variables (mask passwords for security)
printf "[DEBUG] Environment variables:\n"
printf "[DEBUG] MONGODB_CONNECTION_STRING_PRODUCTION: %s\n" "${MONGODB_CONNECTION_STRING_PRODUCTION:-"<NOT_SET>"}"
printf "[DEBUG] MONGODB_PASSWORD_PRODUCTION: %s\n" "${MONGODB_PASSWORD_PRODUCTION:+<SET>}"
printf "[DEBUG] MONGODB_CONNECTION_STRING_STAGE: %s\n" "${MONGODB_CONNECTION_STRING_STAGE:-"<NOT_SET>"}"
printf "[DEBUG] MONGODB_PASSWORD_STAGE: %s\n" "${MONGODB_PASSWORD_STAGE:+<SET>}"
printf "[DEBUG] PROD_PASSIVE_DB: %s\n" "${PROD_PASSIVE_DB:-"<NOT_SET>"}"
printf "[DEBUG] STAGE_DB: %s\n" "${STAGE_DB:-"<NOT_SET>"}"
printf "[DEBUG] MONGODB_USER_NAME: %s\n" "${MONGODB_USER_NAME:-"<NOT_SET>"}"
printf "[DEBUG] COLLECTION_NAME: %s\n" "${COLLECTION_NAME:-"<NOT_SET>"}"
printf "[DEBUG] ----------------------------------------\n"

verify_required_env_vars \
  "MONGODB_CONNECTION_STRING_PRODUCTION" \
  "MONGODB_PASSWORD_PRODUCTION" \
  "MONGODB_CONNECTION_STRING_STAGE" \
  "MONGODB_PASSWORD_STAGE" \
  "COLLECTION_NAME" \
  "PROD_PASSIVE_DB" \
  "STAGE_DB" \
  "MONGODB_USER_NAME"



printf "[INFO] Syncing active product quotes to production\n"

# Create temporary directory for the dump
TEMP_DIR=$(mktemp -d)
printf "[INFO] Using temporary directory: %s\n" "$TEMP_DIR"

# TODO: !!!! improve code below!!!!
# Fix connection strings by ensuring database name and proper format for query parameters
MONGODB_CONNECTION_STRING_STAGE=$(echo "$MONGODB_CONNECTION_STRING_STAGE" | sed 's|mongodb+srv://\([^?]*\).*|mongodb+srv://\1/'"$STAGE_DB"'|')
MONGODB_CONNECTION_STRING_PRODUCTION=$(echo "$MONGODB_CONNECTION_STRING_PRODUCTION" | sed 's|mongodb+srv://\([^?]*\).*|mongodb+srv://\1/'"$PROD_PASSIVE_DB"'|')

# Add auth to connection strings without auth parameters
MONGODB_CONNECTION_STRING_STAGE_WITH_AUTH="${MONGODB_CONNECTION_STRING_STAGE/mongodb+srv:\/\//mongodb+srv:\/\/$MONGODB_USER_NAME:$MONGODB_PASSWORD_STAGE@}"
MONGODB_CONNECTION_STRING_PRODUCTION_WITH_AUTH="${MONGODB_CONNECTION_STRING_PRODUCTION/mongodb+srv:\/\//mongodb+srv:\/\/$MONGODB_USER_NAME:$MONGODB_PASSWORD_PRODUCTION@}"

# Export only ACTIVE records from stage database
printf "[INFO] Exporting ACTIVE product quotes from stage database %s\n" "$STAGE_DB"
mongodump \
  --uri="$MONGODB_CONNECTION_STRING_STAGE_WITH_AUTH" \
  --collection="$COLLECTION_NAME" \
  --query='{"status":"ACTIVE"}' \
  --out="$TEMP_DIR"

# Clean up production collection before import
printf "[INFO] Cleaning up existing data in production collection %s.%s\n" "$PROD_PASSIVE_DB" "$COLLECTION_NAME"
mongosh "$MONGODB_CONNECTION_STRING_PRODUCTION_WITH_AUTH" --eval "
  db.getSiblingDB('$PROD_PASSIVE_DB').getCollection('$COLLECTION_NAME').deleteMany({});
  print('[SUCCESS] Cleared collection: $PROD_PASSIVE_DB.$COLLECTION_NAME');
"

# Import the filtered data to production
printf "[INFO] Importing ACTIVE product quotes to production database %s\n" "$PROD_PASSIVE_DB"
mongorestore \
  --uri="$MONGODB_CONNECTION_STRING_PRODUCTION_WITH_AUTH" \
  --nsInclude="$PROD_PASSIVE_DB.$COLLECTION_NAME" \
  --nsFrom="$STAGE_DB.$COLLECTION_NAME" \
  --nsTo="$PROD_PASSIVE_DB.$COLLECTION_NAME" \
  "$TEMP_DIR/$STAGE_DB/$COLLECTION_NAME.bson"

# Clean up
printf "[INFO] Cleaning up temporary files...\n"
rm -rf "$TEMP_DIR" 

printf "[SUCCESS] Done! Successfully synced ACTIVE product quotes to production.\n"
