set datafile sep ','
set terminal canvas  rounded size 800,600
set termoption dash
set terminal svg size 800,600
set output '//out_name//'
set border 3 front lt black linewidth 1.000 dashtype solid
set xdata time
set format x "%b\n'%y" timedate
set grid nopolar
set grid xtics nomxtics ytics nomytics noztics nomztics nox2tics nomx2tics noy2tics nomy2tics nocbtics nomcbtics
set grid layerdefault   lt 0 linewidth 0.500,  lt 0 linewidth 0.500
unset key
set style arrow 1 head back filled linecolor rgb "#56b4e9"  linewidth 1.500 dashtype solid size screen  0.020,15.000,90.000  fixed
set style data lines
set mxtics 4.000000
set xtics border in scale 2,0.5 nomirror norotate  autojustify
set xtics  norangelimit 2.6784e+06
set ytics border in scale 1,0.5 nomirror norotate  autojustify
set ytics  norangelimit
set ytics   ()
set title "//title//"
set yrange [ -1.00000 : * ] noreverse nowriteback
T(N) = timecolumn(N,timeformat)
timeformat = "%Y-%m-%d"
x = 0.0
plot '//input//' using (T(2)) : ($0) : (T(3)-T(2)) : (0.0) : yticlabel(1) with vector as 1, '//input//' using (T(2)) : ($0) : 1 with labels right offset -2
