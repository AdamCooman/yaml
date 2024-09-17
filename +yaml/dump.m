function result = dump(data, style)
%DUMP Convert data to YAML string
%   STR = YAML.DUMP(DATA) converts DATA to a YAML string STR.
%
%   STR = YAML.DUMP(DATA, STYLE) uses a specific output style.
%   STYLE can be "auto" (default), "block" or "flow".
%
%   The following types are supported for DATA:
%       MATLAB type             | YAML type
%       ------------------------|----------------------
%       1D cell array           | Sequence
%       1D non-scalar array     | Sequence
%       2D/3D cell array        | Nested sequences
%       2D/3D non-scalar array  | Nested sequences
%       struct                  | Mapping
%       scalar single/double    | Floating-point number
%       scalar int8/../int64    | Integer
%       scalar uint8/../uint64  | Integer
%       scalar logical          | Boolean
%       scalar string           | String
%       char vector             | String
%       scalar yaml.Null        | null
%
%   Array conversion can be ambiguous. To ensure consistent conversion
%   behaviour, consider manually converting array data to nested 1D cells
%   before converting it to YAML.
%
%   Example:
%       >> DATA.a = 1
%       >> DATA.b = {"text", false}
%       >> STR = yaml.dump(DATA)
%
%         "a: 1.0
%         b: [text, false]
%         "
%
%   See also YAML.DUMPFILE, YAML.LOAD, YAML.LOADFILE, YAML.ISNULL

arguments
    data
    style {mustBeMember(style, ["flow", "block", "auto"])} = "auto"
end

NULL_PLACEHOLDER = "$%&?"; % Should have 4 characters for correct line breaks.

initSnakeYaml
import org.yaml.snakeyaml.*;

try
    data = convert(data,NULL_PLACEHOLDER);
catch exception
    if string(exception.identifier).startsWith("yaml:dump")
        error(exception.identifier, exception.message);
    end
    exception.rethrow;
end
dumperOptions = DumperOptions();
setFlowStyle(dumperOptions, style);
result = Yaml(dumperOptions).dump(data);
result = string(result).replace(NULL_PLACEHOLDER, "null");

end

function data = convert(data,NULL_PLACEHOLDER)
if isempty(data)
    data = java.util.ArrayList();
    return
end
if ischar(data)
    data = string(data);
end
data = nest(data);
class_name = class(data);
switch class_name
    case {"double" "logical" "single" "int8" "int16" "int32" "int64"}
        % nothing to do
    case "string"
        if any(contains(data, NULL_PLACEHOLDER))
            error("yaml:dump:NullPlaceholderNotAllowed", ...
                "Strings must not contain '%s' since it is used as a placeholder for null values.", NULL_PLACEHOLDER)
        end
    case {"uint8" "uint16" "uint32" "uint64"}
        if isscalar(data)
            data = java.math.BigInteger(dec2hex(data), 16);
        else
            data_copy = data;
            data = javaArray("java.math.BigInteger",size(data));
            data_copy = dec2hex(data_copy);
            for ind = 1 : numel(data_copy)
                data(ind) = java.math.BigInteger(data_copy(ind,:), 16);
            end
        end
    case "cell"
        data_copy = data;
        data = java.util.ArrayList();
        for i = 1:numel(data_copy)
            data.add(convert(data_copy{i},NULL_PLACEHOLDER));
        end
    case "struct"
        data_copy = data;
        if isscalar(data)
            data = java.util.LinkedHashMap();
            for key = string(fieldnames(data_copy))'
                value = convert(data_copy.(key),NULL_PLACEHOLDER);
                data.put(key, value);
            end
        else
            data = cell(size(data_copy));
            keys = string(fieldnames(data_copy))';
            for i = 1 : numel(data_copy)
                temp = java.util.LinkedHashMap();
                for key = keys
                    temp.put(key,convert(data_copy(i).(key),NULL_PLACEHOLDER));
                end
                data{i} = temp;
            end
        end
    case "datetime"
        data.Format = "uuuu-MM-dd'T'HH:mm:ss.SSS";
        data = string(data);
    case "yaml.Null"
        data = java.lang.String(NULL_PLACEHOLDER);
    otherwise
        error("yaml:dump:TypeNotSupported", ...
            "Data type '%s' is not supported.", class(data))
end
end

function data = nest(data)
if isvector(data)
    return
end
data_copy = data;
siz = size(data);
siz_1 = siz(1);
nDimensions = numel(siz);
data = cell(1, siz_1);
if nDimensions == 2
    for i = 1:siz_1
        data{i} = data_copy(i, :);
    end
elseif nDimensions == 3
    for i = 1:siz_1
        data{i} = squeeze(data_copy(i, :, :));
    end
else
    error("yaml:dump:HigherDimensionsNotSupported", ...
        "Arrays with more than three dimensions are not supported."+ ...
        " Use nested cells instead.")
end
end

function initSnakeYaml
snakeYamlFile = fullfile(fileparts(mfilename('fullpath')), 'snakeyaml', 'snakeyaml-1.30.jar');
if ~ismember(snakeYamlFile, javaclasspath('-dynamic'))
    javaaddpath(snakeYamlFile);
end
end

function setFlowStyle(options, style)
import org.yaml.snakeyaml.*;
if style == "auto"
    return
end
classes = options.getClass.getClasses;
classNames = arrayfun(@(c) string(c.getName), classes);
styleClassIndex = find(classNames.endsWith("$FlowStyle"), 1);
if isempty(styleClassIndex)
    error("yaml:dump:FlowStyleSelectionFailed", "Unable to select flow style '%s'.", style);
end
styleFields = classes(styleClassIndex).getDeclaredFields();
styleIndex = find(arrayfun(@(f) string(f.getName).lower == style, styleFields));
if isempty(styleIndex)
    error("yaml:dump:FlowStyleSelectionFailed", "Unable to select flow style '%s'.", style);
end
options.setDefaultFlowStyle(styleFields(styleIndex).get([]));
end


