# CAPIF Services Scripts

This repository contains two Bash scripts to **generate CAPIF services code** from OpenAPI definitions and to **compare two versions** of the generated services.

---

## 1. `capif_build.sh`

This script wraps `openapi-generator` to build Python Flask code from the CAPIF service YAML definitions.  
It allows generating all services or just one specific service.

### Requirements
- `bash` (>= 4.0 recommended)
- [`openapi-generator`](https://openapi-generator.tech/) installed and available in `PATH`

### Usage
```bash
./capif_build.sh --route <5g_repo_path> --output <output_path> [--service <yaml_file>]
```

### Options
- `--route` : Path to the 5G repo containing the CAPIF YAML files.
- `--output`: Path to the folder where the generated code will be stored.
- `--service` *(optional)*: Name of a single YAML file to build (must match one from the CAPIF services list).  
  If omitted, **all services** will be built.
- `-h, --help`: Show help message.

### Examples
Generate all CAPIF services:
```bash
./capif_build.sh --route /path/to/5g_repo --output ./old-version
```

Generate only one service:
```bash
./capif_build.sh --route /path/to/5g_repo --output ./new-version \
  --service TS29222_CAPIF_Events_API.yaml
```

---

## 2. `make_diffs.sh`

This script compares two folders of generated CAPIF services (e.g., `old-version` vs `new-version`).  
It produces:
- A `.diff` file per service (unified diff with `diff -ruN`)
- A `.diffstat` file per service (summary of changes per file, using `diffstat` or `git --no-index --stat`)
- A `summary.txt` file listing the results for all services

### Requirements
- `sh` or `bash`  
- `diff` (standard in Unix-like systems)  
- Optional:  
  - `diffstat` → recommended for per-file summaries  
  - `git` → used as a fallback for summaries if `diffstat` is not available  

### Usage
```bash
./make_diffs.sh --old <old_dir> --new <new_dir> [--out <diffs_dir>] [--service <name>]
```

### Options
- `--old`     : Path to the folder with the old version.
- `--new`     : Path to the folder with the new version.
- `--out`     : (Optional) Output folder for diffs. Default: `./diffs`.
- `--service` : (Optional) Compare only one specific service (folder or file at top level).
- `-h, --help`: Show help message.

### Examples
Compare all services:
```bash
./make_diffs.sh --old ./old-version --new ./new-version
```

Compare only one service:
```bash
./make_diffs.sh --old ./old-version --new ./new-version --service TS29222_CAPIF_Events_API
```

Save diffs into a custom folder:
```bash
./make_diffs.sh --old ./old-version --new ./new-version --out ./diffs_run2
```

### Output
After running, the output folder will contain:
```
diffs/
├── TS29222_CAPIF_Events_API.diff
├── TS29222_CAPIF_Events_API.diffstat
├── TS29222_CAPIF_Auditing_API.diff
├── TS29222_CAPIF_Auditing_API.diffstat
...
└── summary.txt
```

---

## Typical Workflow
1. Generate services for the **old version**:
   ```bash
   ./capif_build.sh --route /path/to/5g_repo --output ./old-version
   ```
2. Generate services for the **new version**:
   ```bash
   ./capif_build.sh --route /path/to/5g_repo --output ./new-version
   ```
3. Compare them:
   ```bash
   ./make_diffs.sh --old ./old-version --new ./new-version --out ./diffs
   ```
4. Inspect the `.diff` and `.diffstat` files or open them in a diff viewer like `meld`, `kdiff3`, or `colordiff`.

---

## Tips
- For easier inspection, install GUI diff tools like [Meld](https://meldmerge.org/).  
- For API-level changes (OpenAPI/Swagger), you may also use tools like [`oasdiff`](https://github.com/Tufin/oasdiff).
