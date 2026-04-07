.include "../include/constants.inc"
.include "../include/header.inc"

; ============================================================
; Zero page
; ============================================================
.segment "ZEROPAGE"

; --- Shared / System ---
frame_ready:      .res 1
tile_base:        .res 1  ; Shared by draw_player, draw_enemy, draw_enemy2
attr_base:        .res 1  ; Shared by draw_player, draw_enemy, draw_enemy2
pad1:             .res 1

; --- Shared / Collision (shared by all) ---
map_ptr:          .res 2  ; 16-bit pointer to map
mt_byte:          .res 1
mt_col:           .res 1
mt_row:           .res 1
ppu_lo:           .res 1  ; draw_map init, draw_* (sprite low row)
ppu_hi:           .res 1
temp:             .res 1  ; get_metatile (row calc), draw_enemy (y-1), draw_coin (y-1)
temp2:            .res 1  ; choose_new_direction (opposite direction)
col_pixel:        .res 1  ; Edge X pixel, survives JSR
row_pixel:        .res 1  ; Edge Y pixel, survives JSR

; --- Player ---
player_x:         .res 1  ; X position in pixels
player_y:         .res 1  ; Y position in pixels
player_direction: .res 1  ; 0=down 1=right 2=up 3=left
player_sprite:    .res 1  ; Animation frame (0,1,2)
anim_dir:         .res 1  ; Ping-pong: 0=rising 1=falling
move_timer:       .res 1
anim_timer:       .res 1
player_hp:        .res 1
player_invincible_timer: .res 1  ; Invincibility counter

; --- Enemy 1 ---
enemy_x:          .res 1
enemy_y:          .res 1
enemy_direction:  .res 1  ; 0=down 1=right 2=up 3=left
enemy_sprite:     .res 1  ; Animation frame
enemy_move_timer: .res 1
enemy_anim_timer: .res 1
enemy_anim_dir:   .res 1
enemy_dir_options:.res 1

; --- Enemy 2 ---
enemy2_x:          .res 1
enemy2_y:          .res 1
enemy2_direction:  .res 1  ; 0=down 1=right 2=up 3=left
enemy2_sprite:     .res 1  ; Animation frame
enemy2_move_timer: .res 1
enemy2_anim_timer: .res 1
enemy2_anim_dir:   .res 1

; --- Coin variables ---
coin_x:           .res 1
coin_y:           .res 1
coin_active:      .res 1
coin_anim_timer:  .res 1
coin_frame:       .res 1
coin_dir:         .res 1
respawn_x:        .res 1
respawn_y:        .res 1
respawn_count:    .res 1
lfsr_seed:        .res 1
coin_count:       .res 1   ; Coin counter (0-9, resets upon reaching 10)

; --- Player score ---
player_score:     .res 2

; --- Hud score sprites ---
hud_score_hundreds: .res 1
hud_score_tens:     .res 1
hud_score_units:    .res 1
temp_y:           .res 1
gameover_blink_timer: .res 1

; --- Speed progression ---
speed_bonus:      .res 1   ; 0..2, increases when collecting coins

; --- Exports ---
; Shared
.exportzp frame_ready
.exportzp tile_base, attr_base, ppu_lo, ppu_hi, temp, temp2
.exportzp col_pixel, row_pixel, mt_col, mt_row, mt_byte
.exportzp map_ptr
.exportzp pad1

; Player
.exportzp player_x, player_y, player_direction, player_sprite
.exportzp anim_dir, move_timer, anim_timer, player_hp, player_invincible_timer

; Enemy 1
.exportzp enemy_x, enemy_y, enemy_direction, enemy_sprite
.exportzp enemy_move_timer, enemy_anim_timer, enemy_anim_dir
.exportzp enemy_dir_options

; Enemy 2
.exportzp enemy2_x, enemy2_y, enemy2_direction, enemy2_sprite
.exportzp enemy2_move_timer, enemy2_anim_timer, enemy2_anim_dir

; Coins
.exportzp coin_x, coin_y, coin_active, coin_anim_timer, coin_frame, coin_dir
.exportzp respawn_x, respawn_y, respawn_count, lfsr_seed, enemy_dir_options
.exportzp coin_count

; Player score
.exportzp player_score

; Hud
.exportzp hud_score_hundreds, hud_score_tens, hud_score_units, gameover_blink_timer

; Speed bonus
.exportzp speed_bonus

; Exports of functions (for other files)
.export get_metatile
.export is_solid

; ============================================================
; Code
; ============================================================
.segment "CODE"

.proc irq_handler
  RTI
.endproc

.proc nmi_handler
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  LDA #$00
  STA OAMADDR
  LDA #$02
  STA OAMDMA

  LDA #$00
  STA $2005
  STA $2005

  LDA #$01
  STA frame_ready

  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTI
.endproc

.import reset_handler

; --- Import player, enemies, collectables and hud---
.import update_player, draw_player, take_player_damage
.import init_enemy, update_enemy, draw_enemy
.import init_enemy2, update_enemy2, draw_enemy2
.import init_coin, update_coin, draw_coin
.import update_score_hud, draw_hud

; ============================================================
; Main
; ============================================================
.export main
.proc main

  ; --- Ppu warmup ---
vwait1:
  BIT PPUSTATUS
  BPL vwait1
vwait2:
  BIT PPUSTATUS
  BPL vwait2

  ; --- Load palettes ---
  LDA PPUSTATUS
  LDA #$3F
  STA PPUADDR
  LDA #$00
  STA PPUADDR
  LDX #$00
load_palettes:
  LDA palettes, X
  STA PPUDATA
  INX
  CPX #$20
  BNE load_palettes

  ; --- Draw map ---
  LDA #<map
  STA map_ptr
  LDA #>map
  STA map_ptr+1
  LDA #$00
  STA mt_row

draw_mt_rows:
  LDA mt_row
  LSR A
  LSR A
  CLC
  ADC #$20
  STA ppu_hi
  LDA mt_row
  AND #$03
  ASL A
  ASL A
  ASL A
  ASL A
  ASL A
  ASL A
  STA ppu_lo
  BIT PPUSTATUS
  LDA ppu_hi
  STA PPUADDR
  LDA ppu_lo
  STA PPUADDR
  LDA #$00
  STA mt_col

draw_top_row:
  LDY #$00
  LDA (map_ptr), Y
  STA mt_byte
  INC map_ptr
  BNE :+
  INC map_ptr+1
:
  LDA mt_byte
  LSR A
  LSR A
  LSR A
  LSR A
  LSR A
  LSR A
  ASL A
  ASL A
  TAX
  LDA metatiles, X
  STA PPUDATA
  LDA metatiles+1, X
  STA PPUDATA

  LDA mt_byte
  LSR A
  LSR A
  LSR A
  LSR A
  AND #$03
  ASL A
  ASL A
  TAX
  LDA metatiles, X
  STA PPUDATA
  LDA metatiles+1, X
  STA PPUDATA

  LDA mt_byte
  LSR A
  LSR A
  AND #$03
  ASL A
  ASL A
  TAX
  LDA metatiles, X
  STA PPUDATA
  LDA metatiles+1, X
  STA PPUDATA

  LDA mt_byte
  AND #$03
  ASL A
  ASL A
  TAX
  LDA metatiles, X
  STA PPUDATA
  LDA metatiles+1, X
  STA PPUDATA

  LDA mt_col
  CLC
  ADC #4
  STA mt_col
  CMP #16
  BNE draw_top_row

  LDA ppu_lo
  CLC
  ADC #32
  STA ppu_lo
  BCC :+
  INC ppu_hi
:
  BIT PPUSTATUS
  LDA ppu_hi
  STA PPUADDR
  LDA ppu_lo
  STA PPUADDR
  LDA map_ptr
  SEC
  SBC #4
  STA map_ptr
  BCS :+
  DEC map_ptr+1
:
  LDA #$00
  STA mt_col

draw_bot_row:
  LDY #$00
  LDA (map_ptr), Y
  STA mt_byte
  INC map_ptr
  BNE :+
  INC map_ptr+1
:
  LDA mt_byte
  LSR A
  LSR A
  LSR A
  LSR A
  LSR A
  LSR A
  ASL A
  ASL A
  TAX
  LDA metatiles+2, X
  STA PPUDATA
  LDA metatiles+3, X
  STA PPUDATA

  LDA mt_byte
  LSR A
  LSR A
  LSR A
  LSR A
  AND #$03
  ASL A
  ASL A
  TAX
  LDA metatiles+2, X
  STA PPUDATA
  LDA metatiles+3, X
  STA PPUDATA

  LDA mt_byte
  LSR A
  LSR A
  AND #$03
  ASL A
  ASL A
  TAX
  LDA metatiles+2, X
  STA PPUDATA
  LDA metatiles+3, X
  STA PPUDATA

  LDA mt_byte
  AND #$03
  ASL A
  ASL A
  TAX
  LDA metatiles+2, X
  STA PPUDATA
  LDA metatiles+3, X
  STA PPUDATA

  LDA mt_col
  CLC
  ADC #4
  STA mt_col
  CMP #16
  BNE draw_bot_row

  INC mt_row
  LDA mt_row
  CMP #15
  BEQ draw_done
  JMP draw_mt_rows
draw_done:

  ; --- Attribute table ---
  BIT PPUSTATUS
  LDA #$23
  STA PPUADDR
  LDA #$C0
  STA PPUADDR
  LDX #$00
load_attributes:
  LDA map + 60, X
  STA PPUDATA
  INX
  CPX #$40
  BNE load_attributes

  ; --- Initialize score ---
  LDA #$00
  STA player_score
  STA player_score+1

  ; --- Initialize invincibility ---
  LDA #$00
  STA player_invincible_timer

  ; ============================================================
  ; Initialize positions of all entities
  ; ============================================================
  
  ; --- Player position at cell (7,7) ---
  LDA #$70          ; 7 * 16 = 112 = $70
  STA player_x
  LDA #$70         
  STA player_y

  ; --- Enemy 1 position (pursuer) ---
  LDA #$C0          ; Cell (12,8) in pixels
  STA enemy_x
  LDA #$80          ; Cell (8,8) in pixels
  STA enemy_y

  ; --- Enemy 2 position (random) ---
  LDA #$10          ; Cell (1,1) in pixels
  STA enemy2_x
  LDA #$10
  STA enemy2_y

  ; --- Initialize additional player variables ---
  LDA #$00
  STA player_direction
  STA player_sprite
  STA anim_dir
  STA move_timer
  STA anim_timer
  STA frame_ready
  STA pad1

  ; --- Initialize enemies ---
  JSR init_enemy
  JSR init_enemy2

  ; --- Initialize coin ---
  JSR init_coin

  ; --- Initialize coin counter for every 10 coins increment speed bonus ---
  LDA #$00
  STA coin_count

  ; --- Initialize hud score ---
  LDA #$00
  STA hud_score_hundreds
  STA hud_score_tens
  STA hud_score_units

  ; --- Initialize game over blink timer ---
  LDA #$00
  STA gameover_blink_timer

  ; --- Initialize Hp (3 lives at start) ---
  LDA #$03
  STA player_hp

  ; --- Initialize speed bonus ---
  LDA #$00
  STA speed_bonus

  ; --- Turn on screen ---
  LDA PPUSTATUS
  LDA #%10001000    ; Nmi on, Bg $0000, sprites $1000
  STA PPUCTRL
  LDA #$00
  STA $2005
  STA $2005
  LDA #%00011110
  STA PPUMASK

MainLoop:
  LDA frame_ready
  BEQ MainLoop
  LDA #$00
  STA frame_ready

  ; --- Update and draw player ---
  JSR read_controller
  JSR update_player
  JSR draw_player

  ; --- Update and draw enemy 1 ---
  JSR update_enemy
  JSR draw_enemy

  ; --- Update and draw enemy 2 ---
  JSR update_enemy2
  JSR draw_enemy2

  ; --- Check collision with enemies ---
  JSR check_enemy_collision

  ; --- Update and draw coin ---
  JSR update_coin
  JSR draw_coin

  ; --- Update and draw hud ---
  JSR update_score_hud
  JSR draw_hud

  JMP MainLoop

.endproc

; ============================================================
; Read controller
; Nes order: A B Select Start Up Down Left Right
; Stores the last pressed direction in pad1 (Pac-Man)
; ============================================================
.proc read_controller
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016

  LDA $4016         ; A      — discard
  LDA $4016         ; B      — discard
  LDA $4016         ; Select — discard
  LDA $4016         ; Start  — discard

  LDA $4016         ; Up
  AND #$01
  BEQ chk_down
  LDA #$02
  STA pad1
  RTS
chk_down:
  LDA $4016         ; Down
  AND #$01
  BEQ chk_left
  LDA #$00
  STA pad1
  RTS
chk_left:
  LDA $4016         ; Left
  AND #$01
  BEQ chk_right
  LDA #$03
  STA pad1
  RTS
chk_right:
  LDA $4016         ; Right
  AND #$01
  BEQ no_input
  LDA #$01
  STA pad1
  RTS
no_input:
  RTS               ; No input → pad1 unchanged (stays on last direction)
.endproc

; ============================================================
; Get metatile
; Input: mt_col (0-15), mt_row (0-14)
; Output: A = metatile Id (0-3)
; Uses temp internally — do not pass temp as argument
; ============================================================
.proc get_metatile
  LDA mt_row
  ASL A
  ASL A             ; mt_row * 4
  STA temp
  LDA mt_col
  LSR A
  LSR A             ; mt_col / 4 = byte within the row
  CLC
  ADC temp
  CLC
  ADC #<map
  STA map_ptr
  LDA #>map
  ADC #$00
  STA map_ptr+1
  LDY #$00
  LDA (map_ptr), Y
  STA mt_byte
  LDA mt_col
  AND #$03
  CMP #$00
  BEQ bits76
  CMP #$01
  BEQ bits54
  CMP #$02
  BEQ bits32
  LDA mt_byte
  AND #$03
  RTS
bits76:
  LDA mt_byte
  LSR A
  LSR A
  LSR A
  LSR A
  LSR A
  LSR A
  AND #$03
  RTS
bits54:
  LDA mt_byte
  LSR A
  LSR A
  LSR A
  LSR A
  AND #$03
  RTS
bits32:
  LDA mt_byte
  LSR A
  LSR A
  AND #$03
  RTS
.endproc

; ============================================================
; Is solid
; Input: A = metatile Id
; Output: Z=1 passable (00 or 11), Z=0 solid (01 or 10)
; ============================================================
.proc is_solid
  CMP #$00
  BEQ passable
  CMP #$03
  BEQ passable
  LDA #$01
  RTS
passable:
  LDA #$00
  RTS
.endproc

; ============================================================
; Check enemy collision
; Checks if player collides with enemy1 or enemy2
; Hitbox reduced to 12x12 to avoid corner touches
; ============================================================
.proc check_enemy_collision
  ; If player is already dead, don't check
  LDA player_hp
  BEQ no_collision
  
  ; ==========================================
  ; Collision with enemy 1
  ; ==========================================
  
  ; Calculate distance in X with enemy1
  LDA player_x
  SEC
  SBC enemy_x
  BCS x_diff1
  EOR #$FF
  CLC
  ADC #$01
x_diff1:
  CMP #$0C        ; 12 pixel threshold (reduced hitbox)
  BCS check_enemy2
  
  ; Calculate distance in Y with enemy1
  LDA player_y
  SEC
  SBC enemy_y
  BCS y_diff1
  EOR #$FF
  CLC
  ADC #$01
y_diff1:
  CMP #$0C        ; 12 pixel threshold (reduced hitbox)
  BCS check_enemy2
  
  ; Collision with enemy1
  JSR take_player_damage
  RTS

  ; ==========================================
  ; Collision with enemy 2
  ; ==========================================
check_enemy2:
  ; Calculate distance in X with enemy2
  LDA player_x
  SEC
  SBC enemy2_x
  BCS x_diff2
  EOR #$FF
  CLC
  ADC #$01
x_diff2:
  CMP #$0C        ; 12 pixel threshold (reduced hitbox)
  BCS no_collision
  
  ; Calculate distance in Y with enemy2
  LDA player_y
  SEC
  SBC enemy2_y
  BCS y_diff2
  EOR #$FF
  CLC
  ADC #$01
y_diff2:
  CMP #$0C        ; 12 pixel threshold (reduced hitbox)
  BCS no_collision
  
  ; Collision with enemy2
  JSR take_player_damage

no_collision:
  RTS
.endproc

; ============================================================
; Vectors
; ============================================================
.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler

; ============================================================
; Rodata
; ============================================================
.segment "RODATA"

palettes:
  .byte $2D, $00, $10, $30  ; Bg Palette 0
  .byte $2D, $17, $27, $37  ; Bg Palette 1
  .byte $2D, $0F, $2D, $00  ; Bg Palette 2
  .byte $2D, $0B, $1A, $29  ; Bg Palette 3
  .byte $2D, $0F, $00, $10  ; Sp Palette 0
  .byte $2D, $0C, $21, $32  ; Sp Palette 1
  .byte $2D, $05, $16, $27  ; Sp Palette 2
  .byte $2D, $0B, $1A, $29  ; Sp Palette 3

metatiles:
  .byte $00, $00, $00, $00  ; 00 → free ground
  .byte $01, $02, $03, $04  ; 01 → wall type 1
  .byte $05, $06, $07, $08  ; 10 → wall type 2
  .byte $09, $0A, $0B, $0C  ; 11 → Grass

.include "map.asm"

.segment "CHR"
.incbin "../assets/tiles_and_sprites.chr"