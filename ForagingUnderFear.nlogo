;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                                                                                                             ;;
;;            LoFC -  Landscape-of-Fear-Community Model                                                        ;;  YY: find better name
;;                                                                                                             ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


globals
[
 ;; General 
  my-seed                                   ;; stores generated random seed

 ;; Landscape  
  cellsize                                  ;; size of one cell in m2   
  productivity-average                      ;; average food productivity in landscape cells
  productivity-community                    ;; share of food that is available to animal community
  productivity                              ;; food in landscape, g/(m2*day)
  foodcells                                 ;; number of food cells
  refugecells                               ;; number of refuge cells
  foodlimit                                 ;; lower boundary to which individuals can exploit food resources
  SafetyMatrix
 ;; Individuals
  attempt                                   ;; number of attempts an individual has to find a home range
  expo                                      ;; exponent of body mass input distribution used to select body mass of individuals
  gamma                                     ;; magnitude of food exploitation
  DecisionFactor                            ;; magnitude of safety in decision for a cell
  
 ;; Community
  nfail                                     ;; number of consecutively failing individuals needed to stop simulation
  commsaturation?                           ;; marker if nfail is reached
  
 ;; Output
  outputfilename                            ;; stores file name of outputfiles
  datafile                                  ;; stores home range size and traits of individuals
  pathfile                                  ;; stores movement path of individual
  patchfile-begin                           ;; stores landscape at the beginning of a run
  patchfile-end                             ;; stores landscape distribution at the end of a run
  outputfile                                ;; stores everything written in output area
  exploitfile                               ;; stores amount of exploited food per patch
  
 ;; Variables needed for home range search of individual
  c-attempt                                 ;; current number of attempts/tries to find home range
  c-path                                    ;; current movement path
  c-pathgain                                ;; current movement path including only cells with positive gain (needed for food consumption)
  c-hrsize                                  ;; size of current home range
  c-food                                    ;; stores amount of food that can be gained from cells currently in the home range
  c-exploit                                 ;; stores resource gain from each cell in the home range
  c-stopsearch?                             ;; stores if current hr is sufficient to fulfill feeding rate of individual
  c-free-patches                            ;; agentset containing currently free patches that were not already checked for home range
  c-possible-patches                        ;; agentset containing patches that the current individual can see
  c-new-ind                                 ;; agentset containing only the newly created individual in one step
]

patches-own
[
 ;; state variables  
  p-food                                    ;; amount of food resources in cell
  p-safety                                  ;; safety of cell
 
 ;; variables needed for output 
  p-nexploit                                ;; stores how often cell was exploited by individuals
  p-exploit                                 ;; stores amount of food that is exploited by individuals (list)
 ;; marker variables needed during home range search  
  p-suit                                    ;; stores degree of suitability of cell for addition to home range      
  p-hr?                                     ;; marks cells that are in home range of current individual             
]


turtles-own
[
 ;;allometric traits 
  i-bodymass                                ;; body mass
  i-maxhr                                   ;; maximum possible home range size
  i-lococost                                ;; locomotion costs
  i-feedrate                                ;; amount of food that the individual needs on a daily basis
  i-foodshare                               ;; factor for amount of food that individuals can exploit from cell
   
 ;; other traits 
  i-move-type                               ;; movement type of individual
  i-fear-type                               ;; response of individual to predation risk
  i-decfac                                  ;; decision factor, defines influence of safety on decision for a cell
  i-foodfac                                 ;; food factor, defines influence of safety on food exploitation if fear-type = "feeding"
  i-movefac                                 ;; movement costs factor, defines influence of safety on movement costs if fear-type = "moving"


 ;; marker variable 
  i-new                                     ;; marks turtle created in current step
  
 ;; variables for storing information about home range
  i-cores                                   ;; stores home range core
  i-hrsize                                  ;; stores home range size
  i-nohr?                                   ;; stores if individual fails to find home range
  i-path                                    ;; stores movement path within home range
  i-pathgain                                ;; stores patches with positive gain on movement path
  i-exploit                                 ;; stores amount of food that can be exploited from each cell along movement path
  i-overflow                                ;; stores food that could be exploited more but is not needed for fulfilling feeding rate
]
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; SETUP PROCEDURE_________________________________________________________________________________________________________

;; TO SETUP:
;; setup the simulation, initialize parameters, variables, landscape

to setup
  clear-all                                                                         ;; clear everything
  set my-seed new-seed                                                              ;; create new random seed
  random-seed my-seed                              
  output-print word "Generated seed: " my-seed     

  set-parameters                                                                    ;; initialize parameters
  set-landscape                                                                     ;; initialize landscape
  if visualize = true
   [ color-patches ]                                                                ;; visualize food and fear in landscape
  if output = true                                                                  ;; write output files
   [ output-begin  
   ]                                  
    
  reset-ticks
end
;;--------------------------------------------------------------------------------

;; SETUP Sub-procedures

;; TO SET-PARAMETERS:
;; initialize parameters of the simulation


to set-parameters
  
  set nfail 100                                                                     ;; number of consecutively failing individuals needed to stop simulation 
  set attempt 1                                                                     ;; number of attempts an individual has to find a home range
  set expo -1.5                                                                     ;; exponent for body mass input distribution used to define body mass of individuals, Buchmann 2011
  set gamma 1                                                                       ;; defines magnitude of food exploitation, Buchmann 2011
 
 ;; Landscape parameters
  set cellsize 4                                                                    ;; cellsize in m²
  set productivity-average 0.685                                                    ;; average productivity in shrub- and grasslands, Whittaker 1975
  set productivity-community 0.2                                                    ;; share of total productivity that is available to animal community, Buchmann 2011
  set productivity 0.685 * 0.2                                                      ;; amount of food that is available to individuals
  set foodlimit 0 ;productivity * cellsize * (1 - productivity-community)           ;; lower boundary to which individuals can exploit food resources  
  set SafetyMatrix 1 - SafetyRefuges                                                
  
 ;; calculate number of productive cells/refuges in random landscape 
  set foodcells world-width * world-height * ShareFood                              ;; number of cells with food in the landscape                 
  set refugecells foodcells * ShareRefuges                                          ;; number of refuge cells
  
  ;; check if values for safety in matrix and refuges are correct:
  if SafetyMatrix > SafetyRefuges 
   [user-message "Refuges are too risky!"]                                          ;; refuges are defined to have a lower predation risk than the matrix, therefore SafetyRefuges needs to be lower than SafetyMatrix 

 ;;Individual parameters
  set DecisionFactor 1                                                              ;; influences the magnitude of safety in the decision for a cell
  

 ;; initialize boolean variables  
 ;; (boolean variables need to be initialized with false, otherwise they are 0 by default)
  ask patches
   [ set p-hr? false                                                                ;; variable that stores if cell is included in hr of current individual
     set p-exploit []                                                               ;; variable that stores amount of food that was exploited by individual (list)
   ]                                                             
  set c-stopsearch? false                                                           ;; variable used for stopping home range search (if individual found a home range or failed to find a home range)
  set commsaturation? false                                                         ;; variable that stores if community is saturated
  
end
;--------------------------------------------------------------------------------

;; TO SET-LANDSCAPE:
;; initialize landscape layer with food resources and landscape layer with safety (landscape of fear)

to set-landscape   
                                              
 ;; initialize food and safety values in all patches
  ask patches
   [ set p-food 0                                                                   ;; initialize food values
     set p-safety SafetyMatrix                                                      ;; setup basic safety in landscape
   ]
   
 ;; distribute productive food patches
  ask n-of foodcells patches   
   [ set p-food productivity * cellsize ] 
  
 ;; distribute refuges
  ask n-of refugecells patches with [p-food = productivity * cellsize ]     ;; distribute safe cells overlapping with food cells
   [ set p-safety SafetyRefuges]

   
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; GO-PROCEDURE___________________________________________________________________

;; TO GO
;; main procedure of the program

to go
  species-pool                                                                      ;; choose individual from regional species pool
  traits                                                                            ;; assign traits to new individual
  search-hr                                                                         ;; search suitable home ranges for individual
  choose-hr                                                                         ;; choose most efficient home range
  consume-food-resources                                                            ;; consume resources in home range
  saturation                                                                        ;; check if community is saturated
  if output = true
  [ output-step 
  ]
  ask c-new-ind
   [ set i-new false ]
  if visualize = true
   [ color-patches ]
  tick
  if commsaturation? = true [ stop ]
end
;;-------------------------------------------------------

;; TO SINGLE-STEP
;; same as go, but makes only one step, saturation is not needed here

to single-step
  species-pool                                                                      ;; choose individual from regional species pool
  traits                                                                            ;; assign traits to new individual
  search-hr                                                                         ;; search suitable home ranges for individual
  choose-hr                                                                         ;; choose most efficient home range
  consume-food-resources                                                            ;; consume resources in home range
  ask c-new-ind
   [ set i-new false ]
  if visualize = true
   [ color-patches ]
  tick
end
;;-------------------------------------------------------

;; GO-Subprocedures

;; TO SPECIES-POOL:
;; create new individuals 
;; assign body mass to individual
;; calculate other traits based on allometric relationships
;; uses body mass input distribution to select body mass of the individual
;; based on upper and lower boundary of the body mass (upB, lowB, chosen by user in the GUI)
;; and the exponent (expo, -1.5 yields realistic communities, see Buchmann et al. 2011) 

to species-pool  
  
  let l-ran random-float 1
  crt 1
   [ set i-new true
    ;; body mass is taken from body mass input distribution
     set i-bodymass ((upB ^(expo + 1) - lowB ^(expo + 1))
                      * l-ran + lowB ^(expo + 1))^(1 / (expo + 1))                  ;; formula distributes random number as given by input probability distribution,  result is in kg
     set i-bodymass i-bodymass * 1000                                               ;; conversion to g
     if i-bodymass <= 0                                                             ;; safety question: if body-mass gets 0 or lower  YY: needed? mark special for easier finding --> Trace?
       [ output-print "Body-mass too low"]
     set color black
   ]
  
  set c-new-ind turtles with [i-new = true]                                         ;; create agentset that contains only the newly created individual (speeds up the model)
  if (count c-new-ind > 1) [ output-print "Too many new turtles!"]                  ;; safety question to make sure that only one turtle is newly created YY: Trace
end
;-----------------------------------------------------

;; TO TRAITS:
;; assign traits to newly created individual
;; most of them are calculated by using allometric relationships

to traits 
  ask c-new-ind    
   [ ;; allometric traits 
      set i-feedrate 0.323 * (i-bodymass ^ 0.744)                                   ;; daily feeding rate of mammals in g dry biomass/day, mass in g, Nagy 2001 
      calc-loco-cost                                                                ;; calculate locomotion costs
      calc-max-hr                                                                   ;; calculate maximum home range size
      set i-foodshare gamma * (i-bodymass ^ (-0.25))                                ;; magnitude of food exploitation, Haskell, 2002, Buchmann,2011
      
     ;; other traits
      set i-move-type MoveType                                                      ;; movement type, iCPF = informed central place forager, iPF = informed patrolling forager
      set i-fear-type FearType
      set i-foodfac FoodFactor
      ;set i-movefac MoveFactor
      set i-decfac DecisionFactor
     ;; initialize individual variables (especially lists need to be initialized for later usage)
      set size 2                                                                    ;; make turtles bigger for better visualization
      set i-hrsize []                                                               ;; empty list of possible home range sizes
      set i-cores []                                                                ;; empty list of home range cores
      set i-path []                                                                 ;; empty list of paths in home range
      set i-pathgain[]                                                              ;; empty list of efficient cells in path in home range
      set i-exploit []                                                              ;; empty list that stores amount of food exploited
      set i-overflow []                                                             ;; empty list that stores how much more food could be exploited from last cell but is not because feeding rate is already fulfilled
      set c-food 0                                                                  ;; stores temporary food in home range
      set i-nohr? false                                                             ;; stores if individual has found a home range or not
  ]
end

;-----------------------------------------------------
to calc-loco-cost 
  set i-lococost 0.0976 * (i-bodymass ^ 0.68)                                       ;; costs for mammals in J/m, mass in g, Calder, 1996
  set i-lococost i-lococost / 14000                                                 ;; conversion to costs in g dry biomass/m, Nagy, 2001
  set i-lococost i-lococost * (sqrt cellsize)                                       ;; locomotion costs in cell units
end
;-----------------------------------------------------
to calc-max-hr 
  set i-maxhr 0.0138 * (i-bodymass ^ 1.18)                                          ;; in ha, body mass in g, Kelt and Van Vuren, 2001, Buchmann, 2011
  set i-maxhr i-maxhr * 10000                                                       ;; in m2
  set i-maxhr i-maxhr / cellsize                                                    ;; in cells
  set i-maxhr ceiling i-maxhr                                                       ;; round to full cells, always take bigger number
  if i-maxhr > world-width * world-height                                           ;; if maximum home range size bigger then landscape it is reduced to landscape size to avoid that cells are included more than once in home range
   [ set i-maxhr world-width * world-height]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; TO SEARCH-HR:
;; home range search 
;; starting from a core cell individual adds cells to its home range
;; until food gain from cells in home range equals feeding rate          

to search-hr         

  set c-attempt 0                                                                   ;; individuals can have several attempts to find a home range, by default attempt is 1
                                                                                    ;; number of already made attempts is stored in temporary variable 
                                                     
 ;; starting from core cell individual adds cells until feeding rate is fulfilled 
  while [ c-attempt < attempt]                             
   [ core                                                                           ;; choose core cell of home range
     while [c-stopsearch? = false]                                                  ;; continues as long as individual has not found a home range that fulfills its feeding rate and has not failed to find a home range
      [ ask c-new-ind
         [ move                                                                     ;; move to next cell that might be included in home range
           check-efficiency                                                         ;; check if included cell is efficient
           check-feed-rate                                                          ;; check if feeding rate is fulfilled
         ]
      ]
      
    ;; remove temporary marks set during home range search  
     ask patches
      [ set p-hr? false                                   
      ]
     set c-stopsearch?  false
   ]
end
;--------------------------------------------------------

;; TO CORE:
;; choose core cell of home range

to core    
 
 ;; initialize variables needed during home range search 
  set c-path []                                                                     ;; stores current movement path for each attempt
  set c-pathgain []                                                                 ;; stores current movement path including only cells with positive gain (needed for food consumption)
  set c-exploit []                                                                  ;; stores resource gain for each atttempt
  set c-hrsize 0                                                                    ;; stores current home range size
  
  set c-attempt c-attempt + 1                                                       ;; increase attempts
 
 ;; find core cell, calculate and store food gain from it      
  ask c-new-ind
  [ move-to one-of patches with [p-food > 0]                                        ;; core cell is randomly chosen from productive cells 
    if visualize = true
     [ pd ]
    set i-cores lput patch-here i-cores                                             ;; store home range center
    set c-path lput patch-here c-path                                               ;; store center as first point in movement path
    set c-pathgain lput patch-here c-pathgain                                       ;; store core cell in movement path including only cells with positive gain
    set c-hrsize 1                                                                  ;; increase home range size
    
    set c-food p-food * i-foodshare                                                 ;; calculate and store potential food gain from core cell (no locomotion costs here, no predation risk in core cell)
    set c-exploit lput (p-food * i-foodshare) c-exploit                             ;; store amount of food that can be exploited from the cell                                 
   
    if p-food - c-food < foodlimit                                                  ;; reduce food gain if individual would exploit more food from the cell than is available to the community
     [ set c-food p-food - foodlimit 
       set c-exploit but-last c-exploit                                             ;; remove last item of the exploit list
       set c-exploit lput (p-food - foodlimit) c-exploit                            ;; and replace with new exploit value
     ]
    
    set p-hr? true                                                                  ;; mark core cell as part of home range
    check-feed-rate                                                                 ;; check if feed-rate is already fulfilled by core cell
    
  ]
  
 set c-free-patches patches with [p-hr? = false]                                    ;; define new agentset only containing patches which are not already in home range or marked as inefficient 
  
end
;--------------------------------------------------------

;; TO MOVE:
;; individual moves to one of the neighbouring cells 
;; decision where to move is based on food in cells and safety of cell 
to move
  
 ifelse any? c-free-patches                                                         ;; safety question to avoid that individual cannot move to a cell
  [ let l-neighbor-patches patch-set [neighbors] of patch-here
    set c-possible-patches l-neighbor-patches with [member? self c-free-patches]    ;; only neighbouring patches that are not already in home range or marked as inefficient are considered
    
    let l-decfac i-decfac                                                           ;; to make i-decfac available to patches
    let l-core last i-cores                                                         ;; to make i-core available to patches
    let l-fear-type i-fear-type
    ifelse any? c-possible-patches
     [ ask c-possible-patches
        [ ifelse l-fear-type = "no"
           [ set p-suit p-food ]
           [ set p-suit p-food * p-safety * l-decfac ]                              ;; calculate suitability of each cell for addition in home range
        ]                                 
                                                                                    ;; based on food content and safety in cell, l-decfac = defines how important safety is in decision for cell 
       ifelse any? c-possible-patches with [ p-suit > 0]                              
        [ if i-move-type = "iCPF" 
           [ ;; face and move to patch with maximum suitability and minimum distance to core
             let bestpatches c-possible-patches with-max [p-suit]
             face one-of bestpatches with-min [distance l-core]
             move-to patch-ahead 1 
           ]
          if i-move-type = "iPF"
           [ ;; face and move to patch with maximum suitability
             face max-one-of c-possible-patches [p-suit]                            
             move-to patch-ahead 1   
           ]
        ]
        ;; else: no possible patch with food or safety > 0
        [ ifelse i-fear-type = "no"
           [ if i-move-type = "iCPF"
              [ ifelse member? patch-ahead 1 c-possible-patches 
                [ move-to patch-ahead 1 ]
                [ face one-of c-possible-patches with-min [distance l-core]          ;; in control iCPF-individuals choose cell with lowest distance to core
                  move-to patch-ahead 1
                ]
              ]
             if i-move-type = "iPF"
              [ ifelse member? patch-ahead 1 c-possible-patches 
                [ move-to patch-ahead 1 ]
                [ face one-of c-possible-patches 
                  move-to patch-ahead 1
                ]
              ]         
           ]
           [ if i-move-type = "iCPF"
              [ ;; if patch-ahead is safest, move there (to have straight movement in areas without food)
                ;; otherwise choose direction with minimum distance to core
                let safestpatches c-possible-patches with-max [p-safety]                
                ifelse member? patch-ahead 1 safestpatches
                 [ move-to patch-ahead 1 ]               
                 [ face one-of safestpatches with-min [distance l-core]
                   move-to patch-ahead 1                   
                 ]           ]
           if i-move-type = "iPF"
            [ ;; if patch-ahead is safest, move there (to have straight movement in areas without food)
              ;; otherwise choose one of safest cells 
              ifelse member? patch-ahead 1 c-possible-patches with-max [p-safety]
                [ move-to patch-ahead 1 ]
                [ face max-one-of c-possible-patches [p-safety]
                  move-to patch-ahead 1
                ]
            ]
           ] 
        ]
     ]
     ;; else: no possible patch was found
     [  face one-of neighbors                                                       ;; if no possible patch was found individual randomly chooses a neighbor patch
        move-to patch-ahead 1
     ]
    
  ]
  ;; else: no patches are left that are not already included in the home range or marked as inefficient
  [ set c-hrsize i-maxhr ]
end
;-------------------------------------------------------

;; TO CHECK-EFFICIENCY:
;; calculates possible gain from chosen cell (depending on food amount, safety, individual traits)
;; checks if chosen cell should be included in home range (gain needs to be higher than movement costs to cell)
 

to check-efficiency
  
 if c-hrsize <= i-maxhr                                                             ;; efficiency check is only needed if max-hr is not already reached                                                     
  [ if p-hr? = false                                                                ;; efficiency check is not needed for cells already in hr 
     [;; initialize local variables needed for this procedure 
       let l-exploit 0                                                              ;; local variable that stores exploitable food from current cell
       let l-cost 0                                                                 ;; local variable that stores costs of moving to current cell
       let l-gain 0                                                                 ;; local variable that stores net gain from current cell
       
      ;; calculate amount of food that can be exploited from the cell 
       if i-fear-type = "moving" or i-fear-type = "no"
        [ set l-exploit p-food * i-foodshare ]                                      ;; amount of food that can be exploited, for "MC" safety does not influence exploited food
       if i-fear-type = "feeding" 
        [ set l-exploit p-food * i-foodshare * p-safety * i-foodfac ]               ;; amount of food that can be exploited, for "Food" safety influences exploited food
       
      ;; reduce exploited food to foodlimit if individual would exploit more food from the cell than is available to the community
       if ((p-food - l-exploit) < foodlimit) and l-exploit > 0                  
         [ set l-exploit p-food - foodlimit ]
      
      ;; calculate movement costs (depending on move-type and fear-type) 
       if i-move-type = "iCPF"
       [ if i-fear-type = "feeding" or i-fear-type = "no"
          [ set l-cost 2 * i-lococost * distance (last i-cores)                     ;; distance to core for central place forager, * 2 is for moving to the cell and back
          ]                                                                         ;; no effect of safety on movement costs for fear-type "feeding" 
         if i-fear-type = "moving" 
          [ ifelse p-safety <= 0.5
             [ set l-cost 2 * i-lococost * distance (last i-cores)  + p-food * i-foodshare * (1 - p-safety * i-foodfac) ]  ;* ((1 - p-safety) * i-movefac)
             [ set l-cost 2 * i-lococost * distance (last i-cores)]
            if l-cost < 0 [ output-print "Costs are too low"]    
          ]                                                                         ;; for fear-type "moving" movement costs increase with decreasing safety
       ]
       if i-move-type = "iPF"
       [ if i-fear-type = "feeding" or i-fear-type = "no"
          [ set l-cost i-lococost * distance (last c-path)                          ;; distance to last cell for patrolling forager
          ]
         if i-fear-type = "moving" 
          [ ifelse p-safety <= 0.5
             [ set l-cost 2 * i-lococost * distance (last c-path)  + p-food * i-foodshare * (1 - p-safety * i-foodfac) ]  ;* ((1 - p-safety) * i-movefac)
             [ set l-cost 2 * i-lococost * distance (last c-path)]
            if l-cost < 0 [ output-print "Costs are too low"]   
          ]
       ]
;print word "l-exploit" l-exploit
;print word "l-cost" l-cost
      ;; calculate efficiency of cell 
       set l-gain l-exploit - l-cost
      
      ;; add cell to home range, update current food gain, path, home range size
       set p-hr? true                                                               ;; mark cell to be part of the home range
       set c-hrsize c-hrsize + 1                                                    ;; increase current home range size
       set c-path lput patch-here c-path                                            ;; store cell in movement path 
       
       ifelse l-gain > 0                                                            ;; if gain > 0 cell is included in home range
        [ set c-food c-food + l-gain                                                ;; increase temporary food gain by gain from newly added home range cell
          set c-exploit lput l-exploit c-exploit                                    ;; store amount of food exploited from this cell  
          set c-pathgain lput patch-here c-pathgain                                 ;; store cell in path with cells with positive gain
        ]
       ;; else gain <= 0                              
        [ if i-move-type = "iPF"                        
           [ set c-food c-food + l-gain                                             ;; patrolling foragers cross not efficient cells in their home range
                                                                                    ;; therefore gain is added to c-food 
                                                                                    ;; gain is negative here, therefore c-food is decreased when iPF moves across a not efficient cell
           ]
         ;; iCPF have no additional costs for not efficient cells since they would not forage in these
         ;; costs for moving across not efficient cells are already covered in movement costs calculation since costs are calculated based on the distance to the core cell 
        ]       

      ;; update free patches
       set c-free-patches c-free-patches with [p-hr? = false]        
     ]
  ]

end
;-----------------------------------------------------

;; TO CHECK-FEED-RATE:
;; check if food resources gained from cells that are currently in the home range fulfill feeding rate and cover movement costs

to check-feed-rate
  
  ifelse c-food >= i-feedrate                                                       ;; food gain is sufficient 
   [ set c-stopsearch? true                                                         ;; stops addition of cells, see while-loop in SEARCH-HR
     set i-overflow lput (c-food - i-feedrate) i-overflow                           ;; individuals only exploit the exact amount of food that they need to fulfill their feeding rate
                                                                                    ;; food that could be exploited more is stored here (needed in CONSUME-FOOD-RESOURCES)
     set c-food 0                                                                   ;; clear c-food 
     set i-path lput c-path i-path                                                  ;; store movement path in individual-own variable
     set i-pathgain lput c-pathgain i-pathgain                                      ;; store movement path containing only cells with positive gain in individual-own variable
     set i-exploit lput c-exploit i-exploit                                         ;; store exploited food from cells with positive gain in the home range
     set i-hrsize lput c-hrsize i-hrsize                                            ;; store home range size
     
     if length i-pathgain != length i-exploit 
      [ output-print "Cells with positive gain does not match exploited cells"]     ;; safety question to avoid mismatches in lists of exploited resources and cells
   ]
  ;; else: food gain is not sufficient 
   [ if c-hrsize >= i-maxhr                                                         ;; if max-hr is reached individual fails and is excluded from the community
      [ set c-stopsearch? true                                                      ;; stops addition of cells, see while-loop in SEARCH-HR 
        set c-food 0                                                                ;; clear c-food for usage by next individual          
        set i-hrsize lput 0 i-hrsize                                                ;; if fail then 0  as home range size in list 
      ]
     ;; else: nothing happens, individual continues to add cells to home range 
   ]

end

;-----------------------------------------------------------------------------------------------

;; TO CHOOSE-HR
;; if individuals has several attempts to find a home range,
;; the home range with the minimum size is chosen here

to choose-hr
  ask c-new-ind
  [ let l-choice 0                                                                  ;; initialize variable for choice of home range
    ifelse sum i-hrsize > 0                                                         ;; choice is only necessary if at least one home range search attempt was successfull
     [ set l-choice position min i-hrsize i-hrsize                                  ;; store position of optimal home range in choice
       set i-hrsize min i-hrsize                                                    ;; set hrsize to minimum home range size
     ]
     [ set i-hrsize 0
     ]
    ifelse i-hrsize != 0
     [ set i-path item l-choice i-path                                              ;; only movement path of optimal home range stored
       set i-pathgain item l-choice i-pathgain          
       set i-exploit item l-choice i-exploit                                        ;; only resource gain of chosen hr is stored
       foreach i-path [ ask ? [set p-hr? true] ]                                    ;; mark patches in home range that individual has chosen
       set i-overflow item l-choice i-overflow
     ]
     [ set i-nohr? true ]
  ]
end

;-----------------------------------------------------------------------------------------------

;; TO CONSUME-FOOD-RESOURCES:
;; exploit food from cells in the home range
;; amount of food that can be exploited was calculated in home range search

to consume-food-resources
  
 ask c-new-ind
  [ if visualize = true
    [ pu ]
   
   ;; individual moves to each cell with positive gain within the home range
   ;; and consumes the amount of food resources that was calculated during home range search 
    if i-nohr? = false                                                              ;; food resources are only consumed if home range search was successful
     [ let l-counter 0                                                              ;; variable defining the item of the exploit list that needs to be used for consumption
       foreach i-pathgain                               
        [ move-to ?                                                                 ;; move to each cell with positive gain
          set p-food p-food - item l-counter i-exploit                              ;; consume the amount of resources as calculated during home range search               
          set p-nexploit p-nexploit + 1                                             ;; count exploitation of cell  
          set p-exploit lput item l-counter i-exploit p-exploit                     ;; add amount of food that was exploited to list                  
          set l-counter l-counter + 1 
        ]
    ;; it is not allowed that individual consumes more food than needed by feeding rate, therefore the amount that would be consumed to much is added here to the last cell    
     let l-overflow i-overflow        
     ask last i-path   
      [ set p-food p-food + l-overflow
        set p-exploit replace-item (length p-exploit - 1) p-exploit (last p-exploit - l-overflow)  ;; adapt last item in p-exploit
      ]
     ]
  ]
end

;-----------------------------------------------------------------------------------------------

;; TO SATURATION:
;; checks if community is saturated 
;; based on the number of individuals that consecutively failed to find a home range

to saturation  

if ticks >= nfail - 1                                                               
 [ if (sum [i-hrsize] of turtles with [ who >= ticks - nfail and who < ticks]) = 0    
        [ set commsaturation? true ]
 ]

end

;-----------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------

               ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
               ;;               VISUALIZATION                   ;;
               ;;    procedure for graphical output             ;;
               ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; TO COLOR-PATCHES:
;; colors patches in the landscape, visualizes food and fear distribution
;; blue: productive cell
;; red: refuge cell
;; violet: productive cell and refuge cell
;; white: unproductive cell, no refuge

to color-patches
  
  let l-maxfood max [p-food] of patches
  let l-minfood min [p-food] of patches
  ask patches
   [ 
     set pcolor scale-color blue p-food  (l-maxfood + 1) l-minfood
     if p-safety = SafetyRefuges 
     [ set pcolor scale-color red p-safety 2 0]
     if p-safety = SafetyRefuges and p-food > 0
     [ set pcolor scale-color red p-food (l-maxfood + 1) l-minfood]
  ]  
 ; clear-drawing
end



;-----------------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------------

               ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
               ;;               OUTPUT                          ;;
               ;;    procedures for creating output files       ;;
               ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; TO OUTPUT-BEGIN:
;; initialize output files
;; export landscape configuration at the beginning of the simulation
;; write used parameters in file

to output-begin  
  
 ;; create filename, use same pattern for all output files
  set outputfilename (word "FLS-Random" "-RLS-Random" "-sref" SafetyRefuges "-smat" precision SafetyMatrix 1 "-ShRefuge" ShareRefuges "-" MoveType "-" FearType "-lowB" lowB "-upB" upB "-bs" behaviorspace-run-number ".txt")
  
 ;; create parameterfile
  let parameterfile word "Parameters-" outputfilename                               ;; exports current parameter settings
  if file-exists? parameterfile
   [ file-delete parameterfile ]
  file-open parameterfile
  file-print (word   "srefuges smatrix ShareRefuges ShareFood MT FT lowB upb DecisionFactor FoodFactor nfail attempt expo gamma cellsize productivity productivity-community foodcells refugecells seed bs-number ")
  file-print (word    SafetyRefuges " " SafetyMatrix " " ShareRefuges " " ShareFood " " MoveType " " FearType " " lowB " " upB " " DecisionFactor " " FoodFactor  " " nfail " " attempt " " expo " " gamma " " cellsize " " 
              productivity " " productivity-community  " " foodcells " " refugecells " " my-seed " " behaviorspace-run-number)
  file-close

 ;; export landscape file
  set patchfile-begin  word "Patch-begin-" outputfilename                           ;; exports patch variables 
  if file-exists? patchfile-begin
   [ file-delete patchfile-begin ]
  file-open patchfile-begin
  file-print ("pxcor pycor p-food p-safety p-nexploit p-exploit srefuges smatrix ShareRefuges MT FT lowB upb DecisionFactor FoodFactor  bs-number ")
  ask patches 
   [ file-print (word pxcor " " pycor " " p-food " " p-safety " " p-nexploit " " p-exploit " "  SafetyRefuges " " SafetyMatrix " " ShareRefuges " " MoveType " " FearType " " lowB " " upB " " DecisionFactor " " FoodFactor  " " behaviorspace-run-number)]
  file-close
  
 ;; create and prepare exportfiles for output-step
  set datafile   word "Data-" outputfilename                                        ;; exports traits and home range sizes
  set pathfile  word "Path-" outputfilename                                         ;; exports movement path in hr --> cells in hr of each individual 
  set patchfile-end  word "Patch-end-" outputfilename                               ;; exports resource distribution at the end of the run
  set outputfile  word "Output-" outputfilename                                     ;; exports  output in output area 
  set exploitfile word "Exploit" outputfilename                                     ;; exports amount of food exploited in each patch
  if file-exists? outputfile
   [ file-delete outputfile ]

 ;; Datafile: Traits of individuals and home range sizes
  if file-exists? datafile
   [ file-delete datafile ]
  file-open datafile
  file-print ("Who Bodymass Feedrate Maxhr Lococost Foodshare Movetype Feartype Decfac Foodfac Hrsize srefuges smatrix ShareRefuges lowB upb bs-number" )
  file-close

;; Pathfile: Cells in home range of individual  
  if file-exists? pathfile
   [ file-delete pathfile ]
  file-open pathfile
  file-print ("Who xcor ycor srefuges smatrix ShareRefuges MT FT lowB upb DecisionFactor FoodFactor p-safety bs-number ")
  file-close

;; Patchfile-end: Landscape at the end of the simulation  
  if file-exists? patchfile-end
   [ file-delete patchfile-end ]
  file-open patchfile-end
  file-print ("pxcor pycor p-food p-safety p-nexploit sum-p-exploit srefuges smatrix ShareRefuges MT FT lowB upb DecisionFactor FoodFactor bs-number ")
  file-close

;; Exploitfile: how much food is exploited from each cell 
  if file-exists? exploitfile
   [ file-delete exploitfile ]
  file-open exploitfile
  file-print ("pxcor pycor p-food p-safety p-nexploit p-exploit srefuges smatrix ShareRefuges MT FT bs-number")
  file-close 
end

;-----------------------------------------------------------------------------------------------

;; TO OUTPUT-STEP:
;; write output in files in each step of the model

to output-step 
  file-open datafile
  ask c-new-ind
   [ file-print (word who  " " precision i-bodymass 1 " " precision i-feedrate 3 " " i-maxhr " " precision i-lococost 10 " " precision i-foodshare 5 " " i-move-type  " " i-fear-type
                  " " i-decfac " " i-foodfac " "  i-hrsize  " "  SafetyRefuges " " SafetyMatrix " " ShareRefuges " " lowB " " upB " " behaviorspace-run-number)
   ]
  file-close

  file-open pathfile
  ask c-new-ind
   [ if i-hrsize > 0
     [ let who-number who
       foreach i-path 
        [ ask ? 
           [ let l-exploit 0                ;; local variable for storing exploitation value
             if length p-exploit > 0
              [set l-exploit last p-exploit ]
             file-print (word who-number " " pxcor " " pycor  " "  SafetyMatrix " " SafetyRefuges " " ShareRefuges" " MoveType " " FearType " " lowB " " upB " " 
                             DecisionFactor " " FoodFactor " " p-safety " " l-exploit " "  behaviorspace-run-number)]
        ]
     ]
   ]
  file-close
end

;-----------------------------------------------------------------------------------------------

;; TO OUTPUT-END: 
;; export landscape at the end of the simulation and everything written in output
;; output-end needs to be added manually in BehaviorSpace in final commands

to output-end 
  export-output outputfile
  
  file-open patchfile-end
  ask patches 
   [ file-print (word pxcor " " pycor " " p-food " " p-safety " " p-nexploit " " sum p-exploit " "  SafetyRefuges " " SafetyMatrix " " ShareRefuges " " MoveType " " FearType " " lowB " " upB " " DecisionFactor " " FoodFactor " " behaviorspace-run-number)]
  file-close
  
  file-open exploitfile
  ask patches 
   [ let nlines length p-exploit
     let counter 0
     repeat nlines
      [  file-print (word pxcor " " pycor " " p-food " " p-safety " " p-nexploit " " item counter p-exploit " "  SafetyRefuges " " SafetyMatrix " " ShareRefuges " " MoveType " " FearType " " behaviorspace-run-number)
         set counter counter + 1
      ]
     if nlines = 0
      [  file-print (word pxcor " " pycor " " p-food " " p-safety " " p-nexploit " " 0 " "  SafetyRefuges " " SafetyMatrix " " ShareRefuges " " MoveType " " FearType " " behaviorspace-run-number)]
   ]
  file-close
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;                            END                                              ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
@#$#@#$#@
GRAPHICS-WINDOW
379
29
1137
808
-1
-1
7.48
1
10
1
1
1
0
1
1
1
0
99
0
99
0
0
1
ticks
30.0

BUTTON
22
27
124
60
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
134
27
235
60
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

BUTTON
244
28
347
61
NIL
single-step
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
7
402
157
421
Trait settings
15
0.0
1

MONITOR
1151
33
1251
86
# individuals
count turtles
17
1
13

MONITOR
1256
33
1373
86
# failed individuals
count turtles with [i-nohr? = true]
17
1
13

MONITOR
1381
33
1498
86
# attempts
c-attempt
17
1
13

OUTPUT
1150
742
1740
807
22

PLOT
1151
427
1739
577
bodymass success
bodymass
frequency
0.0
1000.0
0.0
10.0
true
false
"" ""
PENS
"default" 10.0 1 -16777216 true "" "histogram [i-bodymass] of turtles with [i-hrsize > 0]"

TEXTBOX
12
433
109
451
Movement type
13
0.0
1

CHOOSER
10
456
177
501
MoveType
MoveType
"iCPF" "iPF"
0

PLOT
1151
581
1741
731
bodymass fail
bodymass
frequency
0.0
1000.0
0.0
10.0
true
false
"" ""
PENS
"default" 10.0 1 -16777216 true "" "histogram [i-bodymass] of turtles with [i-hrsize = 0]"

PLOT
1151
273
1741
423
hrsize distribution
hr size
frequency
0.0
100.0
0.0
20.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" "histogram [i-hrsize] of turtles with [i-hrsize > 0]"

PLOT
1151
93
1741
266
mean hrsize
ticks
hr size
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "if any? turtles with [i-hrsize > 0] [plot mean [i-hrsize] of turtles with [i-hrsize > 0]]"

INPUTBOX
17
619
93
679
lowB
0.01
1
0
Number

INPUTBOX
93
619
165
679
upB
1
1
0
Number

TEXTBOX
17
596
196
617
Body mass input distribution
13
0.0
1

TEXTBOX
177
631
382
671
lower and upper boundary for possible body masses of individuals (in kg!)\n
11
0.0
1

SLIDER
15
320
185
353
SafetyRefuges
SafetyRefuges
0
1
0.9
0.1
1
NIL
HORIZONTAL

CHOOSER
184
454
352
499
FearType
FearType
"no" "feeding" "moving"
2

INPUTBOX
17
521
213
581
FoodFactor
2
1
0
Number

TEXTBOX
222
525
379
595
influences magnitude of food exploitation in feeding and decrease in movement costs in moving feartypes
11
0.0
1

SWITCH
24
82
175
115
visualize
visualize
0
1
-1000

TEXTBOX
402
826
512
846
blue: cell with food\n
13
103.0
1

TEXTBOX
537
827
687
845
red: refuge cell\n
13
16.0
1

TEXTBOX
636
827
857
859
violet: cell with food and refuge
13
116.0
1

SWITCH
187
82
345
115
output
output
0
1
-1000

TEXTBOX
8
129
158
148
Landscape settings
15
0.0
1

TEXTBOX
16
297
197
315
Magnitude of predation risk
13
0.0
1

TEXTBOX
190
435
340
453
Fear type
13
0.0
1

MONITOR
1510
33
1720
86
Body mass of curret individual
[precision i-bodymass 0] of c-new-ind
17
1
13

MONITOR
203
304
298
357
NIL
SafetyMatrix
1
1
13

TEXTBOX
198
182
287
210
proportion of food in landscape
11
0.0
1

TEXTBOX
196
224
297
252
proportion of refuges with food
11
0.0
1

SLIDER
16
222
188
255
ShareRefuges
ShareRefuges
0
1
0.9
0.1
1
NIL
HORIZONTAL

SLIDER
15
177
187
210
ShareFood
ShareFood
0
1
0.3
0.1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

The model shows the influence of a landscape of fear on space use of animals and the consequences for community structure. 

## HOW IT WORKS

At the beginning of the model food is distributed in the landscape and each cell gets asssigned a specific predation risk. In each step a new individual with specific traits is created and tries to find a home range in the landscape. The decision to add a cell to the home range depends on specific traits of the individual. The home range has to contain enough food to fulfill the individual's daily food needs and the movement costs for moving to the cells within the home range. Depending on the predation risk in cells individuals can gain more or less food from a cell (FearType=feeding) or have higher or lower movement costs (FearType=moving). If an individual was successfull in finding a home range it consumes the resources within. Then a new individual tries to find a home range. The model continues until a specific amount of animals were not able to find a home range in the landscape, i.e. the community is saturated. 

## HOW TO USE IT

first click setup 
then click go or single-step


## THINGS TO NOTICE

colouring of the patches shows amount of food in cells 
grey paths show cells that the individual checked for adding to the home range
plots show community parameters

## THINGS TO TRY

change the safety of the refuges (matrix)
change the body mass range of individuals 
change the distribution of food or fear in the landscape



## RELATED MODELS

Buchmann CM, Schurr FM, Nathan R, Jeltsch F (2011) An allometric model of home range 			formation explains the structuring of animal communities exploiting 				heterogeneous resources. Oikos 120:106–118. doi: 						10.1111/j.1600-0706.2010.18556.x

## CREDITS AND REFERENCES

This is the code for Teckentrup, L., Grimm, V., Kramer-Schadt, S., Jeltsch, F., 2018. Community consequences of foraging under fear. Ecol. Modell. 383, 80–90. doi:10.1016/j.ecolmodel.2018.05.015



Modelling approach is based on:

Buchmann CM, Schurr FM, Nathan R, Jeltsch F (2011) An allometric model of home range 			formation explains the structuring of animal communities exploiting 				heterogeneous resources. Oikos 120:106–118. doi: 						10.1111/j.1600-0706.2010.18556.x
Buchmann CM, Schurr FM, Nathan R, Jeltsch F (2012) Movement upscaled - the importance 			of individual foraging movement for community response to habitat loss. 			Ecography 35:436–445. doi: 10.1111/j.1600-0587.2011.06924.x
Buchmann CM, Schurr FM, Nathan R, Jeltsch F (2013) Habitat loss and fragmentation 			affecting mammal and bird communities—The role of interspecific competition and 		individual space use. Ecol Inform 14:90–98. doi: 10.1016/j.ecoinf.2012.11.015


References for calculations/parameter values in the model:
Productivity: 
Whittaker 1975

Feeding rate: 
Nagy KA (2001) Food requirements of wild animals: predictive equations for 				free-living mammals, reptiles, and birds. Nutr Abstr Rev Ser B 71:21–31.

Locomotion costs:
Calder WA (1996) Size, Function, and Life History. Dover Publishers Inc.

Maximum home range size:
Kelt DA, Van Vuren DH (2001) The ecology and macroecology of mammalian home range area. 		Am Nat 157:637–45. doi: 10.1086/320621
Buchmann CM, Schurr FM, Nathan R, Jeltsch F (2011) An allometric model of home range 			formation explains the structuring of animal communities exploiting 				heterogeneous resources. Oikos 120:106–118. doi: 						10.1111/j.1600-0706.2010.18556.x

Magnitude of food exploitation (foodshare):
Haskell JP, Ritchie ME, Olff H (2002) Fractal geometry predicts varying body size 			scaling relationships for mammal and bird home ranges. Nature 418:527–30. doi: 			10.1038/nature00840
Buchmann CM, Schurr FM, Nathan R, Jeltsch F (2011) An allometric model of home range 			formation explains the structuring of animal communities exploiting 				heterogeneous resources. Oikos 120:106–118. doi: 						10.1111/j.1600-0706.2010.18556.x

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

mouse side
false
0
Polygon -7500403 true true 38 162 24 165 19 174 22 192 47 213 90 225 135 230 161 240 178 262 150 246 117 238 73 232 36 220 11 196 7 171 15 153 37 146 46 145
Polygon -7500403 true true 289 142 271 165 237 164 217 185 235 192 254 192 259 199 245 200 248 203 226 199 200 194 155 195 122 185 84 187 91 195 82 192 83 201 72 190 67 199 62 185 46 183 36 165 40 134 57 115 74 106 60 109 90 97 112 94 92 93 130 86 154 88 134 81 183 90 197 94 183 86 212 95 211 88 224 83 235 88 248 97 246 90 257 107 255 97 270 120
Polygon -16777216 true false 234 100 220 96 210 100 214 111 228 116 239 115
Circle -16777216 true false 246 117 20
Line -7500403 true 270 153 282 174
Line -7500403 true 272 153 255 173
Line -7500403 true 269 156 268 177

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
NetLogo 5.0.4
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="ShareRefugesAppendix" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <final>output-end</final>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="visualize">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="output">
      <value value="true"/>
    </enumeratedValueSet>
    <steppedValueSet variable="SafetyRefuges" first="0.5" step="0.1" last="0.8"/>
    <enumeratedValueSet variable="MoveType">
      <value value="&quot;iCPF&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="FearType">
      <value value="&quot;feeding&quot;"/>
      <value value="&quot;moving&quot;"/>
      <value value="&quot;no&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ShareFood">
      <value value="0.3"/>
    </enumeratedValueSet>
    <steppedValueSet variable="ShareRefuges" first="0" step="0.1" last="1"/>
    <enumeratedValueSet variable="FoodFactor">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lowB">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="upB">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="ShareRefuges" repetitions="30" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <final>output-end</final>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="visualize">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="output">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SafetyRefuges">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="MoveType">
      <value value="&quot;iCPF&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="FearType">
      <value value="&quot;feeding&quot;"/>
      <value value="&quot;moving&quot;"/>
      <value value="&quot;no&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ShareFood">
      <value value="0.3"/>
    </enumeratedValueSet>
    <steppedValueSet variable="ShareRefuges" first="0" step="0.1" last="1"/>
    <enumeratedValueSet variable="FoodFactor">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lowB">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="upB">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
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
