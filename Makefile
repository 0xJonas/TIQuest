srcDir = src
mainAsm = ${srcDir}/main.asm
resDir = res
scriptsDir = ${resDir}/scripts
spritesDir = ${resDir}/sprites
out = tiquest.8xp

sprites = $(addprefix ${spritesDir}/, \
	player.inc \
)

${out} : ${srcDir}/*.asm ${sprites}
	spasm64.exe -I ${srcDir} -I ${spritesDir} ${mainAsm} ${out}

${spritesDir}/%.inc: ${spritesDir}/%.png ${spritesDir}/%.csv
	python ${scriptsDir}/parse_graphic.py --image ${spritesDir}/$*.png --map ${spritesDir}/$*.csv --out ${spritesDir}/$*.inc
