function bjlname = matfrostjuliacallname(juliaexe)

    bjlname = "matfrostjuliacall_" + mlreportgen.utils.hash(string(version) + juliaversion(juliaexe) + matfrostversion());

end