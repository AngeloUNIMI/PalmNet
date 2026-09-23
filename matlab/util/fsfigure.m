function [] = fsfigure(indf,fullscreenoption)

%default: 50 70 100 170

bordo1 = 50;
bordo2 = 70;
bordo3 = 100;
bordo4 = 170;

if (nargin == 2),
if (strcmp(fullscreenoption,'fullscreen') == 1),
bordo1 = 0;
bordo2 = 0;
bordo3 = 0;
bordo4 = 0;
end,
end,


screen_size = get(0, 'ScreenSize');
if (nargin == 0),
f1 = figure();
else
f1 = figure(indf);
end,
set(f1, 'Position', [bordo1 bordo2 screen_size(3)-bordo3 screen_size(4)-bordo4 ] );