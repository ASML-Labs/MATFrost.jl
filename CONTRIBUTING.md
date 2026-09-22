# Contributing to MATFrost.jl

Thank you for contributing.

This guide focuses on the developer workflow for **MEX binaries** (`matfrostjuliacall.mex*`), because this is the part that is easiest to get wrong when setting up locally.

---

## 1) Use released MEX binaries (recommended)

From repository root, install MATLAB bindings using the artifact defined in `Artifacts.toml`:

```matlab
% MATLAB (run from repo root)
system('julia --project=. -e "using MATFrost; MATFrost.install()"');
```

This will:
- create/update `@matfrostjulia` in the current folder
- copy MATLAB wrapper files from `src/matlab/@matfrostjulia`
- copy released MEX binaries from Julia artifact `matfrost-mex` into `@matfrostjulia/private`

---

## 2) Verify binaries are present

After install, verify these files exist in `@matfrostjulia/private`:
- `matfrostjuliacall.mexw64` (Windows)
- `matfrostjuliacall.mexa64` (Linux, when included in release bundle)

If missing, see Troubleshooting below.

---

## 3) Updating MATFrost to a new released MEX bundle

When a new MEX release is published (for example `v0.6.0`), update artifact metadata so `MATFrost.install()` pulls the new bundle.

### Step A: Download release tarball
Download release asset:
- `matfrost-mex-v<version>.tar.gz`

### Step B: Rebind artifact metadata
Run from repo root:

```powershell
julia --project=. src/matfrostjuliacall/integrate_released_mexbinaries.jl <version> <path-to-tar.gz>
```

Example:

```powershell
julia --project=. src/matfrostjuliacall/integrate_released_mexbinaries.jl 0.6.0 C:\temp\matfrost-mex-v0.6.0.tar.gz
```

This script updates `Artifacts.toml` with:
- `git-tree-sha1`
- download URL (`.../releases/download/v<version>/matfrost-mex-v<version>.tar.gz`)
- `sha256`

### Step C: Reinstall bindings

```matlab
system('julia --project=. -e "using MATFrost; MATFrost.install()"');
```

---

## 4) Build MEX locally (only if needed)

Use local build only when developing C++ MEX changes.

Entry point:
- `src/matfrostjuliacall/matfrostmake.m`

Windows notes:
- Install MinGW-w64 compatible with MATLAB mex.
- Set env var `MW_MINGW64_LOC`.
- `matfrostmake` writes output into `src/matlab/@matfrostjulia/private`.

For most contributors, **prefer released binaries** over local build.

---

## 5) Common pitfalls

### Wrong MATFrost version in bootstrap
If MATLAB starts but server exits immediately with version mismatch, verify:
- `src/matlab/@matfrostjulia/bootstrap.jl` has the correct `MATFROST_MATLAB_VERSION`
- installed copy under `@matfrostjulia/bootstrap.jl` matches

### Stale binaries still loaded
Re-run install from repo root:

```matlab
system('julia --project=. -e "using MATFrost; MATFrost.install()"');
```

This refreshes `@matfrostjulia/private` from current artifact metadata.

### Active project conflict (`Pkg.add("MATFrost")`)
Inside a local checkout, do **not** run `Pkg.add("MATFrost")` in the MATFrost project itself.
Use `using MATFrost; MATFrost.install()` with `--project=.` instead.

---

## 6) Related files

- `Artifacts.toml`
- `src/install.jl`
- `src/matlab/@matfrostjulia/bootstrap.jl`
- `src/matfrostjuliacall/integrate_released_mexbinaries.jl`
- `src/matfrostjuliacall/matfrostmake.m`
- `.github/CONTRIBUTING.md` (CI/test policy)
