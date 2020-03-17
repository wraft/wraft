.PHONY: typeset

FILES=`cat index.txt`

typeset:
	pandoc                        \
	  --from         markdown     \
	  --to           latex        \
	  --template     template2.tex \
	  --out          proposal2.pdf   \
	  --pdf-engine   xelatex      \
	  $(FILES)
