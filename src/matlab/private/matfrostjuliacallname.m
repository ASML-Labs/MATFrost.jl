function bjlname = matfrostjuliacallname()

    bjlname = "matfrostjuliacall_" + mlreportgen.utils.hash(string(version) + matfrostversion());

end