function bjlname = matfrostjuliacallname(bindir)

    bjlname = "matfrostjuliacall_" + mlreportgen.utils.hash(string(version) + juliaversion(bindir) + matfrostversion());

end