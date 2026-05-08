; ============================================================
; enemy2.asm - Second enemy, 100% random movement
; No pursuit. Free movement with Lfsr.
; ============================================================

.export update_enemy2
.export draw_enemy2
.export init_enemy2

; --- Import zero page variables from main.asm ---
.importzp enemy2_x, enemy2_y, enemy2_direction, enemy2_sprite
.importzp enemy2_move_timer, enemy2_anim_timer, enemy2_anim_dir
.importzp enemy_dir_options
.importzp col_pixel, row_pixel, mt_col, mt_row, temp, temp2
.importzp lfsr_seed, speed_bonus
.importzp tile_base, attr_base, ppu_lo

; --- Import functions from main.asm ---
.import get_metatile, is_solid, lfsr_tick

; ============================================================
; Init enemy2
; ============================================================
.proc init_enemy2
  LDA #$01            ; Initial direction right
  STA enemy2_direction
  LDA #$00
  STA enemy2_sprite
  STA enemy2_move_timer
  STA enemy2_anim_timer
  STA enemy2_anim_dir
  RTS
.endproc

; ============================================================
; Update enemy2
; ============================================================
.proc update_enemy2
  INC enemy2_move_timer
  LDA #$05
  SEC
  SBC speed_bonus
  CMP enemy2_move_timer
  BEQ do_movement        ; BEQ instead of BCS
  JMP skip_movement      ; explicit jump to skip movement (no need to check for BCC)

do_movement:
  LDA #$00
  STA enemy2_move_timer   ; reset timer

  ; Check alignment to grid
  LDA enemy2_x
  AND #$0F
  CMP #$00
  BNE not_aligned
  LDA enemy2_y
  AND #$0F
  CMP #$00
  BNE not_aligned

  JSR choose_direction2

not_aligned:
  LDA enemy2_direction
  CMP #$00
  BEQ try_down
  CMP #$01
  BEQ try_right
  CMP #$02
  BEQ try_up
  JMP try_left

try_down:
  JSR can_go_down2
  CMP #$01
  BEQ down_ok
  JMP skip_movement

;down_ok:
; INC enemy2_y
;  JMP skip_movement

down_ok:
  LDA enemy2_y
  CLC
  ADC #$02
  STA enemy2_y
  JMP skip_movement

try_right:
  JSR can_go_right2
  CMP #$01
  BEQ right_ok
  JMP skip_movement

;right_ok:
;  INC enemy2_x
;  JMP skip_movement

right_ok:
  LDA enemy2_x
  CLC
  ADC #$02
  STA enemy2_x
  JMP skip_movement

try_up:
  JSR can_go_up2
  CMP #$01
  BEQ up_ok
  JMP skip_movement

;up_ok:
;  DEC enemy2_y
;  JMP skip_movement

up_ok:
  LDA enemy2_y
  SEC
  SBC #$02
  STA enemy2_y
  JMP skip_movement

try_left:
  JSR can_go_left2
  CMP #$01
  BEQ left_ok
  JMP skip_movement

;left_ok:
;  DEC enemy2_x

left_ok:
  LDA enemy2_x
  SEC
  SBC #$02
  STA enemy2_x

skip_movement:
  ; Ping-pong animation
  INC enemy2_anim_timer
  LDA speed_bonus
  TAX
  LDA enemy2_anim_speed_table, X
  CMP enemy2_anim_timer
  BCS skip_anim
  LDA #$00
  STA enemy2_anim_timer

  LDA enemy2_anim_dir
  CMP #$00
  BNE anim_down
  INC enemy2_sprite
  LDA enemy2_sprite
  CMP #$02
  BNE skip_anim
  LDA #$01
  STA enemy2_anim_dir
  JMP skip_anim
anim_down:
  DEC enemy2_sprite
  LDA enemy2_sprite
  CMP #$00
  BNE skip_anim
  LDA #$00
  STA enemy2_anim_dir
skip_anim:
  RTS
.endproc

enemy2_anim_speed_table:
  .byte $0C, $0A, $08, $06   ; bonus 0,1,2,3

; ============================================================
; Choose direction2 - 100% random movement
; Remove opposite direction from bitmask,
; choose randomly with Lfsr.
; ============================================================
.proc choose_direction2

  ; Build bitmask of free directions
  LDA #$00
  STA enemy_dir_options

  JSR can_go_down2
  CMP #$01
  BNE cnd_chk_right
  LDA enemy_dir_options
  ORA #$01
  STA enemy_dir_options
cnd_chk_right:
  JSR can_go_right2
  CMP #$01
  BNE cnd_chk_up
  LDA enemy_dir_options
  ORA #$02
  STA enemy_dir_options
cnd_chk_up:
  JSR can_go_up2
  CMP #$01
  BNE cnd_chk_left
  LDA enemy_dir_options
  ORA #$04
  STA enemy_dir_options
cnd_chk_left:
  JSR can_go_left2
  CMP #$01
  BNE cnd_pick
  LDA enemy_dir_options
  ORA #$08
  STA enemy_dir_options

cnd_pick:
  ; Always random mode (no pursuit)
  JMP random_mode

; ============================================================
; Random mode
; Remove opposite direction from bitmask,
; choose randomly with Lfsr.
; ============================================================
random_mode:

  ; Remove opposite direction
  LDA enemy2_direction
  CLC
  ADC #$02
  AND #$03
  TAX
  LDA dir_to_bit2, X
  STA temp2
  EOR #$FF
  AND enemy_dir_options
  STA enemy_dir_options

  JSR lfsr_tick
  CMP #$0A          ; ~4% u-turn (10/255)
  BCS rm_pick
  LDA enemy2_direction
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
  JSR can_go_down2
  CMP #$01
  BNE rm_pick
  LDA enemy_dir_options
  ORA #$01
  STA enemy_dir_options
  JMP rm_pick
rm_uturn_right:
  JSR can_go_right2
  CMP #$01
  BNE rm_pick
  LDA enemy_dir_options
  ORA #$02
  STA enemy_dir_options
  JMP rm_pick
rm_uturn_up:
  JSR can_go_up2
  CMP #$01
  BNE rm_pick
  LDA enemy_dir_options
  ORA #$04
  STA enemy_dir_options
  JMP rm_pick
rm_uturn_left:
  JSR can_go_left2
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
  STA enemy2_direction
  RTS
rm_sel_right:
  LDA #$01
  STA enemy2_direction
  RTS
rm_sel_up:
  LDA #$02
  STA enemy2_direction
  RTS
rm_sel_left:
  LDA #$03
  STA enemy2_direction
  RTS

.endproc

; ============================================================
; Direction (0-3) to bitmask table
; ============================================================
dir_to_bit2:
  .byte $01, $02, $04, $08

; ============================================================
; Can go down (enemy2)
; ============================================================
.proc can_go_down2
  LDA enemy2_y
  CLC
  ADC #16
  STA row_pixel
  LSR A
  LSR A
  LSR A
  LSR A
  STA mt_row
  LDA enemy2_x
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
  LDA enemy2_x
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
; Can go right (enemy2)
; ============================================================
.proc can_go_right2
  LDA enemy2_x
  CLC
  ADC #16
  STA col_pixel
  LSR A
  LSR A
  LSR A
  LSR A
  STA mt_col
  LDA enemy2_y
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
  LDA enemy2_y
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
; Can go up (enemy2)
; ============================================================
.proc can_go_up2
  LDA enemy2_y
  SEC
  SBC #1
  STA row_pixel
  LSR A
  LSR A
  LSR A
  LSR A
  STA mt_row
  LDA enemy2_x
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
  LDA enemy2_x
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
; Can go left (enemy2)
; ============================================================
.proc can_go_left2
  LDA enemy2_x
  SEC
  SBC #1
  STA col_pixel
  LSR A
  LSR A
  LSR A
  LSR A
  STA mt_col
  LDA enemy2_y
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
  LDA enemy2_y
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
; Draw enemy2 - Sprites at $0220-$022F
; ============================================================
.proc draw_enemy2
  LDA enemy2_direction
  CMP #$03
  BNE calc_dir
  LDA #$01
  JMP do_calc
calc_dir:
  LDA enemy2_direction
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
  LDA enemy2_sprite
  ASL A
  ASL A
  CLC
  ADC tile_base
  ADC #$25
  STA tile_base

  LDA enemy2_direction
  CMP #$03
  BNE set_attr_normal
  LDA #%01000000
  JMP set_attr
set_attr_normal:
  LDA #%00000000
set_attr:
  STA attr_base

  LDA enemy2_y
  SEC
  SBC #1
  STA temp
  CLC
  ADC #$08
  STA ppu_lo

  LDA temp
  STA $0220
  LDA enemy2_direction
  CMP #$03
  BNE s0_normal
  LDA tile_base
  CLC
  ADC #$01
  JMP s0_store
s0_normal:
  LDA tile_base
s0_store:
  STA $0221
  LDA attr_base
  STA $0222
  LDA enemy2_x
  STA $0223

  LDA temp
  STA $0224
  LDA enemy2_direction
  CMP #$03
  BNE s1_normal
  LDA tile_base
  JMP s1_store
s1_normal:
  LDA tile_base
  CLC
  ADC #$01
s1_store:
  STA $0225
  LDA attr_base
  STA $0226
  LDA enemy2_x
  CLC
  ADC #$08
  STA $0227

  LDA ppu_lo
  STA $0228
  LDA enemy2_direction
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
  STA $0229
  LDA attr_base
  STA $022a
  LDA enemy2_x
  STA $022b

  LDA ppu_lo
  STA $022c
  LDA enemy2_direction
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
  STA $022d
  LDA attr_base
  STA $022e
  LDA enemy2_x
  CLC
  ADC #$08
  STA $022f

  RTS
.endproc