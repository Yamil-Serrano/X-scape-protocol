; ============================================================
; coin.asm - Coin with respawn using Lfsr (pseudo-random Nes)
; ============================================================

.export update_coin
.export draw_coin
.export init_coin
.export inc_speed
.export lfsr_tick 

; --- Import zero page variables from main.asm ---
.importzp player_x, player_y, player_score
.importzp coin_x, coin_y, coin_active
.importzp coin_anim_timer, coin_frame, coin_dir
.importzp respawn_x, respawn_y, respawn_count, lfsr_seed, coin_count
.importzp mt_col, mt_row, temp
.importzp speed_bonus
.importzp tile_base, attr_base, ppu_lo

; --- Import functions from main.asm ---
.import get_metatile

; ============================================================
; Init coin
; ============================================================
.proc init_coin
  ; Initial Lfsr seed (can never be 0)
  LDA #$A5
  STA lfsr_seed

  LDA #$01
  STA coin_active
  LDA #$00
  STA coin_anim_timer
  STA coin_frame
  STA coin_dir

  JSR respawn_coin
  RTS
.endproc

; ============================================================
; Inc speed
; Increments speed_bonus up to maximum (2)
; Player: threshold 4->3->2 | Enemies: threshold 6->5->4
; ============================================================
.proc inc_speed
  INC coin_count
  LDA coin_count
  CMP #10
  BNE no_speed_up
  ; Reached 10 coins
  LDA #$00
  STA coin_count
  LDA speed_bonus
  CMP #$03
  BEQ speed_maxed
  INC speed_bonus
no_speed_up:
speed_maxed:
  RTS
.endproc

; ============================================================
; Lfsr_tick - Advances the Lfsr one step, returns new value in A
; 8-bit Galois Lfsr: taps at bits 7,5,4,3 (polynomial 0xB8)
; Guarantees it never returns 0, cycle of 255 distinct values
; ============================================================
.proc lfsr_tick
  LDA lfsr_seed
  LSR A               ; Bit 0 shifts out to carry
  BCC no_feedback
  EOR #$B8            ; Apply taps if the outgoing bit was 1
no_feedback:
  STA lfsr_seed
  RTS
.endproc

; ============================================================
; Respawn coin
; Generates random position on metatile 00 or 11 (passable)
; Method: Lfsr for X (0-15) and Y (0-11), validates with get_metatile
; If it fails 32 times, uses table of safe positions
; ============================================================
.proc respawn_coin
  LDA #$00
  STA respawn_count

search_loop:
  ; --- Attempt limit ---
  INC respawn_count
  LDA respawn_count
  CMP #$20
  BEQ use_fallback

  ; --- Generate col X: 0-15 ---
  ; Advance Lfsr twice for X to mix more bits
  JSR lfsr_tick
  JSR lfsr_tick
  AND #$0F            ; Range 0-15
  STA respawn_x

  ; --- Generate row Y: 0-11 ---
  ; Advance Lfsr twice for Y for independence from X
  JSR lfsr_tick
  JSR lfsr_tick
  AND #$0F            ; Range 0-15
  CMP #$0C            ; If >= 12, reject and retry
  BCS search_loop
  STA respawn_y

  ; --- Verify that the metatile is passable (00 or 11) ---
  ; get_metatile expects mt_col and mt_row in metatile coordinates
  LDA respawn_x
  STA mt_col
  LDA respawn_y
  STA mt_row
  JSR get_metatile
  ; A = Metatile Id: 0=free ground, 1=wall, 2=wall, 3=special ground

  CMP #$00
  BEQ position_valid
  CMP #$03
  BEQ position_valid

  ; Solid metatile: reject and retry
  ; Advance Lfsr one extra step to avoid repeating the same value
  JSR lfsr_tick
  JMP search_loop

position_valid:
  ; Convert metatile coordinate to pixel (multiply by 16)
  LDA respawn_x
  ASL A
  ASL A
  ASL A
  ASL A
  STA coin_x

  LDA respawn_y
  ASL A
  ASL A
  ASL A
  ASL A
  STA coin_y

  LDA #$01
  STA coin_active
  RTS

; ============================================================
; Fallback: table of 16 known passable positions
; Use Lfsr to choose one, so it doesn't always land on the same
; ============================================================
use_fallback:
  JSR lfsr_tick
  AND #$0F            ; Index 0-15
  CMP #num_safe
  BCC valid_index
  AND #$07            ; Reduce to 0-7 if past num_safe
valid_index:
  ASL A               ; Each entry occupies 2 bytes (x, y)
  TAX
  LDA safe_positions, X
  STA coin_x
  LDA safe_positions+1, X
  STA coin_y
  LDA #$01
  STA coin_active
  RTS
.endproc

; ============================================================
; Table of safe positions (pixels already multiplied by 16)
; Only positions on confirmed metatiles 00 or 11
; ============================================================
safe_positions:
  .byte $50, $50   ; Col=5, row=5
  .byte $70, $50   ; Col=7, row=5
  .byte $90, $50   ; Col=9, row=5
  .byte $B0, $50   ; Col=11, row=5
  .byte $50, $70   ; Col=5, row=7
  .byte $70, $70   ; Col=7, row=7
  .byte $90, $70   ; Col=9, row=7
  .byte $B0, $70   ; Col=11, row=7
  .byte $50, $90   ; Col=5, row=9
  .byte $70, $90   ; Col=7, row=9
  .byte $90, $90   ; Col=9, row=9
  .byte $B0, $90   ; Col=11, row=9
  .byte $50, $B0   ; Col=5, row=11
  .byte $70, $B0   ; Col=7, row=11
  .byte $90, $B0   ; Col=9, row=11
  .byte $B0, $B0   ; Col=11, row=11
num_safe = 16

; ============================================================
; Update coin
; ============================================================
.proc update_coin
  LDA coin_active
  CMP #$01
  BNE coin_inactive

  ; --- Check collision with player ---
  ; Calculate |player_x - coin_x|
  LDA player_x
  SEC
  SBC coin_x
  BCS x_diff
  EOR #$FF
  CLC
  ADC #$01
x_diff:
  CMP #$10            ; Threshold: 16 pixels
  BCS update_animation

  ; Calculate |player_y - coin_y|
  LDA player_y
  SEC
  SBC coin_y
  BCS y_diff
  EOR #$FF
  CLC
  ADC #$01
y_diff:
  CMP #$10
  BCS update_animation

collect_coin:
  INC player_score
  BNE no_overflow
  INC player_score+1
no_overflow:
  ; Increment global speed
  JSR inc_speed 
  ; Advance Lfsr a few times before respawn to
  ; ensure the seed has already changed since last time
  JSR lfsr_tick
  JSR lfsr_tick
  JSR lfsr_tick
  JSR respawn_coin
  RTS

coin_inactive:
  RTS

; --- Ping-pong animation ---
update_animation:
  INC coin_anim_timer
  LDA coin_anim_timer
  CMP #$0C
  BNE skip_anim
  LDA #$00
  STA coin_anim_timer
  LDA coin_dir
  BNE anim_going_down
  INC coin_frame
  LDA coin_frame
  CMP #$02
  BNE skip_anim
  LDA #$01
  STA coin_dir
  JMP skip_anim
anim_going_down:
  DEC coin_frame
  LDA coin_frame
  CMP #$00
  BNE skip_anim
  LDA #$00
  STA coin_dir
skip_anim:
  ; Advance Lfsr every frame so the seed never
  ; gets stuck when respawn time comes
  JSR lfsr_tick
  RTS
.endproc

; ============================================================
; Draw coin
; ============================================================
.proc draw_coin
  LDA coin_active
  CMP #$01
  BEQ draw_it

  ; Hide sprites
  LDA #$FF
  STA $0230
  STA $0234
  STA $0238
  STA $023c
  RTS

draw_it:
  LDA coin_frame
  CMP #$00
  BEQ use_frame0
  CMP #$01
  BEQ use_frame1
  JMP use_frame2

use_frame0:
  LDA #$49
  STA tile_base
  LDA #%00000010
  STA attr_base
  JMP draw_sprites_normal

use_frame1:
  LDA #$4D
  STA tile_base
  LDA #%00000010
  STA attr_base
  JMP draw_sprites_normal

use_frame2:
  JMP draw_sprites_frame2

draw_sprites_normal:
  LDA coin_y
  SEC
  SBC #1
  STA temp
  CLC
  ADC #$08
  STA ppu_lo

  LDA temp
  STA $0230
  LDA tile_base
  STA $0231
  LDA attr_base
  STA $0232
  LDA coin_x
  STA $0233

  LDA temp
  STA $0234
  LDA tile_base
  CLC
  ADC #$01
  STA $0235
  LDA attr_base
  STA $0236
  LDA coin_x
  CLC
  ADC #$08
  STA $0237

  LDA ppu_lo
  STA $0238
  LDA tile_base
  CLC
  ADC #$02
  STA $0239
  LDA attr_base
  STA $023a
  LDA coin_x
  STA $023b

  LDA ppu_lo
  STA $023c
  LDA tile_base
  CLC
  ADC #$03
  STA $023d
  LDA attr_base
  STA $023e
  LDA coin_x
  CLC
  ADC #$08
  STA $023f
  RTS

draw_sprites_frame2:
  LDA coin_y
  SEC
  SBC #1
  STA temp
  CLC
  ADC #$08
  STA ppu_lo

  LDA #%01000010
  STA attr_base

  LDA temp
  STA $0230
  LDA #$4A
  STA $0231
  LDA attr_base
  STA $0232
  LDA coin_x
  STA $0233

  LDA temp
  STA $0234
  LDA #$49
  STA $0235
  LDA attr_base
  STA $0236
  LDA coin_x
  CLC
  ADC #$08
  STA $0237

  LDA ppu_lo
  STA $0238
  LDA #$4C
  STA $0239
  LDA attr_base
  STA $023a
  LDA coin_x
  STA $023b

  LDA ppu_lo
  STA $023c
  LDA #$4B
  STA $023d
  LDA attr_base
  STA $023e
  LDA coin_x
  CLC
  ADC #$08
  STA $023f
  RTS
.endproc