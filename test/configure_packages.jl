import Pkg

Pkg.develop(path=ARGS[1])
Pkg.resolve()
Pkg.instantiate()
