srcDir = src
mainAsm = ${srcDir}/main.asm
resDir = res
out = tiquest.8xp

graphics = $(addprefix ${resDir}/, \
	player.inc \
)

${out} : ${srcDir}/*.asm ${graphics}
	spasm64.exe -I ${srcDir} -I ${resDir} ${mainAsm} ${out}

${resDir}/%.inc: ${resDir}/%.png ${resDir}/%.csv
	python parse_graphic.py --image ${resDir}/$*.png --map ${resDir}/$*.csv --out ${resDir}/$*.inc
