; ============================================================
; player.asm - Complete player logic with damage and invincibility
; ============================================================

.export update_player
.export draw_player
.export take_player_damage

; --- Import zero page variables from main.asm ---
.importzp player_x, player_y, player_direction, player_sprite
.importzp anim_dir, move_timer, anim_timer, player_hp, player_invincible_timer
.importzp pad1, tile_base, attr_base, ppu_lo, temp, temp2
.importzp col_pixel, row_pixel, mt_col, mt_row
.importzp speed_bonus

; --- Import functions from main.asm ---
.import get_metatile, is_solid

; ============================================================
; Take player damage
; ============================================================
.proc take_player_damage
  LDA player_invincible_timer
  BNE already_invincible
  
  LDA player_hp
  BEQ already_dead
  DEC player_hp
  
  LDA #180
  STA player_invincible_timer
  
already_invincible:
already_dead:
  RTS
.endproc

; ============================================================
; Update player
; ============================================================
.proc update_player

  LDA player_invincible_timer
  BEQ invincible_done
  DEC player_invincible_timer
invincible_done:

  INC move_timer
  LDA #$04
  SEC
  SBC speed_bonus
  CMP move_timer
  BEQ do_movement
  JMP skip_movement

do_movement:
  LDA #$00
  STA move_timer

  LDA player_hp
  BNE player_alive_move
  JMP skip_movement

player_alive_move:

  LDA player_x
  AND #$0F
  BNE not_aligned
  
  LDA player_y
  AND #$0F
  BNE not_aligned

aligned:
  LDA pad1
  CMP #$FF
  BEQ use_current_dir
  STA player_direction
  JMP try_move

use_current_dir:
  JMP try_move

not_aligned:

try_move:
  LDA player_direction
  CMP #$00
  BEQ try_down
  CMP #$01
  BEQ try_right
  CMP #$02
  BNE :+
  JMP try_up
:
  CMP #$03
  BEQ :+
  JMP skip_movement
:
  JMP try_left

try_down:
  LDA player_y
  CLC
  ADC #16
  STA row_pixel
  LSR A
  LSR A
  LSR A
  LSR A
  STA mt_row
  LDA player_x
  CLC
  ADC #1
  LSR A
  LSR A
  LSR A
  LSR A
  STA mt_col
  JSR get_metatile
  JSR is_solid
  BEQ down_pt2
  JMP skip_movement
down_pt2:
  LDA player_x
  CLC
  ADC #14
  LSR A
  LSR A
  LSR A
  LSR A
  STA mt_col
  LDA row_pixel
  LSR A
  LSR A
  LSR A
  LSR A
  STA mt_row
  JSR get_metatile
  JSR is_solid
  BEQ down_ok
  JMP skip_movement
down_ok:
  INC player_y
  JMP skip_movement

try_right:
  LDA player_x
  CLC
  ADC #16
  STA col_pixel
  LSR A
  LSR A
  LSR A
  LSR A
  STA mt_col
  LDA player_y
  CLC
  ADC #1
  STA row_pixel
  LSR A
  LSR A
  LSR A
  LSR A
  STA mt_row
  JSR get_metatile
  JSR is_solid
  BEQ right_pt2
  JMP skip_movement
right_pt2:
  LDA col_pixel
  LSR A
  LSR A
  LSR A
  LSR A
  STA mt_col
  LDA player_y
  CLC
  ADC #14
  LSR A
  LSR A
  LSR A
  LSR A
  STA mt_row
  JSR get_metatile
  JSR is_solid
  BEQ right_ok
  JMP skip_movement
right_ok:
  INC player_x
  JMP skip_movement

try_up:
  LDA player_y
  SEC
  SBC #1
  STA row_pixel
  LSR A
  LSR A
  LSR A
  LSR A
  STA mt_row
  LDA player_x
  CLC
  ADC #1
  LSR A
  LSR A
  LSR A
  LSR A
  STA mt_col
  JSR get_metatile
  JSR is_solid
  BEQ up_pt2
  JMP skip_movement
up_pt2:
  LDA player_x
  CLC
  ADC #14
  LSR A
  LSR A
  LSR A
  LSR A
  STA mt_col
  LDA row_pixel
  LSR A
  LSR A
  LSR A
  LSR A
  STA mt_row
  JSR get_metatile
  JSR is_solid
  BEQ up_ok
  JMP skip_movement
up_ok:
  DEC player_y
  JMP skip_movement

try_left:
  LDA player_x
  SEC
  SBC #1
  STA col_pixel
  LSR A
  LSR A
  LSR A
  LSR A
  STA mt_col
  LDA player_y
  CLC
  ADC #1
  STA row_pixel
  LSR A
  LSR A
  LSR A
  LSR A
  STA mt_row
  JSR get_metatile
  JSR is_solid
  BEQ left_pt2
  JMP skip_movement
left_pt2:
  LDA col_pixel
  LSR A
  LSR A
  LSR A
  LSR A
  STA mt_col
  LDA player_y
  CLC
  ADC #14
  LSR A
  LSR A
  LSR A
  LSR A
  STA mt_row
  JSR get_metatile
  JSR is_solid
  BEQ left_ok
  JMP skip_movement
left_ok:
  DEC player_x

skip_movement:

  LDA player_hp
  BEQ skip_anim
  
  INC anim_timer
  LDA anim_timer
  CMP #$0A
  BNE skip_anim
  LDA #$00
  STA anim_timer
  LDA anim_dir
  BNE anim_going_down
  INC player_sprite
  LDA player_sprite
  CMP #$02
  BNE skip_anim
  LDA #$01
  STA anim_dir
  JMP skip_anim
anim_going_down:
  DEC player_sprite
  LDA player_sprite
  CMP #$00
  BNE skip_anim
  LDA #$00
  STA anim_dir
skip_anim:
  RTS
.endproc

; ============================================================
; Draw player
; ============================================================
.proc draw_player
  ; If player is dead, hide
  LDA player_hp
  BNE player_alive
  
  LDA #$FF
  STA $0200
  STA $0204
  STA $0208
  STA $020C
  RTS

player_alive:
  ; If invincible and timer > 0, blink
  LDA player_invincible_timer
  BEQ draw_normal      ; If timer = 0, draw normally
  
  ; Blinking: hide every 8 frames using invincibility timer
  ; Timer AND $08 alternates between $00 and $08 every 8 frames
  LDA player_invincible_timer
  AND #$08
  BEQ draw_normal     ; Bit 3 is 0 → show
  
  ; Hide during blink
  LDA #$FF
  STA $0200
  STA $0204
  STA $0208
  STA $020C
  RTS

draw_normal:
  LDA player_direction
  CMP #$03
  BNE calc_dir
  LDA #$01
  JMP do_calc
calc_dir:
  LDA player_direction
do_calc:
  STA tile_base
  ASL A
  ASL A
  STA attr_base
  LDA tile_base
  ASL A
  ASL A
  ASL A
  CLC
  ADC attr_base
  STA tile_base
  LDA player_sprite
  ASL A
  ASL A
  CLC
  ADC tile_base
  ADC #$01
  STA tile_base

  LDA player_direction
  CMP #$03
  BEQ set_flip
  LDA #%00000011
  JMP set_attr
set_flip:
  LDA #%01000011
set_attr:
  STA attr_base

  LDA player_y
  SEC
  SBC #1
  STA temp
  CLC
  ADC #$08
  STA ppu_lo

  LDA temp
  STA $0200
  LDA player_direction
  CMP #$03
  BEQ s0_left
  LDA tile_base
  JMP s0_store
s0_left:
  LDA tile_base
  CLC
  ADC #$01
s0_store:
  STA $0201
  LDA attr_base
  STA $0202
  LDA player_x
  STA $0203

  LDA temp
  STA $0204
  LDA player_direction
  CMP #$03
  BEQ s1_left
  LDA tile_base
  CLC
  ADC #$01
  JMP s1_store
s1_left:
  LDA tile_base
s1_store:
  STA $0205
  LDA attr_base
  STA $0206
  LDA player_x
  CLC
  ADC #$08
  STA $0207

  LDA ppu_lo
  STA $0208
  LDA player_direction
  CMP #$03
  BEQ s2_left
  LDA tile_base
  CLC
  ADC #$02
  JMP s2_store
s2_left:
  LDA tile_base
  CLC
  ADC #$03
s2_store:
  STA $0209
  LDA attr_base
  STA $020a
  LDA player_x
  STA $020b

  LDA ppu_lo
  STA $020c
  LDA player_direction
  CMP #$03
  BEQ s3_left
  LDA tile_base
  CLC
  ADC #$03
  JMP s3_store
s3_left:
  LDA tile_base
  CLC
  ADC #$02
s3_store:
  STA $020d
  LDA attr_base
  STA $020e
  LDA player_x
  CLC
  ADC #$08
  STA $020f

  RTS
.endproc