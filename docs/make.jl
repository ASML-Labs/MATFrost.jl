using Documenter
using MATFrost

makedocs(
    modules = [MATFrost],
    checkdocs = :none,
    sitename = "MATFrost.jl",
    authors = "ASML Labs",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", "false") == "true",
    ),
    pages = [
        "Home" => "index.md",
        "Getting Started" => "getting-started.md",
        "Calling Julia" => "calling-julia.md",
        "Data Conversion" => "data-conversion.md",
        "Julia Object Handles" => "handles.md",
        "System Images" => "system-images.md",
        "API Reference" => "api.md",
    ],
)

deploydocs(
    repo = "github.com/ASML-Labs/MATFrost.jl.git",
    devbranch = "main",
)