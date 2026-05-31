<<<<<<< HEAD
function template = createTemplate(result_f, general)

% if there isn't an enroll function stop the process
try
    template = feval(general.ENROLL_function, char(result_f(1)));
catch
    template = ''; % FTE value
=======
function template = createTemplate(result_f, general)

% if there isn't an enroll function stop the process
try
    template = feval(general.ENROLL_function, char(result_f(1)));
catch
    template = ''; % FTE value
>>>>>>> 5aa7404d46b056250a68745e148af098f5e8a28e
end