function init_snakeyaml()
persistent is_initiated
if isempty(is_initiated)
    if ~any(endsWith(javaclasspath('-dynamic'),"snakeyaml-1.30.jar"))
        snakeYamlFile = fullfile(fileparts(mfilename('fullpath')), 'snakeyaml', 'snakeyaml-1.30.jar');
        javaaddpath(snakeYamlFile);
    end
end
is_initiated = true;
end