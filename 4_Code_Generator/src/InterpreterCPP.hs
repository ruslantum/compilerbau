{-# LANGUAGE GeneralizedNewtypeDeriving #-}

module InterpreterCPP where

import Debug.Trace
import Data.Word
import Data.String
import Data.List
import Data.Function
import qualified Data.Map as Map

import LLVM.General.Context
import LLVM.General.Module
import LLVM.General.AST
import LLVM.General.AST.Global

import qualified LLVM.General.AST as AST
import qualified LLVM.General.AST.Constant as C
import qualified LLVM.General.AST.Attribute as A
import qualified LLVM.General.AST.Float as F
import qualified LLVM.General.AST.CallingConvention as CC
import qualified LLVM.General.AST.FloatingPointPredicate as FP
import qualified LLVM.General.AST.IntegerPredicate as IP

import Control.Monad
import Control.Monad.State
import Control.Monad.Except
import Control.Applicative

import System.Environment (getArgs)
import System.Exit (exitFailure)

import AbsCPP
import LexCPP
import ParCPP
import PrintCPP
import ErrM
---------------------------------------------------------------------------------
-- Utils
-------------------------------------------------------------------------------

trunc :: String -> String
trunc s = (take 10 s) ++ ".."


---------------------------------------------------------------------------------
-- Types
-------------------------------------------------------------------------------

bool :: AST.Type
bool = IntegerType 1

-- IEEE 754 double
double :: AST.Type
double  = FloatingPointType 64 IEEE

int :: AST.Type
int     = IntegerType 32

void :: AST.Type
void    = VoidType



constTrue = cons $ C.Int 1 1
constFalse = cons $ C.Int 1 0

constIntegerZero = cons $ C.Int 32 0

constDoubleZero = cons $ C.Float (F.Double 0)




---------------------------------------------------------------------------------
-- Emit
-------------------------------------------------------------------------------

argsToSig :: [Arg] -> [(AST.Type, AST.Name)]
argsToSig = map (\x -> argToSig x)

argToSig :: Arg -> (AST.Type, AST.Name)
argToSig (ADecl t (Id id)) = (typeToASTType t, AST.Name id)

typeToASTType :: AbsCPP.Type -> AST.Type
typeToASTType t =
  case t of
    Type_bool   -> bool
    Type_int    -> int
    Type_double -> double
    Type_void   -> InterpreterCPP.void

typeOfOperand :: Operand -> AST.Type
typeOfOperand op =
  case op of
    LocalReference t _ -> t
    ConstantOperand c ->
      case c of
        C.Int _ _   -> int
        C.Float _   -> double
        C.GlobalReference t _ -> t


defaultValueForType :: AbsCPP.Type -> Operand
defaultValueForType t =
    case t of
    Type_bool   -> constFalse
    Type_int    -> constIntegerZero
    Type_double -> constDoubleZero


-- Entry point for code generation
-- "A program is a sequence of definitions"
-- Declares modules for functions, makes arguments available as variables, generates body blocks
codegenTop :: Def -> LLVM()
codegenTop (DFun returnType id arguments statements) =
  trace ("# Generating module for function" ++ show id) $ do
    define returnTypeAST id argumentsAST blocks
    where
      returnTypeAST = typeToASTType returnType
      -- Convert arguments to (AST.Type, AST.Name) pairs
      argumentsAST = argsToSig arguments
      -- Add new blocks
      blocks = createBlocks $ execCodegen $ do
        entry <- addBlock entryBlockName
        setBlock entry
        -- Add function arguments as local variables
        forM argumentsAST $ \(astType, astName) -> trace ("Creating local variable for argument " ++ show id) $ do
          case astName of -- an arguments is always named
            Name strName ->
              do
                var <- alloca astType
                store var $ local astName astType
                assign strName var

        forM statements $ \(statement) -> cgen statement






cgenBlock :: [Stm] -> Codegen Operand
cgenBlock statements = last (map (\stm -> cgen stm) statements)

cgen :: Stm -> Codegen Operand

{- STATEMENT-LEVEL CODE GENERATION -}

-- Initialize a local variable
cgen (SInit t (Id id) e) = trace ("CGEN SInit - Creating local variable named " ++ show id) $ do
  res <- cgenExp e        -- Generate initialization code
  var <- allocNamed astType astName   -- Alloc a local variable
  -- store var $ defaultValueForType t -- store default initialization value
  store var res
  assign id var
  return var

  where
    astType = typeToASTType t
    astName = AST.Name id

-- Return expression
cgen (SReturn e) =
  do
    c <- cgenExp e
    ret c
    return c


-- Return void
cgen SReturnVoid =
  do
    retVoid
    return constFalse

cgen (SExp e) = cgenExp e

cgen (SBlock statements) = cgenBlock statements

cgen (SIfElse condition trueStatements falseStatements) =
  do
    thenBlock <- addBlock "if.then"
    elseBlock <- addBlock "if.else"
    continueBlock <- addBlock "if.exit"

    -- Generate conditional jump
    conditionCode   <- cgenExp condition
    test            <- icmp IP.NE constFalse conditionCode -- True if condition != 0
    cbr test thenBlock elseBlock                            -- Do the branching

    -- then block
    setBlock thenBlock
    cgen trueStatements
    br continueBlock

    -- else block
    setBlock elseBlock
    cgen falseStatements
    br continueBlock

    -- Continue code generation in continueBlock
    setBlock continueBlock
    return constFalse

cgen (SWhile condition statements) =
  do
    testBlock     <- addBlock "while.test"
    loopBlock     <- addBlock "while.loop"
    continueBlock <- addBlock "while.continue"

    -- Test condition
    br testBlock

    -- Generate code for test block
    -- Test condition, start/continue loop on true, else continue
    setBlock testBlock
    conditionCode <- cgenExp condition
    test          <- icmp IP.NE constFalse conditionCode -- True if condition != 0
    cbr test loopBlock continueBlock

    -- Generate code for loop block
    setBlock loopBlock
    cgen statements   -- Execute statements
    br testBlock      -- Then test for next loop

    -- Continue code generation in continueBlock
    setBlock continueBlock
    return constFalse


{- EXPRESSION-LEVEL CODE GENERATION -}
performTypedOperation :: Exp -> Exp -> (Operand -> Operand -> Codegen Operand) -> (Operand -> Operand -> Codegen Operand) -> Codegen Operand
performTypedOperation e1 e2 integerFunction floatingPointFunction = do
  op1 <- cgenExp e1
  op2 <- cgenExp e2
  case typeOfOperand op1 of
    IntegerType _           -> integerFunction op1 op2
    FloatingPointType _ _   -> floatingPointFunction op1 op2

cgenExp :: Exp -> Codegen Operand
cgenExp (ETrue)        = return $ cons $ C.Int 1 1
cgenExp (EFalse)       = return $ cons $ C.Int 1 1
cgenExp (EInt i)       = return $ cons $ C.Int 32 i
cgenExp (EDouble d)    = return $ cons $ C.Float (F.Double d)
cgenExp (EId id)       = getvar (idToStr id) >>= load

-- Function call
cgenExp (EApp id args) =
  do
    argumentList <- mapM cgenExp args
    call (externf astName astType) argumentList
    where
      astName = AST.Name $ idToStr id
      astType = int -- TODO Figure out type of function here

{- TODO: Implement
cgenExp (EPIncr e)   =
cgenExp (EPDecr e)   =
cgenExp (EIncr e)   =
cgenExp (EDecr e)   =
-}






cgenExp (ETimes e1 e2)  = performTypedOperation e1 e2 imul fmul
cgenExp (EDiv e1 e2)    = performTypedOperation e1 e2 idiv fdiv
cgenExp (EPlus e1 e2)   = performTypedOperation e1 e2 iadd fadd
cgenExp (EMinus e1 e2)  = performTypedOperation e1 e2 isub fsub

cgenExp (ELt e1 e2) =
  do
    ce1 <- cgenExp e1
    ce2 <- cgenExp e2
    lt ce1 ce2
cgenExp (EGt e1 e2) =
  do
    ce1 <- cgenExp e1
    ce2 <- cgenExp e2
    gt ce1 ce2
cgenExp (ELtEq e1 e2) =
  do
    ce1 <- cgenExp e1
    ce2 <- cgenExp e2
    lteq ce1 ce2
cgenExp (EGtEq e1 e2) =
  do
    ce1 <- cgenExp e1
    ce2 <- cgenExp e2
    gteq ce1 ce2
cgenExp (EEq e1 e2) =
  do
    ce1 <- cgenExp e1
    ce2 <- cgenExp e2
    eq ce1 ce2
cgenExp (ENEq e1 e2) =
  do
    ce1 <- cgenExp e1
    ce2 <- cgenExp e2
    neq ce1 ce2
cgenExp (EAnd e1 e2) =
  do
    ce1 <- cgenExp e1
    ce2 <- cgenExp e2
    eand ce1 ce2
cgenExp (EOr e1 e2) =
  do
    ce1 <- cgenExp e1
    ce2 <- cgenExp e2
    eand ce1 ce2

cgenExp (EAss e1 e2) =
  do
    a <- cgenExp e1
    cval <- cgenExp e2
    store a cval
    return cval


-------------------------------------------------------------------------------
-- Compilation
-------------------------------------------------------------------------------

liftError :: ExceptT String IO a -> IO a
liftError = runExceptT >=> either fail return

-- Entry point
codegen :: AST.Module -> Program -> IO AST.Module
codegen mod (PDefs fns) = withContext $ \context ->
  liftError $ withModuleFromAST context newast $ \m -> do
    llstr <- moduleLLVMAssembly m
    putStrLn llstr
    return newast
  where
    modn    = mapM codegenTop fns
    newast  = runLLVM mod modn

-------------------------------------------------------------------------------
-- Module Level
-------------------------------------------------------------------------------

newtype LLVM a = LLVM { unLLVM :: State AST.Module a }
  deriving (Functor, Applicative, Monad, MonadState AST.Module )

runLLVM :: AST.Module -> LLVM a -> AST.Module
runLLVM = flip (execState . unLLVM)

emptyModule :: String -> AST.Module
emptyModule label = defaultModule { moduleName = label }

-- Adds a definition
addDefn :: Definition -> LLVM ()
addDefn d = do
  defs <- gets moduleDefinitions
  modify $ \s -> s { moduleDefinitions = defs ++ [d] }

idToStr :: Id -> String
idToStr (Id str) = str

-- Defines a function as global
define ::  AST.Type -> Id -> [(AST.Type, Name)] -> [BasicBlock] -> LLVM ()
define retty label argtys body = addDefn $
  GlobalDefinition $ functionDefaults {
    name        = Name (idToStr label)
  , parameters  = ([Parameter ty nm [] | (ty, nm) <- argtys], False)
  , returnType  = retty
  , basicBlocks = body
  }


-------------------------------------------------------------------------------
-- Names
-------------------------------------------------------------------------------

type Names = Map.Map String Int

uniqueName :: String -> Names -> (String, Names)
uniqueName nm ns =
  case Map.lookup nm ns of
    Nothing -> (nm,  Map.insert nm 1 ns)
    Just ix -> (nm ++ show ix, Map.insert nm (ix+1) ns)

instance IsString Name where
  fromString = Name . fromString

-------------------------------------------------------------------------------
-- Codegen State
-------------------------------------------------------------------------------

type SymbolTable = [(String, Operand)]

data CodegenState
  = CodegenState {
    currentBlock :: Name                     -- Name of the active block to append to
  , blocks       :: Map.Map Name BlockState  -- Blocks for function
  , symtab       :: SymbolTable              -- Function scope symbol table
  , blockCount   :: Int                      -- Count of basic blocks
  , count        :: Word                     -- Count of unnamed instructions
  , names        :: Names                    -- Name Supply
  } deriving Show

data BlockState
  = BlockState {
    idx   :: Int                            -- Block index
  , stack :: [Named Instruction]            -- Stack of instructions
  , term  :: Maybe (Named Terminator)       -- Block terminator
  } deriving Show

-------------------------------------------------------------------------------
-- Codegen Operations
-------------------------------------------------------------------------------

newtype Codegen a = Codegen { runCodegen :: State CodegenState a }
  deriving (Functor, Applicative, Monad, MonadState CodegenState )

sortBlocks :: [(Name, BlockState)] -> [(Name, BlockState)]
sortBlocks = sortBy (compare `on` (idx . snd))

createBlocks :: CodegenState -> [BasicBlock]
createBlocks m = map makeBlock $ sortBlocks $ Map.toList (blocks m)

makeBlock :: (Name, BlockState) -> BasicBlock
makeBlock (l, (BlockState _ s t)) = BasicBlock l s (maketerm t)
  where
    maketerm (Just x) = trace ("Created block: "++ show x) x
    maketerm Nothing = error $ "Block has no terminator: " ++ (show l) ++ " instructions: " ++ show t

entryBlockName :: String
entryBlockName = "entry"

emptyBlock :: Int -> BlockState
emptyBlock i = BlockState i [] Nothing

emptyCodegen :: CodegenState
emptyCodegen = CodegenState (Name entryBlockName) Map.empty [] 1 0 Map.empty

execCodegen :: Codegen a -> CodegenState
execCodegen m = execState (runCodegen m) emptyCodegen

fresh :: Codegen Word
fresh = do
  i <- gets count
  modify $ \s -> s { count = 1 + i }
  return $ i + 1

-- Add action to current block
instr :: Instruction -> AST.Type -> Codegen (Operand)
instr ins t = do
  n <- fresh
  instrNamed ins t $ UnName n


instrNamed :: Instruction -> AST.Type -> AST.Name -> Codegen (Operand)
instrNamed ins t name = trace ("Adding instruction " ++ trunc (show ins) ++ " of type " ++ show t) $ do
  n <- fresh
  let ref = name
  blk <- current
  let i = stack blk
  modifyBlock (blk { stack = i ++ [ref := ins] } )

  return $ local ref t


-- Terminate current block
terminator :: Named Terminator -> Codegen (Named Terminator)
terminator trm = trace ("Adding terminator " ++ trunc (show trm)) $ do
  blk <- current
  modifyBlock (blk { term = Just trm })
  return trm

-------------------------------------------------------------------------------
-- Block Stack
-------------------------------------------------------------------------------

entry :: Codegen Name
entry = gets currentBlock

addBlock :: String -> Codegen Name
addBlock bname = do
  bls <- gets blocks
  ix <- gets blockCount
  nms <- gets names
  let new = emptyBlock ix
      (qname, supply) = uniqueName bname nms
  modify $ \s -> s { blocks = Map.insert (Name qname) new bls
                   , blockCount = ix + 1
                   , names = supply
                   }
  return (Name qname)

-- Sets a named block as current block
setBlock :: Name -> Codegen Name
setBlock bname = do
  modify $ \s -> s { currentBlock = bname }
  return bname

getBlock :: Codegen Name
getBlock = gets currentBlock

modifyBlock :: BlockState -> Codegen ()
modifyBlock new = do
  active <- gets currentBlock
  modify $ \s -> s { blocks = Map.insert active new (blocks s) }

current :: Codegen BlockState
current = do
  c <- gets currentBlock
  blks <- gets blocks
  case Map.lookup c blks of
    Just x -> return x
    Nothing -> error $ "No such block: " ++ show c

-------------------------------------------------------------------------------
-- Symbol Table
-------------------------------------------------------------------------------

-- Associates a variable with a specified id
assign :: String -> Operand -> Codegen ()
assign var x = do
  lcls <- gets symtab
  modify $ \s -> s { symtab = [(var, x)] ++ lcls }

-- Returns the variable associated with an id
getvar :: String -> Codegen Operand
getvar var = do
  syms <- gets symtab
  case lookup var syms of
    Just x  -> return x
    Nothing -> error $ "Local variable not in scope: " ++ show var

-------------------------------------------------------------------------------
-- References
-------------------------------------------------------------------------------

-- Creates a local reference
local ::  Name -> AST.Type -> Operand
local n t = LocalReference t n

externf :: Name -> AST.Type -> Operand
externf n t = ConstantOperand ( C.GlobalReference t n)


-------------------------------------------------------------------------------
-- Low Level Code Generation for Operations
-------------------------------------------------------------------------------
performTypedComparison :: Operand -> Operand -> (IP.IntegerPredicate -> Operand -> Operand -> Codegen Operand) -> IP.IntegerPredicate -> (FP.FloatingPointPredicate -> Operand -> Operand -> Codegen Operand) -> FP.FloatingPointPredicate -> Codegen AST.Operand
performTypedComparison op1 op2 integerFunction integerPredicate floatingPointFunction floatingPointPredicate = do
  case typeOfOperand op1 of
    IntegerType _           -> integerFunction integerPredicate op1 op2
    FloatingPointType _ _   -> floatingPointFunction floatingPointPredicate op1 op2


lt :: Operand -> Operand -> Codegen Operand
lt a b = performTypedComparison a b icmp IP.SLT fcmp FP.SLT

gt :: Operand -> Operand -> Codegen Operand
gt a b = performTypedComparison a b icmp IP.SGT fcmp FP.SGT

lteq :: Operand -> Operand -> Codegen Operand
lteq a b = performTypedComparison a b icmp IP.SLE fcmp FP.SLE

gteq :: Operand -> Operand -> Codegen Operand
gteq a b = performTypedComparison a b icmp IP.SGE fcmp FP.SGE

eq :: Operand -> Operand -> Codegen Operand
eq a b = performTypedComparison a b icmp IP.SQ fcmp FP.SEQ

neq :: Operand -> Operand -> Codegen Operand
neq a b = performTypedComparison a b icmp IP.SE fcmp FP.SNE

eand :: Operand -> Operand -> Codegen Operand
eand a b = do
  uitofp double a

eor :: Operand -> Operand -> Codegen Operand
eor a b = do
  uitofp double a

fadd :: Operand -> Operand -> Codegen Operand
fadd a b = instr (FAdd NoFastMathFlags a b []) double

iadd :: Operand -> Operand -> Codegen Operand
iadd a b = instr (Add False False a b []) int

fsub :: Operand -> Operand -> Codegen Operand
fsub a b = instr (FSub NoFastMathFlags a b []) double

isub :: Operand -> Operand -> Codegen Operand
isub a b = instr (Sub False False a b []) int

fmul :: Operand -> Operand -> Codegen Operand
fmul a b = instr (FMul NoFastMathFlags a b []) double

imul :: Operand -> Operand -> Codegen Operand
imul a b = instr (Mul False False a b []) int

fdiv :: Operand -> Operand -> Codegen Operand
fdiv a b = instr (FDiv NoFastMathFlags a b []) double

idiv :: Operand -> Operand -> Codegen Operand
idiv a b = instr (SDiv True a b []) int

fcmp :: FP.FloatingPointPredicate -> Operand -> Operand -> Codegen Operand
fcmp cond a b = instr (FCmp cond a b []) int

icmp :: IP.IntegerPredicate -> Operand -> Operand -> Codegen Operand
icmp cond a b = instr (ICmp cond a b []) int

cons :: C.Constant -> Operand
cons = ConstantOperand

uitofp :: AST.Type -> Operand -> Codegen Operand
uitofp ty a = instr (UIToFP a ty []) double


toArgs :: [Operand] -> [(Operand, [A.ParameterAttribute])]
toArgs = map (\x -> (x, []))

-------------------------------------------------------------------------------
-- Low Level Code Generation for Calls, Variable declarations
-------------------------------------------------------------------------------

call :: Operand -> [Operand] -> Codegen Operand
call fn args = instr (Call Nothing CC.C [] (Right fn) (toArgs args) [] []) $ typeOfOperand fn -- TODO Get return type

-- Creates variable of provided type
alloca :: AST.Type -> Codegen Operand
alloca ty = instr (Alloca ty Nothing 0 []) ty

allocNamed :: AST.Type -> AST.Name -> Codegen Operand
allocNamed ty name = instrNamed (Alloca ty Nothing 0 []) ty name


-- Stores value in a variable reference
store :: Operand -> Operand -> Codegen Operand
store ptr val = instr (Store False ptr val Nothing 0 []) $ typeOfOperand val

-- Loads variable reference
load :: Operand -> Codegen Operand
load ptr = instr (Load False ptr Nothing 0 []) $ typeOfOperand ptr

-------------------------------------------------------------------------------
-- Low Level Code Generation for Control Flow operations
-------------------------------------------------------------------------------

-- Unconditional branching
br :: Name -> Codegen (Named Terminator)
br val = terminator $ Do $ Br val []

-- Conditional branching
cbr :: Operand -> Name -> Name -> Codegen (Named Terminator)
cbr cond tr fl = terminator $ Do $ CondBr cond tr fl []

-- Return from a function with return value
ret :: Operand -> Codegen (Named Terminator)
ret val = terminator $ Do $ Ret (Just val) []

-- Return from a void function
retVoid :: Codegen (Named Terminator)
retVoid = terminator $ Do $ Ret Nothing []
