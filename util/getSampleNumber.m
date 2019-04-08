function sampNum = getSampleNumber(filename)

[C, ~] = strsplit(filename, {'_', '.'});
sampNum = str2double(C{2});
