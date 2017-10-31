globals [
  gini-index-reserve
  lorenz-points
  total-tax
]

breed [ students student ]

patches-own [
  psugar           ;; the amount of sugar on this patch
  max-psugar       ;; the maximum amount of sugar that can be on this patch
  true-color       ;; since all the patches will appear to be grey when hiding the world, they need a variable to store their true color
]

students-own
[
  user-id   ;; students choose a user name when they log in whenever you receive a
            ;; message from the student associated with this turtle hubnet-message-source
            ;; will contain the user-id
  sugar           ;; the amount of sugar this turtle has
  metabolism      ;; the amount of sugar that each turtles loses each tick
  vision          ;; the distance that this turtle can see in the horizontal and vertical directions
  vision-points   ;; the points that this turtle can see in relative to it's current position (based on vision)
  age             ;; the current age of this turtle (in ticks)
  max-age
  generation  ;;;;;;;;;when turtles die, they are not removed from the model. Instead, they "reborn" with new randomly assigned environment and traits
              ;;;;;;;;;generation starts with 1 when students log in, and increase by 1 after each time they are reborn.
  accumulative-sugar
  next-task  ;; the next task a turtle will run. Can be either harvest, invest, go-to-school, or chill.
  state  ;; the current state a turtle is in. Used to switch between tasks. Can be either harvesting, investing, schooling, or chilling.
;  message-buffer
  investment-percentage
  tax-paid
  my-timer  ;; a countdown timer to disable movements when in a certain state, such as at school
]

;;;;;;;;;;;;;;;;;; Setup Procedures ;;;;;;;;;;;;;;;

to startup
  hubnet-reset
end

to setup
  clear-patches
  clear-drawing
  clear-output

  setup-patches

   ask patches [
      patch-growback
      patch-recolor
    ]

  listen-clients

  ask students
  [
    refresh-turtle
    set vision random-in-range 1 6

    hubnet-send user-id "message" "Welcome to SugarScape!"
    set generation 1
  ]
  if maximum-sugar-endowment <= minimum-sugar-endowment [
    user-message "Oops: the maximum-sugar-endowment must be larger than the minimum-sugar-endowment"
    stop
  ]

  update-lorenz-and-gini
  prepare-plots

  reset-ticks
end

to setup-patches
  file-open "sugar-map.txt"
  foreach sort patches [ p ->
    ask p [
      set max-psugar file-read
      set psugar max-psugar
      set pcolor gray
    ]
  ]
  file-close
end

to prepare-plots
  clear-all-plots
;  set-current-plot "Wealth distribution"
;  auto-plot-on
;  create-temporary-plot-pen "default"
;  set-plot-pen-mode 1
;  set-histogram-num-bars 10
;  set-plot-pen-interval ((max [sugar] of turtles) / 10)

  set-current-plot "Lorenz curve"
  create-temporary-plot-pen "equal"
  set-plot-pen-color black
  ;; draw a straight line from lower left to upper right
  set-current-plot-pen "equal"
  set-plot-pen-interval 100
  plot 0
  plot 100
  create-temporary-plot-pen "lorenz"
  set-plot-pen-color red

  set-current-plot "Gini index vs. time"
  create-temporary-plot-pen "default"
  set-plot-pen-color blue
  set-plot-x-range 0 100
  set-plot-y-range 0 1
end

;;;;;;;;;;;;;;Run Time Procedure;;;;;;;;;;;;;

to go
  listen-clients
  every 0.1 [
    if not any? students [
      stop
    ]
    ask patches [
      patch-growback
      patch-recolor
    ]
    ask students [
      ifelse generations [
        ifelse inheritance [
          get-older
          if age > max-age [ hubnet-send user-id "message" "you died due to age and now you are reborn as a child of the dead person" inherit set generation generation + 1 set my-timer 12 set next-task [-> reborn] set state "reborn" stop]
          if sugar <= 0 [ hubnet-send user-id "message" "you died due to poverty and now you are reborn as a child of the dead person" inherit set generation generation + 1 set my-timer 12 set next-task [-> reborn] set state "reborn" stop]
          run next-task
        ][
          get-older
          ifelse age > max-age [ hubnet-send user-id "message" "you died due to age and now you are reborn as a random new person" refresh-turtle set generation generation + 1 set my-timer 12 set next-task [-> reborn] set state "reborn"]
          [
            if sugar <= 0 [ hubnet-send user-id "message" "you died due to poverty and now you are reborn as a random new person" refresh-turtle set generation generation + 1 set my-timer 12 set next-task [-> reborn] set state "reborn"]
          ]

          run next-task
        ]
      ]
      [
        if sugar <= 0 [set sugar metabolism]; turtles don't die. they just stay alive
        run next-task          ;execute-command message-buffer
      ]
      send-info-to-clients
    ]
    redistribute
    update-lorenz-and-gini
    show-plots
    tick
  ]
end

to redistribute
  if ticks mod 24 = 0 [
    if tax and redistribute-tax  [
      let redistribution-recipients-num count students with [sugar <= poverty-line]
      if redistribution-recipients-num > 0 [
        let redistribution-amount-per-person total-tax / redistribution-recipients-num
        ask students with [sugar <= poverty-line] [
          set total-tax total-tax - redistribution-amount-per-person
          set sugar sugar + redistribution-amount-per-person
        ]
      ]
    ]
    set total-tax 0
  ]
end

to inherit
  move-to one-of neighbors with [not any? other turtles-here]
  visualize-view-points
  ifelse sugar <= 0 [
    set sugar minimum-sugar-endowment
  ][
    ifelse sugar - sugar * .1 > 0 [
      set sugar sugar + (random (sugar * .1) - random (sugar * .1))
    ][
      set sugar sugar + random (sugar * .1)
    ]
  ]
  ifelse vision = 1 [
    set vision vision + random 2
  ][
    ifelse vision = 6 [
      set vision vision - random 2
    ][
      set vision vision + (random 2 - random 2)
    ]
  ]
  ifelse metabolism = 1 [
    set metabolism metabolism + random 2
  ][
    ifelse metabolism = 4 [
      set metabolism metabolism - random 2
    ][
      set metabolism metabolism + (random 2 - random 2)
    ]
  ]
  ifelse max-age > 90 [
    set max-age 100 - random 10
  ][
    ifelse max-age < 70 [
      set max-age 60 + random 10
    ][
      set max-age max-age + (random 10 - random 10)
    ]
  ]
  set accumulative-sugar 0
  set age 0
  set generation generation + 1
  set tax-paid 0
  set investment-percentage 50
;  set vision-points nobody
  set next-task [-> chill]
  set state "chilling"
;  hubnet-send-follow hubnet-message-source self 7
;  hubnet-send user-id "message" ""
  send-info-to-clients
end

to get-older
  if ticks mod 24 = 0 [set age age + 1]
  hubnet-send user-id "age" age
end

;to reborn-random
;  set generation generation + 1
;  hubnet-send user-id "message" "you died are reborn as a random new person"
;end

;;;;;;;;;;;NubNet Procedures;;;;;;;;;;;;;

to listen-clients
  while [ hubnet-message-waiting? ]
  [
    hubnet-fetch-message
    ifelse hubnet-enter-message?
    [ create-new-student ]
    [
      ifelse hubnet-exit-message?
      [ remove-student ]
      [ ask students with [user-id = hubnet-message-source]
        ;[ ask students with [user-id = hubnet-message-source] [set message-buffer hubnet-message-tag ]];
        [ execute-command hubnet-message-tag ]
      ]
    ]
  ]
end

to create-new-student
  create-students 1
  [
    set user-id hubnet-message-source
    set label-color black
    set label user-id
    set color red
    refresh-turtle
    set vision random-in-range 1 6
    set generation 1
    hubnet-send user-id "message" word "You are Generation " generation
  ]
end

to refresh-turtle ; turtle procedure

  set shape "default"

  move-to one-of patches with [not any? other turtles-here]

;  set vision random-in-range 1 6
  set vision-points nobody

  visualize-view-points

  set sugar random-in-range minimum-sugar-endowment maximum-sugar-endowment
  set accumulative-sugar 0
  set investment-percentage 50
  set tax-paid 0
  set metabolism random-in-range 1 4
  set max-age random-in-range 60 100
  set age 0
  set next-task [-> chill]
  set state "chilling"
  hubnet-send-follow user-id self 7
  send-info-to-clients
end

to remove-student
  ask students with [ user-id = hubnet-message-source ]
  [ die ]
end

to execute-command [command]
  if command = "up" [ execute-move 0 ]
  if command = "down" [ execute-move 180 ]
  if command = "right" [ execute-move 90 ]
  if command = "left" [ execute-move 270 ]
  if command = "harvest" [ harvest-pressed ]
  if command = "go-to-school" [ go-to-school-pressed ]
  if command = "invest" [ invest-pressed ]
  if command = "investment-percentage" [ set investment-percentage hubnet-message ]
end

to send-info-to-clients ; turtle procedure
  hubnet-send-override user-id patch-here "pcolor" [true-color]

  hubnet-send user-id "vision" vision
  hubnet-send user-id "metabolism" metabolism
  hubnet-send user-id "age" age
  hubnet-send user-id "generation" generation
  hubnet-send user-id "count-down" my-timer
  hubnet-send user-id "investment-percentage" investment-percentage

  hubnet-send user-id "current-sugar" sugar
  hubnet-send user-id "accumulative-sugar" accumulative-sugar
  hubnet-send user-id "wealth-ranking" (position sugar reverse sort [sugar] of students) + 1
  hubnet-send user-id "rate-of-return" investment-rate-of-return
  hubnet-send user-id "tax-rate" tax-rate
  hubnet-send user-id "current-tax-paid" tax-paid
end

to-report tax-rate
  ifelse sugar > poverty-line [report tax-rate-rich][report tax-rate-poor]
end

;;;;;;;;;;;;;;;;;HubNet Commands;;;;;;;;;;;

to calculate-view-points [dist] ; turtle procedure

  set vision-points patches in-radius dist with [ (pxcor = [pxcor] of [patch-here] of myself) or (pycor = [pycor] of [patch-here] of myself) ]

;  foreach (range 1 (dist + 1)) [ n ->
;   set vision-points (patch-set vision-points
;      patch-at 0 n
;      patch-at n 0
;      patch-at 0 (- n)
;      patch-at (- n) 0)
;  ]
;  if dist > 0 [
;
;    set vision-points (patch-set
;      vision-points
;      patch-at 0 dist
;      patch-at dist 0
;      patch-at 0 (- dist)
;      patch-at (- dist) 0
;    )
;    calculate-view-points (dist - 1)
;  ]
end

to visualize-view-points ; student procedure
    hubnet-clear-overrides user-id
    calculate-view-points vision
    hubnet-send-override user-id vision-points "pcolor" [ true-color ]
    set vision-points nobody
end

to chill
end

to reborn
  set shape "x"
  ifelse my-timer > 0 [
    set my-timer my-timer - 1
  ][
    set state "chilling"
    set next-task [ -> chill ]
set vision random-in-range 1 6;;;;need to add a condition to account for the inherit death
    set shape "default"
  ]
end

to execute-move [new-heading] ; student procedure
  ; "chilling" = move otherwise you can't
  ifelse state = "chilling" [
    set heading new-heading
    fd 1
    hubnet-send user-id "message" "moving..."
    visualize-view-points
    set sugar sugar - 1
    send-info-to-clients
    hubnet-send user-id "message" ""
    stop
  ][
    hubnet-send user-id "message" word "can't move because you are " state
  ]
end

to harvest-pressed
  ifelse state = "harvesting" [
    hubnet-send user-id "message" "already harvesting"
  ][
    ifelse state = "investing" [
      hubnet-send user-id "message" "can't havest because you are investing"
    ][
      ifelse state = "schooling"[
        hubnet-send user-id "message" "can't havest because you are at school"
      ][
        set state "harvesting"
        set next-task [-> harvest]
      ]
    ]
  ]
end

to harvest
  hubnet-send user-id "message" "harvesting..."
  ifelse tax [
    ifelse sugar > poverty-line [
      set tax-paid psugar * tax-rate-rich / 100
      set total-tax total-tax + tax-paid
      set sugar sugar - metabolism + psugar - tax-paid
    ][
      set tax-paid psugar * tax-rate-poor / 100
      set total-tax total-tax + tax-paid
      set sugar sugar - metabolism + psugar - tax-paid
    ]
  ][
  set sugar (sugar - metabolism + psugar)
  set accumulative-sugar accumulative-sugar + psugar
  ]
  set psugar 0
  set next-task [-> chill]
  set state "chilling"
  wait .05
  hubnet-send user-id "message" ""
end

to go-to-school-pressed
  ifelse education [
  ifelse sugar > tuition [
    ifelse vision < 6 [
      ifelse state = "schooling" [
        hubnet-send user-id "message" "you are already at school"
      ][
        ifelse state = "chilling" [
          set state "schooling"
          set my-timer 48
          set sugar sugar - tuition
          set next-task [-> school]
          hubnet-send user-id "message" "at school..."
        ][
          hubnet-send user-id "message" word "can't go to school because you are" state
        ]
      ]
    ][
      hubnet-send user-id "message" "You already have the best vision"
    ]
  ][
    hubnet-send user-id "message" word "you need " word tuition " sugar for tuition"
  ]
  ][
    hubnet-send user-id "message" "education doesn't exist in this world"
  ]
end

to school
  ifelse my-timer > 0 [
    set my-timer my-timer - 1
  ][
      set vision vision + 1
      visualize-view-points
      hubnet-send user-id "message" "You graduated with expanded vision"
      set next-task [-> chill]
      set state "chilling"
  ]
end

to invest-pressed
  ifelse investment [
  ifelse sugar >= poverty-line [
    ifelse state = "investing" [
      hubnet-send user-id "message" "you are already investing"
    ][
      if state = "chilling" [
        set state "investing"
        set my-timer 24
        set next-task [-> invest]
        hubnet-send user-id "message" "investing..."
      ]
    ]
  ][
    hubnet-send user-id "message" word "minimum investment " word poverty-line " sugar"
  ]
  ][
    hubnet-send user-id "message" "investing doesn't exist in this world"
  ]
end

to invest
  ifelse my-timer > 0 [
    set my-timer my-timer - 1
  ][
    let principal sugar * investment-percentage / 100
    let investment-return precision (principal * (1 + investment-rate-of-return / 100)) 2
    ifelse tax [
      set tax-paid precision (investment-return * tax-rate / 100) 2
      set total-tax total-tax + tax-paid
      set sugar precision (sugar - principal + investment-return - tax-paid) 2
      set accumulative-sugar accumulative-sugar + precision (investment-return - tax-paid) 2
    ][
      set sugar precision (sugar - principal + investment-return) 2
      set accumulative-sugar accumulative-sugar + precision (investment-return) 2
    ]
    set next-task [ -> chill ]
    set state "chilling"
    hubnet-send user-id "message" word "investment return this period: " word precision (investment-return) 2 " sugar"
  ]
end

to patch-recolor
  set true-color (yellow + 4.9 - psugar)
end

to patch-growback
  set psugar min (list max-psugar (psugar + 1))
end

to update-lorenz-and-gini
  let num-people count turtles
  let sorted-wealths sort [sugar] of turtles
  ;  show word "sorted-wealths" sorted-wealths
  let total-wealth sum sorted-wealths
  ;  show word "total-wealth" total-wealth
  let wealth-sum-so-far 0
  let index 0
  set gini-index-reserve 0
  set lorenz-points []

  repeat num-people [
    set wealth-sum-so-far (wealth-sum-so-far + item index sorted-wealths)
    set lorenz-points lput ((wealth-sum-so-far / total-wealth) * 100) lorenz-points
    set index (index + 1)
    set gini-index-reserve
    gini-index-reserve +
    (index / num-people) -
    (wealth-sum-so-far / total-wealth)
  ]
end

to show-plots
;  set-current-plot "Wealth distribution"
;  histogram ([sugar] of students)

  set-current-plot "Lorenz curve"
  plot-pen-reset
  set-plot-pen-interval 100 / count turtles
  plot 0
  foreach lorenz-points plot

  set-current-plot "Gini index vs. time"
  plot (gini-index-reserve / count turtles) * 2
end

to-report random-in-range [low high]
  report low + random (high - low + 1)
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
768
569
-1
-1
11.0
1
12
1
1
1
0
1
1
1
0
49
0
49
0
0
1
ticks
30.0

SLIDER
5
95
206
128
maximum-sugar-endowment
maximum-sugar-endowment
0
100
25.0
1
1
NIL
HORIZONTAL

SLIDER
5
63
206
96
minimum-sugar-endowment
minimum-sugar-endowment
0
100
5.0
1
1
NIL
HORIZONTAL

BUTTON
5
10
96
57
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
114
10
205
57
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
5
140
206
173
generations
generations
0
1
-1000

SWITCH
5
172
206
205
inheritance
inheritance
1
1
-1000

SWITCH
4
343
205
376
education
education
0
1
-1000

SWITCH
4
263
205
296
investment
investment
1
1
-1000

SWITCH
5
420
206
453
tax
tax
1
1
-1000

SLIDER
5
453
206
486
tax-rate-poor
tax-rate-poor
0
100
24.0
1
1
%
HORIZONTAL

SLIDER
5
486
206
519
tax-rate-rich
tax-rate-rich
0
100
29.0
1
1
%
HORIZONTAL

SLIDER
4
295
205
328
investment-rate-of-return
investment-rate-of-return
0
100
50.0
1
1
NIL
HORIZONTAL

BUTTON
209
574
314
607
show-world
ask patches [set pcolor true-color]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
320
574
420
607
hide-world
ask patches [set pcolor gray]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
4
217
205
250
poverty-line
poverty-line
0
2000
1800.0
50
1
sugar
HORIZONTAL

SLIDER
4
375
205
408
tuition
tuition
0
2400
24.0
24
1
sugar
HORIZONTAL

SWITCH
4
536
205
569
redistribute-tax
redistribute-tax
1
1
-1000

BUTTON
520
574
639
607
hide-students
ask turtles [ht]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
643
574
768
607
show-students
ask turtles [st]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
772
192
1024
380
Lorenz curve
Pop %
Wealth %
0.0
100.0
0.0
100.0
false
true
"" ""
PENS

PLOT
773
384
1025
568
Gini index vs. time
Time
Gini
0.0
100.0
0.0
1.0
true
false
"" ""
PENS

PLOT
771
11
1024
188
Wealth distribution
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" "set-histogram-num-bars 10\nif any? students [ \n  set-plot-x-range 0 (max [sugar] of students)\n  set-plot-pen-interval ((max [sugar] of students / 10))\n]"
PENS
"default" 1.0 1 -16777216 true "" "if any? students [ histogram ([sugar] of students) ]"

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
BUTTON
77
212
146
245
up
NIL
NIL
1
T
OBSERVER
NIL
W

BUTTON
77
256
146
289
down
NIL
NIL
1
T
OBSERVER
NIL
S

BUTTON
8
256
77
289
left
NIL
NIL
1
T
OBSERVER
NIL
A

BUTTON
146
256
215
289
right
NIL
NIL
1
T
OBSERVER
NIL
D

VIEW
225
67
825
667
0
0
0
1
1
1
1
1
0
1
1
1
0
49
0
49

MONITOR
6
10
825
59
message
NIL
0
1

MONITOR
57
117
135
166
generation
NIL
3
1

MONITOR
7
456
125
505
current-sugar
NIL
2
1

MONITOR
135
117
219
166
count-down
NIL
0
1

MONITOR
7
117
57
166
age
NIL
0
1

MONITOR
7
68
110
117
vision
NIL
0
1

MONITOR
110
68
219
117
metabolism
NIL
0
1

MONITOR
125
456
219
505
wealth-ranking
NIL
0
1

MONITOR
7
505
219
554
accumulative-sugar
NIL
0
1

MONITOR
7
554
75
603
tax-rate
NIL
0
1

MONITOR
7
603
117
652
rate-of-return
NIL
0
1

BUTTON
124
318
215
351
harvest
NIL
NIL
1
T
OBSERVER
NIL
H

BUTTON
6
405
219
438
invest
NIL
NIL
1
T
OBSERVER
NIL
J

BUTTON
8
318
124
351
go-to-school
NIL
NIL
1
T
OBSERVER
NIL
K

SLIDER
6
372
219
405
investment-percentage
investment-percentage
0.0
100.0
0
10.0
1
%
HORIZONTAL

MONITOR
75
554
219
603
current-tax-paid
NIL
2
1

@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
