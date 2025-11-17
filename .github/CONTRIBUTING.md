# Contributing to MATFrost.jl

Thank you for your interest in contributing to MATFrost.jl! This guide explains our development workflow and testing procedures.

## Testing Workflow

Our CI/CD pipeline uses a two-tier testing strategy to balance thorough validation with efficient resource usage:

### 1. Single Configuration Test (Always Runs)

On every pull request, we automatically run tests on a single configuration:
- **OS**: Windows (latest)
- **MATLAB Version**: R2021b
- **Julia Versions**: All supported versions (1.7 through 1.12)
- **MEX Compilation**: Enabled

This provides quick feedback on whether your changes break core functionality.

> [!TIP]
> Mark your PR as a **draft** while developing to test against only Julia 1.12, providing much faster feedback. Convert to a regular PR when ready for full validation.

### 2. Full Test Matrix (Integration PRs & Scheduled)

The full test matrix runs across multiple MATLAB versions and is triggered by:

- **Weekly Schedule**: Runs automatically every Sunday at 3 AM UTC
- **Integration Label**: Add the `integrate` label to your PR to trigger the full test suite

The full matrix includes:
- **MATLAB Versions**: R2021b, R2022b, R2023b, R2024b, R2025b
- **OS**: Windows (latest)
- **Julia Versions**: All supported versions (1.7-1.12)
- **MEX Compilation**: Enabled

### When to Use the Integration Label

Add the `integrate` label to your PR when:

- You're preparing a PR for integration/merge to main
- Your changes affect MATLAB version compatibility
- You've made significant changes that require comprehensive validation
- You need to verify behavior across all supported MATLAB versions

> [!IMPORTANT]
> PRs must pass the full test matrix before being integrated. The CI summary will indicate when the integrate label should be added.

## Caching Strategy

> [!NOTE]
> To optimize CI performance, we cache installations based on OS and MATLAB version combinations.

We cache the following:

- **GCC installations** (Linux): Cached based on OS + MATLAB version
- **MSYS2 installations** (Windows): Cached based on OS + MATLAB version
- **Julia installations**: Cached based on OS + MATLAB version + Julia versions

This significantly reduces setup time for subsequent workflow runs.

## Development Workflow

1. **Create a branch** from `main` for your changes
2. **Make your changes** and commit them with clear, descriptive messages
3. **Open a pull request** (optionally as a draft for faster iteration with Julia 1.12 only)
4. **Address any test failures** from the single configuration test
5. **Convert from draft** (if applicable) to test against all Julia versions
6. **When ready for integration**, add the `integrate` label to trigger the full test matrix
7. **Ensure all tests pass** before merging

## Questions or Issues?

If you have questions about the contribution process or encounter issues with the CI pipeline, please open an issue on GitHub.
