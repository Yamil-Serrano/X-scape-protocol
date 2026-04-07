; ============================================================
; hud.asm - Hud with Scr at top and Vit at bottom
; Game over blinking (visible 30 frames, hidden 30 frames)
; ============================================================

.export update_score_hud
.export draw_hud
.export take_damage

; --- Import zero page variables from main.asm ---
.importzp player_score, player_hp
.importzp hud_score_hundreds, hud_score_tens, hud_score_units
.importzp gameover_blink_timer, temp, temp2

HUD_Y_SCR = $D7
HUD_Y_VIT = $DF
HUD_ATTR  = %00000000
HUD_HIDE  = $FF

; ============================================================
; Update score hud
; ============================================================
.proc update_score_hud
  LDA player_score
  STA temp
  LDA player_score+1
  STA temp2

  LDA #$00
  STA hud_score_hundreds
@h_loop:
  LDA temp2
  BNE @h_sub
  LDA temp
  CMP #100
  BCC @h_done
@h_sub:
  LDA temp
  SEC
  SBC #100
  STA temp
  LDA temp2
  SBC #$00
  STA temp2
  INC hud_score_hundreds
  JMP @h_loop
@h_done:

  LDA #$00
  STA hud_score_tens
@t_loop:
  LDA temp
  CMP #10
  BCC @t_done
  SEC
  SBC #10
  STA temp
  INC hud_score_tens
  JMP @t_loop
@t_done:

  LDA temp
  STA hud_score_units
  RTS
.endproc

; ============================================================
; Take damage
; ============================================================
.proc take_damage
  LDA player_hp
  BEQ @already_dead
  DEC player_hp
@already_dead:
  RTS
.endproc

; ============================================================
; Draw hud
; ============================================================
.proc draw_hud
  ; Update game over blink timer
  INC gameover_blink_timer
  LDA gameover_blink_timer
  CMP #60        ; Change every 60 frames (1 second)
  BCC @check_blink
  LDA #$00
  STA gameover_blink_timer
@check_blink:

  LDA player_hp
  BNE @show_normal_hud
  JMP @show_gameover

@show_normal_hud:
  ; ==========================================
  ; Top row (Y=$D7): Scr: 000
  ; ==========================================
  
  ; S
  LDA #HUD_Y_SCR
  STA $0240
  LDA #$79
  STA $0241
  LDA #HUD_ATTR
  STA $0242
  LDA #$10
  STA $0243

  ; C
  LDA #HUD_Y_SCR
  STA $0244
  LDA #$7A
  STA $0245
  LDA #HUD_ATTR
  STA $0246
  LDA #$18
  STA $0247

  ; R
  LDA #HUD_Y_SCR
  STA $0248
  LDA #$7B
  STA $0249
  LDA #HUD_ATTR
  STA $024A
  LDA #$20
  STA $024B

  ; :
  LDA #HUD_Y_SCR
  STA $024C
  LDA #$7C
  STA $024D
  LDA #HUD_ATTR
  STA $024E
  LDA #$28
  STA $024F

  ; Space
  LDA #HUD_HIDE
  STA $0250
  LDA #$00
  STA $0251
  LDA #$00
  STA $0252
  LDA #$30
  STA $0253

  ; Hundreds
  LDA #HUD_Y_SCR
  STA $0254
  LDA hud_score_hundreds
  CLC
  ADC #$80
  STA $0255
  LDA #HUD_ATTR
  STA $0256
  LDA #$38
  STA $0257

  ; Tens
  LDA #HUD_Y_SCR
  STA $0258
  LDA hud_score_tens
  CLC
  ADC #$80
  STA $0259
  LDA #HUD_ATTR
  STA $025A
  LDA #$40
  STA $025B

  ; Units
  LDA #HUD_Y_SCR
  STA $025C
  LDA hud_score_units
  CLC
  ADC #$80
  STA $025D
  LDA #HUD_ATTR
  STA $025E
  LDA #$48
  STA $025F

  ; ==========================================
  ; Bottom row (Y=$DF): Vit: ❤❤❤
  ; ==========================================

  ; V
  LDA #HUD_Y_VIT
  STA $0260
  LDA #$8B
  STA $0261
  LDA #HUD_ATTR
  STA $0262
  LDA #$10
  STA $0263

  ; I
  LDA #HUD_Y_VIT
  STA $0264
  LDA #$7D
  STA $0265
  LDA #HUD_ATTR
  STA $0266
  LDA #$18
  STA $0267

  ; T
  LDA #HUD_Y_VIT
  STA $0268
  LDA #$7E
  STA $0269
  LDA #HUD_ATTR
  STA $026A
  LDA #$20
  STA $026B

  ; :
  LDA #HUD_Y_VIT
  STA $026C
  LDA #$7C
  STA $026D
  LDA #HUD_ATTR
  STA $026E
  LDA #$28
  STA $026F

  ; Space
  LDA #HUD_HIDE
  STA $0270
  LDA #$00
  STA $0271
  LDA #$00
  STA $0272
  LDA #$30
  STA $0273

  ; Heart 1
  LDA player_hp
  CMP #1
  BCS @heart1_on
  LDA #HUD_HIDE
  STA $0274
  JMP @heart1_done
@heart1_on:
  LDA #HUD_Y_VIT
  STA $0274
@heart1_done:
  LDA #$7F
  STA $0275
  LDA #HUD_ATTR
  STA $0276
  LDA #$38
  STA $0277

  ; Heart 2
  LDA player_hp
  CMP #2
  BCS @heart2_on
  LDA #HUD_HIDE
  STA $0278
  JMP @heart2_done
@heart2_on:
  LDA #HUD_Y_VIT
  STA $0278
@heart2_done:
  LDA #$7F
  STA $0279
  LDA #HUD_ATTR
  STA $027A
  LDA #$40
  STA $027B

  ; Heart 3
  LDA player_hp
  CMP #3
  BCS @heart3_on
  LDA #HUD_HIDE
  STA $027C
  JMP @heart3_done
@heart3_on:
  LDA #HUD_Y_VIT
  STA $027C
@heart3_done:
  LDA #$7F
  STA $027D
  LDA #HUD_ATTR
  STA $027E
  LDA #$48
  STA $027F

  ; Hide game over
  LDA #HUD_HIDE
  STA $0280
  STA $0284
  STA $0288
  STA $028C
  STA $0290
  STA $0294
  STA $0298
  STA $029C
  JMP @hud_done

  ; ==========================================
  ; Game over (blinking)
  ; ==========================================
@show_gameover:
  ; Hide Scr
  LDA #HUD_HIDE
  STA $0240
  STA $0244
  STA $0248
  STA $024C
  STA $0250
  STA $0254
  STA $0258
  STA $025C

  ; Hide Vit and hearts
  STA $0260
  STA $0264
  STA $0268
  STA $026C
  STA $0270
  STA $0274
  STA $0278
  STA $027C

  ; Check whether to show or not (blinking)
  LDA gameover_blink_timer
  CMP #30        ; 30 frames visible, 30 invisible
  BCC @show_gameover_sprites
  ; Hide game over
  LDA #HUD_HIDE
  STA $0280
  STA $0284
  STA $0288
  STA $028C
  STA $0290
  STA $0294
  STA $0298
  STA $029C
  JMP @hud_done

@show_gameover_sprites:
  ; G
  LDA #$D7
  STA $0280
  LDA #$8C
  STA $0281
  LDA #HUD_ATTR
  STA $0282
  LDA #$70
  STA $0283

  ; A
  LDA #$D7
  STA $0284
  LDA #$8D
  STA $0285
  LDA #HUD_ATTR
  STA $0286
  LDA #$78
  STA $0287

  ; M
  LDA #$D7
  STA $0288
  LDA #$8E
  STA $0289
  LDA #HUD_ATTR
  STA $028A
  LDA #$80
  STA $028B

  ; E
  LDA #$D7
  STA $028C
  LDA #$8F
  STA $028D
  LDA #HUD_ATTR
  STA $028E
  LDA #$88
  STA $028F

  ; O
  LDA #$DF
  STA $0290
  LDA #$80
  STA $0291
  LDA #HUD_ATTR
  STA $0292
  LDA #$70
  STA $0293

  ; V
  LDA #$DF
  STA $0294
  LDA #$8B
  STA $0295
  LDA #HUD_ATTR
  STA $0296
  LDA #$78
  STA $0297

  ; E
  LDA #$DF
  STA $0298
  LDA #$8F
  STA $0299
  LDA #HUD_ATTR
  STA $029A
  LDA #$80
  STA $029B

  ; R
  LDA #$DF
  STA $029C
  LDA #$7B
  STA $029D
  LDA #HUD_ATTR
  STA $029E
  LDA #$88
  STA $029F

@hud_done:
  RTS
.endproc