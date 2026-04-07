# Output
OUT = build/X-scape_protocol.nes

# Sources
SRC = src/main.asm src/reset.asm src/player.asm src/enemy.asm src/enemy2.asm src/coin.asm src/hud.asm

# Objects
OBJ = build/main.o build/reset.o build/player.o build/enemy.o build/enemy2.o build/coin.o build/hud.o

# Default rule
all: $(OUT)

# Create build directory if it doesn't exist
build:
	mkdir -p build 2>/dev/null || mkdir build 2>nul

# Link
$(OUT): $(OBJ) | build
	ld65 $(OBJ) -C config/nes.cfg -o $(OUT)

# Compile
build/%.o: src/%.asm | build
	ca65 $< -o $@ -I include

# Clean
clean:
	rm -f build/*.o build/*.nes 2>/dev/null || del /Q build\*.o build\*.nes 2>nul

# Phony targets
.PHONY: all clean

# in windows use "mingw32-make" to compile and "mingw32-make clean" to clean the compiled files
# in linux use "make" to compile and "make clean" to clean compiled files