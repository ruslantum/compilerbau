{-# LANGUAGE GeneralizedNewtypeDeriving #-}

module InterpreterCPP where


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

iOne = cons $ C.Int 1 1
iZero = cons $ C.Int 1 0

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

codegenTop :: Def -> LLVM()
codegenTop (DFun returnType id arguments statements) =
  do
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
        forM argumentsAST $ \(astType, astName) -> do
          case astName of -- an arguments is always named
            Name strName ->
              do
                var <- alloca astType
                store var (local (astName))
                assign strName var

        forM statements $ \(statement) -> do
          cgen statement >>= ret



{-codegenTop :: S.Expr -> LLVM ()
codegenTop (S.Function name args body) = do
  define double name fnargs bls
  where
    fnargs = toSig args
    bls = createBlocks $ execCodegen $ do
      entry <- addBlock entryBlockName
      setBlock entry
      forM args $ \a -> do
        var <- alloca double
        store var (local (AST.Name a))
        assign a var
      cgen body >>= ret

codegenTop (S.Extern name args) = do
  external double name fnargs
  where fnargs = toSig args

codegenTop exp = do
  define double "main" [] blks
  where
    blks = createBlocks $ execCodegen $ do
      entry <- addBlock entryBlockName
      setBlock entry
      cgen exp >>= ret
-}
-------------------------------------------------------------------------------
-- Operations
-------------------------------------------------------------------------------

lt :: AST.Operand -> AST.Operand -> Codegen AST.Operand
lt a b = do
  test <- fcmp FP.ULT a b
  uitofp double test

gt :: AST.Operand -> AST.Operand -> Codegen AST.Operand
gt a b = do
  test <- fcmp FP.UGT a b
  uitofp double test

lteq :: AST.Operand -> AST.Operand -> Codegen AST.Operand
lteq a b = do
  test <- fcmp FP.ULE a b
  uitofp double test

gteq :: AST.Operand -> AST.Operand -> Codegen AST.Operand
gteq a b = do
  test <- fcmp FP.UGE a b
  uitofp double test

eq :: AST.Operand -> AST.Operand -> Codegen AST.Operand
eq a b = do
  test <- fcmp FP.UEQ a b
  uitofp double test

neq :: AST.Operand -> AST.Operand -> Codegen AST.Operand
neq a b = do
  test <- fcmp FP.UNE a b
  uitofp double test

eand :: AST.Operand -> AST.Operand -> Codegen AST.Operand
eand a b = do
  uitofp double a

eor :: AST.Operand -> AST.Operand -> Codegen AST.Operand
eor a b = do
  uitofp double a



cgenBlock :: [Stm] -> Codegen AST.Operand
cgenBlock statements = last (map (\stm -> cgen stm) statements)

cgen :: Stm -> Codegen AST.Operand

{- STATEMENT-LEVEL CODE GENERATION -}

cgen (SExp e) = cgenExp e

cgen (SBlock statements) = cgenBlock statements

cgen (SIfElse condition trueStatements falseStatements) =
  do
    thenBlock <- addBlock "if.then"
    elseBlock <- addBlock "if.else"
    continueBlock <- addBlock "if.exit"

    -- Generate conditional jump
    conditionCode   <- cgenExp condition
    test            <- icmp IP.NE iZero conditionCode -- True if condition != 0
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
    return iZero

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
    test          <- icmp IP.NE iZero conditionCode -- True if condition != 0
    cbr test loopBlock continueBlock

    -- Generate code for loop block
    setBlock loopBlock
    cgen statements   -- Execute statements
    br testBlock      -- Then test for next loop

    -- Continue code generation in continueBlock
    setBlock continueBlock
    return iZero


{- EXPRESSION-LEVEL CODE GENERATION -}
cgenExp :: Exp -> Codegen AST.Operand
cgenExp (ETrue)        = return $ cons $ C.Int 1 1
cgenExp (EFalse)       = return $ cons $ C.Int 1 1
cgenExp (EInt i)       = return $ cons $ C.Int 32 i
cgenExp (EDouble d)    = return $ cons $ C.Float (F.Double d)
cgenExp (EId id)       = getvar (idToStr id) >>= load
{- TODO: Implement function call
cgen (EApp id args) =
  do
    largs <- mapM cgen args
    call (externf (AST.Name fn)) largs)
-}
{- TODO: Implement
cgenExp (EPIncr e)   =
cgenExp (EPDecr e)   =
cgenExp (EIncr e)   =
cgenExp (EDecr e)   =
-}
cgenExp (ETimes e1 e2)  =
  do
    ce1 <- cgenExp e1
    ce2 <- cgenExp e2
    fmul ce1 ce2
cgenExp (EDiv e1 e2)  =
  do
    ce1 <- cgenExp e1
    ce2 <- cgenExp e2
    fdiv ce1 ce2
cgenExp (EPlus e1 e2)  =
  do
    ce1 <- cgenExp e1
    ce2 <- cgenExp e2
    fadd ce1 ce2
cgenExp (EMinus e1 e2)  =
  do
    ce1 <- cgenExp e1
    ce2 <- cgenExp e2
    fsub ce1 ce2
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

addDefn :: Definition -> LLVM ()
addDefn d = do
  defs <- gets moduleDefinitions
  modify $ \s -> s { moduleDefinitions = defs ++ [d] }

idToStr :: Id -> String
idToStr (Id str) = str

define ::  AST.Type -> Id -> [(AST.Type, Name)] -> [BasicBlock] -> LLVM ()
define retty label argtys body = addDefn $
  GlobalDefinition $ functionDefaults {
    name        = Name (idToStr label)
  , parameters  = ([Parameter ty nm [] | (ty, nm) <- argtys], False)
  , returnType  = retty
  , basicBlocks = body
  }

external ::  AST.Type -> String -> [(AST.Type, Name)] -> LLVM ()
external retty label argtys = addDefn $
  GlobalDefinition $ functionDefaults {
    name        = Name label
  , parameters  = ([Parameter ty nm [] | (ty, nm) <- argtys], False)
  , returnType  = retty
  , basicBlocks = []
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
    maketerm (Just x) = x
    maketerm Nothing = error $ "Block has no terminator: " ++ (show l)

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

instr :: Instruction -> Codegen (Operand)
instr ins = do
  n <- fresh
  let ref = (UnName n)
  blk <- current
  let i = stack blk
  trace ("added instruction: " ++ show ins ++ " to block " ++ show blk) (modifyBlock (blk { stack = i ++ [ref := ins] } ))

  return $ local ref

terminator :: Named Terminator -> Codegen (Named Terminator)
terminator trm = do
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

assign :: String -> Operand -> Codegen ()
assign var x = do
  lcls <- gets symtab
  modify $ \s -> s { symtab = [(var, x)] ++ lcls }

getvar :: String -> Codegen Operand
getvar var = do
  syms <- gets symtab
  case lookup var syms of
    Just x  -> return x
    Nothing -> error $ "Local variable not in scope: " ++ show var

-------------------------------------------------------------------------------

-- References
local ::  Name -> Operand
local = LocalReference double

global ::  Name -> C.Constant
global = C.GlobalReference double

externf :: Name -> Operand
externf = ConstantOperand . C.GlobalReference double

-- Arithmetic and Constants

fadd :: Operand -> Operand -> Codegen Operand
fadd a b = instr $ FAdd NoFastMathFlags a b []

fsub :: Operand -> Operand -> Codegen Operand
fsub a b = instr $ FSub NoFastMathFlags a b []

fmul :: Operand -> Operand -> Codegen Operand
fmul a b = instr $ FMul NoFastMathFlags a b []

fdiv :: Operand -> Operand -> Codegen Operand
fdiv a b = instr $ FDiv NoFastMathFlags a b []

fcmp :: FP.FloatingPointPredicate -> Operand -> Operand -> Codegen Operand
fcmp cond a b = instr $ FCmp cond a b []

icmp :: IP.IntegerPredicate -> AST.Operand -> AST.Operand -> Codegen AST.Operand
icmp cond a b = instr $ ICmp cond a b []

cons :: C.Constant -> Operand
cons = ConstantOperand

uitofp :: AST.Type -> Operand -> Codegen Operand
uitofp ty a = instr $ UIToFP a ty []

toArgs :: [Operand] -> [(Operand, [A.ParameterAttribute])]
toArgs = map (\x -> (x, []))

-- Effects
call :: Operand -> [Operand] -> Codegen Operand
call fn args = instr $ Call Nothing CC.C [] (Right fn) (toArgs args) [] []

alloca :: AST.Type -> Codegen Operand
alloca ty = instr $ Alloca ty Nothing 0 []

store :: Operand -> Operand -> Codegen Operand
store ptr val = instr $ Store False ptr val Nothing 0 []

load :: Operand -> Codegen Operand
load ptr = instr $ Load False ptr Nothing 0 []

-- Control Flow
br :: Name -> Codegen (Named Terminator)
br val = terminator $ Do $ Br val []

cbr :: Operand -> Name -> Name -> Codegen (Named Terminator)
cbr cond tr fl = terminator $ Do $ CondBr cond tr fl []

ret :: Operand -> Codegen (Named Terminator)
ret val = terminator $ Do $ Ret (Just val) []
