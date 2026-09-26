# File-Based Resource Seeding

Populate Azure resources with initial data from local files during deployment.

## Reading CSV Files for Table Storage

Use `file()` to read CSV content and populate Azure Table Storage:

```terraform
locals {
  # Read CSV files from a relative path
  products_csv = file("${path.module}/../../../data/products.csv")
  settings_csv = file("${path.module}/../../../data/settings.csv")
}
```

## Bulk File Discovery with `fileset()`

Use `fileset()` to discover multiple files for blob uploads:

```terraform
locals {
  # Discover all files in a directory
  schema_files = {
    for f in fileset("${path.module}/../../../schemas", "**/*.json") :
    f => "${path.module}/../../../schemas/${f}"
  }

  # Discover specific file types
  query_files = {
    for f in fileset("${path.module}/../../../queries", "*.sql") :
    f => "${path.module}/../../../queries/${f}"
  }
}
```

## Uploading Files to Blob Storage

```terraform
resource "azurerm_storage_blob" "schemas" {
  for_each = local.schema_files

  name                   = each.key
  storage_account_name   = azurerm_storage_account.sa.name
  storage_container_name = azurerm_storage_container.schemas.name
  type                   = "Block"
  source                 = each.value
  content_md5            = filemd5(each.value)
}
```

## Content-Based Change Detection

Use `filesha1()` or `filemd5()` to trigger updates only when file content changes:

```terraform
resource "terraform_data" "schema_trigger" {
  input = sha1(join("", [for f in local.schema_files : filesha1(f)]))
}

resource "azurerm_storage_blob" "config" {
  # ... configuration

  lifecycle {
    replace_triggered_by = [terraform_data.schema_trigger]
  }
}
```

## Conditional File Loading

Check file existence before loading:

```terraform
locals {
  config_path   = "${path.module}/config/settings.json"
  config_exists = fileexists(local.config_path)
  config_data   = local.config_exists ? file(local.config_path) : "{}"
  config_sha1   = local.config_exists ? filesha1(local.config_path) : null
}
```

## Folder Structure for Seed Data

Organize seed data files consistently:

```text
inf/
├── data/
│   ├── tables/           # CSV files for Table Storage
│   │   ├── Products.csv
│   │   └── Settings.csv
│   ├── blobs/            # Files for Blob Storage
│   │   ├── schemas/
│   │   └── templates/
│   └── cosmosdb/         # JSON documents for Cosmos DB
│       └── seed-data.json
└── terraform/
    └── resources/
        └── modules/
            └── st/
                └── main.tf   # References ../../../data/
```
