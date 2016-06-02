-- * Compiler cnstruction exercise 3 - Type Checker
-- * Definition of a type checker for a C++ subset defined in ../CPP.cf
-- * Textual description available at http://www1.digitalgrammars.com/ipl-book/assignments/assignment2/assignment2.html
-- * Authors
-- *
-- *   - Ruslan Tumarkin
-- *   - Benno Lauther

module TypeCheckerCPP where


import PrintCPP
import AbsCPP
import ErrM

type Result = Err String


-- Entry point to typecheck a program
typecheck   :: Program -> Err ()
typecheck (PDefs definitions) = checkDefinitions emptyEnvironment definitions


checkDefinitions :: Environment -> [Def] -> Err()
checkDefinitions environment [] = return ()
checkDefinitions environment (currentDef: rest) = 
  do 
    newEnvironment <- checkDefinition environment currentDef
    checkDefinitions newEnvironment rest

checkDefinition :: Environment -> Def -> Err Environment
checkDefinition environment definition = 
  case definition of 
    DFun tp id arguments statements -> fail "Not yet implemented"-- add function definition to environment


checkStatements :: Environment -> [Stm] -> Err ()
checkStatements environment [] = return ()
checkStatements environment (currentStm:rest) = 
  do  newEnvironment <- checkStatement environment currentStm
      checkStatements newEnvironment rest

checkStatement  :: Environment -> Stm -> Err Environment
checkStatement environment statement  = 
  case statement of
      SExp exp                -> fail "Not yet implemented"
      SDecls t ids            -> fail "Not yet implemented" -- add to env
      SInit t id exp          -> fail "Not yet implemented"
      SReturn exp             -> fail "Not yet implemented"
      SReturnVoid             -> fail "Not yet implemented"
      SWhile exp stm          -> fail "Not yet implemented"
      SBlock stms             -> fail "Not yet implemented"
      SIfElse exp stm1 stm2   -> fail "Not yet implemented"


checkExpression :: Environment -> Exp -> Type -> Err ()
checkExpression environment expression tp = 
  do  
    newType <- inferExpression environment expression
    if newType /= tp
      then fail (printTree expression ++ " has type " ++ printTree newType ++ " expected " ++ printTree tp)
      else return ()

-- Ensures two expressions are of equal type
-- Results in an expression of the type of the first expression
ensureEqualTypes :: Environment -> Exp -> Exp -> Err Type 
ensureEqualTypes environment e1 e2 = 
  do
    e1Type <- inferExpression environment e1 
    e2Type <- inferExpression environment e2 
    if e1Type == e2Type 
      then return e1Type
      else failOperandTypesNotEqual e1 e1Type e2 e2Type

-- Ensures two expressions are of equal type
-- Results in an expression of type finalType
ensureEqualTypesReturnResultType :: Environment -> Exp -> Exp -> Type -> Err Type
ensureEqualTypesReturnResultType environment e1 e2 finalType =
  do
    e1Type <- inferExpression environment e1 
    e2Type <- inferExpression environment e2 
    if e1Type == e2Type 
      then return finalType
      else failOperandTypesNotEqual e1 e1Type e2 e2Type

inferExpression :: Environment -> Exp -> Err Type 
inferExpression environment expression = 
  case expression of
    ETrue               -> return Type_bool
    EFalse              -> return Type_bool
    EInt _              -> return Type_int
    EDouble _           -> return Type_double
    EString _           -> return Type_string
    EId id              -> fail "Not yet implemented"
    EApp id expressions -> fail "Not yet implemented"
    EPIncr expression   -> inferExpression environment expression
    EPDecr expression   -> inferExpression environment expression
    EIncr expression    -> inferExpression environment expression
    EDecr expression    -> inferExpression environment expression
    ETimes e1 e2        -> ensureEqualTypes environment e1 e2
    EDiv e1 e2          -> ensureEqualTypes environment e1 e2
    EPlus e1 e2         -> ensureEqualTypes environment e1 e2
    EMinus e1 e2        -> ensureEqualTypes environment e1 e2
    ELt e1 e2           -> ensureEqualTypesReturnResultType environment e1 e2 Type_bool
    EGt e1 e2           -> ensureEqualTypesReturnResultType environment e1 e2 Type_bool
    ELtEq e1 e2         -> ensureEqualTypesReturnResultType environment e1 e2 Type_bool
    EGtEq e1 e2         -> ensureEqualTypesReturnResultType environment e1 e2 Type_bool
    EEq e1 e2           -> ensureEqualTypesReturnResultType environment e1 e2 Type_bool
    ENEq e1 e2          -> ensureEqualTypesReturnResultType environment e1 e2 Type_bool
    EAnd e1 e2          -> ensureEqualTypesReturnResultType environment e1 e2 Type_bool
    EOr e1 e2           -> ensureEqualTypesReturnResultType environment e1 e2 Type_bool
    EAss e1 e2          -> ensureEqualTypes environment e1 e2
    ETyped expression tp -> fail "Not yet implemented"



failOperandTypesNotEqual:: Exp -> Type -> Exp -> Type -> Err Type
failOperandTypesNotEqual e1 t1 e2 t2 = 
  fail (printTree e1 ++ " has type " ++ printTree t1 ++ " but " ++ printTree e2 ++ " has type " ++ printTree t2)

failure :: Show a => a -> Result
failure x = Bad $ "Undefined case: " ++ show x

transId :: Id -> Result
transId x = case x of
  Id string -> failure x
transProgram :: Program -> Result
transProgram x = case x of
  PDefs defs -> failure x
transDef :: Def -> Result
transDef x = case x of
  DFun type_ id args stms -> failure x
transArg :: Arg -> Result
transArg x = case x of
  ADecl type_ id -> failure x
transStm :: Stm -> Result
transStm x = case x of
  SExp exp -> failure x
  SDecls type_ ids -> failure x
  SInit type_ id exp -> failure x
  SReturn exp -> failure x
  SReturnVoid -> failure x
  SWhile exp stm -> failure x
  SBlock stms -> failure x
  SIfElse exp stm1 stm2 -> failure x
transExp :: Exp -> Result
transExp x = case x of
  ETrue -> failure x
  EFalse -> failure x
  EInt integer -> failure x
  EDouble double -> failure x
  EString string -> failure x
  EId id -> failure x
  EApp id exps -> failure x
  EPIncr exp -> failure x
  EPDecr exp -> failure x
  EIncr exp -> failure x
  EDecr exp -> failure x
  ETimes exp1 exp2 -> failure x
  EDiv exp1 exp2 -> failure x
  EPlus exp1 exp2 -> failure x
  EMinus exp1 exp2 -> failure x
  ELt exp1 exp2 -> failure x
  EGt exp1 exp2 -> failure x
  ELtEq exp1 exp2 -> failure x
  EGtEq exp1 exp2 -> failure x
  EEq exp1 exp2 -> failure x
  ENEq exp1 exp2 -> failure x
  EAnd exp1 exp2 -> failure x
  EOr exp1 exp2 -> failure x
  EAss exp1 exp2 -> failure x
  ETyped exp type_ -> failure x
transType :: Type -> Result
transType x = case x of
  Type_bool -> failure x
  Type_int -> failure x
  Type_double -> failure x
  Type_void -> failure x
  Type_string -> failure x


type Environment = [[(Id, Type)]] -- List of list of ids+types
emptyEnvironment :: Environment
emptyEnvironment = [[]]

addVariable :: Environment -> Id -> Type -> Err Environment
addVariable (scope:rest) id tp = 
    case lookup id scope of
      Nothing -> return (((id, tp):scope):rest)
      Just _  -> fail ("Variable " ++ printTree id ++ " already declared.")

lookupIdentifier :: Environment -> Id -> Err Type
lookupIdentifier [] id = fail $ "Unknown identifier " ++ printTree id ++ "."
lookupIdentifier (scope:rest) id = 
  case lookup id scope of
    Nothing  -> lookupIdentifier rest id
    Just tp  -> return tp

addScope :: Environment -> Environment
addScope env = []:env -- Push new scope

