-- * Compiler cnstruction exercise 3 - Type Checker
-- * Definition of a type checker for a C++ subset defined in ../CPP.cf
-- * Textual description available at http://www1.digitalgrammars.com/ipl-book/assignments/assignment2/assignment2.html
-- * Authors
-- *
-- *   - Ruslan Tumarkin
-- *   - Benno Lauther
-- * 
-- * TODO: Extend Environment by function definitions à la "Id [Type] Type" in first run
-- * TODO: Typecheck each function in the resulting Environment

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
    DFun t id arguments statements -> fail "Not yet implemented"-- add function definition to environment
    -- TODO: extend environment for each argument 
    -- TODO: check statements in the resulting environment

-- Checks a list of statements 
checkStatements :: Environment -> [Stm] -> Err ()
checkStatements environment [] = return ()
checkStatements environment (currentStm:rest) = 
  do  newEnvironment <- checkStatement environment currentStm
      checkStatements newEnvironment rest

checkStatement  :: Environment -> Stm -> Err Environment
checkStatement environment statement  = 
  case statement of
      SExp exp                -> fail "Not yet implemented"
      SDecls t ids            -> addVariables environment ids t -- add variables to environment
      SInit t id exp          -> fail "Not yet implemented"
      SReturn exp             -> fail "Not yet implemented"
      SReturnVoid             -> fail "Not yet implemented"
      SWhile exp stm          -> fail "Not yet implemented"
      SBlock stms             -> fail "Not yet implemented"
      SIfElse exp stm1 stm2   -> fail "Not yet implemented"


checkExpression :: Environment -> Exp -> Type -> Err ()
checkExpression environment expression t = 
  do  
    newType <- inferExpression environment expression
    if newType /= t
      then fail (printTree expression ++ " has type " ++ printTree newType ++ " expected " ++ printTree t)
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
    ETyped expression t -> fail "Not yet implemented"



failOperandTypesNotEqual:: Exp -> Type -> Exp -> Type -> Err Type
failOperandTypesNotEqual e1 t1 e2 t2 = 
  fail (printTree e1 ++ " has type " ++ printTree t1 ++ " but " ++ printTree e2 ++ " has type " ++ printTree t2)

failure :: Show a => a -> Result
failure x = Bad $ "Undefined case: " ++ show x

data FunctionType 
  = Type_function Id [Type] Type

type Environment = [[(Id, Type)]] -- List of list of ids+types
emptyEnvironment :: Environment
emptyEnvironment = [[]]


addVariables :: Environment -> [Id] -> Type -> Err Environment
addVariables environment [] _ = Ok environment
addVariables environment (currentId:rest) t = 
  case addVariable environment currentId t of
    Ok  newEnvironment -> addVariables newEnvironment rest t


addVariable :: Environment -> Id -> Type -> Err Environment
addVariable (scope:rest) id t = 
    case lookup id scope of
      Nothing -> return (((id, t):scope):rest)
      Just _  -> fail ("Variable " ++ printTree id ++ " already declared.")

lookupIdentifier :: Environment -> Id -> Err Type
lookupIdentifier [] id = fail $ "Unknown identifier " ++ printTree id ++ "."
lookupIdentifier (scope:rest) id = 
  case lookup id scope of
    Nothing  -> lookupIdentifier rest id
    Just t  -> return t

addScope :: Environment -> Environment
addScope env = []:env -- Push new scope

