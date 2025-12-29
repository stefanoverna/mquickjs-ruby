# Custom Patches for mquickjs

This directory contains patches that are automatically applied after updating from the upstream mquickjs repository.

## How It Works

When you run `rake update_mquickjs`, the task will:
1. Clone the latest mquickjs from upstream
2. Copy the updated files to `ext/mquickjs/`
3. Automatically apply all `.patch` files from this directory in alphabetical order

## Existing Patches

- **001-add-fetch-function.patch**: Adds the custom `fetch` function to the global JavaScript object

## Adding New Patches

If you need to add custom modifications to the upstream mquickjs code:

1. Make your changes to the files in `ext/mquickjs/`
2. Create a patch file:
   ```bash
   git diff ext/mquickjs/FILENAME.c > ext/mquickjs/patches/00X-description.patch
   ```
3. Name your patch with a number prefix (e.g., `002-`, `003-`) to control application order
4. The patch will be automatically applied on the next `rake update_mquickjs`

## Patch Format

Patches should be in unified diff format (git diff output) and use `-p1` patch level.

Example:
```patch
--- a/ext/mquickjs/file.c
+++ b/ext/mquickjs/file.c
@@ -10,6 +10,7 @@ some context
 existing line
 existing line
+new line added
 existing line
```
