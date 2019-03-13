{-# LANGUAGE CPP #-}
module Language.Interpreter where

import Data.ISeq
import Data.List
#if __CLH_EXERCISE_2__ >= 7
import Data.StatHeap
#endif
import Language.Parser
import Language.Prelude
import Language.Types
import Util

run :: String -> String
compile :: CoreProgram -> TiState
eval :: TiState -> [TiState]
showResults :: [TiState] -> String

run = showResults . eval . compile . parse

type TiState = (TiStack, TiDump, TiHeap, TiGlobals, TiStats)

type TiStack = [Addr]

data TiDump = DummyTiDump
initialTiDump = DummyTiDump

#if __CLH_EXERCISE_2__ < 7
type TiHeap = Heap Node
#endif

#if __CLH_EXERCISE_2__ < 13
data Node
  = NAp Addr Addr
  | NSc Name [Name] CoreExpr
  | NNum Int
#endif

type TiGlobals = Assoc Name Addr

tiStatInitial :: TiStats
tiStatIncSteps :: TiStats -> TiStats
tiStatGetSteps :: TiStats -> Int

#if __CLH_EXERCISE_2__ < 7
type TiStats = Int

tiStatInitial = 0
tiStatIncSteps = (+ 1)
tiStatGetSteps s = s
#endif

applyToStats :: (TiStats -> TiStats) -> TiState -> TiState
applyToStats statFun (stack, dump, heap, scDefs, stats)
  = (stack, dump, heap, scDefs, statFun stats)

compile program
  = (initialStack, initialTiDump, initialHeap, globals, tiStatInitial)
  where
    scDefs = program ++ preludeDefs ++ extraPreludeDefs

    (initialHeap, globals) = buildInitialHeap scDefs
    initialStack = [addressOfMain]
    addressOfMain = aLookup globals "main" (error "main is not defined")

extraPreludeDefs :: CoreProgram
extraPreludeDefs = []

buildInitialHeap :: [CoreScDefn] -> (TiHeap, TiGlobals)
#if __CLH_EXERCISE_2__ < 7
buildInitialHeap = mapAccumL allocateSc hInitial
#endif

allocateSc :: TiHeap -> CoreScDefn -> (TiHeap, (Name, Addr))
#if __CLH_EXERCISE_2__ < 7
allocateSc heap (name, args, body)
  = (heap', (name, addr))
  where
    (heap', addr) = hAlloc heap (NSc name args body)
#endif

eval state
  = state : restStates
  where
    restStates
      | tiFinal state = []
      | otherwise = eval nextState
    nextState = doAdmin (step state)

doAdmin :: TiState -> TiState
#if __CLH_EXERCISE_2__ < 7
doAdmin = applyToStats tiStatIncSteps
#endif

tiFinal :: TiState -> Bool
#if __CLH_EXERCISE_2__ < 7
tiFinal ([soleAddr], _, heap, _, _) = isDataNode (hLookup heap soleAddr)
tiFinal ([], _, _, _, _) = error "Empty stack!"
tiFinal _ = False
#endif

isDataNode :: Node -> Bool
isDataNode (NNum n) = True
isDataNode node = False

step :: TiState -> TiState
#if __CLH_EXERCISE_2__ < 7
step state@(stack, dump, heap, globals, stats)
  = dispatch (hLookup heap (head stack))
  where
    dispatch (NNum n) = numStep state n
    dispatch (NAp a1 a2) = apStep state a1 a2
    dispatch (NSc scName argNames body) = scStep state scName argNames body
#endif

numStep :: TiState -> Int -> TiState
numStep state n = error "Num applied as a function!"

apStep :: TiState -> Addr -> Addr -> TiState
apStep (stack, dump, heap, globals, stats) a1 _
  = (a1 : stack, dump, heap, globals, stats)

scStep :: TiState -> Name -> [Name] -> CoreExpr -> TiState
#if __CLH_EXERCISE_2__ < 6
scStep (stack, dump, heap, globals, stats) scName argNames body
  = (stack', dump, heap', globals, stats)
  where
    stack' = resultAddr : drop (length argNames + 1) stack
    (heap', resultAddr) = instantiate body heap env
    env = argBindings ++ globals
    argBindings = zip argNames (getArgs heap stack)
#endif

getArgs :: TiHeap -> TiStack -> [Addr]
#if __CLH_EXERCISE_2__ < 7
getArgs heap (_ : stack)
  = map getArg stack
  where
    getArg a
      = let (NAp fun arg) = hLookup heap a
        in arg
#endif

instantiate :: CoreExpr -> TiHeap -> TiGlobals -> (TiHeap, Addr)
#if __CLH_EXERCISE_2__ < 7
instantiate (ENum n) heap env = hAlloc heap (NNum n)
instantiate (EAp e1 e2) heap env
  = hAlloc heap2 (NAp a1 a2)
  where
    (heap1, a1) = instantiate e1 heap env
    (heap2, a2) = instantiate e2 heap1 env
instantiate (EVar v) heap env
  = (heap, aLookup env v (error ("Undefined name " ++ v)))
instantiate (EConstr tag arity) heap env
  = instantiateConstr tag arity heap env
instantiate (ELet isRec defs body) heap env
  = instantiateLet isRec defs body heap env
instantiate (ECase e alts) heap env
  = error "Can't instantiate case exprs"
#endif

instantiateConstr :: Int -> Int -> TiHeap -> TiGlobals -> (TiHeap, Addr)
instantiateConstr = error "Can't instantiate constructors yet"

instantiateLet :: IsRec -> Assoc Name CoreExpr -> CoreExpr -> TiHeap -> TiGlobals -> (TiHeap, Addr)
#if __CLH_EXERCISE_2__ < 10
instantiateLet = error "Can't instantiate let(rec)s yet"
#endif

showResults states
  = iDisplay resultSeq
  where
    resultSeq
      = iConcat [ iLayn (map showState states)
                , showStats (last states)
                ]

showState :: TiState -> ISeq
#if __CLH_EXERCISE_2__ < 5
showState (stack, _, heap, _, _)
  = iConcat [ showStack heap stack, iNewline ]
#endif

showStack :: TiHeap -> TiStack -> ISeq
#if __CLH_EXERCISE_2__ < 7
showStack heap stack
  = iConcat [ iStr "Stk ["
            , iIndent (iInterleave iNewline (map showStackItem stack))
            , iStr "]"
            ]
  where
    showStackItem addr
      = iConcat [ showFWAddr addr, iStr ": ", showStkNode heap (hLookup heap addr) ]
#endif

showStkNode :: TiHeap -> Node -> ISeq
#if __CLH_EXERCISE_2__ < 7
showStkNode heap (NAp funAddr argAddr)
  = iConcat [ iStr "NAp ", showFWAddr funAddr, iStr " ", showFWAddr argAddr
            , iStr " (", showNode (hLookup heap argAddr), iStr ")"
            ]
showStkNode heap node = showNode node
#endif

#if __CLH_EXERCISE_2__ < 13
showNode :: Node -> ISeq
showNode (NAp a1 a2)
  = iConcat [ iStr "NAp ", showAddrToSeq a1, iStr " ", showAddrToSeq a2 ]
showNode (NSc scName argNames body) = iStr ("NSc " ++ scName)
showNode (NNum n) = iStr "NNum " `iAppend` iNum n
#endif

-- |
-- Name is changed from `showAddr` to `showAddrToSeq` to avoid
-- name collision.
showAddrToSeq :: Addr -> ISeq
showAddrToSeq addr = iStr (showAddr addr)

showFWAddr :: Addr -> ISeq
showFWAddr addr = iStr (space (4 - length str) ++ str)
  where
    str = showAddr addr

showStats :: TiState -> ISeq
#if __CLH_EXERCISE_2__ < 7
showStats (_, _, _, _, stats)
  = iConcat [ iNewline
            , iNewline
            , iStr "Total number of steps = ", iNum (tiStatGetSteps stats)
            ]
#endif

#if __CLH_EXERCISE_2__ >= 5
showState (stack, _, heap, _, _)
  = iConcat [ showStack heap stack, iNewline
#if __CLH_EXERCISE_2__ == 6
            , showHeap heap, iNewline
#endif
            ]

showHeap :: TiHeap -> ISeq
#if __CLH_EXERCISE_2__ < 7
showHeap heap
  = iConcat [ iStr "Heap ["
            , iIndent (iInterleave iNewline (map showHeapItem (hAddresses heap)))
            ]
    where
      showHeapItem addr
        = iConcat [ showFWAddr addr, iStr ": ", showStkNode heap (hLookup heap addr) ]

#if __CLH_EXERCISE_2__ >= 6
scStep (stack, dump, heap, globals, stats) scName argNames body
  | argsLength + 1 <= length stack = (stack', dump, heap', globals, stats)
  where
    stack' = resultAddr : drop (argsLength + 1) stack
    (heap', resultAddr) = instantiate body heap env
    env = argBindings ++ globals
    argBindings = zip argNames (getArgs heap stack)
    argsLength = length argNames
scStep (stack, dump, heap, globals, stats) scName argNames body
  = error ("Two few arguments are provided to the function " ++ scName)
#endif
#endif

#if __CLH_EXERCISE_2__ >= 7
type TiHeap = StatHeap Node

type TiStats
  = ( Int -- The number of steps
    , ( Int -- The number of supercombinator reduction
      , Int -- The number of primitive reduction
      )
    , Int -- The maximun stack depth
    )

tiStatInitial = (0, (0, 0), 0)
tiStatIncSteps (steps, redStats, maxStackDepth)
  = (steps + 1, redStats, maxStackDepth)
tiStatGetSteps (steps, _, _) = steps

tiStatIncScReds :: TiStats -> TiStats
tiStatIncScReds (steps, (scReds, pReds), maxStackDepth)
  = (steps, (scReds + 1, pReds), maxStackDepth)
tiStatGetScReds :: TiStats -> Int
tiStatGetScReds (_, (scReds, _), _)
  = scReds
tiStatIncPReds :: TiStats -> TiStats
tiStatIncPReds (steps, (scReds, pReds), maxStackDepth)
  = (steps, (scReds, pReds + 1), maxStackDepth)
tiStatGetPReds :: TiStats -> Int
tiStatGetPReds (_, (_, pReds), _)
  = pReds
tiStatSetMaxStackDepth :: Int -> TiStats -> TiStats
tiStatSetMaxStackDepth max (steps, (scReds, pReds), _)
  = (steps, (scReds, pReds), max)
tiStatGetMaxStackDepth :: TiStats -> Int
tiStatGetMaxStackDepth (_, _, maxStackDepth)
  = maxStackDepth

buildInitialHeap = mapAccumL allocateSc statHInitial

allocateSc heap (name, args, body)
  = (heap', (name, addr))
  where
    (heap', addr) = statHAlloc heap (NSc name args body)

doAdmin state@(stack, _, _, _, stats)
  = applyToStats (updateMaxStackDepth . tiStatIncSteps) state
  where
    updateMaxStackDepth
      | stackDepth > statMaxStackDepth = tiStatSetMaxStackDepth stackDepth
      | otherwise = id

    stackDepth = length stack
    statMaxStackDepth = tiStatGetMaxStackDepth stats

tiFinal ([soleAddr], _, heap, _, _) = isDataNode (statHLookup heap soleAddr)
tiFinal ([], _, _, _, _) = error "Empty stack!"
tiFinal _ = False

#if __CLH_EXERCISE_2__ < 13
step state@(stack, dump, heap, globals, stats)
  = dispatch (statHLookup heap (head stack))
  where
    dispatch (NNum n) = numStep state n
    dispatch (NAp a1 a2) = apStep state a1 a2
    dispatch (NSc scName argNames body) = scStep state scName argNames body
#endif

getArgs heap (_ : stack)
  = map getArg stack
  where
    getArg a
      = let (NAp fun arg) = statHLookup heap a
        in arg

instantiate (ENum n) heap env = statHAlloc heap (NNum n)
instantiate (EAp e1 e2) heap env
  = statHAlloc heap2 (NAp a1 a2)
  where
    (heap1, a1) = instantiate e1 heap env
    (heap2, a2) = instantiate e2 heap1 env
instantiate (EVar v) heap env
  = (heap, aLookup env v (error ("Undefined name " ++ v)))
instantiate (EConstr tag arity) heap env
  = instantiateConstr tag arity heap env
instantiate (ELet isRec defs body) heap env
  = instantiateLet isRec defs body heap env
instantiate (ECase e alts) heap env
  = error "Can't instantiate case exprs"

showStack heap stack
  = iConcat [ iStr "Stk ["
            , iIndent (iInterleave iNewline (map showStackItem stack))
            , iStr "]"
            ]
  where
    showStackItem addr
      = iConcat [ showFWAddr addr, iStr ": ", showStkNode heap (statHLookup heap addr) ]

#if __CLH_EXERCISE_2__ < 13
showStkNode heap (NAp funAddr argAddr)
  = iConcat [ iStr "NAp ", showFWAddr funAddr, iStr " ", showFWAddr argAddr
            , iStr " (", showNode (statHLookup heap argAddr), iStr ")"
            ]
showStkNode heap node = showNode node
#endif

showStats (_, _, heap, _, stats)
  = iConcat [ iNewline
            , iNewline
            , iStr "Total number of steps                        : ", iNum steps, iNewline
            , iNewline
            , iStr "Total number of reductions                   : ", iNum (scReds + pReds), iNewline
            , iStr "Total number of supercombinator reductions   : ", iNum scReds, iNewline
            , iStr "Total number of primitive reductions         : ", iNum pReds, iNewline
            , showStatHeapStats heap, iNewline
            , iNewline
            , iStr "Maximum stack depth                          : ", iNum maxStackDepth
            ]
    where
      steps = tiStatGetSteps stats
      scReds = tiStatGetScReds stats
      pReds = tiStatGetPReds stats
      maxStackDepth = tiStatGetMaxStackDepth stats

showStatHeapStats :: TiHeap -> ISeq
showStatHeapStats heap
  = iConcat [ iNewline
            , iStr "Total number of heap allocations             : ", iNum allocations, iNewline
            , iStr "Total number of heap updates                 : ", iNum updates, iNewline
            , iStr "Total number of heap frees                   : ", iNum frees
            ]
    where
      allocations = statHSGetHAlloc stats
      updates = statHSGetHUpdate stats
      frees = statHSGetHFree stats
      stats = statHGetStats heap

showHeap heap
  = iConcat [ iStr "Heap ["
            , iIndent (iInterleave iNewline (map showHeapItem (statHAddresses heap)))
            ]
    where
      showHeapItem addr
        = iConcat [ showFWAddr addr, iStr ": ", showStkNode heap (statHLookup heap addr) ]

#if __CLH_EXERCISE_2__ < 13
scStep (stack, dump, heap, globals, stats) scName argNames body
  | argsLength + 1 <= length stack = (stack', dump, heap', globals, tiStatIncScReds stats)
  where
    stack' = resultAddr : drop (argsLength + 1) stack
    (heap', resultAddr) = instantiate body heap env
    env = argBindings ++ globals
    argBindings = zip argNames (getArgs heap stack)
    argsLength = length argNames
scStep (stack, dump, heap, globals, stats) scName argNames body
  = error ("Two few arguments are provided to the function " ++ scName)
#endif

#if __CLH_EXERCISE_2__ >= 10
#if __CLH_EXERCISE_2__ < 11
instantiateLet isRec defs body heap env
  | not isRec = instantiate body heap' env'
  where
    (heap', defBindings) = mapAccumL (instantiateDef env) heap defs
    env' = defBindings ++ env
#endif

instantiateDef env heap (name, body)
  = (heap', (name, addr))
  where
    (heap', addr) = instantiate body heap env

#if __CLH_EXERCISE_2__ >= 11
instantiateLet isRec defs body heap env = instantiate body heap' env'
  where
    (heap', defBindings) = mapAccumL allocateDef heap defs
    allocateDef
      | isRec = instantiateDef env'
      | otherwise = instantiateDef env
    env' = defBindings ++ env

#if __CLH_EXERCISE_2__ >= 13
data Node
  = NAp Addr Addr
  | NSc Name [Name] CoreExpr
  | NNum Int
  | NInd Addr

showNode :: TiHeap -> Node -> ISeq
showNode _ (NAp a1 a2)
  = iConcat [ iStr "NAp ", showAddrToSeq a1, iStr " ", showAddrToSeq a2 ]
showNode _ (NSc scName argNames body) = iStr ("NSc " ++ scName)
showNode _ (NNum n) = iStr "NNum " `iAppend` iNum n
showNode heap (NInd a)
  = iConcat [ iStr "NInd (", showNode heap (statHLookup heap a), iStr ")" ]

showStkNode heap (NAp funAddr argAddr)
  = iConcat [ iStr "NAp ", showFWAddr funAddr, iStr " ", showFWAddr argAddr
            , iStr " (", showNode heap (statHLookup heap argAddr), iStr ")"
            ]
showStkNode heap node = showNode heap node

scStep (stack, dump, heap, globals, stats) scName argNames body
  | argsLength + 1 <= length stack = (stack'', dump, heap'', globals, tiStatIncScReds stats)
  where
    rootAddr : stack' = drop argsLength stack
    stack'' = resultAddr : stack'
    (heap', resultAddr) = instantiate body heap env
    heap'' = statHUpdate heap' rootAddr (NInd resultAddr)
    env = argBindings ++ globals
    argBindings = zip argNames (getArgs heap stack)
    argsLength = length argNames
scStep (stack, dump, heap, globals, stats) scName argNames body
  = error ("Two few arguments are provided to the function " ++ scName)

step state@(stack, dump, heap, globals, stats)
  = dispatch (statHLookup heap (head stack))
  where
    dispatch (NNum n) = numStep state n
    dispatch (NAp a1 a2) = apStep state a1 a2
    dispatch (NSc scName argNames body) = scStep state scName argNames body
    dispatch (NInd addr) = indStep state addr

indStep :: TiState -> Addr -> TiState
indStep (_ : stack, dump, heap, globals, stats) addr
  = (addr : stack, dump, heap, globals, stats)
#endif
#endif
#endif
#endif
#endif
