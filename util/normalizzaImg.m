function img = normalizzaImg(I)

I = double(I);
minimo = min(I(:));
I = I - minimo;
massimo = max(I(:));
img = I / massimo;
