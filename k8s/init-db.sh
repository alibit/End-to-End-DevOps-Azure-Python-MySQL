#!/bin/bash

# Log in to Azure CLI (you might want to replace this with service principal login for CI/CD)
az login --service-principal -u "$AZURE_CLIENT_ID" -p "$AZURE_CLIENT_SECRET" --tenant "$AZURE_TENANT_ID"

# Define SQL query to create table

SQL_QUERY="
CREATE TABLE tasks (
  id SERIAL PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  is_complete BOOLEAN DEFAULT false
);
"
# Execute the SQL query
az sql db query \
  --resource-group "$RESOURCE_GROUP" \
  --server "$DB_HOST" \
  --database "$DB_DATABASE" \
  --user "$DB_USER" \
  --password "$DB_PASSWORD" \
  --query "$SQL_QUERY"

# Check if the command was successful
if [ $? -eq 0 ]; then
    echo "Table created successfully"
else
    echo "Error occurred in table creation"
    exit 1
fi

