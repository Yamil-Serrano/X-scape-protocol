; ============================================================
; enemy.asm - Enemy with Lfsr Ai
; 80% pursuit by delta X/Y toward player
; 20% random movement
; ============================================================

.export update_enemy
.export draw_enemy
.export init_enemy

; --- Import zero page variables from main.asm ---
.importzp enemy_x, enemy_y, enemy_direction, enemy_sprite
.importzp enemy_move_timer, enemy_anim_timer, enemy_anim_dir
.importzp enemy_dir_options, player_x, player_y
.importzp col_pixel, row_pixel, mt_col, mt_row, temp, temp2
.importzp lfsr_seed, speed_bonus
.importzp tile_base, attr_base, ppu_lo

; --- Import functions from main.asm ---
.import get_metatile, is_solid, lfsr_tick

; ============================================================
; Init enemy
; ============================================================
.proc init_enemy
  LDA #$03
  STA enemy_direction
  LDA #$00
  STA enemy_sprite
  STA enemy_move_timer
  STA enemy_anim_timer
  STA enemy_anim_dir
  RTS
.endproc

; ============================================================
; Update enemy
; ============================================================
.proc update_enemy
  INC enemy_move_timer
  LDA #$05
  SEC
  SBC speed_bonus
  CMP enemy_move_timer
  BEQ do_movement        ; BEQ instead of BCS
  JMP skip_movement      ; explicit jump to skip movement (no need to check for BCC)

do_movement:
  LDA #$00
  STA enemy_move_timer   ; reset timer

  ; Check alignment to grid
  LDA enemy_x
  AND #$0F
  CMP #$00
  BNE not_aligned
  LDA enemy_y
  AND #$0F
  CMP #$00
  BNE not_aligned

  JSR choose_new_direction

not_aligned:
  LDA enemy_direction
  CMP #$00
  BEQ try_down
  CMP #$01
  BEQ try_right
  CMP #$02
  BEQ try_up
  JMP try_left

try_down:
  JSR can_go_down
  CMP #$01
  BEQ down_ok
  JMP skip_movement

;down_ok:
;  INC enemy_y
;  JMP skip_movement

down_ok:
  LDA enemy_y
  CLC
  ADC #$02
  STA enemy_y
  JMP skip_movement

try_right:
  JSR can_go_right
  CMP #$01
  BEQ right_ok
  JMP skip_movement

;right_ok:
;  INC enemy_x
;  JMP skip_movement

right_ok:
  LDA enemy_x
  CLC
  ADC #$02
  STA enemy_x
  JMP skip_movement

try_up:
  JSR can_go_up
  CMP #$01
  BEQ up_ok
  JMP skip_movement

;up_ok:
;  DEC enemy_y
;  JMP skip_movement

up_ok:
  LDA enemy_y
  SEC
  SBC #$02
  STA enemy_y
  JMP skip_movement

try_left:
  JSR can_go_left
  CMP #$01
  BEQ left_ok
  JMP skip_movement

;left_ok:
;  DEC enemy_x

left_ok:
  LDA enemy_x
  SEC
  SBC #$02
  STA enemy_x

skip_movement:
  ; Ping-pong animation
  INC enemy_anim_timer
  LDA speed_bonus
  TAX
  LDA enemy_anim_speed_table, X
  CMP enemy_anim_timer
  BCS skip_anim
  LDA #$00
  STA enemy_anim_timer

  LDA enemy_anim_dir
  CMP #$00
  BNE anim_down
  INC enemy_sprite
  LDA enemy_sprite
  CMP #$02
  BNE skip_anim
  LDA #$01
  STA enemy_anim_dir
  JMP skip_anim
anim_down:
  DEC enemy_sprite
  LDA enemy_sprite
  CMP #$00
  BNE skip_anim
  LDA #$00
  STA enemy_anim_dir
skip_anim:
  RTS
.endproc

enemy_anim_speed_table:
  .byte $0C, $0A, $08, $06   ; bonus 0,1,2,3

; ============================================================
; Choose new direction
; Tick Lfsr: < $34 (~20%) random, >= $34 (~80%) pursuit
; ============================================================
.proc choose_new_direction

  ; Build bitmask of free directions
  LDA #$00
  STA enemy_dir_options

  JSR can_go_down
  CMP #$01
  BNE cnd_chk_right
  LDA enemy_dir_options
  ORA #$01
  STA enemy_dir_options
cnd_chk_right:
  JSR can_go_right
  CMP #$01
  BNE cnd_chk_up
  LDA enemy_dir_options
  ORA #$02
  STA enemy_dir_options
cnd_chk_up:
  JSR can_go_up
  CMP #$01
  BNE cnd_chk_left
  LDA enemy_dir_options
  ORA #$04
  STA enemy_dir_options
cnd_chk_left:
  JSR can_go_left
  CMP #$01
  BNE cnd_mode_roll
  LDA enemy_dir_options
  ORA #$08
  STA enemy_dir_options

cnd_mode_roll:
  JSR lfsr_tick
  CMP #$34
  BCS chase_mode
  JMP random_mode

; ============================================================
; Pursuit mode
; Delta X/Y to derive the 2 preferred directions.
; Try the one with greater distance first.
; If both blocked → random fallback.
; ============================================================
chase_mode:

  ; delta_x = player_x - enemy_x
  ; Carry set → player to the right → pref_h = right (1)
  ; Carry clear → player to the left → pref_h = left (3)
  LDA player_x
  SEC
  SBC enemy_x
  BCS chase_px_right
  EOR #$FF
  CLC
  ADC #$01
  STA temp2           ; |delta_x|
  LDA #$03
  STA temp            ; pref_h = left
  JMP chase_calc_y
chase_px_right:
  STA temp2           ; |delta_x|
  LDA #$01
  STA temp            ; pref_h = right

chase_calc_y:
  ; delta_y = player_y - enemy_y
  ; Carry set → player below → pref_v = down (0)
  ; Carry clear → player above → pref_v = up (2)
  LDA player_y
  SEC
  SBC enemy_y
  BCS chase_py_down
  EOR #$FF
  CLC
  ADC #$01
  STA col_pixel       ; |delta_y|
  LDA #$02
  JMP chase_got_pref_v
chase_py_down:
  STA col_pixel       ; |delta_y|
  LDA #$00
chase_got_pref_v:
  STA row_pixel       ; pref_v

  ; Compare |delta_x| vs |delta_y|
  LDA temp2
  CMP col_pixel
  BCS chase_try_h_first

chase_try_v_first:
  LDA row_pixel
  TAX
  LDA dir_to_bit, X
  AND enemy_dir_options
  BNE chase_select_v
  LDA temp
  TAX
  LDA dir_to_bit, X
  AND enemy_dir_options
  BNE chase_select_h
  JMP random_mode

chase_try_h_first:
  LDA temp
  TAX
  LDA dir_to_bit, X
  AND enemy_dir_options
  BNE chase_select_h
  LDA row_pixel
  TAX
  LDA dir_to_bit, X
  AND enemy_dir_options
  BNE chase_select_v
  JMP random_mode

chase_select_h:
  LDA temp
  STA enemy_direction
  RTS

chase_select_v:
  LDA row_pixel
  STA enemy_direction
  RTS

; ============================================================
; Random mode
; Remove opposite direction from bitmask (4% u-turn),
; choose randomly with Lfsr.
; ============================================================
random_mode:

  ; Remove opposite direction
  LDA enemy_direction
  CLC
  ADC #$02
  AND #$03
  TAX
  LDA dir_to_bit, X
  STA temp2
  EOR #$FF
  AND enemy_dir_options
  STA enemy_dir_options

  JSR lfsr_tick
  CMP #$0A          ; ~4% u-turn (10/255)
  BCS rm_pick
  LDA enemy_direction
  CLC
  ADC #$02
  AND #$03
  CMP #$00
  BEQ rm_uturn_down
  CMP #$01
  BEQ rm_uturn_right
  CMP #$02
  BEQ rm_uturn_up
  JMP rm_uturn_left
rm_uturn_down:
  JSR can_go_down
  CMP #$01
  BNE rm_pick
  LDA enemy_dir_options
  ORA #$01
  STA enemy_dir_options
  JMP rm_pick
rm_uturn_right:
  JSR can_go_right
  CMP #$01
  BNE rm_pick
  LDA enemy_dir_options
  ORA #$02
  STA enemy_dir_options
  JMP rm_pick
rm_uturn_up:
  JSR can_go_up
  CMP #$01
  BNE rm_pick
  LDA enemy_dir_options
  ORA #$04
  STA enemy_dir_options
  JMP rm_pick
rm_uturn_left:
  JSR can_go_left
  CMP #$01
  BNE rm_pick
  LDA enemy_dir_options
  ORA #$08
  STA enemy_dir_options

rm_pick:
  LDA enemy_dir_options
  CMP #$00
  BNE rm_count
  RTS

rm_count:
  LDA #$00
  STA temp
  LDA enemy_dir_options
  AND #$01
  CLC
  ADC temp
  STA temp
  LDA enemy_dir_options
  AND #$02
  BEQ :+
  INC temp
:
  LDA enemy_dir_options
  AND #$04
  BEQ :+
  INC temp
:
  LDA enemy_dir_options
  AND #$08
  BEQ :+
  INC temp
:
  LDA temp
  CMP #$01
  BEQ rm_only
  CMP #$04
  BEQ rm_from4
  CMP #$03
  BEQ rm_from3
  JMP rm_from2

rm_from4:
  JSR lfsr_tick
  AND #$03
  STA temp
  JMP rm_by_idx

rm_from3:
  JSR lfsr_tick
rm_from3_retry:
  CMP #$AB
  BCS rm_from3_reroll
  CMP #$56
  BCS rm_idx1
  LDA #$00
  STA temp
  JMP rm_by_idx
rm_idx1:
  LDA #$01
  STA temp
  JMP rm_by_idx
rm_from3_reroll:
  JSR lfsr_tick
  JMP rm_from3_retry

rm_from2:
  JSR lfsr_tick
  AND #$01
  STA temp

rm_by_idx:
  LDA #$00
  STA temp2
  LDA enemy_dir_options
  AND #$01
  BEQ rm_try_right
  LDA temp2
  CMP temp
  BEQ rm_sel_down
  INC temp2
rm_try_right:
  LDA enemy_dir_options
  AND #$02
  BEQ rm_try_up
  LDA temp2
  CMP temp
  BEQ rm_sel_right
  INC temp2
rm_try_up:
  LDA enemy_dir_options
  AND #$04
  BEQ rm_try_left
  LDA temp2
  CMP temp
  BEQ rm_sel_up
  INC temp2
rm_try_left:
  JMP rm_sel_left

rm_only:
  LDA enemy_dir_options
  AND #$01
  BNE rm_sel_down
  LDA enemy_dir_options
  AND #$02
  BNE rm_sel_right
  LDA enemy_dir_options
  AND #$04
  BNE rm_sel_up
  JMP rm_sel_left

rm_sel_down:
  LDA #$00
  STA enemy_direction
  RTS
rm_sel_right:
  LDA #$01
  STA enemy_direction
  RTS
rm_sel_up:
  LDA #$02
  STA enemy_direction
  RTS
rm_sel_left:
  LDA #$03
  STA enemy_direction
  RTS

.endproc

; ============================================================
; Direction (0-3) to bitmask table
; ============================================================
dir_to_bit:
  .byte $01, $02, $04, $08

; ============================================================
; Can go down
; ============================================================
.proc can_go_down
  LDA enemy_y
  CLC
  ADC #16
  STA row_pixel
  LSR A
  LSR A
  LSR A
  LSR A
  STA mt_row
  LDA enemy_x
  CLC
  ADC #2
  LSR A
  LSR A
  LSR A
  LSR A
  STA mt_col
  JSR get_metatile
  JSR is_solid
  CMP #$00
  BNE down_blocked1
  LDA enemy_x
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
  CMP #$00
  BNE down_blocked2
  LDA #$01
  RTS
down_blocked1:
down_blocked2:
  LDA #$00
  RTS
.endproc

; ============================================================
; Can go right
; ============================================================
.proc can_go_right
  LDA enemy_x
  CLC
  ADC #16
  STA col_pixel
  LSR A
  LSR A
  LSR A
  LSR A
  STA mt_col
  LDA enemy_y
  CLC
  ADC #2
  STA row_pixel
  LSR A
  LSR A
  LSR A
  LSR A
  STA mt_row
  JSR get_metatile
  JSR is_solid
  CMP #$00
  BNE right_blocked1
  LDA col_pixel
  LSR A
  LSR A
  LSR A
  LSR A
  STA mt_col
  LDA enemy_y
  CLC
  ADC #14
  LSR A
  LSR A
  LSR A
  LSR A
  STA mt_row
  JSR get_metatile
  JSR is_solid
  CMP #$00
  BNE right_blocked2
  LDA #$01
  RTS
right_blocked1:
right_blocked2:
  LDA #$00
  RTS
.endproc

; ============================================================
; Can go up
; ============================================================
.proc can_go_up
  LDA enemy_y
  SEC
  SBC #1
  STA row_pixel
  LSR A
  LSR A
  LSR A
  LSR A
  STA mt_row
  LDA enemy_x
  CLC
  ADC #2
  LSR A
  LSR A
  LSR A
  LSR A
  STA mt_col
  JSR get_metatile
  JSR is_solid
  CMP #$00
  BNE up_blocked1
  LDA enemy_x
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
  CMP #$00
  BNE up_blocked2
  LDA #$01
  RTS
up_blocked1:
up_blocked2:
  LDA #$00
  RTS
.endproc

; ============================================================
; Can go left
; ============================================================
.proc can_go_left
  LDA enemy_x
  SEC
  SBC #1
  STA col_pixel
  LSR A
  LSR A
  LSR A
  LSR A
  STA mt_col
  LDA enemy_y
  CLC
  ADC #2
  STA row_pixel
  LSR A
  LSR A
  LSR A
  LSR A
  STA mt_row
  JSR get_metatile
  JSR is_solid
  CMP #$00
  BNE left_blocked1
  LDA col_pixel
  LSR A
  LSR A
  LSR A
  LSR A
  STA mt_col
  LDA enemy_y
  CLC
  ADC #14
  LSR A
  LSR A
  LSR A
  LSR A
  STA mt_row
  JSR get_metatile
  JSR is_solid
  CMP #$00
  BNE left_blocked2
  LDA #$01
  RTS
left_blocked1:
left_blocked2:
  LDA #$00
  RTS
.endproc

; ============================================================
; Draw enemy
; ============================================================
.proc draw_enemy
  LDA enemy_direction
  CMP #$03
  BNE calc_dir
  LDA #$01
  JMP do_calc
calc_dir:
  LDA enemy_direction
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
  LDA enemy_sprite
  ASL A
  ASL A
  CLC
  ADC tile_base
  ADC #$55        ; Tiles from $55 (previously #$25)
  STA tile_base

  LDA enemy_direction
  CMP #$03
  BNE set_attr_normal
  LDA #%01000000   ; Flip horizontal + palette 1
  JMP set_attr
set_attr_normal:
  LDA #%00000000   ; Palette 1
set_attr:
  STA attr_base

  LDA enemy_y
  SEC
  SBC #1
  STA temp
  CLC
  ADC #$08
  STA ppu_lo

  LDA temp
  STA $0210
  LDA enemy_direction
  CMP #$03
  BNE s0_normal
  LDA tile_base
  CLC
  ADC #$01
  JMP s0_store
s0_normal:
  LDA tile_base
s0_store:
  STA $0211
  LDA attr_base
  STA $0212
  LDA enemy_x
  STA $0213

  LDA temp
  STA $0214
  LDA enemy_direction
  CMP #$03
  BNE s1_normal
  LDA tile_base
  JMP s1_store
s1_normal:
  LDA tile_base
  CLC
  ADC #$01
s1_store:
  STA $0215
  LDA attr_base
  STA $0216
  LDA enemy_x
  CLC
  ADC #$08
  STA $0217

  LDA ppu_lo
  STA $0218
  LDA enemy_direction
  CMP #$03
  BNE s2_normal
  LDA tile_base
  CLC
  ADC #$03
  JMP s2_store
s2_normal:
  LDA tile_base
  CLC
  ADC #$02
s2_store:
  STA $0219
  LDA attr_base
  STA $021a
  LDA enemy_x
  STA $021b

  LDA ppu_lo
  STA $021c
  LDA enemy_direction
  CMP #$03
  BNE s3_normal
  LDA tile_base
  CLC
  ADC #$02
  JMP s3_store
s3_normal:
  LDA tile_base
  CLC
  ADC #$03
s3_store:
  STA $021d
  LDA attr_base
  STA $021e
  LDA enemy_x
  CLC
  ADC #$08
  STA $021f

  RTS
.endproc